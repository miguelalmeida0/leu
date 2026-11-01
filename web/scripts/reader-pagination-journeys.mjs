import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdir } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { chromium, webkit } from 'playwright'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const base = 'http://127.0.0.1:4184'
const evidence = join(root, 'qa-evidence/pagination')
await mkdir(evidence, { recursive: true })
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', 'preview', '--host', '127.0.0.1', '--port', '4184', '--strictPort'], { cwd: root, stdio: 'ignore' })
const configs = [
  [chromium, 'chromium-phone', 390, 844, 'no-preference'],
  [webkit, 'webkit-phone', 390, 844, 'no-preference'],
  [webkit, 'webkit-small', 320, 640, 'reduce'],
  [webkit, 'webkit-landscape', 844, 390, 'no-preference'],
  [chromium, 'chromium-desktop', 1440, 900, 'no-preference'],
  [chromium, 'chromium-desktop-reduced', 1440, 900, 'reduce'],
  [chromium, 'chromium-reduced', 390, 844, 'reduce'],
]
const visible = (locator) => locator.waitFor({ state: 'visible', timeout: 20000 })
const location = (page) => page.locator('.paged-reader').getAttribute('data-location')

// A real, deterministic PDF: dense source pages and a sentence longer than a
// screen. Exercise the parser and browser layout rather than injecting prose.
function densePdf(tall = false) {
  const objects = ['<< /Type /Catalog /Pages 2 0 R >>', '<< /Type /Pages /Kids [4 0 R 6 0 R 8 0 R] /Count 3 >>', '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>']
  for (let source = 1; source <= 3; source++) {
    const sheetWidth = tall === 'shapes' && source === 2 ? 792 : 612
    const sheetHeight = tall === 'shapes' ? [792, 612, 1800][source - 1] : tall ? 1800 : 792
    const lines = Array.from({ length: sheetHeight < 700 ? 32 : 44 }, (_, i) => `Source ${source} line ${String(i + 1).padStart(2, '0')}: careful reading keeps every word in order across the screen${i < 15 ? ',' : '.'}`)
    const stream = `BT /F1 10 Tf 42 ${sheetHeight - 52} Td 14 TL ${lines.map((line, i) => `${i ? 'T* ' : ''}(${line}) Tj`).join('\n')} ET`
    const content = objects.length + 2
    objects.push(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${sheetWidth} ${sheetHeight}] /Resources << /Font << /F1 3 0 R >> >> /Contents ${content} 0 R >>`)
    objects.push(`<< /Length ${Buffer.byteLength(stream)} >>\nstream\n${stream}\nendstream`)
  }
  let pdf = '%PDF-1.4\n', offsets = [0]
  objects.forEach((object, i) => { offsets.push(Buffer.byteLength(pdf)); pdf += `${i + 1} 0 obj\n${object}\nendobj\n` })
  const xref = Buffer.byteLength(pdf)
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n` + offsets.slice(1).map((n) => `${String(n).padStart(10, '0')} 00000 n \n`).join('')
  return Buffer.from(pdf + `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`)
}
async function ready(page) {
  await visible(page.locator('.paged-current .prose'))
  await page.waitForFunction(() => Number(document.querySelector('.paged-reader')?.dataset.parts) > 1)
}
async function tapCenter(page) {
  const box = await page.locator('.paged-reader').boundingBox()
  await page.locator('.paged-reader').click({ position: { x: box.width / 2, y: box.height / 2 } })
}
async function keyStep(page, key) {
  const before = await location(page)
  await page.keyboard.press(key)
  await page.waitForFunction((old) => document.querySelector('.paged-reader')?.dataset.location !== old && document.querySelector('.paged-reader')?.dataset.settled === 'true', before)
}
async function resize(page, width, height) {
  await page.setViewportSize({ width, height })
  // setViewportSize acknowledges the protocol command before the browser must
  // deliver visualViewport.resize and ResizeObserver. Wait for the observable
  // fitted layout, including column measurement, rather than racing that event.
  await page.waitForFunction(() => {
    const shell = document.querySelector('.reader-immersive').getBoundingClientRect()
    const viewport = visualViewport
    const area = document.querySelector('.paged-current .paged-text')
    const prose = area.querySelector('.prose')
    const parts = Math.max(1, Math.round((prose.scrollWidth + 32) / (area.clientWidth + 32)))
    const reader = document.querySelector('.paged-reader')
    const measured = `${reader.dataset.location.split(':')[0]}:${area.clientWidth}:${area.clientHeight}:1:rebuilt:`
    return reader.dataset.layout?.startsWith(measured) && Math.abs(shell.height - (viewport?.height ?? innerHeight)) < 2
      && Math.abs(shell.width - (viewport?.width ?? innerWidth)) < 2
      && Math.abs(shell.y - (viewport?.offsetTop ?? 0)) < 2
      && Math.abs(parseFloat(area.style.getPropertyValue('--paged-column-width')) - area.clientWidth) < 1
      && parts === Number(document.querySelector('.paged-reader').dataset.parts)
  })
}

async function geometry(page) {
  return page.evaluate(() => {
    const reader = document.querySelector('.reader-immersive').getBoundingClientRect()
    const viewport = window.visualViewport
    return { x: reader.x, y: reader.y, width: reader.width, height: reader.height,
      expectedY: viewport?.offsetTop ?? 0, expectedHeight: viewport?.height ?? innerHeight,
      windowY: scrollY, gridY: document.querySelector('.reader-grid').scrollTop,
      overflow: document.documentElement.scrollWidth - innerWidth }
  })
}
async function still(page, before) {
  const after = await geometry(page)
  assert.ok(Math.abs(after.y - after.expectedY) < 2, 'The reader must stay anchored to the visual viewport')
  assert.ok(Math.abs(after.height - after.expectedHeight) < 2, 'The reader must fill the visual viewport')
  assert.equal(after.windowY, before.windowY, 'A page gesture must not move the background')
  assert.equal(after.gridY, 0, 'The outer reader grid remains fixed')
  assert.ok(after.overflow <= 2, 'The document must not extend outside the screen')
}
async function fittedText(page) {
  const clipped = await page.locator('.paged-current .paged-text').evaluate((el) => {
    const area = el.getBoundingClientRect()
    return [...el.querySelectorAll('.prose .s')].flatMap((span) => [...span.getClientRects()])
      .filter((r) => r.width > 0 && r.right > area.left + 1 && r.left < area.right - 1 && (r.top < area.top - 2 || r.bottom > area.bottom + 2))
      .map((r) => ({ top: r.top, bottom: r.bottom, areaTop: area.top, areaBottom: area.bottom }))
  })
  assert.deepEqual(clipped, [], 'Text visible on a screen must fit vertically without clipped lines')
}
async function drag(page, engine, dx, dy = 0, follow = false, ratio = 1, wait = true) {
  const box = await page.locator('.paged-reader').boundingBox()
  const start = { x: box.x + box.width * (dx < 0 ? .78 : .22), y: box.y + box.height * .55 }
  if (engine === chromium && box.width < 600) {
    const session = await page.context().newCDPSession(page)
    await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [start] })
    for (let i = 1; i <= 8; i++) {
      await session.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: start.x + dx * i / 8, y: start.y + dy * i / 8 }] })
      if (follow && i === 4) {
        const offset = await page.locator('.paged-motion').evaluate((el) => new DOMMatrixReadOnly(getComputedStyle(el).transform).m41)
        assert.ok(Math.abs(offset - dx / 2 * ratio) < 3, 'The page follows the finger before release')
      }
    }
    await session.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] })
    await session.detach()
  } else {
    // Use the page margin: dragging prose with a mouse remains text selection.
    const x = box.x + (dx < 0 ? box.width - 9 : 9)
    await page.mouse.move(x, start.y)
    await page.mouse.down()
    await page.mouse.move(x + dx / 2, start.y + dy / 2, { steps: 4 })
    if (follow) {
      const offset = await page.locator('.paged-motion').evaluate((el) => new DOMMatrixReadOnly(getComputedStyle(el).transform).m41)
      assert.ok(Math.abs(offset - dx / 2 * ratio) < 3, 'The page follows the pointer before release, resisting source boundaries')
    }
    await page.mouse.move(x + dx, start.y + dy, { steps: 4 })
    await page.mouse.up()
  }
  if (wait) await page.waitForFunction(() => document.querySelector('.paged-reader')?.getAttribute('data-settled') === 'true')
}

