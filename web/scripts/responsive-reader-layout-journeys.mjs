import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdir } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { chromium, webkit } from 'playwright'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const base = 'http://127.0.0.1:4195'
const evidence = join(root, 'qa-evidence/responsive-reader')
await mkdir(evidence, { recursive: true })
const server = spawn(process.execPath,
  ['node_modules/vite/bin/vite.js', 'preview', '--host', '127.0.0.1', '--port', '4195', '--strictPort'],
  { cwd: root, stdio: 'ignore' })
const overlap = (a, b) => Math.min(a.right, b.right) - Math.max(a.left, b.left) > 1
  && Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top) > 1
const frame = (page) => page.evaluate(() => new Promise((resolve) =>
  requestAnimationFrame(() => requestAnimationFrame(resolve))))

async function check(engine) {
  const browser = await engine.launch({ headless: true })
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, reducedMotion: 'reduce' })
  const errors = []
  page.on('pageerror', (error) => errors.push(error.message))
  try {
    await page.goto(base)
    await page.getByRole('button', { name: /start with a sample book/i }).click()
    await page.locator('.sewn-actions .btn.ink').click({ timeout: 25000 })
    await page.locator('.reader-paper canvas').waitFor({ state: 'visible' })

    for (const width of [320, 390, 700, 721, 768, 820, 900, 980, 1024, 1280, 1440, 1920]) {
      const height = width <= 720 ? 844 : 900
      await page.setViewportSize({ width, height })
      await page.waitForFunction((desktop) => !!document.querySelector('.reader-bar .segmented') === desktop,
        width > 720)
      await frame(page)
      const rects = await page.evaluate(() => {
        const get = (selector) => {
          const node = document.querySelector(selector)
          return node ? node.getBoundingClientRect().toJSON() : null
        }
        const actions = [...document.querySelectorAll('.reader-view-controls button')]
          .filter((node) => node.getClientRects().length > 0)
          .map((node) => ({ label: node.ariaLabel || node.textContent.trim(), ...node.getBoundingClientRect().toJSON() }))
        const bar = get('.reader:not(.reader-immersive) .reader-bar')
        return { back: get('.reader-bar .reader-back'), modes: get('.reader-bar .segmented'),
          tools: get('.reader-bar .reader-view-controls'), bar, actions, scrollWidth: document.documentElement.scrollWidth }
      })
      assert.ok(rects.scrollWidth <= width + 2, engine.name() + ' ' + width + ': reader overflows screen')
      assert.ok(rects.actions.length >= 2 && rects.actions.every((a) => a.width >= 40 && a.height >= 40),
        engine.name() + ' ' + width + ': header actions must retain touch targets ' + JSON.stringify(rects))
      for (let i = 0; i < rects.actions.length; i++) {
        const item = rects.actions[i]
        assert.ok(item.left >= -1 && item.right <= width + 1, 'Tools stay inside viewport at ' + width)
        for (let j = i + 1; j < rects.actions.length; j++) {
          assert.ok(!overlap(item, rects.actions[j]), 'Top-right controls overlap at ' + width)
        }
      }
      if (width > 720) {
        assert.ok(rects.back && rects.modes && rects.tools
          && !overlap(rects.back, rects.modes) && !overlap(rects.modes, rects.tools)
          && rects.back.right <= rects.modes.left + 1 && rects.modes.right <= rects.tools.left + 1,
          engine.name() + ' ' + width + ': reader header regions overlap ' + JSON.stringify(rects))
        const paddedHover = await page.getByRole('button', { name: 'For reading', exact: true }).evaluate((button) => {
          const range = document.createRange()
          range.selectNodeContents(button)
          const text = range.getBoundingClientRect(), hit = button.getBoundingClientRect()
          return { left: text.left - hit.left, right: hit.right - text.right }
        })
        assert.ok(paddedHover.left >= 8 && paddedHover.right >= 8,
          'Mode hover must have breathing room around its label at ' + width + ': ' + JSON.stringify(paddedHover))
      }
      await page.locator('.reader-bar .contents-trigger').click()
      const dialog = page.getByRole('dialog', { name: 'Contents', exact: true })
      await dialog.waitFor({ state: 'visible' })
      const settings = await dialog.getByRole('button', { name: 'Reading settings' }).boundingBox()
      const close = await dialog.getByRole('button', { name: 'Close dialog' }).boundingBox()
      const heading = await dialog.locator('.contents-heading').boundingBox()
      assert.ok(settings && close && heading && !overlap(settings, close)
        && close.bottom + 4 <= heading.top,
        engine.name() + ' ' + width + ': close X must sit in its own row ABOVE the Contents heading and settings')
      if ([390, 820, 1440].includes(width)) {
        await page.screenshot({ path: join(evidence, engine.name() + '-' + width + '-contents.png') })
      }
      await page.keyboard.press('Escape')
      await dialog.waitFor({ state: 'hidden' })
      console.log('PASS ' + engine.name() + ' ' + width + ': toolbar hit targets, padding, modal close clearance')
    }

    await page.getByRole('link', { name: 'Back to book overview' }).click()
    await page.locator('.book-grid').waitFor({ state: 'visible' })
    await page.locator('.book-chapter-item[aria-pressed="true"]').waitFor({ state: 'visible' })
    assert.equal(await page.locator('.book-chapter-item[aria-pressed="true"]').count(), 1,
      'Only one chapter preview is selected')
    const another = page.locator('.book-chapter-item[aria-pressed="false"]').first()
    const differentTitle = await another.locator('.book-chapter-item-title').innerText()
    await another.click()
    await page.waitForFunction((title) => document.querySelector('.chapter-card h3')?.textContent === title, differentTitle)
    assert.equal(await another.getAttribute('aria-pressed'), 'true',
      'Choosing a chapter updates the preview and its selected state without navigating')
    for (const width of [390, 760, 820, 1024, 1440]) {
      await page.setViewportSize({ width, height: 900 })
      await frame(page)
      const boxes = await page.evaluate(() => {
        const get = (s) => document.querySelector(s).getBoundingClientRect().toJSON()
        return { head: get('.book-head'), chapter: get('.book-chapters'), side: get('.book-side'),
          list: get('.book-chapter-index'), preview: get('.chapter-card'),
          visibleChapters: [...document.querySelectorAll('.book-chapter-item')].filter(n => !!n.getClientRects().length).length,
          viewport: innerWidth, scrollWidth: document.documentElement.scrollWidth }
      })
      assert.ok(boxes.scrollWidth <= width + 2, 'Book grid horizontal overflow at ' + width)
      assert.ok(!overlap(boxes.chapter, boxes.side), 'Book chapters and reading panel overlap at ' + width)
      assert.ok(boxes.head.top >= 0 && boxes.head.left >= 0, 'Book title begins in viewport at ' + width)
      if (width > 980) {
        assert.ok(boxes.chapter.right + 16 <= boxes.side.left
          && Math.abs(boxes.chapter.top - boxes.side.top) < 3
          && Math.abs(boxes.chapter.bottom - boxes.side.bottom) < 3,
          'Desktop chapter and reading panels must have identical top AND bottom edges at ' + width + ': ' + JSON.stringify(boxes))
        assert.ok(boxes.visibleChapters >= 2
          && boxes.list.bottom <= boxes.preview.top + 1
          && boxes.preview.bottom <= boxes.chapter.bottom + 1,
          'Inline chapter navigation uses the left panel rather than leaving a dead zone: ' + JSON.stringify(boxes))
      } else {
        assert.ok(boxes.side.top >= boxes.chapter.bottom + 12, 'Stacked book panels have their own space at ' + width)
        if (width <= 720) assert.equal(boxes.visibleChapters, 0,
          'Mobile preserves the compact chapter preview and searchable Contents menu')
      }
      if ([390, 820, 1440].includes(width)) {
        await page.screenshot({ path: join(evidence, engine.name() + '-' + width + '-book.png') })
      }
    }

    await page.goto(base + '/#/home')
    await page.locator('.home-scene').waitFor({ state: 'visible' })
    for (const width of [820, 1024, 1440]) {
      await page.setViewportSize({ width, height: 900 })
      await frame(page)
      const home = await page.evaluate(() => {
        const get = (s) => document.querySelector(s).getBoundingClientRect().toJSON()
        return { story: get('.home-story'), resume: get('.home-resume'),
          action: get('.resume-action'), header: get('.topbar'), viewport: innerHeight,
          scrollWidth: document.documentElement.scrollWidth }
      })
      assert.ok(home.scrollWidth <= width + 2 && !overlap(home.story, home.resume),
        'Home columns need independent space at ' + width)
      assert.ok(home.action.bottom <= 900, 'Home continue CTA belongs in first viewport at ' + width)
      const center = (home.header.bottom + 900) / 2
      assert.ok(Math.abs(home.story.top + home.story.height / 2 - center) <= 125
        && Math.abs(home.resume.top + home.resume.height / 2 - center) <= 125,
        'Home columns must be vertically balanced instead of crowded at the top: ' + JSON.stringify(home))
      if (width === 820) await page.screenshot({ path: join(evidence, engine.name() + '-820-home.png') })
    }
    assert.deepEqual(errors, [], 'No browser runtime exceptions')
  } finally { await browser.close() }
}

try {
  let ready = false
  for (let i = 0; i < 60; i++) {
    try { if ((await fetch(base)).ok) { ready = true; break } } catch {}
    await new Promise((resolve) => setTimeout(resolve, 250))
  }
  assert.ok(ready, 'Leu Vite preview must start')
  await check(chromium)
  await check(webkit)
} finally {
  server.kill('SIGTERM')
}
