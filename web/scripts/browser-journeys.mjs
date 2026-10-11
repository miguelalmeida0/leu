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
  await locator.waitFor({ s¶»§q«^