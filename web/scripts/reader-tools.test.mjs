import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import ts from 'typescript'
const source = await readFile(new URL('../src/features/reader-tools/models.ts', import.meta.url), 'utf8')
const js = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.ESNext } }).outputText
const { matchingLabs, validReference, wholePage } = await import(`data:text/javascript;base64,${Buffer.from(js).toString('base64')}`)
test('only concrete supported mechanisms offer interactive examples', () => {
  assert.deepEqual(matchingLabs('A stack is last-in, first-out. Push A, then pop it.'), ['stack'])
  assert.deepEqual(matchingLabs('A queue follows FIFO ordering.'), ['queue'])
  assert.deepEqual(matchingLabs('Both references point to the same object.'), ['references'])
  assert.deepEqual(matchingLabs('A stack of books. Queue for tickets. Reference the author.'), [])
  assert.deepEqual(matchingLabs(''), [])
})
test('persisted pins reject corrupt data, out-of-book pages and out-of-page crops', () => {
  assert.equal(validReference({ page: 2, crop: wholePage }, 4), true)
  assert.equal(validReference({ page: 2, crop: { x: .2, y: .2, width: .3, height: .4 }, quote: 'A source passage' }, 4), true)
  for (const value of [null, {}, {page:5,crop:wholePage}, {page:1.5,crop:wholePage}, {page:1,crop:{...wholePage,x:-.1}}, {page:1,crop:{...wholePage,width:0}}, {page:1,crop:{...wholePage,x:.5}}, {page:1,crop:{...wholePage,y:NaN}}, {page:1,crop:wholePage,quote:'x'.repeat(12001)}]) assert.equal(validReference(value, 4), false)
})
