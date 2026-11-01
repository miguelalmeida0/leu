import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdir } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { chromium, webkit } from 'playwright'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const base = 'http://127.0.0.1:4193'
const evidence = join(root, 'qa-evidence/interaction-states')
await mkdir(evidence, { recursive: true })
const server = spawn(process.execPath,
  ['node_modules/vite/bin/vite.js', 'preview', '--host', '127.0.0.1', '--port', '4193', '--strictPort'],
  { cwd: root, stdio: 'ignore' })

const effectiveBackground = (locator) => locator.evaluate((node) => {
  // Compare painted colors, not raw rgba strings; translucency needs its parent surface.
  let rgb = [0, 0, 0], opacity = 0
  for (let element = node; element && opacity < .999; element = element.parentElement) {
    const components = getComputedStyle(element).backgroundColor.match(/[\d.]+/g)?.map(Number)
    if (!components) continue
    const amount = (components[3] ?? 1) * (1 - opacity)
    rgb = rgb.map((value, index) => value + amount * components[index])
    opacity += amount
  }
  return rgb.map(Math.round)
})
const distance = (a, b) => Math.hypot(...a.map((value, index) => value - b[index]))
const selected = (locator) => locator.getAttribute('aria-current')
async function distinguish(active, hover, label) {
  await active.waitFor({ state: 'visible' })
  await hover.hover()
  assert.ok(await selected(active) || await active.getAttribute('aria-checked') === 'true'
    || await active.getAttribute('aria-pressed') === 'true',
    label + ': the selected item must keep its semantic state when another is hovered')
  const current = await effectiveBackground(active)
  const pointer = await effectiveBackground(hover)
  assert.ok(distance(current, pointer) >= 25,
    label + ': selected and hovered surfaces must look visibly different (' + current + ' vs ' + pointer + ')')
  assert.match(await active.evaluate((node) => getComputedStyle(node).boxShadow), /inset/,
    label + ': selected state must retain its persistent location marker')
}

