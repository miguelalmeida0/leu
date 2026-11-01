import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdir } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { chromium, webkit } from 'playwright'

const root = dirname(dirname(fileURLToPath(import.meta.url))), base = 'http://127.0.0.1:4187'
const evidence = join(root, 'qa-evidence/contents')
await mkdir(evidence, { recursive: true })
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', 'preview', '--host', '127.0.0.1', '--port', '4187', '--strictPort'], { cwd: root, stdio: 'ignore' })
const configs = [
  [chromium, 'chromium-320', 320, 'no-preference'], [webkit, 'webkit-390', 390, 'no-preference'],
  [webkit, 'webkit-320-reduced', 320, 'reduce'], [chromium, 'chromium-768', 768, 'reduce'],
  [chromium, 'chromium-1440', 1440, 'no-preference'], [chromium, 'chromium-1920', 1920, 'reduce'],
  [chromium, 'chromium-landscape', 568, 'no-preference', 320], [webkit, 'webkit-landscape', 568, 'no-preference', 320],
  [chromium, 'chromium-keyboard', 390, 'reduce', 320], [webkit, 'webkit-keyboard', 390, 'reduce', 320],
]
// A real PDF outline with twelve nested levels and a top-level sibling.
// Destinations use actual page references, exercising PDF.js and import storage.
function deepOutlinePdf() {
  const objects = ['<< /Type /Catalog /Pages 2 0 R /Outlines 10 0 R >>', '<< /Type /Pages /Kids [4 0 R 6 0 R 8 0 R] /Count 3 >>', '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>']
  for (let page = 0; page < 3; page++) {
    const stream = `BT /F1 16 Tf 42 740 Td (Outline source page ${page + 1}) Tj ET`
    objects.push(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents ${5 + page * 2} 0 R >>`)
    objects.push(`<< /Length ${Buffer.byteLength(stream)} >>\nstream\n${stream}\nendstream`)
  }
  objects.push('<< /Type /Outlines /First 11 0 R /Last 23 0 R /Count 13 >>')
  for (let depth = 0; depth < 12; depth++) {
    const title = depth === 11 ? 'Deepest needle level twelve' : `Nested level ${depth + 1}`
    objects.push(`<< /Title (${title}) /Parent ${depth ? 10 + depth : 10} 0 R /Dest [${depth === 11 ? 8 : 4} 0 R /Fit] ${depth < 11 ? `/First ${12 + depth} 0 R /Last ${12 + depth} 0 R /Count ${11 - depth}` : ''} ${depth === 0 ? '/Next 23 0 R' : ''} >>`)
  }
  objects.push('<< /Title (Sibling chapter) /Parent 10 0 R /Prev 11 0 R /Dest [6 0 R /Fit] >>')
  let pdf = '%PDF-1.4\n', offsets = [0]
  objects.forEach((object, index) => { offsets.push(Buffer.byteLength(pdf)); pdf += `${index + 1} 0 obj\n${object}\nendobj\n` })
  const xref = Buffer.byteLength(pdf)
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n` + offsets.slice(1).map((offset) => `${String(offset).padStart(10, '0')} 00000 n \n`).join('')
  return Buffer.from(pdf + `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`)
}
async function deepOutline([engine, name, width, reducedMotion, height = 900]) {
  const browser = await engine.launch({ headless: true })
  const page = await browser.newPage({ viewport: { width, height }, reducedMotion, hasTouch: true, isMobile: width < 600 })
  try {
    await page.route('**/samples/*.pdf', (route) => route.fulfill({ contentType: 'application/pdf', body: deepOutlinePdf() }))
    await page.goto(base)
    await page.getByRole('button', { name: /start with a sample book/i }).click()
    await page.getByText('Sewn in', { exact: true }).waitFor({ state: 'visible' })
    await page.locator('.sewn-actions .btn.ink').click()
    await page.locator('.reader-paper canvas').waitFor({ state: 'visible' })
    await page.getByRole('button', { name: /^Contents/ }).click()
    const dialog = page.getByRole('dialog', { name: 'Contents', exact: true })
    await page.waitForFunction(() => document.querySelectorAll('.contents-results li').length > 1)
    assert.equal(await dialog.locator('li').count(), 13, 'Actual PDF import retains all twelve outline depths in preorder')
    assert.deepEqual(await dialog.locator('.contents-title').allTextContents(), [...Array.from({ length: 11 }, (_, i) => `Nested level ${i + 1}`), 'Deepest needle level twelve', 'Sibling chapter'])
    await dialog.getByRole('searchbox', { name: 'Search chapters' }).fill('Deepest needle')
    await dialog.getByRole('button', { name: /Deepest needle/ }).click()
    await dialog.waitFor({ state: 'hidden' })
    assert.ok(page.url().endsWith('/3'), 'An actual deeply nested outline destination jumps to its referenced source page')
    await page.getByRole('button', { name: /^Contents/ }).click()
    await dialog.waitFor({ state: 'visible' })
    assert.match(await dialog.locator('[aria-current="location"]').innerText(), /Deepest needle/, 'Active location uses the closest source destination even when PDF outline preorder is not page order')
    await page.keyboard.press('Escape')
    console.log('PASS ' + name + ': real PDF twelve-level outline import, preorder, deepest search and source jump')
  } finally { await browser.close() }
}
async function settledShot(page, path) {
  await page.locator('.scrim, .modal, .book, .reader-bar, .reader-foot').evaluateAll(async (elements) => {
    await Promise.all(elements.flatMap((el) => el.getAnimations()).map((animation) => animation.finished.catch(() => {})))
  })
  const modal = page.locator('.modal')
  if (await modal.count()) {
    const paint = await modal.evaluate((el) => ({ opacity: getComputedStyle(el).opacity, background: getComputedStyle(el).backgroundColor, cream: el.classList.contains('cream'), results: el.querySelector('.contents-results')?.getBoundingClientRect().toJSON() }))
    assert.equal(paint.opacity, '1', 'Visual evidence captures the fully settled dialog')
    assert.ok(paint.cream && /^rgb\(/.test(paint.background), 'The settled Contents dialog paints its opaque cream surface')
    console.log('PAINT ' + path.split('/').at(-1) + ' ' + JSON.stringify(paint))
  }
  await page.screenshot({ path })
}
const overflow = async (page) => {
  const result = await page.evaluate(() => ({ viewport: innerWidth, width: document.documentElement.scrollWidth,
    ribbon: [...document.querySelectorAll('.chapter-strip')].map((el) => ({ width: el.clientWidth, content: el.scrollWidth })) }))
  assert.ok(result.width <= page.viewportSize().width + 2, 'Contents must stay within the page width: ' + JSON.stringify(result))
  assert.ok(result.ribbon.every((r) => r.content <= r.width + 2), 'Chapter ribbons must not scroll sideways')
}
async function run([engine, name, width, reducedMotion, height = 900]) {
  const browser = await engine.launch({ headless: true })
  const page = await browser.newPage({ viewport: { width, height }, isMobile: width < 600, hasTouch: true, reducedMotion })
  const errors = []
  page.on('pageerror', (e) => errors.push(e.message))
  try {
    await page.goto(base)
    await page.getByRole('button', { name: /start with a sample book/i }).click()
    await page.getByText('Sewn in', { exact: true }).waitFor({ state: 'visible', timeout: 25000 })
    await page.locator('.sewn-actions .btn.ink').click({ timeout: 25000 })
    await page.locator('.reader-paper canvas').waitFor({ state: 'visible' })
    const id = await page.evaluate(() => JSON.parse(localStorage.getItem('leu.web.v1')).books[0].id)
    // Persist the real importer's outline shape, including repeated names and
    // deep entries, against the actual sample PDF kept in IndexedDB.
    await page.evaluate(async (id) => {
      const state = JSON.parse(localStorage.getItem('leu.web.v1')), book = state.books.find((b) => b.id === id)
      const outline = Array.from({ length: 500 }, (_, i) => ({
        title: i === 499 ? 'Last chapter needle ' + 'https://example.org/'.repeat(20) : i % 13 === 0 ? 'Repeated heading' : `${i + 1}.1.2.3 ` + 'VeryLongUnbrokenChapterTitle'.repeat(12),
        page: Math.max(1, Math.ceil((i + 1) / 500 * book.pages)), depth: i > 450 ? i % 15 : 0,
      }))
      await new Promise((resolve, reject) => {
        const request = indexedDB.open('keyval-store')
        request.onsuccess = () => {
          const db = request.result, tx = db.transaction('keyval', 'readwrite')
          tx.objectStore('keyval').put(outline, `outline:${id}`)
          tx.oncomplete = () => { db.close(); resolve() }; tx.onerror = () => reject(tx.error)
        }
        request.onerror = () => reject(request.error)
      })
    }, id)
    await page.goto(base + '/#/book/' + id)
    await page.reload()
    await page.locator('.chapter-card').waitFor({ state: 'visible' })
    await overflow(page)
    await settledShot(page, join(evidence, name + '-book.png'))
    console.log('GEOMETRY ' + name + ' book ' + JSON.stringify(await page.evaluate(() => ({ viewport: innerWidth, document: document.documentElement.scrollWidth, section: document.querySelector('.book-grid > section').getBoundingClientRect().toJSON() }))))
    const trigger = page.getByRole('button', { name: /^Contents/ }).first()
    await trigger.click()
    let dialog = page.getByRole('dialog', { name: 'Contents', exact: true })
    await dialog.waitFor({ state: 'visible' })
    assert.equal(await dialog.locator('li').count(), 500, 'No outline entries are silently truncated')
    const chapterWidth = await dialog.locator('.contents-results').evaluate((el) => ({
      viewport: el.clientWidth, content: el.scrollWidth,
      rowsFit: [...el.querySelectorAll('li button')].every((button) =>
        button.getBoundingClientRect().right <= el.getBoundingClientRect().right + 2),
    }))
    assert.ok(chapterWidth.content <= chapterWidth.viewport + 2 && chapterWidth.rowsFit,
      'Five hundred long chapters must use the available width and scroll vertically only: ' + JSON.stringify(chapterWidth))
    assert.ok(await dialog.locator('.contents-results').evaluate((el) => el.clientHeight >= 44), 'Contents keeps a usable chapter result viewport in short/keyboard-height screens')
    await dialog.getByRole('searchbox', { name: 'Search chapters' }).fill('Repeated heading')
    await dialog.getByRole('button', { name: /Repeated heading/ }).nth(2).click()
    await dialog.waitFor({ state: 'hidden' })
    assert.equal(await trigger.getAttribute('aria-label'), 'Contents, 27 of 500', 'Repeated titles keep their stable outline identity')
    await trigger.click()
    await dialog.waitFor({ state: 'visible' })
    await dialog.getByRole('searchbox', { name: 'Search chapters' }).fill('Last chapter needle')
    assert.equal(await dialog.locator('li').count(), 1)
    await overflow(page)
    await dialog.getByRole('button', { name: /Last chapter needle/ }).click()
    await dialog.waitFor({ state: 'hidden' })
    assert.equal(await trigger.evaluate((el) => document.activeElement === el), true, 'Selecting restores disclosure focus')
    await page.getByRole('button', { name: 'Read this chapter', exact: true }).click()
    await page.locator('.reader-paper canvas').waitFor({ state: 'visible' })
    const lastPage = await page.evaluate(() => JSON.parse(localStorage.getItem('leu.web.v1')).books[0].pages)
    assert.ok(page.url().endsWith('/' + lastPage), 'Read this chapter opens the selected late section page')
    await overflow(page)
    await page.getByRole('button', { name: /^Contents/ }).click()
    dialog = page.getByRole('dialog', { name: 'Contents', exact: true })
    await dialog.waitFor({ state: 'visible' })
    await page.waitForFunction(() => document.querySelectorAll('.contents-results li').length === 500)
    assert.equal(await dialog.locator('li').count(), 500)
    assert.match(await dialog.locator('[aria-current="location"]').innerText(), /Last chapter needle/)
    await dialog.getByRole('searchbox', { name: 'Search chapters' }).fill('Repeated heading')
    await dialog.getByRole('button', { name: /Repeated heading/ }).first().click()
    await dialog.waitFor({ state: 'hidden' })
    assert.ok(page.url().endsWith('/1'), 'Contents jumps to an earlier source page')
    await page.waitForFunction(() => document.activeElement === document.querySelector('.reader-bar .contents-trigger'))
    assert.equal(await page.getByRole('button', { name: /^Contents/ }).evaluate((el) => document.activeElement === el), true, 'Reader page jumps restore the disclosure focus')
    await page.getByRole('button', { name: /^Contents/ }).click()
    await dialog.waitFor({ state: 'visible' })
    await page.keyboard.press('Escape')
    await dialog.waitFor({ state: 'hidden' })
    assert.equal(await page.getByRole('button', { name: /^Contents/ }).evaluate((el) => document.activeElement === el), true)
    await page.getByRole('button', { name: 'Enter full-screen reading' }).click()
    await page.locator('.paged-reader').waitFor({ state: 'visible' })
    await page.getByRole('button', { name: 'Show reading controls' }).focus()
    await page.keyboard.press('Enter')
    await settledShot(page, join(evidence, name + '-controls.png'))
    await page.getByRole('button', { name: /^Contents/ }).click()
    dialog = page.getByRole('dialog', { name: 'Contents', exact: true })
    await dialog.waitFor({ state: 'visible' })
    await dialog.getByRole('searchbox', { name: 'Search chapters' }).fill('Repeated heading')
    assert.ok(await dialog.locator('li').count() > 2, 'Repeated titles remain independently reachable')
    await overflow(page)
    await settledShot(page, join(evidence, name + '.png'))
    await page.locator('.scrim').click({ position: { x: 2, y: 2 } })
    await dialog.waitFor({ state: 'hidden' })
    assert.equal(await page.locator('.reader-immersive').count(), 1, 'Dismiss contents keeps fullscreen active')
    const controls = await page.locator('.reader-bar button').evaluateAll((buttons) => buttons.filter((b) => b.getClientRects().length).map((b) => ({ label: b.textContent || b.ariaLabel, ...b.getBoundingClientRect().toJSON() })))
    assert.ok(controls.every((b) => b.left >= -1 && b.right <= width + 1 && b.height >= 40), 'Toolbar controls fit and keep usable target heights: ' + JSON.stringify(controls))
    console.log('PASS ' + name + ': 500 long/deep chapters, overview select/read, last result, active location, repeat titles, focus, Escape/outside, fullscreen, no overflow')
    assert.deepEqual(errors, [])
  } catch (error) {
    await page.screenshot({ path: join(evidence, name + '-failed.png') }).catch(() => {})
    throw error
  } finally { await browser.close() }
}
try {
  for (let i = 0; i < 60; i++) {
    try { if ((await fetch(base)).ok) break } catch {}
    if (i === 59) throw new Error('Preview did not start')
    await new Promise((r) => setTimeout(r, 150))
  }
  for (const config of configs) if (!process.env.LEU_CONTENTS_CASE || config[1] === process.env.LEU_CONTENTS_CASE) { await deepOutline(config); await run(config) }
} finally { server.kill('SIGTERM') }
