import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdir, writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { chromium, webkit } from 'playwright'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const base = 'http://127.0.0.1:4177'
const evidence = join(root, 'qa-evidence')
await mkdir(evidence, { recursive: true })
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', 'preview', '--host', '127.0.0.1', '--port', '4177', '--strictPort'], { cwd: root, stdio: 'ignore' })
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

// Inspect visible canvas pixels on the actual app route, with real elapsed time.
// No isolated scene fixture, synthetic animation clock, or image-load-only assertion.
async function movement(page) {
  const canvas = page.locator('.home-scene .nook-glass canvas')
  await canvas.waitFor({ state: 'visible' })
  await canvas.scrollIntoViewIfNeeded()
  await page.waitForTimeout(1600)
  await canvas.evaluate((el) => {
    window.__homeBefore = Array.from(el.getContext('2d').getImageData(0, 0, el.width, el.height).data)
  })
  await page.waitForTimeout(1600)
  return canvas.evaluate((el) => {
    const pixels = el.getContext('2d').getImageData(0, 0, el.width, el.height).data
    const old = window.__homeBefore
    let changed = 0
    for (let i = 0; i < pixels.length; i += 4) {
      if (Math.max(Math.abs(pixels[i] - old[i]), Math.abs(pixels[i + 1] - old[i + 1]), Math.abs(pixels[i + 2] - old[i + 2])) > 12) changed++
    }
    return changed / (pixels.length / 4)
  })
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
  page.on('requestfailed', (request) => record('network', { url: request.url(), reason: request.failure()?.errorText }))
  page.on('console', (message) => { if (message.type() === 'error') record('console', message.text()) })
  try {
    await page.goto(base, { waitUntil: 'domcontentloaded' })
    phase = 'import'
    await page.getByRole('button', { name: /start with a sample book/i }).click()
    await page.locator('.sewn-actions .btn.ink').click({ timeout: 25000 })
    await page.locator('.reader-paper .prose p').first().waitFor({ state: 'visible', timeout: 25000 })
    phase = 'home'
    await page.getByRole('link', { name: 'Leu, home', exact: true }).click()
    await page.locator('.home-scene .nook').waitFor({ state: 'visible' })
    const initialChange = await movement(page)
    record('initial', { preference: reduced, changedPercent: initialChange * 100, hasPlay: await page.getByRole('button', { name: 'Play animation', exact: true }).count(), hasPause: await page.getByRole('button', { name: 'Pause animation', exact: true }).count() })
    await page.screenshot({ path: join(evidence, 'home-' + label + '-before.png') })
    if (reduced === 'reduce') {
      assert.equal(initialChange, 0, 'Device reduced-motion preference must initially be respected')
      assert.equal(await page.getByRole('button', { name: 'Play animation', exact: true }).count(), 1, 'Home silently disables its illustration: the user needs an explicit Play animation control')
      await page.getByRole('button', { name: 'Play animation', exact: true }).click()
    } else {
      assert.ok(initialChange > 0, 'Home must animate automatically without touch')
    }
    phase = 'play-pause'
    assert.ok(await movement(page) > 0.005, 'Playing must produce visible rain, not only a running timer')
    await page.getByRole('button', { name: 'Pause animation', exact: true }).click()
    assert.equal(await movement(page), 0, 'Pause must stop the actual scene')
    await page.getByRole('button', { name: 'Play animation', exact: true }).click()
    assert.ok(await movement(page) > 0.005, 'Play must restart the actual scene')
    phase = 'reload'
    await page.reload({ waitUntil: 'domcontentloaded' })
    await page.locator('.home-scene .nook').waitFor({ state: 'visible' })
    assert.equal(await page.getByRole('button', { name: 'Pause animation', exact: true }).count(), 1, 'An explicit playback choice must survive reloading')
    assert.ok(await movement(page) > 0.005, 'The scene must resume after reload')
    phase = 'other-tab'
    const other = await context.newPage()
    await other.goto('about:blank')
    await page.waitForTimeout(600)
    await other.close()
    await page.bringToFront()
    await page.evaluate(() => window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true })))
    assert.ok(await movement(page) > 0.005, 'The scene must resume after returning to the page')
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2), false)
    assert.equal(await page.locator('.nook-glass canvas').evaluate((el) => getComputedStyle(el).touchAction), 'auto')
    phase = 'reopen-reader'
    await page.getByRole('button', { name: 'Pause animation', exact: true }).click()
    await page.getByRole('button', { name: 'Keep reading', exact: true }).click()
    await page.locator('.reader-paper .prose p').first().waitFor({ state: 'visible' })
    phase = 'return-home'
    await page.getByRole('link', { name: 'Leu, home', exact: true }).click()
    assert.equal(await page.getByRole('button', { name: 'Play animation', exact: true }).count(), 1, 'Pause choice must survive app navigation')
    assert.equal(await movement(page), 0)
    await page.getByRole('button', { name: 'Play animation', exact: true }).click()
    await page.screenshot({ path: join(evidence, 'home-' + label + '-after.png') })
    record('behaviors-passed', 'Motion, pause, reload and reading navigation passed')
    assert.deepEqual(errors, [], 'Home must not raise browser exceptions')
    console.log('PASS ' + label + ': actual Home rain, explicit reduced-motion override, Pause/Play, reload, return to page, reading and scrolling')
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
