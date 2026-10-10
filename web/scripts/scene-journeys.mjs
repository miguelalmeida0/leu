import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdir, writeFile, rm } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { chromium, webkit } from 'playwright'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const evidence = join(root, 'qa-evidence')
const name = 'scene-acceptance-' + process.pid
const html = join(root, name + '.html')
const entry = join(root, name + '.tsx')
const base = 'http://127.0.0.1:4176'
await mkdir(evidence, { recursive: true })
await writeFile(html, '<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><title>Leu scene acceptance</title><div id="root"></div><script type="module" src="/' + name + '.tsx"></script>')
await writeFile(entry, `
import { useState } from 'react'
import { createRoot } from 'react-dom/client'
import { Basket } from './src/scenes/Basket'
import { NookScene } from './src/scenes/NookScene'
import { SnowGlobe } from './src/scenes/SnowGlobe'
import { Dock } from './src/components/Dock'
import { chooseVoice, speak } from './src/lib/voice'
import './src/styles.css'
chooseVoice('system:default')
function Fixture() {
  const [scene, setScene] = useState('basket')
  const [lit, setLit] = useState(2)
  return <main style={{ maxWidth: 720, padding: 16, margin: '0 auto' }}>
    <h1 style={{ fontSize: 22 }}>Leu scene acceptance</h1>
    <div style={{ display: 'flex', gap: 16, padding: '14px 0', flexWrap: 'wrap' }}>
      {['basket', 'nook', 'globe'].map((item) => <button key={item} onClick={() => setScene(item)}>{item}</button>)}
      <label>Earned windows <input aria-label="Earned windows" type="number" min="0" max="3" value={lit} onChange={(e) => setLit(Number(e.target.value))} style={{ width: 44 }} /></label>
    </div>
    <div data-scene={scene} style={{ width: '100%' }}>
      {scene === 'basket' ? <Basket /> : scene === 'nook' ? <NookScene /> : <SnowGlobe lit={lit} />}
    </div>
    <Dock page={1} pages={4} canPlay={true} onPlay={() => speak('Read this sentence.', 'acceptance')} onTurn={() => {}} />
  </main>
}
createRoot(document.getElementById('root')).render(<Fixture />)
`)
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--port', '4176', '--strictPort'], {
  cwd: root, env: { ...process.env, NO_OPEN: '1' }, stdio: ['ignore', 'pipe', 'pipe'],
})
let serverLog = ''
server.stdout.on('data', (s) => { serverLog += s })
server.stderr.on('data', (s) => { serverLog += s })
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

async function canvasChanges(page, selector, label) {
  const canvas = page.locator(selector).first()
  await canvas.waitFor({ state: 'visible' })
  const touch = await canvas.evaluate((el) => getComputedStyle(el).touchAction)
  assert.equal(touch, 'auto', label + ': canvas must not capture touch scrolling')
  await page.clock.runFor(1000)
  const before = await canvas.evaluate((el) => el.toDataURL())
  await page.clock.runFor(1400)
  const after = await canvas.evaluate((el) => el.toDataURL())
  assert.notEqual(before, after, label + ': artwork must animate without a pointer')
}

async function windowLight(page, which) {
  return page.locator('canvas.globe').evaluate((el, n) => {
    const panes = [[448, 360], [501, 361.5], [555, 364]]
    const [x, y] = panes[n]
    const k = el.width / 1155
    const data = el.getContext('2d').getImageData(Math.round(x * k), Math.round(y * k), Math.max(1, Math.round(7 * k)), Math.max(1, Math.round(7 * k))).data
    let sum = 0
    for (let i = 0; i < data.length; i += 4) sum += (data[i] + data[i + 1] + data[i + 2]) / 3
    return sum / (data.length / 4)
  }, which)
}

