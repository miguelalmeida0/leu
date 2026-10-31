import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import vm from 'node:vm'
import ts from 'typescript'

async function fixture() {
  const requests = []
  class Image {
    constructor() { requests.push(this) }
    set src(value) { this.url = value }
  }
  const context = vm.createContext({ Image, Map, Promise })
  const source = await readFile(new URL('../src/lib/motion.ts', import.meta.url), 'utf8')
  const code = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ESNext } }).outputText
  const module = new vm.SourceTextModule(code, { context })
  await module.link((specifier) => {
    const exports = specifier === 'react' ? { createContext(value) { return { value } }, useContext() {}, useEffect() {}, useRef() {}, useState() {} } : { SceneMotionOverride: {} }
    return new vm.SyntheticModule(Object.keys(exports), function () {
      for (const [key, value] of Object.entries(exports)) this.setExport(key, value)
    }, { context })
  })
  await module.evaluate()
  return { loadImage: module.namespace.loadImage, requests }
}

test('missing optional artwork settles safely and can be retried after reconnection', async () => {
  const { loadImage, requests } = await fixture()
  const missing = loadImage('/art/basket.webp')
  requests[0].onerror({ type: 'error' })
  assert.equal(await missing, undefined)
  const retry = loadImage('/art/basket.webp')
  assert.equal(requests.length, 2, 'failed images must not poison the shared cache')
  requests[1].onload()
  assert.equal(await retry, requests[1])
})

test('concurrent scene image requests share one successful decoded image', async () => {
  const { loadImage, requests } = await fixture()
  const first = loadImage('/art/globe-base.webp'), second = loadImage('/art/globe-base.webp')
  assert.equal(requests.length, 1)
  requests[0].onload()
  assert.equal(await first, await second)
  assert.equal(await loadImage('/art/globe-base.webp'), requests[0])
  assert.equal(requests.length, 1)
})
