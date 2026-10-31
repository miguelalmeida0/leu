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
  [chromium, 'chromium-reduced', 390, 844, 'reduce'],
]
const visible = (locator) => locator.waitFor({ state: 'visible', timeout: 20000 })
const location = (page) => page.locator('.paged-reader').getAttribute('data-location')

// A real, deterministic PDF: dense source pages and a sentence longer than a
// screen. Exercise the parser and browser layout rather than injecting prose.
function densePdf() {
  const objects = ['<< /Type /Catalog /Pages 2 0 R >>', '<< /Type /Pages /Kids [4 0 R 6 0 R 8 0 R] /Count 3 >>', '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>']
  for (let source = 1; source <= 3; source++) {
    const lines = Array.from({ length: 44 }, (_, i) => `Source ${source} line ${String(i + 1).padStart(2, '0')}: careful reading keeps every word in order across the screen${i < 15 ? ',' : '.'}`)
    const stream = `BT /F1 10 Tf 42 740 Td 14 TL ${lines.map((line, i) => `${i ? 'T* ' : ''}(${line}) Tj`).join('\n')} ET`
    const content = objects.length + 2
    objects.push(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents ${content} 0 R >>`)
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
    return Math.abs(shell.height - (viewport?.height ?? innerHeight)) < 2
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
  assert.equal(after.gridY, 0, 'There is no vertical reading scroll surface')
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
async function drag(page, engine, dx, dy = 0, follow = false) {
  const box = await page.locator('.paged-reader').boundingBox()
  const start = { x: box.x + box.width * (dx < 0 ? .78 : .22), y: box.y + box.height * .55 }
  if (engine === chromium && box.width < 600) {
    const session = await page.context().newCDPSession(page)
    await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [start] })
    for (let i = 1; i <= 8; i++) {
      await session.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: start.x + dx * i / 8, y: start.y + dy * i / 8 }] })
      if (follow && i === 4) {
        const offset = await page.locator('.paged-motion').evaluate((el) => new DOMMatrixReadOnly(getComputedStyle(el).transform).m41)
        assert.ok(Math.abs(offset - dx / 2) < 3, 'The page follows the finger before release')
      }
    }
    await session.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] })
    await session.detach()
  } else {
    // Use the page margin: dragging prose with a mouse remains text selection.
    const x = box.x + (dx < 0 ? box.width - 9 : 9)
    await page.mouse.move(x, start.y)
    await page.mouse.down()
    await page.mouse.move(x + dx, start.y + dy, { steps: 8 })
    await page.mouse.up()
  }
  await page.waitForFunction(() => document.querySelector('.paged-reader')?.getAttribute('data-settled') === 'true')
}

async function run([engine, name, width, height, reducedMotion]) {
  const browser = await engine.launch({ headless: true })
  const page = await browser.newPage({ viewport: { width, height }, isMobile: width < 600 || height < 500, hasTouch: true, reducedMotion })
  const errors = []
  page.on('pageerror', (e) => errors.push(e.message))
  try {
    await page.route('**/samples/*.pdf', (route) => route.fulfill({ contentType: 'application/pdf', body: densePdf() }))
    await page.goto(base, { waitUntil: 'domcontentloaded' })
    await page.getByRole('button', { name: /start with a sample book/i }).click()
    await page.locator('.sewn-actions .btn.ink').click({ timeout: 25000 })
    await visible(page.locator('.reader-paper .prose'))
    await page.getByRole('button', { name: 'Enter full-screen reading' }).click()
    await visible(page.locator('.paged-reader'))
    assert.equal(await page.locator('.reader-immersive').getAttribute('data-controls'), 'hidden', 'Reading opens with the app chrome hidden')
    await ready(page)
    const before = await geometry(page)
    await still(page, before)
    await fittedText(page)
    const first = await location(page)
    await drag(page, engine, -Math.min(240, width * .65), 55, true)
    assert.notEqual(await location(page), first, 'A sideways drag must turn one fitted screen')
    await still(page, before)
    await fittedText(page)
    const second = await location(page)
    await drag(page, engine, 8, 110)
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
      return r.left >= a.left - 2 && r.right <= a.right + 2 && r.top >= a.top - 2 && r.bottom <= a.bottom + 2
    }), 'A complete original PDF page fits at 100%')
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
    // Rotation/viewport resize keeps the same passage, then repaginates back.
    await resize(page, width > 900 ? 1000 : height, width > 900 ? 720 : width)
    await fittedText(page)
    await still(page, await geometry(page))
    await resize(page, width, height)
    await ready(page)
    await fittedText(page)
    await page.screenshot({ path: join(evidence, name + '-reading.png') })
    assert.ok(await page.locator('.paged-panel').count() <= 3, 'The prepared page deck stays bounded')
    assert.deepEqual(errors, [], name + ': runtime errors')
    console.log('PASS ' + name + ': dense PDF, every screen, touch side turns, cancellation, fixed viewport, hidden overlays, original fit/pan, bookmark, resize')
  } catch (error) {
    await page.screenshot({ path: join(evidence, name + '-failed.png') }).catch(() => {})
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
    if (!process.env.LEU_PAGED_CASE || config[1] === process.env.LEU_PAGED_CASE) await run(config)
  }
  if (!process.env.LEU_PAGED_CASE) {
    await extractionFallback(chromium, 'chromium-fallback')
    await extractionFallback(webkit, 'webkit-fallback')
  }
} finally { server.kill('SIGTERM') }