async function standaloneMetadata(page) {
  assert.match(await page.locator('meta[name="viewport"]').getAttribute('content'), /viewport-fit=cover/)
  assert.equal(await page.locator('meta[name="apple-mobile-web-app-capable"]').getAttribute('content'), 'yes')
  const href = await page.locator('link[rel="manifest"]').getAttribute('href')
  assert.ok(href, 'The app advertises an install manifest')
  const response = await page.request.get(new URL(href, page.url()).href)
  assert.equal(response.status(), 200)
  const manifest = await response.json()
  assert.equal(manifest.name, 'Leu')
  assert.equal(manifest.display, 'standalone', 'Home Screen launches request a standalone app surface')
  const start = new URL(manifest.start_url, response.url()), scope = new URL(manifest.scope, response.url())
  assert.equal(start.origin, new URL(page.url()).origin)
  assert.ok(start.href.startsWith(scope.href), 'The launch URL is inside the app scope')
  const icon = manifest.icons.find((entry) => entry.type === 'image/svg+xml' && entry.sizes === 'any')
  assert.ok(icon, 'A scalable self-hosted install icon is supplied')
  const iconUrl = new URL(icon.src, response.url())
  assert.equal(iconUrl.origin, start.origin)
  const image = await page.request.get(iconUrl.href)
  assert.equal(image.status(), 200)
  assert.match(image.headers()['content-type'], /image\/svg\+xml/)
  assert.match(await image.text(), /<svg/)
}

async function bookmarkSnapshot(page) {
  return page.evaluate(() => {
    const root = document.querySelector('.paged-reader'), area = document.querySelector('.paged-current .paged-text')
    const prose = area?.querySelector('.prose'), stride = area ? area.clientWidth + 32 : 1
    const origin = prose?.getBoundingClientRect().left ?? 0
    return {
      root: root ? { ...root.dataset } : null, bookmark: JSON.parse(localStorage.getItem('leu.web.v1'))?.books[0]?.readingPosition,
      fonts: document.fonts.status, area: area?.getBoundingClientRect().toJSON(), font: prose && getComputedStyle(prose).font,
      columns: prose && [...prose.querySelectorAll('.s')].map((sentence) => ({ index: Number(sentence.dataset.s),
        fragments: [...sentence.getClientRects()].map((r) => Math.floor((r.left - origin + .5) / stride)) })),
      writes: window.__BOOKMARK_WRITES,
    }
  })
}

