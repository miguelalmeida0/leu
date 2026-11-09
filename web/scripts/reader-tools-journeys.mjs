import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdir } from 'node:fs/promises'
import { chromium, webkit } from 'playwright'
import AxeBuilder from '@axe-core/playwright'

const base = 'http://127.0.0.1:4196'
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js','preview','--host','127.0.0.1','--port','4196','--strictPort'], {stdio:'ignore'})
await mkdir('qa-evidence/reader-tools', {recursive:true})
function fixture() {
  const texts = [
    ['Stacks', 'A stack is last-in, first-out. Push A, push B, then pop B.'],
    ['Queues', 'A queue is first-in, first-out. Enqueue A, enqueue B, then dequeue A.'],
    ['Object references', 'Two references share the same object. Mutating it through either name changes that object.'],
    ['Reading', 'This page discusses a different subject without any interactive example.'],
  ]
  const objects = ['<< /Type /Catalog /Pages 2 0 R >>', '<< /Type /Pages /Kids [4 0 R 6 0 R 8 0 R 10 0 R] /Count 4 >>', '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>']
  for (let n=0;n<4;n++) {
    const stream = `BT /F1 22 Tf 40 720 Td (${texts[n][0]}) Tj /F1 11 Tf 0 -40 Td (${texts[n][1]}) Tj ET 0.4 0.5 0.3 rg 40 350 250 80 re f`
    objects.push(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents ${5+n*2} 0 R >>`)
    objects.push(`<< /Length ${Buffer.byteLength(stream)} >>\nstream\n${stream}\nendstream`)
  }
  let pdf='%PDF-1.4\n';const offsets=[0]
  objects.forEach((o,i)=>{offsets.push(Buffer.byteLength(pdf));pdf+=`${i+1} 0 obj\n${o}\nendobj\n`})
  const xref=Buffer.byteLength(pdf)
  pdf+=`xref\n0 ${objects.length+1}\n0000000000 65535 f \n`+offsets.slice(1).map(o=>`${String(o).padStart(10,'0')} 00000 n \n`).join('')
  return Buffer.from(pdf+`trailer\n<< /Size ${objects.length+1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`)
}
const configs = [[chromium,1440,'no-preference'],[chromium,1440,'reduce'],[chromium,390,'no-preference'],[webkit,390,'no-preference'],[webkit,320,'reduce']]
try {
  for(let i=0;i<60;i++){try{if((await fetch(base)).ok)break}catch{}await new Promise(r=>setTimeout(r,100))}
  for(const [engine,width,motion] of configs) {
    if(process.env.LEU_TOOLS_BROWSER && engine.name()!==process.env.LEU_TOOLS_BROWSER)continue
    const browser=await engine.launch()
    const context=await browser.newContext({viewport:{width,height:900},hasTouch:width<721,isMobile:width<721,reducedMotion:motion})
    const page=await context.newPage()
    const name=`${engine.name()}-${width}-${motion}`,errors=[]
    page.on('pageerror',e=>errors.push(e.message))
    try {
      await page.route('**/samples/*.pdf',r=>r.fulfill({contentType:'application/pdf',body:fixture()}))
      await page.goto(base)
      await page.getByRole('button',{name:'or start with a sample book',exact:true}).click()
      await page.getByRole('button',{name:'Open Computer Science Essentials',exact:true}).click()
      await page.getByRole('button',{name:'Try a stack',exact:false}).waitFor({state:'attached'})
      const id=new URL(page.url()).hash.split('/')[2]
      const tools=()=>page.getByRole('button',{name:'Reading tools',exact:true}).click()
      const close=()=>page.getByRole('button',{name:'Close dialog',exact:true}).click()
      const openPage=async n=>{await page.goto(`${base}/#/read/${id}/${n}`);await page.waitForFunction(()=>document.querySelector('.original-page')?.width>0);await page.waitForFunction(()=>!document.querySelector('.reader-tools-trigger')?.disabled)}
      await tools()
      await page.getByRole('dialog',{name:'Reading tools',exact:true}).getByRole('button',{name:/Try a stack/}).click()
      await page.getByRole('button',{name:'Pop an item',exact:true}).click()
      await page.getByRole('status').filter({hasText:'Popped B'}).waitFor()
      await page.getByRole('button',{name:'Pop an item',exact:true}).click()
      assert.equal(await page.getByRole('button',{name:'Pop an item',exact:true}).isEnabled(),false)
      await page.getByRole('button',{name:'Reset example',exact:true}).click()
      for(let i=0;i<4;i++)await page.getByRole('button',{name:'Push an item',exact:true}).click()
      assert.equal(await page.getByRole('button',{name:'Push an item',exact:true}).isEnabled(),false)
      const axe=await new AxeBuilder({page}).include('.reading-tools').analyze()
      assert.deepEqual(axe.violations.filter(v=>['critical','serious'].includes(v.impact)),[])
      await close()
      await tools();await page.getByRole('button',{name:'Choose a region',exact:true}).click()
      await page.locator('.region-picker[data-ready="true"]').waitFor()
      const region=await page.locator('.region-picker').boundingBox()
      await page.mouse.move(region.x+region.width*.1,region.y+region.height*.2)
      await page.mouse.down();await page.mouse.move(region.x+region.width*.8,region.y+region.height*.6,{steps:8});await page.mouse.up()
      assert.ok(Number(await page.getByLabel('Width (%)',{exact:true}).inputValue())<90,'Dragging changes the crop')
      await page.getByLabel('Left (%)',{exact:true}).fill('0')
      await page.getByLabel('Width (%)',{exact:true}).fill('100')
      await page.getByLabel('Top (%)',{exact:true}).fill('40')
      await page.getByLabel('Height (%)',{exact:true}).fill('20')
      await page.getByRole('button',{name:'Pin this region',exact:true}).click()
      await page.locator('.pinned-reference canvas:not([hidden])').waitFor()
      const imageWidth=await page.locator('.pinned-reference canvas').evaluate(el=>el.getBoundingClientRect().width)
      await page.getByRole('button',{name:'Enlarge reference',exact:true}).click()
      assert.ok(await page.locator('.pinned-reference canvas').evaluate(el=>el.getBoundingClientRect().width)>imageWidth)
      await page.getByRole('button',{name:'Reset reference zoom',exact:true}).click()
      await page.locator('.reference-body').focus();await page.keyboard.press('ArrowRight')
      assert.ok(page.url().endsWith('/1'),'Reference keyboard scrolling does not turn the book')
      const pinAxe=await new AxeBuilder({page}).include('.pinned-reference').analyze()
      assert.deepEqual(pinAxe.violations.filter(v=>['critical','serious'].includes(v.impact)),[])
      const stored=await page.evaluate(id=>JSON.parse(localStorage.getItem(`leu.reference.${id}`)),id)
      assert.equal(stored.page,1);assert.equal(stored.crop.y,.4);assert.equal(stored.crop.height,.2)
      const clear=async()=>{
        const rect=await page.evaluate(()=>({pin:document.querySelector('.pinned-reference').getBoundingClientRect().toJSON(),grid:document.querySelector('.reader-grid').getBoundingClientRect().toJSON(),width:innerWidth,scroll:document.documentElement.scrollWidth}))
        assert.ok(rect.scroll<=rect.width+1,JSON.stringify(rect))
        assert.ok(rect.grid.right<=rect.pin.left+1 || rect.grid.bottom<=rect.pin.top+1,`Reference must not obscure reading: ${JSON.stringify(rect)}`)
      }
      await clear()
      await page.getByRole('button',{name:'Next page',exact:true}).click()
      await page.waitForURL(`**/#/read/${id}/2`)
      await page.getByRole('button',{name:'Open source page 1',exact:true}).click()
      await page.waitForURL(`**/#/read/${id}/1`)
      await page.getByRole('button',{name:'Back to reading page 2',exact:true}).click()
      await page.waitForURL(`**/#/read/${id}/2`)
      await page.reload();await page.locator('.pinned-reference canvas:not([hidden])').waitFor();await clear()
      await page.getByRole('button',{name:'Enter full-screen reading',exact:true}).click()
      await page.waitForFunction(()=>document.querySelector('.reader-immersive'))
      await clear()
      await page.getByRole('button',{name:'Pinned · page 1',exact:true}).click()
      assert.equal(await page.locator('.reference-body').count(),0)
      await page.getByRole('button',{name:'Pinned · page 1',exact:true}).click();await clear()
      await page.waitForFunction(()=>{
        const grid=document.querySelector('.reader-grid').getBoundingClientRect(),pin=document.querySelector('.pinned-reference').getBoundingClientRect()
        const canvas=document.querySelector('.paged-current canvas')?.getBoundingClientRect()
        const bottom=innerWidth>=1000 ? pin.bottom : pin.top
        const fit=Math.min(grid.width,grid.height*612/792)
        return Math.abs(grid.bottom-bottom)<2 && canvas && Math.abs(canvas.width-fit)<2
      })
      await page.screenshot({path:`qa-evidence/reader-tools/${name}-reference.png`})
      await page.getByRole('button',{name:'Show reading controls',exact:true}).focus();await page.keyboard.press('Enter')
      await tools();await page.getByRole('dialog',{name:'Reading tools',exact:true}).getByRole('button',{name:/Try a queue/}).click()
      await page.getByRole('button',{name:'Dequeue an item',exact:true}).click()
      await page.getByRole('status').filter({hasText:'Dequeued A'}).waitFor()
      await page.keyboard.press('Escape')
      assert.equal(await page.locator('.reader-immersive').count(),1,'Closing an example preserves fullscreen')
      await page.getByRole('button',{name:'Exit full-screen reading',exact:true}).click()
      await page.getByRole('button',{name:'Unpin reference',exact:true}).click()
      assert.equal(await page.evaluate(id=>localStorage.getItem(`leu.reference.${id}`),id),null)
      await openPage(3)
      await page.getByRole('button',{name:/Try shared references/}).waitFor({state:'attached'})
      await tools();await page.getByRole('dialog',{name:'Reading tools',exact:true}).getByRole('button',{name:/Try shared references/}).click()
      await page.getByRole('button',{name:'Increase through B',exact:true}).click()
      assert.equal(await page.getByLabel('Value through A').textContent(),'2')
      await page.getByRole('button',{name:'Give B a copy',exact:true}).click()
      await page.getByRole('button',{name:'Increase through B',exact:true}).click()
      assert.equal(await page.getByLabel('Value through A').textContent(),'2')
      assert.equal(await page.getByLabel('Value through B').textContent(),'3')
      await page.locator('.reading-tools').evaluate(el=>{el.scrollTop=el.scrollHeight})
      const closeBox=await page.getByRole('button',{name:'Close dialog',exact:true}).boundingBox()
      assert.ok(closeBox.y>=0 && closeBox.y+closeBox.height<=900,'Close stays visible while scrolling an example')
      await page.screenshot({path:`qa-evidence/reader-tools/${name}-lab.png`})
      await close();await openPage(4);await tools()
      await page.getByText('No interactive example matches this page.',{exact:false}).waitFor()
      await close()
      if(width>720){
        await openPage(1)
        await page.getByRole('button',{name:'For reading',exact:true}).click()
        await page.locator('.prose p').first().waitFor()
        await page.evaluate(()=>{const p=[...document.querySelectorAll('.prose p')].find(el=>el.textContent.includes('A stack'));const range=document.createRange();range.selectNodeContents(p);const selection=window.getSelection();selection.removeAllRanges();selection.addRange(range);document.dispatchEvent(new Event('selectionchange'))})
        await page.getByRole('button',{name:'Pin reference',exact:true}).click()
        await page.locator('.pinned-reference blockquote').waitFor()
        assert.match(await page.locator('.pinned-reference blockquote').textContent(),/stack/)
        await page.getByRole('button',{name:'Next page',exact:true}).click()
        await page.reload()
        await page.locator('.pinned-reference blockquote').waitFor()
        assert.match(await page.locator('.pinned-reference blockquote').textContent(),/stack/)
        await page.getByRole('button',{name:'Unpin reference',exact:true}).click()
        assert.equal(await page.getByRole('button',{name:'Reading tools',exact:true}).evaluate(el=>el===document.activeElement),true)
      }
      assert.deepEqual(errors,[])
      console.log(`PASS ${name}: stack/queue/reference behavior, source crop, persistence, source-return, fullscreen, collapse, removal, keyboard, accessibility and unsupported pages`)
    } catch(error) {await page.screenshot({path:`qa-evidence/reader-tools/${name}-failure.png`}).catch(()=>{});throw error}
    finally{await browser.close()}
  }
} finally {server.kill('SIGTERM')}
