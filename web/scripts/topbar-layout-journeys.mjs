import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { chromium, webkit } from 'playwright'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const base = 'http://127.0.0.1:4178'
const widths = [320, 360, 390, 430, 600, 768, 900, 901, 1024, 1100, 1101, 1280, 1440, 1920]
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', 'preview', '--host', '127.0.0.1', '--port', '4178', '--strictPort'], { cwd: root, stdio: 'ignore' })

async function ready() {
  for (let i = 0; i < 60; i++) {
    try { if ((await fetch(base)).ok) return } catch {}
    await new Promise((resolve) => setTimeout(resolve, 250))
  }
  throw new Error('Leu preview did not start')
}

async function verify(engine) {
  const browser = await engine.launch({ headless: true })
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, reducedMotion: 'reduce' })
  const errors = []
  page.on('pageerror', (error) => errors.push(error.message))
  try {
    await page.goto(base, { waitUntil: 'domcontentloaded' })
    await page.locator('.topbar').waitFor({ state: 'visible' })
    await page.evaluate(() => document.fonts.ready)

    for (const width of widths) {
      await page.setViewportSize({ width, height: width <= 430 ? 740 : 900 })
      await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))))
      const geometry = await page.evaluate(() => {
        const rect = (selector) => {
          const node = document.querySelector(selector)
          const box = node.getBoundingClientRect()
          return { left: box.left, right: box.right, width: box.width, height: box.height,
            visible: getComputedStyle(node).display !== 'none' }
        }
        const search = document.querySelector('.search-pill')
        const box = search.getBoundingClientRect()
        return {
          viewport: innerWidth,
          overflow: document.documentElement.scrollWidth - innerWidth,
          logo: rect('.topbar .wordmark'), nav: rect('.desktop-places'),
          tools: rect('.topbar-tools'), search: rect('.search-pill'),
          links: [...document.querySelectorAll('.desktop-places a')].map((link) => link.getBoundingClientRect().height),
          searchHit: search.contains(document.elementFromPoint(box.x + box.width / 2, box.y + box.height / 2)),
        }
      })
      const label = `${engine.name()} ${width}px`
      assert.ok(geometry.overflow <= 2, `${label}: page overflows (${geometry.overflow}px)`)
      assert.ok(geometry.search.width >= 44 && geometry.search.height >= 44 && geometry.searchHit,
        `${label}: search is too small or obstructed`)
      assert.ok(geometry.logo.left >= 0 && geometry.tools.right <= width + 1,
        `${label}: header controls extend offscreen`)

      if (width > 900) {
        assert.equal(geometry.nav.visible, true, `${label}: desktop navigation is missing`)
        const center = (geometry.nav.left + geometry.nav.right) / 2
        assert.ok(Math.abs(center - geometry.viewport / 2) <= 1.5,
          `${label}: navigation midpoint ${center}, viewport midpoint ${geometry.viewport / 2}`)
        assert.ok(geometry.logo.right + 8 <= geometry.nav.left && geometry.nav.right + 8 <= geometry.tools.left,
          `${label}: navigation overlaps its neighboring controls`)
        assert.ok(geometry.links.every((height) => height >= 43.5), `${label}: navigation targets below 44px`)
      } else {
        assert.equal(geometry.nav.visible, false, `${label}: desktop links should collapse to a menu`)
        const trigger = page.getByRole('button', { name: 'Open navigation' })
        assert.ok(await trigger.isVisible(), `${label}: navigation trigger is missing`)
        await trigger.click()
        const menu = page.getByRole('navigation', { name: 'Mobile places' })
        await menu.waitFor({ state: 'visible' })
        const menuBox = await menu.boundingBox()
        assert.ok(menuBox.x >= 0 && menuBox.x + menuBox.width <= width + 1,
          `${label}: navigation menu extends outside viewport`)
        await page.keyboard.press('Escape')
        await menu.waitFor({ state: 'hidden' })
        assert.equal(await trigger.getAttribute('aria-expanded'), 'false', `${label}: menu did not close`)
        assert.equal(await trigger.evaluate((node) => document.activeElement === node), true,
          `${label}: Escape should restore focus to menu trigger`)
      }
      console.log(`PASS ${label}: center/overflow/targets/menu`)
    }

    // Compact search retains its accessible name and opens on a phone.
    await page.setViewportSize({ width: 390, height: 844 })
    await page.getByRole('button', { name: 'Search your books' }).click()
    await page.getByRole('dialog', { name: 'Search your books' }).waitFor({ state: 'visible' })
    await page.keyboard.press('Escape')
    await page.getByRole('dialog', { name: 'Search your books' }).waitFor({ state: 'hidden' })
    // Text expansion (translation or personalization) must switch to the same compact menu.
    await page.setViewportSize({ width: 1440, height: 900 })
    await page.evaluate(() => {
      const nodes = [...document.querySelectorAll('.desktop-places .place, .search-pill span')]
      window.__topbarLabels = nodes.map((node) => node.textContent)
      for (const node of nodes) node.textContent += ' — Antidisestablishmentarianism, a longer translated label'
    })
    const immediate = await page.evaluate(() => new Promise((resolve) => {
      queueMicrotask(() => resolve({
        compact: document.querySelector('.topbar')?.classList.contains('compact-nav'),
        overflow: document.documentElement.scrollWidth - innerWidth,
      }))
    }))
    assert.equal(immediate.compact, true, `${engine.name()}: expanded labels should collapse without waiting a frame`)
    assert.ok(immediate.overflow <= 2, `${engine.name()}: expanded labels should not overflow before paint`)
    await page.waitForFunction(() => document.querySelector('.topbar')?.classList.contains('compact-nav'))
    const expanded = await page.evaluate(() => {
      const search = document.querySelector('.search-pill')
      const box = search.getBoundingClientRect()
      return {
        overflow: document.documentElement.scrollWidth - innerWidth,
        searchHit: search.contains(document.elementFromPoint(box.x + box.width / 2, box.y + box.height / 2)),
      }
    })
    assert.ok(expanded.overflow <= 2 && expanded.searchHit,
      `${engine.name()}: expanded navigation labels obstruct the header`)
    const compactTrigger = page.getByRole('button', { name: 'Open navigation' })
    await compactTrigger.click()
    await page.getByRole('navigation', { name: 'Mobile places' }).waitFor({ state: 'visible' })
    await page.keyboard.press('Escape')
    await page.evaluate(() => {
      const nodes = [...document.querySelectorAll('.desktop-places .place, .search-pill span')]
      nodes.forEach((node, index) => { node.textContent = window.__topbarLabels[index] })
    })
    await page.waitForFunction(() => !document.querySelector('.topbar')?.classList.contains('compact-nav'))
    assert.deepEqual(errors, [], `${engine.name()}: runtime errors`)
  } finally {
    await browser.close()
  }
}

try {
  await ready()
  await verify(chromium)
  await verify(webkit)
} finally {
  server.kill('SIGTERM')
}
