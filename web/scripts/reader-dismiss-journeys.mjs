import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdir } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { chromium, webkit } from 'playwright'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const base = 'http://127.0.0.1:4185'
const evidence = join(root, 'qa-evidence/dismiss')
await mkdir(evidence, { recursive: true })
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', 'preview', '--host', '127.0.0.1', '--port', '4185', '--strictPort'], { cwd: root, stdio: 'ignore' })
const configs = [
  [chromium, 'chromium-phone', 390, 844, 'no-preference', 'record'],
  [webkit, 'webkit-phone', 390, 844, 'no-preference', 'absent'],
  [webkit, 'webkit-small', 320, 640, 'reduce', 'throw'],
  [webkit, 'webkit-landscape', 844, 390, 'no-preference', 'absent'],
  [chromium, 'chromium-desktop', 1440, 900, 'no-preference', 'record'],
  [chromium, 'chromium-reduced', 390, 844, 'reduce', 'absent'],
]
const visible = (el) => el.waitFor({ state: 'visible', timeout: 20000 })
async function enter(page) {
  await page.getByRole('button', { name: 'Enter full-screen reading' }).click()
  await visible(page.locator('.paged-current .prose'))
}
async function drive(page, engine, path, inspect, ending = 'up') {
  const box = await page.locator('.paged-reader').boundingBox()
  const touch = engine === chromium && box.width < 600
  const start = { x: box.x + (touch ? box.width * (path[0][0] < 0 ? .72 : .5) : path[0][0] < 0 ? box.width - 9 : 9), y: box.y + box.height * .3 }
  const session = touch ? await page.context().newCDPSession(page) : null
  if (session) await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [start] })
  else { await page.mouse.move(start.x, start.y); await page.mouse.down() }
  let previous = [0, 0]
  for (const [dx, dy] of path) {
    for (let i = 1; i <= 8; i++) {
      const point = { x: start.x + previous[0] + (dx - previous[0]) * i / 8, y: start.y + previous[1] + (dy - previous[1]) * i / 8 }
      if (session) await session.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [point] })
      else await page.mouse.move(point.x, point.y)
    }
    previous = [dx, dy]
  }
  if (inspect) await inspect()
  if (session) {
    if (ending === 'pinch') await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 0, x: start.x + previous[0], y: start.y + previous[1] }, { id: 2, x: 80, y: start.y }] })
    await session.send('Input.dispatchTouchEvent', { type: ending === 'cancel' ? 'touchCancel' : 'touchEnd', touchPoints: [] })
    await session.detach()
  } else {
    if (ending === 'cancel') await page.evaluate(() => window.dispatchEvent(new PointerEvent('pointercancel')))
    await page.mouse.up()
  }
}
const pull = (page, engine, dy, inspect, ending) => drive(page, engine, [[4, dy]], inspect, ending)
async function settled(page) {
  await page.waitForFunction(() => {
    const root = document.querySelector('.paged-reader'), stage = document.querySelector('.paged-dismiss-stage')
    return root?.dataset.settled === 'true' && !root.dataset.pullState && stage && Math.abs(new DOMMatrixReadOnly(getComputedStyle(stage).transform).m42) < 1
  }, null, { timeout: 5000 })
}
async function neutral(page, saved) {
  await settled(page)
  assert.equal(await page.locator('.paged-reader').getAttribute('data-location'), saved)
  assert.equal(await page.evaluate(() => document.querySelector('.reader-grid').scrollTop), 0)
}
async function center(page) {
  const box = await page.locator('.paged-reader').boundingBox()
  const point = { x: box.x + box.width / 2, y: box.y + box.height / 2 }
  assert.ok(await page.evaluate(({ x, y }) => document.querySelector('.paged-reader').contains(document.elementFromPoint(x, y)), point), 'The centre is an unobstructed reading surface')
  await page.touchscreen.tap(point.x, point.y)
}
async function run([engine, name, width, height, reducedMotion, haptics]) {
  const browser = await engine.launch({ headless: true })
  const page = await browser.newPage({ viewport: { width, height }, isMobile: width < 600 || height < 500, hasTouch: true, reducedMotion })
  const errors = []
  page.on('pageerror', (error) => errors.push(error.message))
  await page.addInitScript((mode) => {
    window.__HAPTIC_CALLS = []
    window.__NORMAL_CLICKS = 0
    window.__INPUT_TRACE = []
    for (const type of ['pointerdown', 'pointerup', 'pointercancel', 'blur', 'resize']) window.addEventListener(type, (event) => { window.__INPUT_TRACE.push({ type, target: event.target?.className, x: event.clientX, y: event.clientY, selected: !!getSelection()?.toString(), settled: document.querySelector('.paged-reader')?.dataset.settled, pull: document.querySelector('.paged-reader')?.dataset.pullState }); window.__INPUT_TRACE = window.__INPUT_TRACE.slice(-25) })
    window.addEventListener('click', (event) => {
      if (event.target.closest('.reader:not(.reader-immersive)')) window.__NORMAL_CLICKS++
    })
    Object.defineProperty(navigator, 'vibrate', { configurable: true, value: mode === 'absent' ? undefined : (pattern) => {
      window.__HAPTIC_CALLS.push(pattern)
      if (mode === 'throw') throw new Error('Hardware not available')
      return true
    } })
  }, haptics)
  try {
    await page.goto(base, { waitUntil: 'domcontentloaded' })
    await page.getByRole('button', { name: /start with a sample book/i }).click()
    await page.locator('.sewn-actions .btn.ink').click({ timeout: 25000 })
    await visible(page.locator('.reader-paper .prose'))
    await enter(page)
    const first = await page.locator('.paged-reader').getAttribute('data-location')
    // Horizontal input remains page navigation even when it finishes diagonally.
    await drive(page, engine, [[-Math.min(440, width * .52), 30], [-Math.min(440, width * .52), 100]])
    await page.waitForFunction((old) => document.querySelector('.paged-reader')?.dataset.location !== old && document.querySelector('.paged-reader')?.dataset.settled === 'true', first)
    const saved = await page.locator('.paged-reader').getAttribute('data-location')
    await pull(page, engine, -70)
    await neutral(page, saved)
    await pull(page, engine, 42, async () => {
      assert.equal(await page.locator('.paged-reader').getAttribute('data-pull-state'), 'tracking')
      const geometry = await page.evaluate(() => {
        const shell = document.querySelector('.reader-immersive').getBoundingClientRect()
        return { y: shell.y, expected: visualViewport?.offsetTop ?? 0, windowY: scrollY, gridY: document.querySelector('.reader-grid').scrollTop,
          offset: new DOMMatrixReadOnly(getComputedStyle(document.querySelector('.paged-dismiss-stage')).transform).m42 }
      })
      assert.ok(Math.abs(geometry.y - geometry.expected) < 2)
      assert.equal(geometry.windowY, 0)
      assert.equal(geometry.gridY, 0)
      assert.ok(reducedMotion === 'reduce' ? geometry.offset === 0 : geometry.offset > 0 && geometry.offset < 42, 'Pull feedback is resisted; reduced motion stays stationary')
    })
    await neutral(page, saved)
    await page.evaluate(() => { window.__HAPTIC_CALLS = [] })
    await drive(page, engine, [[4, 190], [4, 30], [4, 180], [4, 25]])
    await neutral(page, saved)
    assert.ok((await page.evaluate(() => window.__HAPTIC_CALLS)).length <= 1, 'Threshold haptic fires at most once per gesture')
    await pull(page, engine, 190, async () => {
      assert.equal(await page.locator('.paged-reader').getAttribute('data-pull-state'), 'ready')
      assert.equal(await page.locator('.paged-dismiss-hint span').textContent(), 'Release to exit')
      assert.ok(await page.locator('.paged-dismiss-hint').evaluate((el) => { const before = el.style.pointerEvents; el.style.pointerEvents = 'auto'; const r = el.getBoundingClientRect(), hit = document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2); el.style.pointerEvents = before; return el === hit || el.contains(hit) }), 'The ready hint must be painted above the page, including reduced motion')
    }, 'cancel')
    await neutral(page, saved)
    if (engine === chromium && width < 600) {
      await pull(page, engine, 170, undefined, 'pinch')
      await neutral(page, saved)
    }
    await pull(page, engine, 42, async () => {
      await page.evaluate(() => {
        const sentence = document.querySelector('.paged-current .prose .s'), range = document.createRange()
        range.selectNodeContents(sentence)
        const selection = getSelection(); selection.removeAllRanges(); selection.addRange(range)
        document.dispatchEvent(new Event('selectionchange'))
      })
    })
    await neutral(page, saved)
    await page.evaluate(() => { getSelection().removeAllRanges(); document.dispatchEvent(new Event('selectionchange')) })
    if (engine === chromium && width < 600) {
      await pull(page, engine, 170, async () => {
        await page.setViewportSize({ width: width - 10, height })
        await page.waitForFunction(() => !document.querySelector('.paged-reader')?.dataset.pullState)
      })
      await settled(page)
      await page.setViewportSize({ width, height })
      await page.waitForFunction((old) => document.querySelector('.paged-reader')?.dataset.location === old, saved)
    }
    // A native selected passage owns its gesture; dismissal must not steal it.
    await page.evaluate(() => {
      const sentence = document.querySelector('.paged-current .prose .s'), range = document.createRange()
      range.selectNodeContents(sentence)
      const selection = getSelection(); selection.removeAllRanges(); selection.addRange(range)
      document.dispatchEvent(new Event('selectionchange'))
    })
    await pull(page, engine, 190)
    await neutral(page, saved)
    await page.evaluate(() => { getSelection().removeAllRanges(); document.dispatchEvent(new Event('selectionchange')) })
    await center(page)
    await visible(page.getByRole('button', { name: 'Original page' }))
    await page.getByRole('button', { name: 'Original page' }).click()
    assert.equal(await page.getByRole('button', { name: 'Original page' }).getAttribute('aria-pressed'), 'true', 'A new intentional tap immediately after revealing controls is not swallowed')
    await page.waitForFunction(() => parseFloat(document.querySelector('.paged-current canvas')?.style.width ?? '0') > 0)
    for (let i = 0; i < 4; i++) await page.getByRole('button', { name: 'Zoom in' }).click()
    await page.waitForFunction(() => parseFloat(document.querySelector('.paged-current canvas')?.style.height ?? '0') > document.querySelector('.paged-current .paged-original').clientHeight + 10)
    const originalY = await page.locator('.paged-current canvas').evaluate((el) => el.getBoundingClientRect().y)
    await pull(page, engine, 130)
    await settled(page)
    assert.ok(await page.locator('.paged-current canvas').evaluate((el, y) => el.getBoundingClientRect().y > y + 4, originalY), 'A zoomed original pans vertically without exiting')
    await page.getByRole('button', { name: 'Reset zoom' }).click()
    await page.getByRole('button', { name: 'For reading' }).click()
    await visible(page.locator('.paged-current .prose'))
    await center(page)
    await neutral(page, saved)
    await page.evaluate(() => { window.__HAPTIC_CALLS = []; window.__NORMAL_CLICKS = 0 })
    const beforeExit = await page.url()
    await pull(page, engine, 190)
    await page.locator('.reader-immersive').waitFor({ state: 'hidden', timeout: 4000 })
    assert.equal(await page.url(), beforeExit, 'The exit gesture does not navigate to another source')
    assert.equal(await page.evaluate(() => window.__NORMAL_CLICKS), 0, 'No trailing click reaches the normal reader')
    const calls = await page.evaluate(() => window.__HAPTIC_CALLS)
    if (haptics === 'record') assert.ok(calls.length >= 1 && calls.length <= 2 && calls.every((n) => n === 6 || n === 12), 'Haptics use short semantic ticks only')
    if (haptics === 'absent') assert.deepEqual(calls, [])
    assert.equal(await page.evaluate(() => document.body.style.position), '', 'Exit restores background scroll')
    assert.equal(await page.evaluate(() => document.fullscreenElement === null), true)
    await enter(page)
    await page.waitForFunction((old) => document.querySelector('.paged-reader')?.dataset.location === old, saved)
    if (name === 'chromium-desktop') {
      const box = await page.locator('.paged-reader').boundingBox()
      await page.mouse.move(box.width / 2, box.height / 2)
      await page.mouse.wheel(0, 35)
      await settled(page)
      await neutral(page, saved)
      const beforeWheel = await page.locator('.paged-reader').getAttribute('data-location')
      for (let i = 0; i < 7; i++) { await page.mouse.wheel(40, 2); await page.waitForTimeout(65) }
      await settled(page)
      const afterWheel = await page.locator('.paged-reader').getAttribute('data-location')
      assert.equal(afterWheel, `${Number(beforeWheel.split(':')[0]) + 1}:0`, 'One continuous wheel burst turns exactly one source page')
      await page.keyboard.press('ArrowLeft')
      await page.waitForFunction((old) => document.querySelector('.paged-reader')?.dataset.location === old && document.querySelector('.paged-reader')?.dataset.settled === 'true', beforeWheel)
      await page.mouse.wheel(0, 80)
      await page.mouse.wheel(0, 80)
      await page.locator('.reader-immersive').waitFor({ state: 'hidden' })
    }
    await page.screenshot({ path: join(evidence, name + '-passed.png') })
    assert.deepEqual(errors, [])
    console.log('PASS ' + name + ': pull/return/cancel, locked diagonals, selection, zoomed pan, haptic fallback, exit and bookmark')
  } catch (error) {
    console.error(name, await page.evaluate(() => ({ trace: window.__INPUT_TRACE, root: document.querySelector('.paged-reader')?.dataset, hit: document.elementFromPoint(innerWidth / 2, innerHeight / 2)?.outerHTML.slice(0,200), inert: [...document.querySelectorAll('[inert]')].map(el=>el.className), rect: document.querySelector('.paged-reader')?.getBoundingClientRect().toJSON(), pointer: document.querySelector('.paged-reader') ? getComputedStyle(document.querySelector('.paged-reader')).pointerEvents : null, scroll:[scrollX,scrollY], viewport:[innerWidth,innerHeight,visualViewport?.offsetLeft,visualViewport?.offsetTop], selected: !!getSelection()?.toString() })))
    await page.screenshot({ path: join(evidence, name + '-failed.png') }).catch(() => {})
    throw error
  } finally { await browser.close() }
}
try {
  for (let attempt = 0; attempt < 60; attempt++) {
    try { if ((await fetch(base)).ok) break } catch {}
    if (attempt === 59) throw new Error('Preview did not start')
    await new Promise((resolve) => setTimeout(resolve, 150))
  }
  for (const config of configs) if (!process.env.LEU_DISMISS_CASE || config[1] === process.env.LEU_DISMISS_CASE) await run(config)
} finally { server.kill('SIGTERM') }