async function run([engine, name, width, height, reducedMotion]) {
  const browser = await engine.launch({ headless: true })
  const page = await browser.newPage({ viewport: { width, height }, isMobile: width < 600 || height < 500, hasTouch: true, reducedMotion })
  const errors = []
  let reloadCheckpoint, releaseReadingFonts = () => {}
  await page.addInitScript(() => {
    window.__BOOKMARK_WRITES = []
    const write = Storage.prototype.setItem
    Storage.prototype.setItem = function (key, value) {
      write.call(this, key, value)
      if (key !== 'leu.web.v1') return
      const area = document.querySelector('.paged-current .paged-text')
      window.__BOOKMARK_WRITES.push({ at: performance.now(), bookmark: JSON.parse(value).books[0]?.readingPosition,
        location: document.querySelector('.paged-reader')?.dataset.location, fonts: document.fonts.status,
        size: area && [area.clientWidth, area.clientHeight] })
      window.__BOOKMARK_WRITES = window.__BOOKMARK_WRITES.slice(-30)
    }
  })
  page.on('pageerror', (e) => errors.push(e.message))
  try {
    await page.route('**/samples/*.pdf', (route) => route.fulfill({ contentType: 'application/pdf', body: densePdf() }))
    await page.goto(base, { waitUntil: 'domcontentloaded' })
    await standaloneMetadata(page)
    await page.getByRole('button', { name: /start with a sample book/i }).click()
    await page.getByText('Sewn in', { exact: true }).waitFor({ state: 'visible', timeout: 25000 })
    await page.locator('.sewn-actions .btn.ink').click({ timeout: 25000 })
    await page.getByRole('button', { name: 'For reading', exact: true }).click()
    await visible(page.locator('.reader-paper .prose'))
    await page.getByRole('button', { name: 'Enter full-screen reading' }).click()
    await visible(page.locator('.paged-reader'))
    assert.equal(await page.locator('.reader-immersive').getAttribute('data-controls'), 'hidden', 'Reading opens with the app chrome hidden')
    assert.ok(await page.getByRole('navigation', { name: 'Full-screen pages' }).isVisible(),
      'Immersive fullscreen provides visible page controls without a large footer')
    assert.ok(await page.getByRole('button', { name: 'Exit full-screen reading' }).isVisible(),
      'Fullscreen has one persistent accessible X')
    assert.equal(await page.getByRole('button', { name: 'Show reader tools' }).count(), 0,
      'There is no redundant Tools button; tapping the page reveals the toolbar on every screen')
    await ready(page)
    if (width <= 720) {
      const occlusion = await page.evaluate(() => {
        const content = document.querySelector('.paged-current .paged-text')?.getBoundingClientRect()
        const controls = document.querySelector('.reader-immersive .reader-page-nav')?.getBoundingClientRect()
        const hint = document.querySelector('.reader-immersive .reader-focus-hint')
        return { contentBottom: content?.bottom ?? 0, controlsTop: controls?.top ?? 0,
          hintVisible: hint ? getComputedStyle(hint).display !== 'none' : false }
      })
      assert.ok(occlusion.contentBottom + 6 <= occlusion.controlsTop,
        'The persistent mobile page controls must never overlap reflowed PDF text: ' + JSON.stringify(occlusion))
      assert.equal(occlusion.hintVisible, false,
        'A fullscreen instruction hint must not obscure document content on phones')
    }
    const before = await geometry(page)
    await still(page, before)
    await fittedText(page)
    const first = await location(page)
    await drag(page, engine, -Math.min(240, width * .65), 55, true)
    assert.notEqual(await location(page), first, 'A sideways drag must turn one fitted screen')
    await still(page, before)
    await fittedText(page)
    const second = await location(page)
    await drag(page, engine, 8, -110)
    assert.equal(await location(page), second, 'Vertical and tiny diagonal gestures must not turn a page')
    await still(page, before)
    if (engine === chromium && width < 600) {
      const box = await page.locator('.paged-reader').boundingBox()
      const session = await page.context().newCDPSession(page)
      const firstFinger = { id: 1, x: box.width * .75, y: box.height * .5 }
      await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [firstFinger] })
      firstFinger.x -= 40
      await session.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [firstFinger] })
      await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [firstFinger, { id: 2, x: box.width * .25, y: firstFinger.y }] })
      await session.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] })
      await session.detach()
      await page.waitForFunction(() => document.querySelector('.paged-reader')?.dataset.settled === 'true')
      assert.equal(await location(page), second)
      assert.ok(await page.locator('.paged-motion').evaluate((el) => Math.abs(new DOMMatrixReadOnly(getComputedStyle(el).transform).m41) < 1), 'Changing from swipe to pinch always leaves the page aligned')
      // Touch the area where a mode control will appear after the tap. Its
      // compatibility click must not activate that newly revealed control.
      await page.touchscreen.tap(width * .5, 30)
      await visible(page.getByRole('button', { name: 'Original page' }))
      assert.equal(await page.getByRole('button', { name: 'For reading' }).getAttribute('aria-pressed'), 'true')
      await tapCenter(page)
    }
    // Tiny horizontal drags spring back; cancellation never commits a page.
    await drag(page, engine, -9, 0)
    assert.equal(await location(page), second)
    const cancelBox = await page.locator('.paged-reader').boundingBox()
    await page.mouse.move(cancelBox.x + 9, cancelBox.y + 200)
    await page.mouse.down()
    await page.mouse.move(cancelBox.x + 120, cancelBox.y + 202, { steps: 3 })
    await page.evaluate(() => window.dispatchEvent(new PointerEvent('pointercancel')))
    await page.mouse.up()
    await page.waitForFunction(() => document.querySelector('.paged-reader')?.dataset.settled === 'true')
    assert.equal(await location(page), second)
    const textBox = await page.locator('.paged-current .paged-text').boundingBox()
    await tapCenter(page)
    await visible(page.getByRole('button', { name: 'Exit full-screen reading' }))
    assert.deepEqual(await page.locator('.paged-current .paged-text').boundingBox(), textBox, 'Overlay controls never reflow the text')
    const originalPart = await page.locator('.paged-reader').getAttribute('data-part')
    await page.getByRole('button', { name: 'Zoom in' }).click()
    await fittedText(page)
    await page.getByRole('button', { name: 'Reset zoom' }).click()
    await page.waitForFunction((part) => document.querySelector('.paged-reader')?.dataset.part === part, originalPart)
    await tapCenter(page)
    assert.equal(await page.locator('.reader-immersive').getAttribute('data-controls'), 'hidden')
    // Traverse every reflowed screen, including both source boundaries. Every
    // extracted sentence must have appeared on at least one fitted screen.
    const seen = new Set(), expected = new Set()
    let turns = 0
    await keyStep(page, 'ArrowLeft')
    assert.equal(await location(page), first)
    while (true) {
      await fittedText(page)
      const allSentences = await page.locator('.paged-current .s').evaluateAll((spans) => spans.map((span) => span.closest('[data-page]').dataset.page + ':' + span.dataset.s))
      allSentences.forEach((sentence) => expected.add(sentence))
      const sentences = await page.locator('.paged-current .paged-text').evaluate((area) => {
        const bounds = area.getBoundingClientRect()
        return [...area.querySelectorAll('.s')].filter((span) => [...span.getClientRects()].some((r) => r.width && r.right > bounds.left + 1 && r.left < bounds.right - 1))
          .map((span) => span.closest('[data-page]').dataset.page + ':' + span.dataset.s)
      })
      sentences.forEach((sentence) => seen.add(sentence))
      const { at, parts } = await page.locator('.paged-reader').evaluate((el) => ({ at: Number(el.dataset.part), parts: Number(el.dataset.parts) }))
      const source = Number((await location(page)).split(':')[0])
      if (source === 3 && at === parts - 1) break
      assert.ok(turns++ < 100, 'Pagination must reach the final source without loops')
      await keyStep(page, 'ArrowRight')
    }
    assert.ok(expected.size >= 80, 'The dense fixture exercises many sentences')
    assert.deepEqual([...seen].sort(), [...expected].sort(), 'Every extracted sentence must appear during traversal')
    const last = await location(page)
    await drag(page, engine, -Math.min(240, width * .65), 40)
    assert.equal(await location(page), last, 'The final boundary resists rather than leaving a blank screen')
    await still(page, before)
    await keyStep(page, 'ArrowLeft')
    const saved = await location(page)
    const bookmark = await page.evaluate(() => JSON.parse(localStorage.getItem('leu.web.v1')).books[0].readingPosition)
    await tapCenter(page)
    await page.getByRole('button', { name: 'Original page' }).click()
    await page.waitForFunction(() => parseFloat(document.querySelector('.paged-current canvas')?.style.width ?? '0') > 0)
    assert.ok(await page.locator('.paged-current canvas').evaluate((el) => {
      const r = el.getBoundingClientRect(), a = el.parentElement.getBoundingClientRect()
      return r.left >= a.left - 2 && r.right <= a.right + 2
        && r.top >= a.top - 2 && r.bottom <= a.bottom + 2
        && Math.abs(r.width / r.height - 612 / 792) < .002
    }), 'The complete original PDF fits both viewport dimensions without changing its aspect ratio')
    await page.getByRole('button', { name: 'Zoom in' }).click()
    await page.getByRole('button', { name: 'Zoom in' }).click()
    await page.getByRole('button', { name: 'Zoom in' }).click()
    await page.getByRole('button', { name: 'Zoom in' }).click()
    await page.waitForFunction(() => parseFloat(document.querySelector('.paged-current canvas')?.style.width ?? '0') > document.querySelector('.paged-current .paged-original').clientWidth || parseFloat(document.querySelector('.paged-current canvas')?.style.height ?? '0') > document.querySelector('.paged-current .paged-original').clientHeight)
    await tapCenter(page)
    const sourceBeforePan = (await location(page)).split(':')[0]
    await drag(page, engine, -90, 40)
    assert.equal((await location(page)).split(':')[0], sourceBeforePan, 'Dragging an enlarged original pans instead of turning')
    await still(page, before)
    // A centre tap also exposes controls while an original is zoomed.
    await tapCenter(page)
    await visible(page.getByRole('button', { name: 'Reset zoom' }))
    await page.getByRole('button', { name: 'Reset zoom' }).click()
    await page.getByRole('button', { name: 'For reading' }).click()
    await ready(page)
    await page.waitForFunction((old) => document.querySelector('.paged-reader')?.dataset.location === old, saved)
    assert.deepEqual(await page.evaluate(() => JSON.parse(localStorage.getItem('leu.web.v1')).books[0].readingPosition), bookmark)
    await page.getByRole('button', { name: 'Exit full-screen reading' }).click()
    await page.getByRole('button', { name: 'Enter full-screen reading' }).click()
    await ready(page)
    await page.waitForFunction((old) => document.querySelector('.paged-reader')?.dataset.location === old, saved)
    // Rotation must not briefly persist a different passage before restoring it.
    const reflowSentence = await page.evaluate(() => JSON.parse(localStorage.getItem('leu.web.v1')).books[0].readingPosition.sentence)
    await page.evaluate(() => { window.__BOOKMARK_WRITES = [] })
    // Rotation/viewport resize keeps the same passage, then repaginates back.
    await resize(page, width > 900 ? 1000 : height, width > 900 ? 720 : width)
    await fittedText(page)
    await still(page, await geometry(page))
    await resize(page, width, height)
    await ready(page)
    await fittedText(page)
    const checkpoint = await bookmarkSnapshot(page)
    reloadCheckpoint = checkpoint
    const reflowWrites = checkpoint.writes.filter((write) => write.bookmark?.page === checkpoint.bookmark.page).map((write) => write.bookmark.sentence)
    assert.ok(reflowWrites.every((sentence) => sentence === reflowSentence), 'Reflow never persists a transient screen start over the saved passage anchor')
    assert.equal(checkpoint.bookmark.sentence, reflowSentence)
    const part = Number(checkpoint.root.part), parts = Number(checkpoint.root.parts)
    assert.equal(checkpoint.bookmark.fraction, parts > 1 ? part / (parts - 1) : 0, 'The atomic reload checkpoint matches the committed screen fraction')
    assert.ok(checkpoint.columns.find((sentence) => sentence.index === reflowSentence).fragments.includes(part), 'The saved passage is visible in the atomic reload checkpoint')
    const reloadLocation = checkpoint.root.location
    const reloadBookmark = checkpoint.bookmark
    console.log('BOOKMARK ' + name + ' ' + JSON.stringify({ location: reloadLocation, bookmark: reloadBookmark, fonts: checkpoint.fonts }))
    // Hold actual cold Literata bytes until fallback prose paints. A monospace
    // fallback makes its different geometry deterministic across OS font sets.
    // Final glyphs still use the unchanged real reading font.
    const fontGate = new Promise((resolve) => { releaseReadingFonts = resolve })
    let heldFonts = 0
    await page.route('**/assets/*.css', async (route) => {
      const response = await route.fetch()
      await route.fulfill({ response, body: (await response.text())
        .replace(/(\/fonts\/Literata-[\w-]+\.ttf)/g, '$1?reader-cold-font=1')
        .replace(/Literata,\s*Georgia,\s*serif/g, 'Literata,monospace') })
    })
    await page.route('**/fonts/Literata-*.ttf*', async (route) => {
      const response = await route.fetch()
      heldFonts++
      await fontGate
      await route.fulfill({ response })
    })
    await page.reload({ waitUntil: 'domcontentloaded' })
    await visible(page.locator('.reader-paper canvas'))
    await page.getByRole('button', { name: 'For reading', exact: true }).click()
    await page.getByRole('button', { name: 'Enter full-screen reading' }).click()
    await visible(page.locator('.paged-current .prose'))
    await page.waitForFunction(() => document.fonts.status === 'loading')
    await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))))
    assert.ok(heldFonts > 0, 'The reload journey holds actual cold reading-font bytes')
    assert.deepEqual(await page.evaluate(() => JSON.parse(localStorage.getItem('leu.web.v1')).books[0].readingPosition), reloadBookmark,
      'Fallback font layout must not overwrite the durable saved passage or fraction')
    releaseReadingFonts()
    await page.evaluate(() => document.fonts.ready)
    await ready(page)
    await page.waitForFunction(() => document.querySelector('.paged-reader')?.dataset.layout?.endsWith(':ready'))
    const activated = await bookmarkSnapshot(page)
    const [, , , , , , , cachedColumns, cachedEnds] = activated.root.layout.split(':')
    for (const sentence of activated.columns) {
      assert.equal(Number(cachedColumns.split(',')[sentence.index]), Math.min(...sentence.fragments), 'Cached font-start fragments match activated browser glyphs')
      assert.equal(Number(cachedEnds.split(',')[sentence.index]), Math.max(...sentence.fragments), 'Cached font-end fragments match activated browser glyphs')
    }
    await page.waitForFunction(({ old, bookmark }) => document.querySelector('.paged-reader')?.dataset.location === old && JSON.parse(localStorage.getItem('leu.web.v1')).books[0].readingPosition.sentence === bookmark.sentence, { old: reloadLocation, bookmark: reloadBookmark })
    assert.deepEqual(await page.evaluate(() => JSON.parse(localStorage.getItem('leu.web.v1')).books[0].readingPosition), reloadBookmark, 'A full reload restores the saved reading passage')
    await page.screenshot({ path: join(evidence, name + '-reading.png') })
    assert.ok(await page.locator('.paged-panel').count() <= 3, 'The prepared page deck stays bounded')
    assert.deepEqual(errors, [], name + ': runtime errors')
    console.log('PASS ' + name + ': dense PDF, every screen, touch side turns, cancellation, fixed viewport, hidden overlays, original fit/pan, bookmark, resize')
  } catch (error) {
    console.error('BOOKMARK FAILURE ' + name + ' ' + JSON.stringify({ checkpoint: reloadCheckpoint, actual: await bookmarkSnapshot(page) }))
    await page.screenshot({ path: join(evidence, name + '-failed.png') }).catch(() => {})
    throw error
  } finally { releaseReadingFonts(); await browser.close() }
}


