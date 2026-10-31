import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const source = async (path) => readFile(new URL('../' + path, import.meta.url), 'utf8')
const contrast = (foreground, background) => {
  const luminance = (hex) => {
    const channels = [1, 3, 5].map((index) => parseInt(hex.slice(index, index + 2), 16) / 255)
      .map((value) => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4)
    return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
  }
  const [high, low] = [luminance(foreground), luminance(background)].sort((a, b) => b - a)
  return (high + 0.05) / (low + 0.05)
}

test('all book-cover metadata color pairs pass 4.5:1', async () => {
  const store = await source('src/lib/store.ts')
  const colors = [...store.matchAll(/\w+: \{ bg: '(#[A-Fa-f0-9]{6})', fg: '(#[A-Fa-f0-9]{6})', muted: '(#[A-Fa-f0-9]{6})' \}/g)]
  assert.equal(colors.length, 7, 'cover all seven named book palettes')
  for (const [, background, foreground, muted] of colors) {
    assert.ok(contrast(foreground, background) >= 4.5, `foreground ${foreground} on ${background}`)
    assert.ok(contrast(muted, background) >= 4.5, `metadata ${muted} on ${background}`)
  }
})

test('choice popovers expose disclosure and native button semantics', async () => {
  const study = await source('src/screens/Study.tsx')
  assert.match(study, /aria-expanded=\{open\} aria-controls=\{popupId\}/)
  assert.match(study, /role="group" aria-label=\{label\}/)
  assert.match(study, /aria-pressed=\{o\.id === value\}/)
  assert.doesNotMatch(study, /role="listbox"|role="option"/)
  assert.match(study, /ArrowUp.*ArrowDown.*Home.*End/)
  assert.match(study, /triggerRef\.current\?\.focus\(\)/)
})

test('reader modes are tab-accessible toggle buttons, not incomplete radio widgets', async () => {
  const reader = await source('src/screens/Reader.tsx')
  assert.match(reader, /role="group" aria-label="How to show the page"/)
  assert.match(reader, /aria-pressed=\{mode === 'rebuilt'\}/)
  assert.match(reader, /aria-pressed=\{mode === 'original'\}/)
  assert.doesNotMatch(reader, /role="radiogroup"|role="radio"/)
  assert.match(reader, /Choose For reading to access the extracted text/)
})

test('route changes restore semantic focus without stealing first-load focus', async () => {
  const app = await source('src/App.tsx')
  assert.match(app, /previousRoute\.current !== null/)
  assert.match(app, /mainRef\.current\?\.focus\(\{ preventScroll: true \}\)/)
  assert.match(app, /<main id="main" ref=\{mainRef\} tabIndex=\{-1\}/)
})

test('felt text and artwork captions have opaque AA contrast', async () => {
  const css = await source('src/tokens.css') + await source('src/styles.css')
  const token = (name) => css.match(new RegExp(`--${name}: (#[A-Fa-f0-9]{6})`))[1]
  for (const foreground of ['eyebrow-felt', 'secondary', 'ink']) {
    assert.ok(contrast(token(foreground), token('felt')) >= 4.5, `${foreground} must pass on felt`)
  }
  assert.doesNotMatch(css.match(/@keyframes fadeIn \{[^\n]+/)[0], /opacity:/,
    'Text entrances must not temporarily reduce contrast')
  assert.match(css, /transition-duration: 0s !important/,
    'Reduced motion must not introduce transitions on normally immediate focus styles')
})

test('production CSP allows local workers and all static previews use same-origin scripts', async () => {
  const config = JSON.parse(await source('vercel.json'))
  const policy = config.headers[0].headers.find(({ key }) => key === 'Content-Security-Policy').value
  assert.match(policy, /worker-src 'self' blob:/)
  assert.match(policy, /script-src 'self' blob: 'wasm-unsafe-eval'/)
  assert.doesNotMatch(policy.match(/script-src[^;]+/)[0], /'unsafe-inline'|'unsafe-eval'/)
  for (const page of ['quiet-weather', 'afterglow', 'material-rhythm']) {
    const html = await source(`public/motion/${page}.html`)
    assert.doesNotMatch(html, /<script\s*>/)
    assert.match(html, /<script src="\.\/motion\.js"><\/script>/)
  }
})