async function run(engine, label, width, mobile) {
  const browser = await engine.launch({ headless: true })
  const page = await browser.newPage({ viewport: { width, height: 1000 }, isMobile: mobile, hasTouch: mobile, deviceScaleFactor: 2, reducedMotion: 'no-preference' })
  const errors = []
  page.on('pageerror', (e) => errors.push(e.message))
  // This stub verifies the existing speech state/UI wiring, not audible output.
  await page.addInitScript(() => {
    const speech = new EventTarget()
    speech.getVoices = () => []
    speech.speak = (utterance) => { queueMicrotask(() => utterance.onstart?.(new Event('start'))) }
    speech.cancel = speech.pause = speech.resume = () => {}
    Object.defineProperty(window, 'speechSynthesis', { configurable: true, value: speech })
  })
  await page.clock.install()
  try {
    await page.goto(base + '/' + name + '.html', { waitUntil: 'networkidle' })
    await page.locator('canvas.basket').waitFor({ state: 'visible' })
    await page.clock.pauseAt(await page.evaluate(() => Date.now() + 100))
    assert.equal(await page.locator('.dock-avatar i').count(), 4, 'Supplied voice equalizer must replace the letter/music-note icon')
    assert.equal(await page.locator('.dock-avatar').evaluate((el) => getComputedStyle(el).backgroundColor), 'rgb(179, 38, 30)', 'Voice tile must use Leu red')
    for (const [scene, selector] of [['basket', 'canvas.basket'], ['nook', '.nook-glass canvas'], ['globe', 'canvas.globe']]) {
      await page.getByRole('button', { name: scene, exact: true }).click()
      // Images may arrive after a scene mounts, including under reduced motion.
      await page.waitForLoadState('networkidle')
      await canvasChanges(page, selector, label + '/' + scene)
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2), false, scene + ': horizontal overflow')
      await page.screenshot({ path: join(evidence, 'bundle-' + label + '-' + scene + '.png') })
      console.log('PASS ' + label + ': ' + scene + ' animates without input, touch scroll remains available')
    }

    // Capture the new 20-second lighting choreography, on desktop AND touch.
    const now = await page.evaluate(() => performance.now())
    const toDark = (16000 - (now % 20000) + 20000) % 20000
    await page.clock.fastForward(toDark)
    await page.clock.runFor(4500)
    const dark = [await windowLight(page, 0), await windowLight(page, 1)]
    await page.clock.runFor(8500)
    const lit = [await windowLight(page, 0), await windowLight(page, 1)]
    assert.ok(lit[0] - dark[0] > 25 && lit[1] - dark[1] > 25, label + ': earned windows should replay from dark to lit; ' + JSON.stringify({ dark, lit }))
    await page.getByLabel('Earned windows').fill('0')
    await page.clock.runFor(4500)
    const zero = await windowLight(page, 0)
    await page.clock.runFor(12000)
    assert.ok(await windowLight(page, 0) < lit[0] - 25, label + ': automatic choreography must not award unearned windows')
    console.log('PASS ' + label + ': 20-second lighting cycle and zero-earned progress preserved, sample=' + zero.toFixed(1))

    await page.getByRole('button', { name: 'Listen to this page', exact: true }).click()
    await page.clock.runFor(100)
    assert.equal(await page.locator('.dock-avatar.speaking i').count(), 4)
    assert.equal(await page.locator('.dock-avatar i').first().evaluate((el) => getComputedStyle(el).animationName), 'leuVoiceBar')
    await page.getByRole('button', { name: 'Pause', exact: true }).click()
    assert.equal(await page.locator('.dock-avatar.speaking').count(), 0)
    console.log('PASS ' + label + ': equalizer follows playing/paused speech state')

    await page.emulateMedia({ reducedMotion: 'reduce' })
    await page.clock.runFor(1000)
    for (const [scene, selector] of [['basket', 'canvas.basket'], ['nook', '.nook-glass canvas'], ['globe', 'canvas.globe']]) {
      await page.getByRole('button', { name: scene, exact: true }).click()
      await page.waitForLoadState('networkidle')
      await page.clock.runFor(1400)
      const before = await page.locator(selector).evaluate((el) => el.toDataURL())
      await page.clock.runFor(1400)
      const after = await page.locator(selector).evaluate((el) => el.toDataURL())
      assert.equal(before, after, label + '/' + scene + ': Reduced Motion should be static')
    }
    console.log('PASS ' + label + ': Reduced Motion static for all supplied scenes')
    assert.deepEqual(errors, [], label + ': browser exceptions')
  } catch (error) {
    await page.screenshot({ path: join(evidence, 'bundle-failed-' + label + '.png'), fullPage: true }).catch(() => {})
    throw error
  } finally { await browser.close() }
}

try {
  let ready = false
  for (let n = 0; n < 60; n++) {
    try { if ((await fetch(base)).ok) { ready = true; break } } catch {}
    await sleep(500)
  }
  assert.ok(ready, 'Vite scene test server did not start: ' + serverLog)
  await run(chromium, 'desktop-1440', 1440, false)
  await run(chromium, 'mobile-390', 390, true)
  await run(webkit, 'webkit-390', 390, true)
  await run(webkit, 'webkit-320', 320, true)
} finally {
  server.kill('SIGTERM')
  await Promise.all([rm(html, { force: true }), rm(entry, { force: true })])
}
