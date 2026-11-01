import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdir } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { chromium, webkit } from 'playwright'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const base = 'http://127.0.0.1:4186'
const evidence = join(root, 'qa-evidence/design')
await mkdir(evidence, { recursive: true })
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', 'preview', '--host', '127.0.0.1', '--port', '4186', '--strictPort'], { cwd: root, stdio: 'ignore' })

async function assertPlainExit(button, name) {
  await button.waitFor({ state: 'visible' })
  assert.equal((await button.textContent()).trim(), '', `${name}: fullscreen exit is an icon, not a Done label`)
  assert.equal(await button.locator('svg').count(), 1, `${name}: fullscreen exit has one close icon`)
  const appearance = await button.evaluate((node) => {
    const style = getComputedStyle(node), box = node.getBoundingClientRect()
    return { background: style.backgroundColor, image: style.backgroundImage,
      border: parseFloat(style.borderTopWidth), shadow: style.boxShadow,
      width: box.width, height: box.height }
  })
  assert.ok(appearance.background === 'transparent' || /rgba\([^)]*,\s*0\)$/.test(appearance.background),
    `${name}: fullscreen exit must not have a colored container: ${JSON.stringify(appearance)}`)
  assert.equal(appearance.image, 'none', `${name}: exit has no decorative background`)
  assert.equal(appearance.border, 0, `${name}: exit has no container border`)
  assert.equal(appearance.shadow, 'none', `${name}: exit has no container shadow`)
  assert.ok(appearance.width >= 44 && appearance.height >= 44,
    `${name}: the plain close icon retains a usable invisible touch target`)
}

