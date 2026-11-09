import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdir, writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { setTimeout as delay } from 'node:timers/promises'
import { chromium, firefox, webkit } from 'playwright'
import AxeBuilder from '@axe-core/playwright'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const base = process.env.LEU_STRESS_URL || 'http://127.0.0.1:4181'
const evidence = process.env.LEU_STRESS_EVIDENCE || join(root, 'qa-evidence/stress')
const quick = process.env.LEU_STRESS_QUICK === '1'
const server = process.env.LEU_STRESS_URL ? null : spawn(process.execPath,
  ['node_modules/vite/bin/vite.js', 'preview', '--host', '127.0.0.1', '--port', '4181', '--strictPort'],
  { cwd: root, stdio: 'ignore' })
const routes = ['', '#/library', '#/study', '#/notes']
const viewports = [{ width: 320, height: 640 }, { width: 390, height: 844 },
  { width: 844, height: 390 }, { width: 768, height: 1024 }, { width: 1440, height: 900 }]
const scenarios = quick ? ['baseline', 'long-text', 'large-type', 'missing-images'] :
  ['baseline', 'long-text', 'large-type', 'text-spacing', 'missing-images', 'rtl', 'dark', 'reduced-motion', 'storage-denied', 'offline']
const failures = [], results = []
await mkdir(evidence, { recursive: true })

async function verifyWorkerPolicy(browser) {
  const context = await browser.newContext()
  const origins = ['https://huggingface.co', 'https://cas-bridge.xethub.hf.co', 'https://cdn.jsdelivr.net']
  // Mock only the remote bytes: the real browser still enforces CSP and COEP.
  for (const origin of origins) await context.route(origin + '/leu-policy-probe', (route) => route.fulfill({
    body: 'ok', headers: { 'Access-Control-Allow-Origin': '*', 'Cross-Origin-Resource-Policy': 'cross-origin' },
  }))
  try {
    const page = await context.newPage()
    await page.goto(base, { waitUntil: 'load' })
    const result = await page.evaluate((origins) => new Promise((resolve, reject) => {
      const code = `onmessage = async ({data: origins}) => {
        try {
          const url = URL.createObjectURL(new Blob(['export const answer = 42'], {type: 'text/javascript'}));
          const module = await import(url); URL.revokeObjectURL(url);
          await WebAssembly.compile(new Uint8Array([0,97,115,109,1,0,0,0]));
          const responses = await Promise.all(origins.map(origin => fetch(origin + '/leu-policy-probe').then(r => r.text())));
          postMessage({answer: module.answer, responses});
        } catch (error) { postMessage({error: error.message}); }
      }`
      const url = URL.createObjectURL(new Blob([code], { type: 'text/javascript' }))
      const worker = new Worker(url)
      const cleanup = () => { clearTimeout(timer); worker.terminate(); URL.revokeObjectURL(url) }
      const timer = setTimeout(() => { cleanup(); reject(new Error('Worker policy probe timed out')) }, 15000)
      worker.onerror = (event) => { cleanup(); reject(new Error(event.message || 'Worker blocked')) }
      worker.onmessage = ({ data }) => { cleanup(); resolve(data) }
      worker.postMessage(origins)
    }), origins)
    assert.deepEqual(result, { answer: 42, responses: origins.map(() => 'ok') }, browser.browserType().name() + ': CSP must support worker modules, WASM and model requests')
    console.log('PASS ' + browser.browserType().name() + ': production worker security policy')
  } finally { await context.close() }
}

async function stress(page, scenario) {
  if (scenario === 'long-text') {
    await page.evaluate(() => {
      const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT)
      const nodes = []
      while (walker.nextNode()) {
        const node = walker.currentNode
        if (node.textContent.trim() && !node.parentElement.closest('script,style,.sr-only,[aria-hidden="true"]')) nodes.push(node)
      }
      for (const node of nodes) node.textContent += ' — Antidisestablishmentarianism, a longer translated label'
    })
  }
  if (scenario === 'large-type') await page.evaluate(() => {
    const sizes = [...document.querySelectorAll('body *')].map((el) => [el, parseFloat(getComputedStyle(el).fontSize) * 2])
    for (const [el, size] of sizes) el.style.setProperty('font-size', size + 'px', 'important')
  })
  if (scenario === 'text-spacing') await page.addStyleTag({ content: '* { line-height: 1.5 !important; letter-spacing: .12em !important; word-spacing: .16em !important; } p { margin-bottom: 2em !important; }' })
  if (scenario === 'rtl') await page.evaluate(() => { document.documentElement.dir = 'rtl' })
  await page.waitForTimeout(100)
}

