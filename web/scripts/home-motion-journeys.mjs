import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdir, writeFile, readdir } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { chromium, webkit } from 'playwright'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const base = 'http://127.0.0.1:4177'
const evidence = join(root, 'qa-evidence')
await mkdir(evidence, { recursive: true })
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', 'preview', '--host', '127.0.0.1', '--port', '4177', '--strictPort'], { cwd: root, stdio: 'ignore' })
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

async function checkRevalidatedWorker() {
  const name = (await readdir(join(root, 'dist/assets'))).find((item) => /^pdf\.worker.*\.mjs$/.test(item))
  assert.ok(name, 'Production PDF worker not found')
  const first = await fetch(base + '/assets/' + name)
  assert.equal(first.status, 200)
  const etag = first.headers.get('etag')
  assert.ok(etag, 'Worker must be cache-revalidated in this check')
  await first.arrayBuffer()
  const cached = await fetch(base + '/assets/' + name, { headers: { 'If-None-Match': etag } })
  assert.equal(cached.status, 304)
  assert.equal(cached.headers.get('Cross-Origin-Embedder-Policy'), 'require-corp')
  assert.equal(cached.headers.get('Cross-Origin-Resource-Policy'), 'same-origin')
  console.log('PASS worker revalidation preserves COEP and CORP')
}

// Verify the real Home canvas AND the composited pixels the browser displays.
// A running offscreen canvas or an advancing counter is not a passing animation.
async function movement(page, label) {
  const canvas = page.locator('.home-scene .nook-glass canvas')
  await canvas.waitFor({ state: 'visible' })
  await canvas.scrollIntoViewIfNeeded()
  await page.waitForTimeout(1600)
  const screenBefore = await page.locator('.home-scene .nook-glass').screenshot()
  await canvas.evaluate((el) => {
    window.__homeBefore = el.getContext('2d').getImageData(0, 0, el.width, el.height).data
  })
  await page.waitForTimeout(1600)
  const fraction = await canvas.evaluate((el) => {
    const pixels = el.getContext('2d').getImageData(0, 0, el.width, el.height).data
    const old = window.__homeBefore
    let changed = 0
    for (let i = 0; i < pixels.length; i += 4) {
      if (Math.max(Math.abs(pixels[i] - old[i]), Math.abs(pixels[i + 1] - old[i + 1]), Math.abs(pixels[i + 2] - old[i + 2])) > 12) changed++
    }
    return changed / (pixels.length / 4)
  })
  const screenAfter = await page.locator('.home-scene .nook-glass').screenshot()
  const screenChanged = !screenBefore.equals(screenAfter)
  console.log('MOTION ' + label + ': ' + JSON.stringify({ changedPercent: fraction * 100, screenChanged }))
  if (fraction > 0.005) assert.ok(screenChanged, label + ': moving canvas must also change the visible illustration')
  return fraction
}