async function fittedOriginal([engine, name, width, height, reducedMotion]) {
  const browser = await engine.launch({ headless: true })
  const page = await browser.newPage({ viewport: { width, height }, isMobile: width < 600 || height < 500, hasTouch: true, reducedMotion })
  const errors = []
  page.on('pageerror', (error) => errors.push(error.message))
  const fitted = async (aspect) => {
    await page.waitForFunction((aspect) => {
      const canvas = document.querySelector('.paged-current canvas'), area = canvas?.parentElement
      return canvas?.width > 0 && Math.abs(parseFloat(canvas.style.width) - Math.min(area.clientWidth, area.clientHeight * aspect)) < 2
    }, aspect)
    const geometry = await page.locator('.paged-current canvas').evaluate((el) => ({
      canvas: el.getBoundingClientRect().toJSON(), area: el.parentElement.getBoundingClientRect().toJSON(),
      surface: getComputedStyle(el.closest('.paged-panel')).backgroundColor,
    }))
    const { canvas: c, area: a } = geometry
    assert.ok(c.left >= a.left - 2 && c.right <= a.right + 2 && c.top >= a.top - 2 && c.bottom <= a.bottom + 2,
      'Fit page shows the complete source sheet inside the viewport')
    assert.ok(Math.abs(c.width / c.height - aspect) < .002, 'Fit page preserves the source PDF aspect ratio')
    assert.equal(geometry.surface, 'rgb(255, 255, 255)', 'The original reader surface is white around intrinsic source whitespace')
    return geometry
  }
  try {
    await page.route('**/samples/*.pdf', (route) => route.fulfill({ contentType: 'application/pdf', body: densePdf('shapes') }))
    await page.goto(base, { waitUntil: 'domcontentloaded' })
    await page.getByRole('button', { name: /start with a sample book/i }).click()
    await page.getByText('Sewn in', { exact: true }).waitFor({ state: 'visible', timeout: 25000 })
    await page.locator('.sewn-actions .btn.ink').click({ timeout: 25000 })
    await visible(page.locator('.reader-paper canvas'))
    if (width <= 720 || height <= 500) {
      assert.equal(await page.locator('.reader-bar .segmented').count(), 0, 'Mobile has original PDF only')
      assert.equal(await page.locator('.app > .topbar').isVisible(), false, 'Mobile reader has no global menu/search header')
      await visible(page.getByRole('link', { name: 'Back to book overview' }))
      await visible(page.locator('.reader-bar .contents-trigger'))
    }
    await page.getByRole('button', { name: 'Enter full-screen reading' }).click()
    await page.waitForFunction(() => document.querySelector('.paged-current canvas')?.width > 0)
    // Tiny trackpad jitter is not a turn. Accumulated deliberate movement is.
    if (engine === chromium && width > 900) {
      await page.mouse.move(width * .5, height * .5)
      await page.mouse.wheel(6, 1)
      await page.waitForTimeout(280)
      assert.equal(await location(page), '1:0', 'Tiny horizontal wheel movement leaves the source page in place')
      for (let i = 0; i < 7; i++) { await page.mouse.wheel(12, 2); await page.waitForTimeout(30) }
      await page.waitForFunction(() => document.querySelector('.paged-reader')?.dataset.location === '2:0')
      await page.waitForTimeout(280)
      assert.equal(await location(page), '2:0', 'A sustained trackpad swipe turns exactly one source sheet')
      await keyStep(page, 'ArrowLeft')
    }
    // Reproduce the reported default-original regression using actual pointer
    // input before checking the new Fit page control or its geometry.
    await drag(page, engine, -Math.min(240, width * .65), 25, true)
    assert.equal(await location(page), '2:0', 'A normal-zoom original swipe turns exactly one source page')
    await keyStep(page, 'ArrowLeft')
    await drag(page, engine, width * .35, 15, true, .2)
    assert.equal(await location(page), '1:0', 'The first source boundary resists without panning or turning')
    await drag(page, engine, -8, -100)
    assert.equal(await location(page), '1:0', 'A vertical diagonal does not turn an original')
    const cancelBox = await page.locator('.paged-reader').boundingBox()
    await page.mouse.move(cancelBox.width - 9, cancelBox.height * .5)
    await page.mouse.down()
    await page.mouse.move(cancelBox.width - 109, cancelBox.height * .5 + 2, { steps: 4 })
    await page.evaluate(() => window.dispatchEvent(new PointerEvent('pointercancel')))
    await page.mouse.up()
    await page.waitForFunction(() => document.querySelector('.paged-reader')?.dataset.settled === 'true')
    assert.equal(await location(page), '1:0', 'Cancelling an original drag never commits a page')
    if (reducedMotion !== 'reduce') {
      await drag(page, engine, -Math.min(240, width * .45), 10, false, 1, false)
      await drag(page, engine, -Math.min(240, width * .45), 10, false, 1, false)
      await page.waitForFunction(() => document.querySelector('.paged-reader')?.dataset.settled === 'true')
      assert.equal(await location(page), '2:0', 'A second swipe during settling cannot skip a source page')
      await keyStep(page, 'ArrowLeft')
    }
    if (engine === chromium && width < 600) {
      const session = await page.context().newCDPSession(page)
      const a = { id: 1, x: width * .6, y: height * .45 }, b = { id: 2, x: width * .3, y: height * .45 }
      await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [a] })
      a.x -= 28
      await session.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [a] })
      await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [a, b] })
      a.x += 50; b.x -= 40
      await session.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [a, b] })
      await session.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] })
      await session.detach()
      await page.waitForFunction(() => document.querySelector('.paged-current .paged-original')?.dataset.zoomed === 'true' && document.querySelector('.paged-reader')?.dataset.settled === 'true')
      assert.equal(await location(page), '1:0', 'Changing from a source swipe to a real pinch zoom never turns a page')
      await tapCenter(page)
      await page.getByRole('button', { name: 'Reset zoom', exact: true }).click()
      await tapCenter(page)
    }
    for (const [source, aspect] of [[1, 612 / 792], [2, 792 / 612], [3, 612 / 1800]]) {
      const geometry = await fitted(aspect)
      await page.screenshot({ path: join(evidence, name + '-fit-source-' + source + '.png') })
      console.log('GEOMETRY ' + name + ' source ' + source + ' ' + JSON.stringify(geometry))
      if (source < 3) {
        await drag(page, engine, -Math.min(240, width * .65), 25, true)
        assert.equal(await location(page), (source + 1) + ':0')
      }
    }
    const last = await location(page)
    await drag(page, engine, -width * .4, 0, true, .2)
    assert.equal(await location(page), last, 'Last source boundary springs back')
    await tapCenter(page)
    const fits = page.getByRole('group', { name: 'Original page fit', exact: true })
    assert.equal(await fits.getByRole('button', { name: 'Fit page', exact: true }).getAttribute('aria-pressed'), 'true')
    await fits.getByRole('button', { name: 'Fit width', exact: true }).click()
    await page.waitForFunction(() => Math.abs(parseFloat(document.querySelector('.paged-current canvas')?.style.width ?? '0') - innerWidth) < 2)
    await page.getByRole('button', { name: 'Zoom in', exact: true }).click()
    await tapCenter(page)
    const beforePan = await page.locator('.paged-current canvas').boundingBox()
    await drag(page, engine, -90, 35)
    const afterPan = await page.locator('.paged-current canvas').boundingBox()
    assert.ok(afterPan.x < beforePan.x - 5, 'A zoomed original actually pans in response to the pointer')
    assert.equal(await location(page), last, 'An enlarged original pans without turning')
    for (let n = 0; n < 5; n++) await drag(page, engine, 0, height * .35)
    assert.equal(await page.locator('.reader-immersive').count(), 1, 'Zoomed pans reaching the top never become an exit gesture')
    assert.equal(await location(page), last)
    assert.ok(await page.locator('.paged-current canvas').evaluate((canvas) => {
      const c = canvas.getBoundingClientRect(), a = canvas.parentElement.getBoundingClientRect()
      return c.width <= a.width + 2 ? Math.abs(c.x + c.width / 2 - a.x - a.width / 2) < 2 : c.left <= a.left + 2 && c.right >= a.right - 2
    }), 'Pan offsets stay bounded by the enlarged sheet')
    await tapCenter(page)
    await page.getByRole('button', { name: 'Reset zoom', exact: true }).click()
    await fitted(612 / 1800)
    await tapCenter(page)
    await drag(page, engine, width * .45, 20, true)
    assert.equal(await location(page), '2:0', 'Reset restores Fit page and sideways paging')
    await fitted(792 / 612)
    if (engine === chromium && width > 900) {
      await page.mouse.move(width * .5, height * .5)
      for (let i = 0; i < 7; i++) { await page.mouse.wheel(40, 2); await page.waitForTimeout(65) }
      await page.waitForFunction(() => document.querySelector('.paged-reader')?.dataset.settled === 'true')
      assert.equal(await location(page), '3:0', 'A continuous original-page wheel momentum burst commits only one source turn')
      await keyStep(page, 'ArrowLeft')
    }
    for (const viewport of [{ width: height, height: width }, { width, height }]) {
      await page.setViewportSize(viewport)
      await page.waitForFunction(({ width, height }) => {
        const shell = document.querySelector('.reader-immersive').getBoundingClientRect()
        return Math.abs(shell.width - width) < 2 && Math.abs(shell.height - height) < 2
          && Math.abs(shell.height - (visualViewport?.height ?? innerHeight)) < 2
      }, viewport)
      await fitted(792 / 612)
    }
    await still(page, await geometry(page))
    assert.deepEqual(errors, [])
    console.log('PASS ' + name + ': fitted portrait/landscape/tall originals, pointer turns, zoom pan, reset, boundaries, rotation')
  } catch (error) {
    await page.screenshot({ path: join(evidence, name + '-fit-failed.png') }).catch(() => {})
    throw error
  } finally { await browser.close() }
}

