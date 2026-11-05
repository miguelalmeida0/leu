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
    assert.equal(await page.getByRole('button', { name: 'Original page', exact: true }).getAttribute('aria-pressed'), 'true', 'Original PDF is the default')
    await page.getByRole('button', { name: 'For reading', exact: true }).click()
    await page.getByRole('button', { name: 'For reading', exact: true }).click()
    await page.locator('.reader-paper .prose p').first().waitFor()
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
    const displaySize = await page.locator('h1').evaluate(el => getComputedStyle(el).fontSize)
    for (const route of ['notes', 'explore']) {
      await page.goto(base + '/#/' + route)
      await page.locator('h1, .empty .display').waitFor()
      assert.equal(await page.locator('h1, .empty .display').evaluate(el => getComputedStyle(el).fontSize), displaySize, route + ': shared display token')
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2), false, route + ': no overflow')
    }
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
    await page.getByRole('button', { name: 'For reading', exact: true }).click()
    await page.locator('.reader-paper .prose p').first().waitFor()
    const focus = page.getByRole('button', { name: 'Enter full-screen reading' })
    const focusBox = await focus.boundingBox()
    assert.ok(focusBox && focusBox.y < 150, `${name}: fullscreen belongs in the top toolbar`)
    const geometry = await page.evaluate(() => ({
      textBottom: document.querySelector('.reader-grid').getBoundingClientRect().bottom,
      footerTop: document.querySelector('.reader-foot').getBoundingClientRect().top,
    }))
    assert.ok(geometry.textBottom <= geometry.footerTop + 1, `${name}: footer never overlays text (${JSON.stringify(geometry)})`)
    const foot = await page.locator('.reader-foot').boundingBox()
    assert.ok(Math.abs(foot.y + foot.height - page.viewportSize().height) < 2, 'Reader footer reaches viewport bottom')
    const viewport = page.viewportSize()
    await page.setViewportSize({ ...viewport, height: viewport.height - 140 })
    await page.waitForFunction(() => Math.abs(document.querySelector('.reader-foot').getBoundingClientRect().bottom - innerHeight) < 2)
    await page.setViewportSize(viewport)
    await page.waitForFunction(() => Math.abs(document.querySelector('.reader-foot').getBoundingClientRect().bottom - innerHeight) < 2)
    await capture('reader')
    const scrolled = await page.locator('.reader-grid').evaluate((node) => {
      node.scrollTop = node.scrollHeight
      return node.scrollTop
    })
    if (width <= 430) assert.ok(scrolled > 0, 'Exercise page reset from an actually scrolled reading region')
    await page.getByRole('button', { name: 'Next page', exact: true }).click()
    await page.locator('.reader-paper[aria-label="Page 2 of 4"]').waitFor()
    assert.equal(await page.locator('.reader-grid').evaluate((node) => node.scrollTop), 0, 'A new page starts at the top')
    await page.getByRole('button', { name: 'Reading settings', exact: true }).click()
    await page.getByRole('button', { name: 'Zoom in', exact: true }).click()
    assert.equal(await page.getByRole('button', { name: 'Reset zoom' }).textContent(), '125%')
    await page.keyboard.press('Escape')
    await page.getByRole('button', { name: 'Original page', exact: true }).click()
    await page.locator('.original-stage canvas').waitFor()
    await page.getByRole('button', { name: 'For reading', exact: true }).click()
    const beforeFocusScroll = await page.locator('.reader-grid').evaluate((node) => {
      node.scrollTop = Math.min(150, node.scrollHeight - node.clientHeight)
      return node.scrollTop
    })
    await focus.focus()
    await page.keyboard.press('Enter')
    await page.locator('.reader-immersive').waitFor()
    await page.keyboard.press('Escape')
    await page.locator('.reader-immersive').waitFor({ state: 'hidden' })
    assert.equal(await focus.evaluate((node) => document.activeElement === node), true, 'Escape restores keyboard focus to the fullscreen entry')
    assert.ok(Math.abs(await page.locator('.reader-grid').evaluate((node) => node.scrollTop) - beforeFocusScroll) <= 1,
      'Fullscreen restores the normal reading position on the same PDF page')
    await page.getByRole('button', { name: 'Open navigation', exact: true }).click()
    await page.getByRole('navigation', { name: 'Mobile places' }).getByRole('link', { name: 'Library', exact: true }).click()
    await page.getByText('4 pages · Page 2', { exact: true }).waitFor()
    assert.deepEqual(errors, [], `${name}: no runtime errors`)
    console.log(`PASS ${name}: Home → Library → Reader, filters/search, saved progress, settings, original default, top fullscreen, shared tokens, no text overlap`)
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