async function run(engine, label, width, reduced) {
  const browser = await engine.launch({ headless: true })
  const context = await browser.newContext({ viewport: { width, height: 844 }, deviceScaleFactor: 2, isMobile: width < 600, hasTouch: width < 600, reducedMotion: reduced })
  const page = await context.newPage()
  const errors = [], diagnostics = []
  let phase = 'load'
  const record = (type, detail) => {
    const entry = { type, phase, detail, url: page.url() }
    diagnostics.push(entry)
    console.log('HOME ' + label + ' ' + JSON.stringify(entry))
  }
  page.on('pageerror', (error) => { errors.push({ phase, message: error.message }); record('exception', error.message) })
  page.on('crash', () => record('crash', 'Browser page process crashed'))
  page.on('close', () => record('close', 'Browser page closed'))
  page.on('requestfailed', (request) => record('network', { url: request.url(), reason: request.failure()?.errorText }))
  page.on('console', (message) => { if (message.type() === 'error') record('console', message.text()) })
  const moves = () => movement(page, label + '/' + phase)
  try {
    await page.goto(base, { waitUntil: 'domcontentloaded' })
    phase = 'import'
    await page.getByRole('button', { name: /start with a sample book/i }).click()
    await page.locator('.sewn-actions .btn.ink').click({ timeout: 25000 })
    await page.getByRole('button', { name: 'For reading', exact: true }).click()
    await page.locator('.reader-paper .prose p').first().waitFor({ state: 'visible', timeout: 25000 })
    phase = 'home'
    if (width > 760) {
      // In a book, the title links to its overview; Home is the next wordmark.
      await page.locator('.topbar .reader-top-title').click()
      await page.getByRole('heading', { name: 'Computer Science Essentials' }).waitFor()
      await page.locator('.topbar .wordmark').click()
    } else {
      await page.getByRole('button', { name: 'Open navigation' }).click()
      await page.getByRole('navigation', { name: 'Mobile places' }).getByRole('link', { name: 'Home', exact: true }).click()
    }
    await page.locator('.home-scene .nook').waitFor({ state: 'visible' })
    const noAnimationButtons = async () => assert.equal(
      await page.getByRole('button', { name: /^(Play animation|Pause animation|Resume automatic playback)$/ }).count(),
      0, 'Home must not expose animation playback controls',
    )
    const assertMotion = async () => {
      const changed = await moves()
      assert.ok(changed > 0.005, 'Home must always visibly animate as explicitly requested')
    }
    await noAnimationButtons()
    const resume = await page.getByRole('button', { name: 'Continue reading', exact: true }).boundingBox()
    assert.ok(resume && resume.y + resume.height <= (width <= 430 ? 844 : 900), 'Continue reading must be visible in the first viewport')
    await assertMotion()
    await page.screenshot({ path: join(evidence, 'home-' + label + '-before.png') })
    // Obsolete manual choices must neither freeze the scene nor override the OS.
    for (const oldChoice of ['pause', 'play']) {
      await page.evaluate((choice) => localStorage.setItem('leu.scene-motion.v1', choice), oldChoice)
      phase = 'reload-' + oldChoice
      await page.reload({ waitUntil: 'domcontentloaded' })
      await page.locator('.home-scene .nook').waitFor({ state: 'visible' })
      await noAnimationButtons()
      await assertMotion()
    }
    phase = 'other-tab'
    const other = await context.newPage()
    await other.goto('about:blank')
    await page.waitForTimeout(600)
    await other.close()
    await page.bringToFront()
    await page.evaluate(() => window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true })))
    await assertMotion()
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2), false)
    assert.equal(await page.locator('.nook-glass canvas').evaluate((el) => getComputedStyle(el).touchAction), 'auto')
    phase = 'reopen-reader'
    await page.getByRole('button', { name: 'Continue reading', exact: true }).click()
    await page.getByRole('button', { name: 'For reading', exact: true }).click()
    await page.locator('.reader-paper .prose p').first().waitFor({ state: 'visible' })
    phase = 'return-home'
    if (width > 760) {
      // In a book, the title links to its overview; Home is the next wordmark.
      await page.locator('.topbar .reader-top-title').click()
      await page.getByRole('heading', { name: 'Computer Science Essentials' }).waitFor()
      await page.locator('.topbar .wordmark').click()
    } else {
      await page.getByRole('button', { name: 'Open navigation' }).click()
      await page.getByRole('navigation', { name: 'Mobile places' }).getByRole('link', { name: 'Home', exact: true }).click()
    }
    await page.locator('.home-scene .nook').waitFor({ state: 'visible' })
    await noAnimationButtons()
    await assertMotion()
    // Preference changes must apply immediately, without a page reload.
    await page.emulateMedia({ reducedMotion: reduced === 'reduce' ? 'no-preference' : 'reduce' })
    const liveChange = await moves()
    assert.ok(liveChange > 0.005, 'Home stays playing across device preference changes')
    await page.screenshot({ path: join(evidence, 'home-' + label + '-after.png') })
    assert.deepEqual(errors, [], 'Home must not raise browser exceptions')
    console.log('PASS ' + label + ': actual visible Home rain, no playback controls, live reduced motion, legacy storage, reload and reading')
  } catch (error) {
    record('failure', String(error))
    await page.screenshot({ path: join(evidence, 'home-' + label + '-failed.png'), fullPage: true }).catch(() => {})
    throw error
  } finally {
    await writeFile(join(evidence, 'home-' + label + '-diagnostics.json'), JSON.stringify(diagnostics, null, 2))
    await browser.close()
  }
}
try {
  let ready = false
  for (let n = 0; n < 50; n++) {
    try { if ((await fetch(base)).ok) { ready = true; break } } catch {}
    await sleep(200)
  }
  assert.ok(ready, 'Preview server did not start')
  await checkRevalidatedWorker()
  const failed = []
  for (const args of [
    [webkit, 'webkit-390-reduced', 390, 'reduce'],
    [webkit, 'webkit-390-auto', 390, 'no-preference'],
    [webkit, 'webkit-320-auto', 320, 'no-preference'],
    [chromium, 'desktop-1440', 1440, 'no-preference'],
  ]) {
    try { await run(...args) } catch (error) { failed.push(args[1] + ': ' + error.message) }
  }
  assert.deepEqual(failed, [], 'Home browser configurations failed')
} finally { server.kill('SIGTERM') }