async function tallOriginal([engine, name, width, height, reducedMotion]) {
  const browser = await engine.launch({ headless: true })
  const page = await browser.newPage({ viewport: { width, height }, isMobile: width < 600 || height < 500, hasTouch: true, reducedMotion })
  const errors = []
  page.on('pageerror', (error) => errors.push(error.message))
  const area = () => page.locator('.paged-current .paged-original')
  const scroll = () => area().evaluate((el) => el.scrollTop)
  try {
    await page.route('**/samples/*.pdf', (route) => route.fulfill({ contentType: 'application/pdf', body: densePdf(true) }))
    await page.goto(base, { waitUntil: 'domcontentloaded' })
    await page.getByRole('button', { name: /start with a sample book/i }).click()
    await page.getByText('Sewn in', { exact: true }).waitFor({ state: 'visible', timeout: 25000 })
    await page.locator('.sewn-actions .btn.ink').click({ timeout: 25000 })
    await visible(page.locator('.reader-paper canvas'))
    await page.getByRole('button', { name: 'Enter full-screen reading' }).click()
    await page.waitForFunction(() => parseFloat(document.querySelector('.paged-current canvas')?.style.width ?? '0') > 0)
    await tapCenter(page)
    await page.getByRole('group', { name: 'Original page fit', exact: true }).getByRole('button', { name: 'Fit width', exact: true }).click()
    await tapCenter(page)
    await page.waitForFunction(() => Math.abs(parseFloat(document.querySelector('.paged-current canvas')?.style.width ?? '0') - innerWidth) < 2)
    assert.ok(await area().evaluate((el) => {
      const canvas = el.querySelector('canvas').getBoundingClientRect(), box = el.getBoundingClientRect()
      return Math.abs(canvas.width - box.width) < 2 && Math.abs(canvas.y - box.y) < 2
        && Math.abs(canvas.width / canvas.height - 612 / 1800) < .002
        && canvas.height > box.height + 50 && el.scrollHeight >= canvas.height - 2
    }), 'A tall original keeps its full source aspect ratio and exposes its whole height')
    await area().focus()
    assert.equal(await area().evaluate((el) => document.activeElement === el), true, 'The original scroll surface is keyboard focusable')
    await page.keyboard.press('ArrowDown')
    await page.waitForFunction(() => document.querySelector('.paged-current .paged-original').scrollTop > 0)
    await area().evaluate((el) => { el.scrollTop = 0 })
    await drag(page, engine, 4, -110)
    assert.ok(await scroll() > 80, 'An upward drag scrolls the tall original')
    const saved = await location(page)
    await drag(page, engine, 4, 190)
    assert.equal(await location(page), saved, 'A drag begun within the PDF scroll never exits or turns, even when it reaches the top')
    assert.equal(await scroll(), 0)
    assert.equal(await page.locator('.paged-reader').getAttribute('data-pull-state'), null)
    await drag(page, engine, 4, -110)
    await drag(page, engine, -Math.min(240, width * .65), 25, true)
    assert.equal(await location(page), '2:0', 'Horizontal swipes turn source pages while an original is vertically scrolled')
    assert.equal(await scroll(), 0, 'A new source page starts at the top')
    await drag(page, engine, Math.min(240, width * .65), 25, true)
    assert.equal(await location(page), saved)
    assert.equal(await scroll(), 0, 'Returning to a source page also resets its scroll')
    await page.mouse.move(width * .5, height * .5)
    // Playwright cannot send native wheel input in mobile WebKit. Dispatch the
    // wheel boundary event there; desktop and Chromium use native browser input.
    const wheel = (dy) => engine === webkit && (width < 600 || height < 500)
      ? page.locator('.paged-reader').dispatchEvent('wheel', { deltaY: dy, deltaX: 0, bubbles: true, cancelable: true })
      : page.mouse.wheel(0, dy)
    await wheel(140)
    await page.waitForFunction(() => document.querySelector('.paged-current .paged-original').scrollTop > 100)
    await wheel(-300)
    await wheel(-180)
    await page.waitForTimeout(220)
    assert.equal(await location(page), saved, 'Wheel momentum that reaches the top cannot turn into an exit gesture')
    assert.equal(await scroll(), 0)
    await area().evaluate((el) => { el.scrollTop = el.scrollHeight })
    assert.ok(await area().evaluate((el) => {
      const canvas = el.querySelector('canvas').getBoundingClientRect(), box = el.getBoundingClientRect()
      return Math.abs(canvas.bottom - box.bottom) < 2
    }), 'Scrolling to the bottom exposes the original PDF bottom edge without cropping')
    await area().evaluate((el) => { el.scrollTop = 0 })
    const box = await page.locator('.paged-reader').boundingBox()
    await page.mouse.move(box.x + width * .5, box.y + height * .25)
    await page.mouse.down()
    await page.mouse.move(box.x + width * .5 + 4, box.y + height * .25 + 190, { steps: 8 })
    assert.equal(await page.locator('.paged-reader').getAttribute('data-pull-state'), 'ready', 'Pulling down at the PDF top still offers exit')
    await page.mouse.up()
    await page.locator('.reader-immersive').waitFor({ state: 'hidden' })
    assert.deepEqual(errors, [])
    console.log('PASS ' + name + ': tall original drag/wheel scroll, bottom edge, locked scroll ownership, source turns/reset, top pull exit')
  } catch (error) {
    await page.screenshot({ path: join(evidence, name + '-tall-failed.png') }).catch(() => {})
    throw error
  } finally { await browser.close() }
}