async function journey(engine) {
  const browser = await engine.launch({ headless: true })
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, reducedMotion: 'reduce' })
  const label = engine.name()
  const errors = []
  page.on('pageerror', (error) => errors.push(error.message))
  try {
    await page.goto(base)
    await page.getByRole('button', { name: /start with a sample book/i }).click()
    await page.locator('.sewn-actions .btn.ink').click({ timeout: 25000 })
    await page.locator('.reader-paper canvas').waitFor({ state: 'visible' })
    await page.getByRole('button', { name: 'Next page', exact: true }).click()
    await page.locator('.reader-paper[aria-label="Page 2 of 4"]').waitFor()

    await page.locator('.reader-bar .contents-trigger').click()
    const contents = page.getByRole('dialog', { name: 'Contents', exact: true })
    const rows = contents.locator('.contents-results button')
    const current = rows.locator('[aria-current="location"]')
    // The active chapter and another hovered chapter must never share the same fill.
    const active = contents.locator('.contents-results button[aria-current="location"]')
    const other = contents.getByRole('button', { name: /References and copies/ })
    assert.equal(await active.count(), 1, 'One chapter is current')
    await distinguish(active, other, label + ' contents')
    assert.equal(await active.count(), 1, 'Hover must not select another chapter')
    assert.equal(await other.getAttribute('title'), null, 'Chapter hover does not add a native black tooltip')
    await page.screenshot({ path: join(evidence, label + '-contents.png') })

    await contents.getByRole('searchbox', { name: 'Search chapters' }).focus()
    await page.keyboard.press('Tab')
    const focused = contents.locator('.contents-results button:focus-visible')
    assert.equal(await focused.count(), 1, 'Keyboard navigation has a distinct visible focus state')
    assert.equal(await focused.evaluate((node) => getComputedStyle(node).outlineStyle), 'solid')

    await other.click()
    await contents.waitFor({ state: 'hidden' })
    await page.locator('.reader-paper[aria-label="Page 3 of 4"]').waitFor()
    await page.locator('.reader-bar .contents-trigger').click()
    assert.match(await contents.locator('.contents-results button[aria-current="location"]').innerText(),
      /References and copies/, 'Current chapter updates only after navigation')

    await contents.getByRole('button', { name: 'Reading settings' }).click()
    const settings = page.getByRole('dialog', { name: 'Reading settings' })
    const radios = settings.getByRole('radiogroup', { name: 'Reading voice' }).getByRole('radio')
    assert.ok(await radios.count() > 1, 'Desktop voice choices support selection and hover checks')
    const chosen = radios.locator('[aria-checked="true"]')
    const chosenRadio = settings.locator('.reader-voice-list button[aria-checked="true"]')
    const otherRadio = settings.locator('.reader-voice-list button[aria-checked="false"]').first()
    assert.equal(await chosenRadio.count(), 1)
    await distinguish(chosenRadio, otherRadio, label + ' voice')
    await page.keyboard.press('Escape')
    await settings.waitFor({ state: 'hidden' })

    // Fit-page is an actual selection, not simply the zoom button being hovered.
    await page.getByRole('button', { name: 'Enter full-screen reading' }).click()
    await page.locator('.paged-reader').waitFor({ state: 'visible' })
    await page.getByRole('button', { name: 'Show reading controls' }).focus()
    await page.keyboard.press('Enter')
    const fits = page.getByRole('group', { name: 'Original page fit', exact: true })
    const fitPage = fits.getByRole('button', { name: 'Fit page', exact: true })
    const fitWidth = fits.getByRole('button', { name: 'Fit width', exact: true })
    await distinguish(fitPage, fitWidth, label + ' original PDF fit')
    await page.screenshot({ path: join(evidence, label + '-pdf-fit.png') })
    await page.getByRole('button', { name: 'Exit full-screen reading' }).click()
    await page.locator('.reader-immersive').waitFor({ state: 'hidden' })

    await page.getByRole('link', { name: 'Back to book overview' }).click()
    await page.getByRole('button', { name: 'Search your books' }).click()
    const search = page.getByRole('dialog', { name: 'Search your books' })
    await search.locator('.search-progress').waitFor({ state: 'hidden', timeout: 30000 })
    const searchField = search.getByRole('textbox', { name: 'Ask your books anything' })
    // Both concepts occur on different pages of the bundled sample PDF.
    await searchField.fill('model references')
    await page.waitForFunction(() => document.querySelectorAll('.search-results [role="option"]').length > 1,
      null, { timeout: 15000 })
    const best = search.locator('#result-0')
    const second = search.locator('#result-1')
    assert.equal(await best.getAttribute('aria-selected'), 'true')
    await second.hover()
    assert.equal(await best.getAttribute('aria-selected'), 'true', 'Pointer hover must not rewrite keyboard selection')
    assert.equal(await second.getAttribute('aria-selected'), 'false')
    await searchField.focus()
    await page.keyboard.press('ArrowDown')
    assert.equal(await second.getAttribute('aria-selected'), 'true',
      'ArrowDown still moves the active search result')
    assert.equal(await best.getAttribute('aria-selected'), 'false')
    await page.screenshot({ path: join(evidence, label + '-search.png') })
    await page.keyboard.press('Escape')
    await search.waitFor({ state: 'hidden' })

    await page.getByRole('navigation', { name: 'Places' }).getByRole('link', { name: 'Library' }).click()
    const filters = page.locator('.library-filters')
    const all = filters.locator('a[aria-current="page"]')
    const collection = filters.locator('a:not([aria-current])').first()
    assert.ok(await collection.count() > 0)
    await collection.hover()
    assert.equal(await all.getAttribute('aria-current'), 'page',
      'Collection hover does not change the selected filter')
    assert.ok(distance(await effectiveBackground(all), await effectiveBackground(collection)) >= 25,
      'Collection selection and hover have visibly different surfaces')

    await page.setViewportSize({ width: 700, height: 900 })
    await page.getByRole('button', { name: 'Open navigation' }).click()
    const menu = page.getByRole('navigation', { name: 'Mobile places' })
    const currentPlace = menu.locator('a[aria-current="page"]')
    const hoverPlace = menu.getByRole('link', { name: 'Study', exact: true })
    await distinguish(currentPlace, hoverPlace, label + ' mobile navigation')
    await page.screenshot({ path: join(evidence, label + '-navigation.png') })
    assert.equal(await currentPlace.innerText(), 'Library')
    assert.deepEqual(errors, [], 'No browser errors during interactive state transitions')
    console.log('PASS ' + label + ': Contents, voice, search, filters, navigation, mouse and keyboard states')
  } finally {
    await browser.close()
  }
}

try {
  let started = false
  for (let i = 0; i < 60; i++) {
    try { if ((await fetch(base)).ok) { started = true; break } } catch {}
    await new Promise((resolve) => setTimeout(resolve, 250))
  }
  assert.ok(started, 'Leu preview must start')
  await journey(chromium)
  await journey(webkit)
} finally {
  server.kill('SIGTERM')
}
