import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdir, readFile } from 'node:fs/promises'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { chromium, webkit } from 'playwright'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const evidence = join(root, 'qa-evidence')
const base = 'http://127.0.0.1:4173'
await mkdir(evidence, { recursive: true })
// Run Vite directly, not through npm -> shell -> Vite. Otherwise the test process
// can hang after the suite completes because the orphaned child holds stdio open.
const server = spawn(process.execPath,
  ['node_modules/vite/bin/vite.js', 'preview', '--host', '127.0.0.1', '--port', '4173', '--strictPort'],
  { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] })
let serverLog = ''
for (const pipe of [server.stdout, server.stderr]) pipe.on('data', (chunk) => { serverLog += chunk.toString() })
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
for (let attempt = 0; attempt < 60; attempt++) {
  try {
    const response = await fetch(base, { signal: AbortSignal.timeout(1000) })
    if (response.ok) break
  } catch { /* wait for Vite */ }
  if (attempt === 59) throw new Error('Vite preview did not start: ' + serverLog)
  await wait(1000)
}

async function visible(locator, timeout = 20000) {
  await locator.waitFor({ state: 'visible', timeout })
}
async function unhidden(locator, timeout = 8000) {
  await locator.waitFor({ state: 'hidden', timeout })
}
async function noHorizontalOverflow(page, name) {
  const dimensions = await page.evaluate(() => ({
    screen: window.innerWidth,
    content: document.documentElement.scrollWidth,
  }))
  assert.ok(dimensions.content <= dimensions.screen + 3,
    `${name}: horizontal overflow (${dimensions.content}px content / ${dimensions.screen}px viewport)`)
}
async function selectPassage(page) {
  await page.evaluate(() => {
    const element = document.querySelector('.reader-paper .prose .s')
    if (!element) throw new Error('Text page was not rendered')
    const text = Array.from(element.childNodes).find((node) => node.nodeType === Node.TEXT_NODE)
    if (!text || !text.textContent?.length) throw new Error('Readable selectable text not found')
    const range = document.createRange()
    range.setStart(text, 0)
    range.setEnd(text, Math.min(text.textContent.length, 24))
    const selection = window.getSelection()
    selection?.removeAllRanges()
    selection?.addRange(range)
    document.dispatchEvent(new Event('selectionchange'))
  })
  await visible(page.getByRole('toolbar', { name: 'Actions for selected text' }), 8000)
}
async function navigateMobile(page, name) {
  const trigger = page.getByRole('button', { name: 'Open navigation' })
  await trigger.click()
  await visible(page.getByRole('navigation', { name: 'Mobile places' }))
  await page.getByRole('navigation', { name: 'Mobile places' }).getByRole('link', { name }).click()
}
async function goTo(page, mobile, name) {
  if (mobile) return navigateMobile(page, name)
  return page.getByRole('navigation', { name: 'Places' }).getByRole('link', { name }).click()
}
async function runBrowser(browserType, name, mobile, width) {
  const browser = await browserType.launch({ headless: true })
  const pageErrors = []
  const page = await browser.newPage({
    viewport: { width, height: mobile ? 844 : 900 },
    isMobile: mobile, hasTouch: mobile, deviceScaleFactor: mobile ? 2 : 1,
    reducedMotion: 'reduce',
  })
  page.on('pageerror', (err) => pageErrors.push(err.message))
  page.setDefaultTimeout(16000)
  const evidenceName = `${name}-${width}`
  try {
    await page.goto(base, { waitUntil: 'domcontentloaded', timeout: 30000 })
    await visible(page.getByRole('heading', { name: /Make yourself comfortable/i }))
    await noHorizontalOverflow(page, 'Welcome ' + name)
    await page.getByRole('button', { name: /start with a sample book/i }).click()
    await visible(page.getByRole('dialog', { name: /Sewing in Computer Science Essentials/i }))
    await visible(page.locator('.sewn-actions .btn.ink'), 25000)
    await page.locator('.sewn-actions .btn.ink').click()
    await visible(page.locator('.reader-paper .prose p'), 25000)
    await noHorizontalOverflow(page, 'Reader ' + name)
    if (mobile) {
      await page.getByRole('button', { name: 'Open navigation' }).click()
      await visible(page.getByRole('navigation', { name: 'Mobile places' }))
      // Tapping the reader (outside the menu) dismisses the menu with one touch.
      await page.locator('.reader-paper').click({ position: { x: 6, y: 6 } })
      await unhidden(page.getByRole('navigation', { name: 'Mobile places' }))
      assert.equal(await page.getByRole('button', { name: 'Open navigation' }).getAttribute('aria-expanded'), 'false')
      // Escape also works when a hardware keyboard is connected.
      await page.getByRole('button', { name: 'Open navigation' }).click()
      await page.keyboard.press('Escape')
      await unhidden(page.getByRole('navigation', { name: 'Mobile places' }))
    }

    await selectPassage(page)
    await page.getByRole('toolbar', { name: 'Actions for selected text' }).getByRole('button', { name: 'Keep a note' }).click()
    await visible(page.getByRole('dialog', { name: /Keep a note from Computer Science Essentials/i }))
    const noteText = 'Key point from the selected sentence.'
    await page.locator('#note-body').fill(noteText)
    await page.getByRole('button', { name: 'Save note' }).click()
    await unhidden(page.getByRole('dialog', { name: /Keep a note from Computer Science Essentials/i }))
    await visible(page.locator('.margin-note').getByText(noteText))
    // Original PDF is readable, but selection requires reconstructed text.
    await page.getByRole('radio', { name: 'Original page' }).click()
    await visible(page.getByText(/switch to “For reading”/))
    await page.getByRole('radio', { name: 'For reading' }).click()
    await visible(page.locator('.reader-paper .prose p'))
    await selectPassage(page)
    await page.getByRole('toolbar', { name: 'Actions for selected text' }).getByRole('button', { name: 'Explain', exact: true }).click()
    await visible(page.getByRole('region', { name: 'Explained simply' }).or(page.locator('.explain-panel')))
    await page.getByRole('button', { name: /Close and go back to reading/i }).click()
    await visible(page.locator('.reader-paper .prose p'))

    await page.getByRole('button', { name: 'Next page' }).click()
    await visible(page.locator('.reader-paper[aria-label="Page 2 of 4"]'))
    await page.getByRole('button', { name: 'Previous page' }).click()
    await visible(page.locator('.reader-paper[aria-label="Page 1 of 4"]'))

    await goTo(page, mobile, 'Notes')
    await visible(page.getByText(noteText))
    await noHorizontalOverflow(page, 'Notes ' + name)
    await page.getByRole('link', { name: /Open Computer Science Essentials, p. 1/i }).click()
    await visible(page.locator('.reader-paper .prose p'))

    await goTo(page, mobile, 'Library')
    await visible(page.getByRole('heading', { name: 'Your library' }))
    await noHorizontalOverflow(page, 'Library ' + name)
    // The entire sample shelf covers more concepts for Search / Explore / Trails.
    const add = page.getByRole('button', { name: /Add the .* sample books/i })
    if (await add.count()) {
      await add.click()
      await page.waitForFunction(() => document.querySelectorAll('.quilt-cell').length >= 6, null, { timeout: 55000 })
    }
    await noHorizontalOverflow(page, 'Six sample books ' + name)
    await page.locator('.quilt-cell button').first().click()
    await visible(page.getByRole('heading', { name: /Essentials|Notes|Patterns|System|JavaScript|Interviews/i }))
    await noHorizontalOverflow(page, 'Book overview ' + name)
    await page.getByRole('button', { name: /Read this chapter/i }).click()
    await visible(page.locator('.reader-paper .prose p'))

    await goTo(page, mobile, 'Study')
    await visible(page.getByRole('heading', { name: /I'd like to/i }))
    await noHorizontalOverflow(page, 'Study ' + name)
    await page.getByRole('button', { name: /How to study:/i }).click()
    await visible(page.getByRole('listbox', { name: 'How to study' }))
    // Outside interactions dismiss other popovers too.
    await page.locator('.study-next').click({ position: { x: 8, y: 8 } })
    await unhidden(page.getByRole('listbox', { name: 'How to study' }))
    await page.getByRole('button', { name: /Start remembering/i }).click()
    await visible(page.locator('.recall').or(page.getByText(/Nothing to study on this subject yet/i)), 20000)

    await goTo(page, mobile, 'Explore')
    await visible(page.locator('.explore, .empty'))
    await noHorizontalOverflow(page, 'Explore ' + name)
    const makeTrail = page.getByRole('button', { name: 'Make it a trail' })
    if (await makeTrail.isVisible().catch(() => false) && await makeTrail.isEnabled()) {
      await makeTrail.click()
      await visible(page.locator('.walk'))
      await noHorizontalOverflow(page, 'Trail map ' + name)
    } else {
      await goTo(page, mobile, 'Trails')
      await visible(page.locator('.walk, .empty'))
    }

    await page.getByRole('button', { name: 'Search books' }).click()
    await visible(page.getByRole('dialog', { name: 'Search your books' }))
    await page.getByRole('textbox', { name: 'Ask your books anything' }).fill('algorithm')
    await visible(page.locator('.best, .search-hint'))
    await page.getByRole('button', { name: 'Close search' }).click()
    await unhidden(page.getByRole('dialog', { name: 'Search your books' }))
    await noHorizontalOverflow(page, 'Final ' + name)
    assert.deepEqual(pageErrors, [], name + ': browser exceptions')
    await page.screenshot({ path: join(evidence, evidenceName + '-passed.png'), fullPage: false })
    console.log(`PASS ${evidenceName}: sample import, reader, touch menu, text notes, original PDF, explain, page turns, library, study, explore/trails, search, responsive width`)
  } catch (error) {
    await page.screenshot({ path: join(evidence, evidenceName + '-failed.png'), fullPage: true, timeout: 12000 }).catch(() => {})
    console.error(`FAIL ${evidenceName}: ${error?.stack ?? error}`)
    if (pageErrors.length) console.error('Page errors:', pageErrors)
    throw error
  } finally {
    await browser.close()
  }
}

try {
  await runBrowser(chromium, 'chromium-desktop', false, 1440)
  await runBrowser(chromium, 'chromium-mobile', true, 390)
  await runBrowser(webkit, 'webkit-iphone', true, 390)
  await runBrowser(webkit, 'webkit-compact', true, 320)
} catch {
  process.exitCode = 1
} finally {
  server.kill('SIGTERM')
}