async function extractionFallback(engine, name) {
  const browser = await engine.launch({ headless: true })
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true })
  let injected = false
  try {
    await page.route('**/assets/pdf.worker*.mjs', async (route) => {
      const response = await route.fetch()
      const source = await response.text()
      const patched = source.replace(/(\.on\("GetTextContent",function\([\s\S]*?\)\{)/, '$1throw new Error("Injected text extraction failure");')
      assert.notEqual(patched, source, 'The fallback test must inject a real extraction failure')
      injected = true
      await route.fulfill({ response, body: patched })
    })
    await page.goto(base, { waitUntil: 'domcontentloaded' })
    await page.getByRole('button', { name: /start with a sample book/i }).click()
    await page.getByText('Sewn in', { exact: true }).waitFor({ state: 'visible', timeout: 25000 })
    await page.locator('.sewn-actions .btn.ink').click({ timeout: 25000 })
    await visible(page.locator('.reader-paper canvas'))
    await page.getByRole('button', { name: 'Enter full-screen reading' }).click()
    await visible(page.locator('.paged-current canvas'))
    await page.waitForFunction(() => document.querySelector('.paged-current canvas')?.width > 0)
    assert.ok(injected)
    assert.equal(await page.locator('.paged-current [role="alert"]').count(), 0, 'Text extraction failure must not block a renderable original PDF')
    console.log('PASS ' + name + ': original PDF remains readable when the real PDF text worker fails')
  } finally { await browser.close() }
}

try {
  for (let i = 0; i < 60; i++) {
    try { if ((await fetch(base)).ok) break } catch {}
    if (i === 59) throw new Error('Preview did not start')
    await new Promise((resolve) => setTimeout(resolve, 150))
  }
  for (const config of configs) {
    if (!process.env.LEU_PAGED_CASE || config[1] === process.env.LEU_PAGED_CASE) {
      await fittedOriginal(config)
      // Reflowed-screen tests remain on desktop. Phones have one source-PDF mode.
      if (config[2] > 720 && config[3] > 500) await run(config)
      await tallOriginal(config)
    }
  }
  if (!process.env.LEU_PAGED_CASE) {
    await extractionFallback(chromium, 'chromium-fallback')
    await extractionFallback(webkit, 'webkit-fallback')
  }
} finally { server.kill('SIGTERM') }
