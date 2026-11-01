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
    const element = document.querySelector('.reader-immersive [data-active="true"] .prose .s, .reader:not(.reader-immersive) .reader-paper .prose .s')
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
/** Dispatch a touch gesture to the real reader handlers; no fake page routes. */
async function swipeReader(page, dx, dy = 0) {
  await page.locator('.reader-paper').evaluate((paper, movement) => {
    const start = { clientX: 190, clientY: 320 }
    const finish = { clientX: start.clientX + movement.dx, clientY: start.clientY + movement.dy }
    const dispatch = (type, current, changed) => {
      const event = new Event(type, { bubbles: true, cancelable: true })
      Object.defineProperties(event, {
        touches: { value: current ? [current] : [] },
        changedTouches: { value: [changed] },
      })
      paper.dispatchEvent(event)
    }
    dispatch('touchstart', start, start)
    dispatch('touchend', null, finish)
  }, { dx, dy })
}

async function navigateMobile(page, name) {
  const trigger = page.getByRole('button', { name: 'Open navigation' })
  await trigger.click()
  await visible(page.getByRole('navigation', { name: 'Mobile places' }))
  await page.getByRole('navigation', { name: 'Mobile places' }).getByRole('link', { name }).click()
}
async function goTo(page, mobile, name) {
  if (mobile) return navigateMobile(page, name)
  if (name === 'Home') return page.locator('.topbar .wordmark').click()
  return page.getByRole('navigation', { name: 'Places' }).getByRole('link', { name, exact: true }).click()
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
  page.on('console', (message) => {
    if (message.type() === 'error' || message.type() === 'warning') console.error(`BROWSER ${name} ${message.type()}: ${message.text()}`)
  })
  page.on('requestfailed', (request) => console.error(`NETWORK ${name}: ${request.url()} — ${request.failure()?.errorText}`))
  page.setDefaultTimeout(16000)
  const evidenceName = `${name}-${width}`
  try {
    await page.goto(base, { waitUntil: 'domcontentloaded', timeout: 30000 })
    await visible(page.getByRole('heading', { name: /Make yourself comfortable/i }))
    await noHorizontalOverflow(page, 'Welcome ' + name)
    if (mobile) {
      const touchAction = await page.locator('.welcome-art canvas').evaluate((canvas) => getComputedStyle(canvas).touchAction)
      assert.equal(touchAction, 'auto', 'Knitting-basket animation must not intercept touch scrolling')
    }
    await page.getByRole('button', { name: /start with a sample book/i }).click()
    await visible(page.getByRole('dialog', { name: /Sewing in Computer Science Essentials/i }))
    await visible(page.locator('.sewn-actions .btn.ink'), 25000)
    await page.locator('.sewn-actions .btn.ink').click()
    try {
      await page.getByRole('button', { name: 'For reading', exact: true }).click()
      await visible(page.locator('.reader-paper .prose p').first(), 25000)
    } catch (error) {
      const details = await page.evaluate(() => ({
        hash: location.hash, text: document.querySelector('.reader-paper')?.textContent?.slice(0,1100),
        page: document.body.textContent?.slice(0,2000),
        canvases: document.querySelectorAll('.reader-paper canvas').length,
        mode: document.querySelector('.segmented [aria-pressed="true"]')?.textContent,
      }))
      console.error(`READER DIAGNOSTIC ${name}: ${JSON.stringify(details)}`)
      throw error
    }
    await noHorizontalOverflow(page, 'Reader ' + name)
    const focusBox = await page.getByRole('button', { name: 'Enter full-screen reading' }).boundingBox()
    assert.ok(focusBox && focusBox.y < 150,
      'Fullscreen entry is reachable in the top reader toolbar')
    const scrollBox = await page.locator('.reader-grid').boundingBox()
    const footerBox = await page.locator('.reader-foot').boundingBox()
    const playButton = await page.locator('.reader-foot .dock-play').boundingBox()
    const pageControl = await page.locator('.reader-foot .dock-pages').boundingBox()
    const voiceControl = await page.locator('.reader-foot .dock-voice').boundingBox()
    assert.ok(playButton && pageControl && voiceControl && pageControl.x >= playButton.x + playButton.width + 4,
      'Page turning is a distinct centered group, visually separate from listening')
    assert.ok(voiceControl.x >= playButton.x && pageControl.x + pageControl.width <= width + 2
      && Math.abs(pageControl.x + pageControl.width / 2 - width / 2) <= 3,
      'Listening and centered page controls fit the same footer without overlap')
    assert.ok(await page.locator('.reader-foot .dock-pages').getByRole('button', { name: 'Next page' }).isVisible(),
      'A visible Next page button remains in the reader footer')
    assert.ok(footerBox && footerBox.height <= 62, 'The ordinary reader footer fits in a single compact row')
    assert.ok(scrollBox && footerBox && scrollBox.y + scrollBox.height <= footerBox.y + 1,
      'The listening footer reserves space and cannot cover reading text')

    if (mobile) {
      const voiceButton = page.getByRole('button', { name: /^Voice: .* Change$/ })
      await visible(voiceButton)
      await voiceButton.click()
      await visible(page.getByRole('menu', { name: 'Voices' }))
      await visible(page.getByRole('menuitemradio', { name: /Device default/i }))
      await page.getByRole('menuitemradio', { name: /Device default/i }).click()
      await visible(page.getByRole('button', { name: /^Reading speed / }))
      const speedButton = page.getByRole('button', { name: /^Reading speed / })
      const speedBefore = await speedButton.getAttribute('aria-label')
      await speedButton.click()
      assert.notEqual(await speedButton.getAttribute('aria-label'), speedBefore, 'Mobile voice speed must change')
      // A horizontal swipe turns a page; vertical scrolling must never do so.
      await swipeReader(page, -140)
      await visible(page.locator('.reader-paper[aria-label="Page 2 of 4"]'))
      await swipeReader(page, -12, -150)
      await visible(page.locator('.reader-paper[aria-label="Page 2 of 4"]'))
      await swipeReader(page, 140)
      await visible(page.locator('.reader-paper[aria-label="Page 1 of 4"]'))
      await noHorizontalOverflow(page, 'Mobile voice and swipes ' + name)

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

    // Intentional replacement of continuous vertical scrolling: fitted screens,
    // hidden overlay chrome, horizontal navigation and original PDF fit/zoom.
    const normalBar = await page.locator('.reader-bar').boundingBox()
    const entry = await page.getByRole('button', { name: 'Enter full-screen reading' }).boundingBox()
    if (mobile) assert.ok(entry.y >= normalBar.y && entry.y + entry.height <= normalBar.y + normalBar.height + 1, 'Fullscreen entry stays in the top reading toolbar')
    const reveal = async () => {
      if (await page.locator('.reader-immersive').getAttribute('data-controls') === 'hidden') {
        const box = await page.locator('.paged-reader').boundingBox()
        await page.locator('.paged-reader').click({ position: { x: box.width / 2, y: box.height / 2 } })
      }
      await visible(page.getByRole('button', { name: 'Exit full-screen reading' }))
    }
    await page.getByRole('button', { name: 'Enter full-screen reading' }).click()
    await visible(page.locator('.paged-current .prose p').first())
    assert.equal(await page.locator('.reader-immersive').getAttribute('data-controls'), 'hidden')
    const focusPages = page.getByRole('navigation', { name: 'Full-screen pages' })
    assert.ok(await focusPages.isVisible() && await page.getByRole('button', { name: 'Show reader tools' }).isVisible()
      && await page.getByRole('button', { name: 'Leave full-screen' }).isVisible(),
      'Fullscreen retains discoverable navigation, tool access and exit even with its chrome hidden')
    assert.ok(await page.locator('.reader-focus-hint').isVisible(),
      'First-time fullscreen readers get direct gesture and toolbar guidance')
    await page.waitForFunction(() => {
      const reader = document.querySelector('.reader-immersive').getBoundingClientRect()
      return Math.abs(reader.top - (visualViewport?.offsetTop ?? 0)) < 2 && Math.abs(reader.height - (visualViewport?.height ?? innerHeight)) < 2
    })
    if (!mobile && name.startsWith('chromium')) assert.ok(await page.evaluate(() => !!document.fullscreenElement))
    const activePaper = () => page.locator('.paged-current')
    await reveal()
    await visible(page.getByRole('navigation', { name: 'Full-screen pages' }))
    await visible(page.locator('.reader-immersive .dock[data-focus="true"] .dock-focus-action'))
    assert.equal(await page.locator('.reader-immersive .paged-position').count(), 0,
      'PDF content must not have a second visible page counter')
    const textSize = await activePaper().locator('.prose').evaluate((el) => parseFloat(getComputedStyle(el).fontSize))
    await page.getByRole('button', { name: 'Zoom in' }).click()
    assert.ok(await activePaper().locator('.prose').evaluate((el) => parseFloat(getComputedStyle(el).fontSize)) > textSize)
    await page.getByRole('button', { name: 'Reset zoom' }).click()
    const pageNavigation = page.getByRole('navigation', { name: 'Full-screen pages' })
    const step = async (direction) => {
      const before = await page.locator('.paged-reader').getAttribute('data-location')
      await pageNavigation.getByRole('button', { name: direction > 0 ? 'Next page' : 'Previous page' }).click()
      await page.waitForFunction((old) => document.querySelector('.paged-reader')?.dataset.location !== old && document.querySelector('.paged-reader')?.dataset.settled === 'true', before).catch(async (error) => { console.error('STEP', before, await page.locator('.paged-reader').evaluate((el) => ({ ...el.dataset, transform: el.firstElementChild.style.transform }))); throw error })
    }
    await step(1)
    await step(-1)
    assert.equal(await page.locator('.paged-reader').getAttribute('data-location'), '1:0')
    await page.getByRole('button', { name: 'Original page' }).click()
    await visible(activePaper().locator('canvas'))
    await page.waitForFunction(() => parseFloat(document.querySelector('.paged-current canvas')?.style.width ?? '0') > 0)
    assert.ok(await activePaper().locator('canvas').evaluate((el) => {
      const rect = el.getBoundingClientRect(), area = el.parentElement.getBoundingClientRect()
      return rect.left >= area.left - 2 && rect.right <= area.right + 2
        && rect.top >= area.top - 2 && rect.bottom <= area.bottom + 2
    }), 'The complete original page fits inside both viewport dimensions at 100%')
    const originalWidth = await activePaper().locator('canvas').evaluate((el) => parseFloat(el.style.width))
    await page.getByRole('button', { name: 'Zoom in' }).click()
    await page.waitForFunction((before) => parseFloat(document.querySelector('.paged-current canvas')?.style.width ?? '0') > before, originalWidth)
    await page.getByRole('button', { name: 'Reset zoom' }).click()
    await page.getByRole('button', { name: 'For reading' }).click()
    await visible(activePaper().locator('.prose p').first())
    for (let guard = 0; guard < 40 && await pageNavigation.getByRole('button', { name: 'Next page' }).isEnabled(); guard++) await step(1)
    assert.equal(await activePaper().getAttribute('data-page'), '4')
    assert.equal(await pageNavigation.getByRole('button', { name: 'Next page' }).isDisabled(), true)
    assert.equal(await page.locator('.reader-grid').evaluate((el) => el.scrollTop), 0)
    assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('leu.web.v1')).books[0].page), 4)
    await page.getByRole('button', { name: 'Original page' }).click()
    await visible(activePaper().locator('canvas'))
    await page.getByRole('button', { name: 'For reading' }).click()
    await visible(activePaper().locator('.prose p').first())
    // Same-book search remains in fullscreen and opens the first screen of its source.
    await page.keyboard.press('Control+k')
    await visible(page.getByRole('dialog', { name: 'Search your books' }))
    await page.getByRole('textbox', { name: 'Ask your books anything' }).fill('References')
    await visible(page.locator('#result-0'), 25000)
    await page.locator('#result-0').click()
    await page.waitForFunction(() => document.querySelector('.paged-reader')?.dataset.location === '3:0')
    await selectPassage(page)
    await page.getByRole('toolbar', { name: 'Actions for selected text' }).getByRole('button', { name: 'Keep a note' }).click()
    await visible(page.getByRole('dialog', { name: /Keep a note from.*page 3/i }))
    await page.locator('#note-body').fill('A note made in full screen.')
    await page.getByRole('button', { name: 'Save note' }).click()
    await unhidden(page.getByRole('dialog', { name: /Keep a note from/i }))
    assert.ok(await page.evaluate(() => JSON.parse(localStorage.getItem('leu.web.v1')).notes.some((n) => n.page === 3 && n.note === 'A note made in full screen.')))
    for (let guard = 0; guard < 30 && await pageNavigation.getByRole('button', { name: 'Next page' }).isEnabled(); guard++) await step(1)
    const lastLocation = await page.locator('.paged-reader').getAttribute('data-location')
    await page.screenshot({ path: join(evidence, evidenceName + '-fullscreen.png') })
    await page.getByRole('button', { name: 'Exit full-screen reading' }).click()
    await unhidden(page.locator('.reader.reader-immersive'))
    await page.waitForFunction(() => !document.fullscreenElement)
    await visible(page.locator('.reader-foot .dock:not([data-focus="true"]) .dock-play'))
    await noHorizontalOverflow(page, 'After full-screen zoom ' + name)
    await page.evaluate(() => Object.defineProperty(document, 'fullscreenEnabled', { value: false, configurable: true }))
    await page.getByRole('button', { name: 'Enter full-screen reading' }).click()
    await visible(activePaper().locator('.prose p').first())
    await page.waitForFunction((saved) => document.querySelector('.paged-reader')?.dataset.location === saved, lastLocation)
    assert.equal(await page.evaluate(() => !!document.fullscreenElement), false)
    const beforeKey = await page.locator('.paged-reader').getAttribute('data-location')
    await page.keyboard.press('PageUp')
    await page.waitForFunction((before) => document.querySelector('.paged-reader')?.dataset.location !== before, beforeKey)
    assert.equal(await page.locator('.reader-grid').evaluate((el) => el.scrollTop), 0)
    await reveal()
    for (let guard = 0; guard < 40 && await pageNavigation.getByRole('button', { name: 'Previous page' }).isEnabled(); guard++) await step(-1)
    assert.equal(await page.locator('.paged-reader').getAttribute('data-location'), '1:0')
    await page.keyboard.press('Escape')
    await unhidden(page.locator('.reader.reader-immersive'))
    await page.evaluate(() => { delete document.fullscreenEnabled })
    assert.equal(await page.evaluate(() => document.body.style.position), '', 'Exiting restores background scrolling')

    await selectPassage(page)
    await page.getByRole('toolbar', { name: 'Actions for selected text' }).getByRole('button', { name: 'Keep a note' }).click()
    await visible(page.getByRole('dialog', { name: /Keep a note from Computer Science Essentials/i }))
    const noteText = 'Key point from the selected sentence.'
    await page.locator('#note-body').fill(noteText)
    await page.getByRole('button', { name: 'Save note' }).click()
    await unhidden(page.getByRole('dialog', { name: /Keep a note from Computer Science Essentials/i }))
    await visible(page.locator('.margin-note').getByText(noteText))
    // Original PDF is readable, but selection requires reconstructed text.
    await page.getByRole('button', { name: 'Original page' }).click()
    await visible(page.getByText(/For selectable text and notes|switch to “For reading”/i))
    await page.getByRole('button', { name: 'For reading' }).click()
    await page.getByRole('button', { name: 'For reading', exact: true }).click()
    await visible(page.locator('.reader-paper .prose p').first())
    await selectPassage(page)
    await page.getByRole('toolbar', { name: 'Actions for selected text' }).getByRole('button', { name: 'Explain', exact: true }).click()
    await visible(page.getByRole('region', { name: 'Explained simply' }).or(page.locator('.explain-panel')))
    // The CI browser has no built-in local language model. Never present quoted text as teaching.
    await visible(page.getByText(/On-device explanations aren't available/i))
    assert.equal(await page.getByText('The short version').count(), 0)
    await page.getByRole('button', { name: /Close and go back to reading/i }).click()

    // Exercise the actual model integration using a deterministic browser-native mock:
    // structured teaching, no network, disposal, source disclosure and failure gating.
    await page.evaluate(() => {
      window.__EXPLANATION_TEST = { calls: 0, destroyed: 0, bad: true }
      window.LanguageModel = {
        availability: async () => 'available',
        create: async () => ({
          prompt: async (query, options) => {
            window.__EXPLANATION_TEST.calls++
            window.__EXPLANATION_TEST.prompt = query
            window.__EXPLANATION_TEST.schema = options.responseConstraint
            const quote = JSON.parse(query.slice(query.indexOf('{"selectedPassage":'))).selectedPassage
            if (window.__EXPLANATION_TEST.bad)
              return JSON.stringify({ meaning: quote, mechanism: quote, example: '', caveat: '' })
            return JSON.stringify({
              meaning: 'A model is a useful shortcut. It keeps the parts of something that help you decide what will happen and ignores less important details.',
              mechanism: 'The stack description tells you which item comes out first without needing to describe every possible detail. The order matters because a new item goes onto the top, so it will be the first one removed.',
              example: 'Imagine putting three plates on top of one another. You take the top plate off first, even though it was the last plate you added. That is the useful prediction the model gives you.',
              caveat: 'This shortcut only helps when leaving out those details does not change the decision you need to make.',
            })
          },
          destroy: () => { window.__EXPLANATION_TEST.destroyed++ },
        }),
      }
    })
    await page.evaluate(() => {
      const paragraph = document.querySelector('.reader-paper .prose p')
      if (!paragraph) throw new Error('No paragraph to explain')
      const range = document.createRange()
      range.selectNodeContents(paragraph)
      const selection = window.getSelection()
      selection.removeAllRanges()
      selection.addRange(range)
      document.dispatchEvent(new Event('selectionchange'))
    })
    await visible(page.getByRole('toolbar', { name: 'Actions for selected text' }))
    await page.getByRole('toolbar', { name: 'Actions for selected text' }).getByRole('button', { name: 'Explain', exact: true }).click()
    await visible(page.getByText(/repeated the source rather than explaining/i))
    assert.equal(await page.locator('.explain-meaning').count(), 0, 'Copied output must never be shown')
    await page.evaluate(() => { window.__EXPLANATION_TEST.bad = false })
    await page.getByRole('button', { name: 'Try again' }).click()
    await visible(page.locator('.explain-meaning'))
    await visible(page.getByText(/three plates on top/i))
    assert.equal(await page.getByText('The short version').count(), 0)
    assert.ok(await page.evaluate(() => window.__EXPLANATION_TEST.calls >= 2 && window.__EXPLANATION_TEST.destroyed >= 2))
    await noHorizontalOverflow(page, 'Generated explanation ' + name)
    await page.getByRole('button', { name: /Close and go back to reading/i }).click()
    await page.evaluate(() => { delete window.LanguageModel; delete window.__EXPLANATION_TEST })
    await page.getByRole('button', { name: 'For reading', exact: true }).click()
    await visible(page.locator('.reader-paper .prose p').first())

    await page.getByRole('button', { name: 'Next page' }).click()
    await visible(page.locator('.reader-paper[aria-label="Page 2 of 4"]'))
    await page.getByRole('button', { name: 'Previous page' }).click()
    await visible(page.locator('.reader-paper[aria-label="Page 1 of 4"]'))

    // Simulate an existing Leu user whose indexed text was saved as empty by
    // an older Safari PDF parser. Search must repair from the saved PDF.
    const sampleId = await page.evaluate(() => {
      const state = JSON.parse(localStorage.getItem('leu.web.v1'))
      return state.books.find((book) => book.title === 'Computer Science Essentials').id
    })
    await page.evaluate(async (id) => {
      await new Promise((resolve, reject) => {
        const open = indexedDB.open('keyval-store')
        open.onerror = () => reject(open.error)
        open.onsuccess = () => {
          const database = open.result
          const tx = database.transaction('keyval', 'readwrite')
          tx.objectStore('keyval').put(['', '', '', ''], `text:${id}`)
          tx.oncomplete = () => { database.close(); resolve() }
          tx.onerror = () => reject(tx.error)
        }
      })
    }, sampleId)
    await page.getByRole('button', { name: 'Search your books' }).click()
    await visible(page.getByRole('dialog', { name: 'Search your books' }))
    await page.getByRole('textbox', { name: 'Ask your books anything' }).fill('References')
    await visible(page.locator('#result-0'), 40000)
    const bestSource = await page.locator('#result-0 .result-place').innerText()
    assert.ok(bestSource.includes('Computer Science Essentials'), 'Repaired search should find the sample book')
    assert.ok(bestSource.includes('p. 3'), `References must link to its real source on page 3, got: ${bestSource}`)
    await page.locator('#result-0').click()
    await visible(page.locator('.reader-paper[aria-label="Page 3 of 4"]'))
    await noHorizontalOverflow(page, 'Recovered search result ' + name)

    await goTo(page, mobile, 'Notes')
    await visible(page.getByText(noteText))
    await noHorizontalOverflow(page, 'Notes ' + name)
    await page.getByRole('link', { name: /Open Computer Science Essentials, p. 1/i }).click()
    await page.getByRole('button', { name: 'For reading', exact: true }).click()
    await visible(page.locator('.reader-paper .prose p').first())

    await goTo(page, mobile, 'Library')
    await visible(page.getByRole('heading', { name: 'Your library' }))
    await noHorizontalOverflow(page, 'Library ' + name)
    // The entire sample shelf covers more concepts for Search / Explore / Trails.
    const add = page.getByRole('button', { name: /Try \d+ sample PDFs?/i })
    if (await add.count()) {
      await add.click()
      await page.waitForFunction(() => document.querySelectorAll('.quilt-cell').length >= 6, null, { timeout: 55000 })
    }
    await noHorizontalOverflow(page, 'Six sample books ' + name)
    await page.locator('.quilt-cell button').first().click()
    await visible(page.getByRole('heading', { name: /Essentials|Notes|Patterns|System|JavaScript|Interviews/i }).first())
    await noHorizontalOverflow(page, 'Book overview ' + name)
    await page.getByRole('button', { name: /Read this chapter/i }).click()
    await page.getByRole('button', { name: 'For reading', exact: true }).click()
    await visible(page.locator('.reader-paper .prose p').first())

    await goTo(page, mobile, 'Study')
    await visible(page.getByRole('heading', { name: /I'd like to/i }))
    await noHorizontalOverflow(page, 'Study ' + name)
    await page.getByRole('button', { name: /How to study:/i }).click()
    await visible(page.getByRole('group', { name: 'How to study' }))
    // Outside interactions dismiss other popovers too.
    await page.locator('.study-next').click({ position: { x: 8, y: 8 } })
    await unhidden(page.getByRole('group', { name: 'How to study' }))
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

    await page.getByRole('button', { name: 'Search your books' }).click()
    await visible(page.getByRole('dialog', { name: 'Search your books' }))
    await page.getByRole('textbox', { name: 'Ask your books anything' }).fill('algorithm')
    await visible(page.locator('.best, .search-hint'))
    await page.getByRole('button', { name: 'Close search' }).click()
    await unhidden(page.getByRole('dialog', { name: 'Search your books' }))
    await noHorizontalOverflow(page, 'Final ' + name)
    assert.deepEqual(pageErrors, [], name + ': browser exceptions')
    await page.screenshot({ path: join(evidence, evidenceName + '-passed.png'), fullPage: false })
    console.log(`PASS ${evidenceName}: sample import, reader, touch menu, mobile voice and swipes, text notes, full-screen reflow and PDF zoom, legacy index self-repair, exact source search, page turns, library, study, explore/trails, responsive width`)
  } catch (error) {
    await page.screenshot({ path: join(evidence, evidenceName + '-failed.png'), fullPage: true, timeout: 12000 }).catch(() => {})
    console.error(`FAIL ${evidenceName}: ${error?.stack ?? error}`)
    if (pageErrors.length) console.error('Page errors:', pageErrors)
    throw error
  } finally {
    await browser.close()
  }
}


/**
 * Static HTTPS previews must visibly animate actual Leu images on mobile.
 * Compare canvas frames rather than just asserting that a page rendered.
 */
async function checkMotionPreviews(browserType, engine, width) {
  const browser = await browserType.launch({ headless: true })
  const page = await browser.newPage({
    viewport: { width, height: 844 },
    deviceScaleFactor: 2, isMobile: true, hasTouch: true,
    reducedMotion: 'no-preference',
  })
  const errors = []
  page.on('pageerror', (error) => errors.push(error.message))
  try {
    for (const variant of ['quiet-weather', 'afterglow', 'material-rhythm']) {
      const response = await page.goto(base + '/motion/' + variant + '.html', { waitUntil: 'domcontentloaded', timeout: 25000 })
      assert.equal(response?.status(), 200, 'Preview ' + variant + ' should load as HTML')
      await page.waitForFunction(() => window.__LEU_MOTION_TEST?.frames >= 7, null, { timeout: 15000 })
      await page.waitForFunction(() => [...document.querySelectorAll('img[data-art]')].every((img) => img.complete && img.naturalWidth > 0), null, { timeout: 16000 })
      assert.equal(await page.locator('[data-playing]').getAttribute('data-playing'), 'true')
      const dimensions = await page.evaluate(() => ({
        top: document.querySelector('.stage').getBoundingClientRect().top,
        canvasWidth: document.querySelector('[data-fx="rain"]').width,
        horizontalOverflow: document.documentElement.scrollWidth > innerWidth + 3,
      }))
      assert.ok(dimensions.top < 250, engine + ': artwork should appear above fold')
      assert.ok(dimensions.canvasWidth > 120, engine + ': canvas must cover the artwork')
      assert.equal(dimensions.horizontalOverflow, false, engine + ': horizontal overflow in ' + variant)
      for (const [scene, label, fx] of [
        ['nook', 'Reading nook', 'rain'],
        ['basket', 'Knitting basket', 'basket'],
        ['globe', 'Snow globe', 'globe'],
      ]) {
        await page.getByRole('tab', { name: label }).click()
        assert.equal(await page.evaluate(() => window.__LEU_MOTION_TEST.active), scene)
        const canvas = page.locator('canvas[data-fx="' + fx + '"]')
        await page.waitForTimeout(180)
        const before = await canvas.evaluate((el) => el.toDataURL())
        await page.waitForTimeout(500)
        const after = await canvas.evaluate((el) => el.toDataURL())
        assert.notEqual(before, after, variant + '/' + scene + ': animation is static')
        const pointer = await page.locator('[data-scene="' + scene + '"] .ill').evaluate((el) => getComputedStyle(el).pointerEvents)
        assert.equal(pointer, 'none', 'Artwork must not steal touches')
      }
      await page.getByRole('button', { name: 'Pause motion' }).click()
      const stoppedAt = await page.evaluate(() => window.__LEU_MOTION_TEST.frames)
      await page.waitForTimeout(230)
      assert.equal(await page.evaluate(() => window.__LEU_MOTION_TEST.frames), stoppedAt, 'Pause failed in ' + variant)
      await page.getByRole('button', { name: 'Play motion' }).click()
      await page.waitForFunction((before) => window.__LEU_MOTION_TEST.frames > before, stoppedAt)
      await page.getByRole('tab', { name: 'Reading nook' }).click()
      await page.screenshot({ path: join(evidence, 'motion-' + variant + '-' + engine + '-' + width + '.png') })
      console.log('PASS ' + engine + '-' + width + ' ' + variant + ': original art loaded, 3 moving scenes, touch-safe controls, Pause/Play')
    }
    await page.emulateMedia({ reducedMotion: 'reduce' })
    await page.goto(base + '/motion/quiet-weather.html', { waitUntil: 'domcontentloaded' })
    await visible(page.getByRole('button', { name: 'Play motion' }))
    assert.equal(await page.evaluate(() => window.__LEU_MOTION_TEST.playing), false)
    await page.getByRole('button', { name: 'Play motion' }).click()
    await page.waitForFunction(() => window.__LEU_MOTION_TEST.frames >= 4, null, { timeout: 15000 })
    console.log('PASS ' + engine + '-' + width + ': Reduced Motion respected and user can explicitly start preview')
    assert.deepEqual(errors, [], engine + ': motion preview browser exceptions')
  } catch (error) {
    await page.screenshot({ path: join(evidence, 'motion-failed-' + engine + '-' + width + '.png'), fullPage: true }).catch(() => {})
    console.error('FAIL ' + engine + '-' + width + ': ' + (error?.stack ?? error))
    if (errors.length) console.error('Browser errors:', errors)
    throw error
  } finally {
    await browser.close()
  }
}

try {
  await runBrowser(chromium, 'chromium-desktop', false, 1440)
  await runBrowser(webkit, 'webkit-compact', true, 320)
  await runBrowser(webkit, 'webkit-iphone', true, 390)
  await runBrowser(chromium, 'chromium-mobile', true, 390)
  await checkMotionPreviews(webkit, 'webkit-iphone', 390)
  await checkMotionPreviews(chromium, 'chromium-android', 390)
} catch {
  process.exitCode = 1
} finally {
  server.kill('SIGTERM')
}