async function journey(engine, width, reducedMotion) {
  const browser = await engine.launch({ headless: true })
  const page = await browser.newPage({ viewport: { width, height: width > 720 ? 900 : 844 }, deviceScaleFactor: 1, isMobile: width <= 430, hasTouch: width <= 430, reducedMotion })
  const errors = []
  page.on('pageerror', (error) => errors.push(error.message))
  const name = `${engine.name()}-${width}-${reducedMotion}`
  const capture = async (screen) => page.screenshot({ path: join(evidence, `${name}-${screen}.png`) })
  try {
    await page.goto(base)
    await page.getByRole('button', { name: /start with a sample book/i }).click()
    await page.getByRole('button', { name: 'Open Computer Science Essentials', exact: true }).click()
    if (width > 720) {
      await page.waitForFunction(() => (document.querySelector('.original-stage canvas')?.width ?? 0) > 0)
      await page.waitForFunction(() => {
        const canvas = document.querySelector('.original-stage canvas')
        const sheet = document.querySelector('.reader-paper')
        const midpoint = innerWidth / 2
        return canvas && sheet
          && Math.abs(canvas.getBoundingClientRect().left + canvas.getBoundingClientRect().width / 2 - midpoint) <= 3
          && Math.abs(sheet.getBoundingClientRect().left + sheet.getBoundingClientRect().width / 2 - midpoint) <= 3
      })
      const fitted = await page.evaluate(() => {
        const pdf = document.querySelector('.original-stage canvas').getBoundingClientRect()
        const grid = document.querySelector('.reader-grid').getBoundingClientRect()
        return { pdfBottom: pdf.bottom, readingBottom: grid.bottom,
          hiddenGlobalNavigation: getComputedStyle(document.querySelector('.app > .topbar')).display === 'none' }
      })
      assert.ok(fitted.pdfBottom <= fitted.readingBottom + 2,
        'The complete source PDF must fit above the playback bar: ' + JSON.stringify(fitted))
      assert.equal(fitted.hiddenGlobalNavigation, true, 'Reading has one contextual header')
    }
    if (width <= 720) {
      assert.equal(await page.locator('.reader-bar .segmented').count(), 0, 'Mobile reader shows only the original PDF, with no mode switch')
      await page.locator('.reader-paper canvas').waitFor({ state: 'visible' })
      assert.equal(await page.locator('.app > .topbar').isVisible(), false, 'Global header is not shown while reading')
      await page.getByRole('link', { name: 'Back to book overview' }).waitFor()
      assert.equal(await page.locator('.reader:not(.reader-immersive) .reader-bar button:visible').count(), 2,
        'Mobile reading header offers only chapters and fullscreen')
    } else {
      assert.equal(await page.getByRole('button', { name: 'Original page', exact: true }).getAttribute('aria-pressed'), 'true', 'Original PDF is the default')
      await page.getByRole('button', { name: 'For reading', exact: true }).click()
      await page.locator('.reader-paper .prose p').first().waitFor()
    }
    await page.goto(base + '/#/home')
    await page.locator('.home-scene img').waitFor()
    await page.evaluate(() => document.fonts.ready)
    await page.waitForFunction(() => {
      const canvas = document.querySelector('.nook-glass canvas')
      if (!canvas || !canvas.width || !canvas.height) return false
      const pixels = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data
      for (let n = 0; n < pixels.length; n += 64) if (pixels[n] > 120 || pixels[n + 1] > 120) return true
      return false
    })
    const continueButton = page.getByRole('button', { name: 'Continue reading', exact: true })
    const cta = await continueButton.boundingBox()
    assert.ok(cta && cta.y + cta.height <= page.viewportSize().height, `${name}: Home resume action is visible without scrolling`)
    await capture('home')
    const homeDisplaySize = parseFloat(await page.locator('h1').evaluate(el => getComputedStyle(el).fontSize))
    let sectionDisplaySize = null
    for (const route of ['notes', 'library']) {
      await page.goto(base + '/#/' + route)
      await page.locator('h1, .empty .display').waitFor()
      const displaySize = parseFloat(await page.locator('h1, .empty .display').evaluate(el => getComputedStyle(el).fontSize))
      if (sectionDisplaySize !== null) assert.equal(displaySize, sectionDisplaySize, route + ': shared section display token')
      sectionDisplaySize = displaySize
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2), false, route + ': no overflow')
    }
    if (width > 900) assert.ok(homeDisplaySize <= sectionDisplaySize,
      'Home uses a quieter headline scale without changing other route typography')
    await page.goto(base + '/#/home')
    await page.getByRole('button', { name: 'Your library · 1 book' }).click()
    await page.getByRole('heading', { name: 'Your library', exact: true }).waitFor()
    assert.equal(await page.getByRole('heading', { name: 'Your shelf', exact: true }).count(), 0)
    assert.equal(await page.locator('.library-book').count(), 1)
    const cover = await page.locator('.library-cover-button').boundingBox()
    assert.ok(cover && cover.y + cover.height < page.viewportSize().height, `${name}: book cover appears in first viewport`)
    await capture('library')
    const field = page.getByRole('searchbox', { name: 'Find a book' })
    await field.fill('COMPUTER')
    assert.equal(await page.locator('.library-book').count(), 1)
    await field.fill('no-such-document')
    await page.getByRole('status').filter({ hasText: 'No matching books' }).waitFor()
    assert.equal(await page.locator('.library-book').count(), 0)
    assert.ok(await page.getByRole('button', { name: 'Import a PDF', exact: true }).isVisible())
    await field.fill('')
    await page.getByRole('navigation', { name: 'Book collections' }).getByRole('link', { name: 'Programming 1' }).click()
    assert.equal(await page.locator('.library-book').count(), 1)
    await page.getByRole('button', { name: 'Continue reading', exact: true }).click()
    if (width > 720) {
      await page.getByRole('button', { name: 'For reading', exact: true }).click()
      await page.locator('.reader-paper .prose p').first().waitFor()
    } else await page.locator('.reader-paper canvas').waitFor({ state: 'visible' })
    const focus = page.getByRole('button', { name: 'Enter full-screen reading' })
    if (width <= 720) {
      const backBox = await page.getByRole('link', { name: 'Back to book overview' }).boundingBox()
      const chaptersBox = await page.locator('.reader-bar .contents-trigger').boundingBox()
      const fullScreenBox = await focus.boundingBox()
      assert.ok(backBox && chaptersBox && fullScreenBox
        && Math.abs(backBox.y + backBox.height / 2 - chaptersBox.y - chaptersBox.height / 2) <= 2
        && Math.abs(chaptersBox.y + chaptersBox.height / 2 - fullScreenBox.y - fullScreenBox.height / 2) <= 2,
        'Back, Chapters and Fullscreen must fit in one aligned mobile header row')
    }
    const focusBox = await focus.boundingBox()
    assert.ok(focusBox && focusBox.y < 150, `${name}: fullscreen belongs in the top toolbar`)
    const geometry = await page.evaluate(() => ({
      textBottom: document.querySelector('.reader-grid').getBoundingClientRect().bottom,
      footerTop: document.querySelector('.reader-foot').getBoundingClientRect().top,
    }))
    assert.ok(geometry.textBottom <= geometry.footerTop + 1, `${name}: footer never overlays text (${JSON.stringify(geometry)})`)
    const priority = await page.evaluate(() => {
      const box = (selector) => document.querySelector(selector).getBoundingClientRect()
      const probe = document.createElement('div')
      probe.style.paddingTop = 'env(safe-area-inset-top)'
      document.body.appendChild(probe)
      const safeTop = parseFloat(getComputedStyle(probe).paddingTop) || 0
      probe.remove()
      return { header: box('.topbar').height, toolbar: box('.reader-bar').height,
        footer: box('.reader-foot').height, reading: box('.reader-grid').height,
        viewport: innerHeight, scrollWidth: document.documentElement.scrollWidth,
        safeTop }
    })
    // On an iPhone the single reader header includes the system status-bar inset;
    // measure its usable controls independently of that reserved system space.
    assert.ok(priority.header <= 64 && priority.toolbar - priority.safeTop <= 54 && priority.footer <= 68,
      `${name}: PDF reading must not lose height to oversized fixed chrome (${JSON.stringify(priority)})`)
    assert.ok(priority.reading / priority.viewport >= .70,
      `${name}: PDF area must occupy at least 70% of the viewport (${JSON.stringify(priority)})`)
    assert.ok(priority.scrollWidth <= page.viewportSize().width + 2,
      `${name}: compact controls must not create horizontal overflow`)
    const foot = await page.locator('.reader-foot').boundingBox()
    assert.ok(Math.abs(foot.y + foot.height - page.viewportSize().height) < 2, 'Reader footer reaches viewport bottom')
    const chrome = await page.evaluate(() => ({
      top: document.querySelector('.topbar').getBoundingClientRect().height,
      toolbar: document.querySelector('.reader-bar').getBoundingClientRect().height,
      footer: document.querySelector('.reader-foot').getBoundingClientRect().height,
      text: document.querySelector('.reader-grid').getBoundingClientRect().height,
      viewport: innerHeight,
      overflow: document.documentElement.scrollWidth - innerWidth,
    }))
    assert.ok(chrome.top <= 70 && chrome.toolbar - priority.safeTop <= 58 && chrome.footer <= 70,
      `${name}: reading chrome consumes excessive vertical space ${JSON.stringify(chrome)}`)
    assert.ok(chrome.text >= chrome.viewport * .67 && chrome.overflow <= 2,
      `${name}: PDF reading area must dominate the viewport ${JSON.stringify(chrome)}`)
    const viewport = page.viewportSize()
    await page.setViewportSize({ ...viewport, height: viewport.height - 140 })
    await page.waitForFunction(() => Math.abs(document.querySelector('.reader-foot').getBoundingClientRect().bottom - innerHeight) < 2)
    await page.setViewportSize(viewport)
    await page.waitForFunction(() => Math.abs(document.querySelector('.reader-foot').getBoundingClientRect().bottom - innerHeight) < 2)
    await capture('reader')
    const scrollCheck = await page.locator('.reader-grid').evaluate((node) => {
      const scrollable = node.scrollHeight > node.clientHeight + 2
      node.scrollTop = node.scrollHeight
      return { position: node.scrollTop, scrollable }
    })
    if (width <= 430 && scrollCheck.scrollable) {
      assert.ok(scrollCheck.position > 0, 'Exercise page reset when the original PDF actually overflows')
    }
    await page.getByRole('button', { name: 'Next page', exact: true }).click()
    await page.locator('.reader-paper[aria-label="Page 2 of 4"]').waitFor()
    assert.equal(await page.locator('.reader-grid').evaluate((node) => node.scrollTop), 0, 'A new page starts at the top')
    if (width <= 720) {
      await page.locator('.reader-bar .contents-trigger').click()
      await page.getByRole('dialog', { name: 'Contents' }).getByRole('button', { name: 'Reading settings' }).click()
      await page.getByRole('dialog', { name: 'Reading settings' }).waitFor({ state: 'visible' })
    } else {
      await page.getByRole('button', { name: 'Reading settings', exact: true }).click()
    }
    await page.getByRole('button', { name: 'Zoom in', exact: true }).click()
    assert.equal(await page.getByRole('button', { name: 'Reset zoom' }).textContent(), '125%')
    await page.keyboard.press('Escape')
    if (width > 720) await page.getByRole('button', { name: 'Original page', exact: true }).click()
    await page.locator('.original-stage canvas').waitFor()
    if (width > 720) await page.getByRole('button', { name: 'For reading', exact: true }).click()
    const beforeFocusScroll = await page.locator('.reader-grid').evaluate((node) => {
      node.scrollTop = Math.min(150, node.scrollHeight - node.clientHeight)
      return node.scrollTop
    })
    await focus.focus()
    await page.keyboard.press('Enter')
    await page.locator('.reader-immersive').waitFor()
    const plainExit = page.getByRole('button', { name: 'Exit full-screen reading', exact: true })
    await assertPlainExit(plainExit, name)
    if (width > 720) {
      await plainExit.hover()
      await assertPlainExit(plainExit, name + ' hover')
    }
    await capture('plain-fullscreen-exit')
    await plainExit.click()
    await page.locator('.reader-immersive').waitFor({ state: 'hidden' })
    assert.equal(await focus.evaluate((node) => document.activeElement === node), true, 'Close returns focus to the fullscreen entry')
    await focus.click()
    await page.locator('.reader-immersive').waitFor()
    await page.keyboard.press('Escape')
    await page.locator('.reader-immersive').waitFor({ state: 'hidden' })
    assert.equal(await focus.evaluate((node) => document.activeElement === node), true, 'Escape restores keyboard focus to the fullscreen entry')
    await page.waitForFunction((saved) =>
      Math.abs(document.querySelector('.reader-grid')?.scrollTop - saved) <= 1, beforeFocusScroll)
    assert.ok(Math.abs(await page.locator('.reader-grid').evaluate((node) => node.scrollTop) - beforeFocusScroll) <= 1,
      'Fullscreen restores the normal reading position on the same PDF page')
    if (width <= 720 && beforeFocusScroll > 0) {
      await page.getByRole('button', { name: 'Next page' }).click()
      await page.locator('.reader-paper[aria-label="Page 3 of 4"]').waitFor()
      await page.getByRole('button', { name: 'Previous page' }).click()
      await page.locator('.reader-paper[aria-label="Page 2 of 4"]').waitFor()
      assert.equal(await page.locator('.reader-grid').evaluate((node) => node.scrollTop), 0,
        'The former fullscreen scroll position is not incorrectly replayed on later source page turns')
    }
    if (width > 760) {
      await page.getByRole('link', { name: 'Back to book overview' }).click()
      await page.getByRole('navigation', { name: 'Places' }).getByRole('link', { name: 'Library', exact: true }).click()
    } else {
      await page.getByRole('link', { name: 'Back to book overview' }).click()
      await page.locator('.book-side .side-card').waitFor({ state: 'visible' })
      assert.equal(await page.locator('.book-side .side-block:visible').count(), 0,
        'Mobile book overview has no loose ends, quiz or shelf/trail options below the resume card')
      const deletePdf = page.getByRole('button', { name: 'Delete PDF', exact: true })
      await deletePdf.waitFor({ state: 'visible' })
      assert.equal(await deletePdf.locator('svg[data-icon="material-delete-outline"]').count(), 1,
        'Delete PDF uses the requested Material trash icon')
      assert.equal(await page.locator('.book-side > :visible').count(), 2,
        'Only the white resume card and Delete PDF remain in the mobile book sidebar')
      const booksBefore = await page.evaluate(() => JSON.parse(localStorage.getItem('leu.web.v1')).books.length)
      const confirmation = page.waitForEvent('dialog')
      const clicked = deletePdf.click()
      const dialog = await confirmation
      assert.equal(dialog.type(), 'confirm', 'Deleting a PDF still requires confirmation')
      assert.match(dialog.message(), /Computer Science Essentials/)
      await dialog.dismiss()
      await clicked
      assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('leu.web.v1')).books.length), booksBefore,
        'Cancelling Delete PDF preserves the book')
      await capture('book-actions')
      await page.getByRole('button', { name: 'Open navigation', exact: true }).click()
      await page.getByRole('navigation', { name: 'Mobile places' }).getByRole('link', { name: 'Library', exact: true }).click()
    }
    await page.getByText('4 pages · Page 2', { exact: true }).waitFor()
    assert.deepEqual(errors, [], `${name}: no runtime errors`)
    console.log(`PASS ${name}: Home → Library → Reader, original-only mobile, contextual header, plain fullscreen close, simplified book actions, saved progress and confirmation`)
  } finally { await browser.close() }
}
try {
  for (let n = 0; n < 60; n++) {
    try { if ((await fetch(base)).ok) break } catch {}
    if (n === 59) throw new Error('Preview did not start')
    await new Promise((resolve) => setTimeout(resolve, 200))
  }
  for (const [engine, width, motion] of [[chromium, 1440, 'no-preference'], [chromium, 390, 'reduce'], [webkit, 390, 'no-preference'], [webkit, 320, 'reduce']]) await journey(engine, width, motion)
} finally { server.kill('SIGTERM') }
