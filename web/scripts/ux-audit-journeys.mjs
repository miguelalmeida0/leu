import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdir } from 'node:fs/promises'
import { chromium, webkit } from 'playwright'

const base = 'http://127.0.0.1:4193'
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', 'preview', '--host', '127.0.0.1', '--port', '4193', '--strictPort'], { stdio: 'ignore' })
await mkdir('qa-evidence/ux-audit', { recursive: true })
try {
  for (let n = 0; n < 60; n++) {
    try { if ((await fetch(base)).ok) break } catch {}
    await new Promise(resolve => setTimeout(resolve, 100))
  }
  for (const [engine, width, motion] of [[chromium,1440,'no-preference'],[chromium,1440,'reduce'],[webkit,390,'no-preference'],[webkit,320,'reduce']]) {
    const browser = await engine.launch()
    const page = await browser.newPage({ viewport: { width, height: 900 }, isMobile: width < 721, hasTouch: width < 721, reducedMotion: motion })
    const name = `${engine.name()}-${width}-${motion}`
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    try {
      await page.goto(base)
      await page.getByRole('button', {name: 'or start with a sample book', exact: true}).click()
      await page.getByRole('button', {name: 'Open Computer Science Essentials', exact: true}).click()
      await page.waitForFunction(() => document.querySelector('.original-page')?.width > 0)
      const id = new URL(page.url()).hash.split('/')[2]
      await page.getByRole('button', {name:'Enter full-screen reading',exact:true}).click()
      await page.waitForFunction(() => document.querySelector('.paged-current canvas')?.width > 0)
      await page.getByRole('button',{name:'Show reading controls',exact:true}).focus()
      await page.keyboard.press('Enter')
      await page.locator('.reader-immersive[data-controls="shown"]').waitFor()
      await page.waitForFunction(() => {
        const canvas = document.querySelector('.paged-current canvas')?.getBoundingClientRect()
        const bar = document.querySelector('.reader-bar')?.getBoundingClientRect()
        const foot = document.querySelector('.reader-foot')?.getBoundingClientRect()
        return canvas && bar && foot && canvas.top >= bar.bottom - 1 && canvas.bottom <= foot.top + 1
      })
      const before = await page.locator('.paged-current canvas').boundingBox()
      await page.getByRole('button',{name:'Show reading controls',exact:true}).focus()
      await page.keyboard.press('Enter')
      const after = await page.locator('.paged-current canvas').boundingBox()
      assert.deepEqual(after, before, 'Hiding tools preserves PDF geometry')
      await page.getByRole('button',{name:'Exit full-screen reading',exact:true}).click()
      if (width > 720) {
        await page.getByRole('button',{name:'For reading',exact:true}).click()
        await page.getByRole('button',{name:'Enter full-screen reading',exact:true}).click()
        await page.getByRole('button',{name:'Show reading controls',exact:true}).focus()
        await page.keyboard.press('Enter')
        await page.waitForFunction(() => {
          const title = document.querySelector('.paged-current .prose h2')?.getBoundingClientRect()
          const bar = document.querySelector('.reader-bar')?.getBoundingClientRect()
          return title && bar && title.top >= bar.bottom
        })
        await page.screenshot({path:`qa-evidence/ux-audit/${name}-fullscreen.png`})
        await page.keyboard.press('Escape')
        await page.getByRole('button',{name:'Explain this page simply',exact:true}).waitFor()
        assert.equal(await page.getByRole('button',{name:'Explain this page simply',exact:true}).isEnabled(), false)
        await page.getByText('On-device explanations are unavailable in this browser.',{exact:false}).waitFor()
        await page.getByRole('button',{name:'Listen to this page',exact:true}).click()
        await page.getByRole('dialog',{name:'Download the reading voice'}).waitFor()
        await page.getByRole('button',{name:'Not now',exact:true}).click()
        await page.getByRole('link',{name:'Back to book overview',exact:true}).click()
        await page.getByRole('button',{name:'Start reading',exact:true}).click()
        assert.equal(await page.getByRole('button',{name:'For reading',exact:true}).getAttribute('aria-pressed'),'true')
      }
      await page.goto(`${base}/#/read/${id}/4`)
      await page.getByRole('link',{name:'Back to book overview',exact:true}).click()
      await page.getByText(/Last opened: page 4/).first().waitFor()
      assert.equal(await page.getByText(/You've read/).count(),0)
      if (width > 720) {
        const practice = page.getByRole('button', {name: /^Ask me [0-9]+ questions?$/})
        const requested = Number((await practice.textContent()).match(/[0-9]+/)[0])
        await practice.click()
        assert.equal(new URL(page.url()).hash, `#/study/${id}/${requested}`)
        await page.getByRole('button',{name:/Start, about/}).click()
        await page.getByText(`A question · 1 of ${requested}`,{exact:true}).waitFor()
        await page.getByRole('button',{name:'Stop for now',exact:true}).click()
      }
      // Explicit route preserves the book/count even after reload.
      await page.goto(`${base}/#/study/${id}/4`)
      await page.reload()
      await page.getByRole('button',{name:/Subject: Computer Science Essentials/}).waitFor()
      await page.getByRole('button',{name:/Start, about/}).click()
      await page.getByText('A question · 1 of 4',{exact:true}).waitFor()
      await page.getByRole('button',{name:'Stop for now',exact:true}).click()
      await page.goto(`${base}/#/words/${id}/4`)
      await page.getByRole('textbox',{name:'Your explanation',exact:true}).fill('A short answer')
      await page.getByText('Write at least 5 words to check your explanation.',{exact:true}).waitFor()
      assert.equal(await page.getByRole('button',{name:'See what got across',exact:true}).isEnabled(), false)
      await page.getByRole('textbox',{name:'Your explanation',exact:true}).fill('Choose a structure based on the operations it must support.')
      assert.equal(await page.getByRole('button',{name:'See what got across',exact:true}).isEnabled(), true)
      assert.deepEqual(errors, [])
      console.log(`PASS ${name}: fullscreen gutters, stable fit, study context/count, truthful progress, reflection validation${width > 720 ? ', mode persistence, capability check, voice consent' : ''}`)
    } finally { await browser.close() }
  }
} finally { server.kill() }