async function inspect(page, label, scenario) {
  const geometry = await page.evaluate(() => {
    const bad = []
    for (const el of document.querySelectorAll('main h1,main h2,main p,main button,main input,.topbar a,.topbar button')) {
      const r = el.getBoundingClientRect(), s = getComputedStyle(el)
      if (!r.width || !r.height || s.visibility === 'hidden' || el.closest('[hidden]')) continue
      if (r.left < -1 || r.right > innerWidth + 1) bad.push(el.className || el.tagName)
    }
    const search = document.querySelector('.search-pill'), r = search.getBoundingClientRect()
    const hit = document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2)
    const burger = document.querySelector('.mobile-menu-trigger')
    const desktop = document.querySelector('.desktop-places')
    const compact = document.querySelector('.topbar').classList.contains('compact-nav')
    const visible = (element) => {
      const rect = element.getBoundingClientRect()
      return rect.width > 0 && rect.height > 0 && getComputedStyle(element).visibility !== 'hidden'
        && getComputedStyle(element).display !== 'none'
    }
    return { overflow: document.documentElement.scrollWidth - innerWidth, bad,
      searchBlocked: !search.contains(hit), topbar: document.querySelector('.topbar')?.className,
      compact, navigationAvailable: compact
        ? visible(burger) && burger.getBoundingClientRect().width >= 44 && burger.getBoundingClientRect().height >= 44
        : visible(desktop) && [...desktop.querySelectorAll('.place')].every((link) => visible(link)) }
  })
  assert.ok(geometry.overflow <= 2 && !geometry.bad.length, label + ': overflow ' + JSON.stringify(geometry))
  assert.equal(geometry.searchBlocked, false, label + ': search obstructed')
  assert.equal(geometry.navigationAvailable, true, label + ': desktop links or compact mobile menu must remain accessible')
  const axe = await new AxeBuilder({ page }).withRules(['color-contrast', 'label-content-name-mismatch', 'target-size']).analyze()
  assert.deepEqual(axe.violations.map(({ id, nodes }) => ({ id, targets: nodes.map((n) => n.target) })), [], label + ': accessibility')
  // Every tab stop must expose its focus point below the sticky header. A canvas
  // can exceed a short viewport; its interactive center must still be reachable.
  if (scenario === 'baseline' || scenario === 'reduced-motion') {
    await page.evaluate(() => { document.activeElement?.blur(); scrollTo(0, 0) })
    for (let n = 0; n < 16; n++) {
      await page.keyboard.press('Tab')
      const focus = await page.evaluate(() => {
        const el = document.activeElement, r = el.getBoundingClientRect()
        if (el === document.body) return null
        const hit = document.elementFromPoint(r.x + r.width / 2, Math.min(innerHeight - 1, r.y + r.height / 2))
        return { name: el.id || el.className, visible: r.bottom > 0 && r.top < innerHeight && el.contains(hit) }
      })
      assert.ok(!focus || focus.visible, label + ': focus obscured ' + JSON.stringify(focus))
    }
  }
}

try {
  for (let n = 0; n < 60; n++) {
    try { if ((await fetch(base)).ok) break } catch { /* server starting */ }
    await delay(100)
  }
  const engines = (quick ? [chromium] : [chromium, firefox, webkit])
    .filter((engine) => !process.env.LEU_STRESS_BROWSER || engine.name() === process.env.LEU_STRESS_BROWSER)
  assert.ok(engines.length, 'LEU_STRESS_BROWSER must name chromium, firefox or webkit')
  for (const engine of engines) {
    const browser = await engine.launch({ headless: true })
    try {
      await verifyWorkerPolicy(browser)
      for (const viewport of quick ? [viewports[0], viewports[2], viewports[4]] : viewports) {
        for (const scenario of scenarios) {
          const context = await browser.newContext({ viewport, reducedMotion: scenario === 'reduced-motion' ? 'reduce' : 'no-preference', colorScheme: scenario === 'dark' ? 'dark' : 'light' })
          if (scenario === 'missing-images') await context.route('**/*', (route) => route.request().resourceType() === 'image' ? route.abort() : route.continue())
          if (scenario === 'storage-denied') await context.addInitScript(() => {
            Storage.prototype.getItem = Storage.prototype.setItem = () => { throw new DOMException('Storage denied', 'SecurityError') }
          })
          // The full route matrix owns baseline and content expansion. Other
          // environmental faults exercise the shared shell and Welcome scene.
          for (const route of ['baseline', 'long-text', 'large-type', 'text-spacing'].includes(scenario) ? routes : ['']) {
            const page = await context.newPage(), errors = []
            const label = `${engine.name()}-${viewport.width}-${scenario}-${route || 'home'}`
            page.on('pageerror', (error) => errors.push(error.message))
            await page.addInitScript(() => {
              window.__policyErrors = []
              document.addEventListener('securitypolicyviolation', (event) => window.__policyErrors.push(event.violatedDirective))
            })
            try {
              const response = await page.goto(base + '/' + route, { waitUntil: 'load' })
              assert.ok(response.headers()['content-security-policy']?.includes("object-src 'none'"), label + ': missing production CSP')
              await page.evaluate(() => document.fonts.ready)
              await page.locator('main h1, main h2').first().waitFor({ state: 'visible' })
              await stress(page, scenario)
              if (scenario === 'offline') await context.setOffline(true)
              await inspect(page, label, scenario)
              await page.locator('.search-pill').click()
              await page.getByRole('dialog', { name: 'Search your books' }).waitFor({ state: 'visible' })
              await page.keyboard.press('Escape')
              await page.getByRole('dialog').waitFor({ state: 'hidden' })
              assert.deepEqual(errors, [], label + ': runtime errors')
              assert.deepEqual(await page.evaluate(() => window.__policyErrors), [], label + ': CSP blocked app resources')
              results.push({ label, status: 'passed' })
            } catch (error) {
              failures.push({ label, error: error.message, runtime: errors })
              console.error('FAIL ' + label + ': ' + error.message.slice(0, 550))
              await page.screenshot({ path: join(evidence, `${results.length}-${failures.length}.png`) }).catch(() => {})
            } finally {
              await context.setOffline(false)
              await page.close()
            }
          }
          await context.close()
        }
        console.log(`DONE ${engine.name()} ${viewport.width}: ${results.length} passed, ${failures.length} failed`)
      }
    } finally { await browser.close() }
  }
} finally {
  server?.kill('SIGTERM')
  await writeFile(join(evidence, 'results.json'), JSON.stringify({ results, failures }, null, 2))
}
assert.deepEqual(failures, [], `${failures.length} stress cases failed`)
console.log(`PASS ${results.length} stress cases`)
