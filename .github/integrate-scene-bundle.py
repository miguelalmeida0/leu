"""One-time, hash-guarded integration of supplied bundle 10a9c77491988ed2137e7425c35f1c182f32014a.
The local candidate was compiled and its running-rain algorithm tested before transfer.
Only the named source files change; current mobile reader, storage and voice code stay intact.
"""
from pathlib import Path
import hashlib

expected = {
    'web/src/components/Dock.tsx': ('10864c9996880b157a6f37ebe46dbf67d798f767', 'dea13d8427f8b8841cf2ae27c1fdb73cec69370d'),
    'web/src/lib/motion.ts': ('b554c5c23d4eb961eb0391b05679ccebbea61be3', '7d827fb9b084a93aafb13ca0d882ebf837cab665'),
    'web/src/scenes/Basket.tsx': ('b7b2ab1e72a51accc0d6e61a30ba23e7de4d6d0b', '0f6692e88369c09246fb507e1c34959f09d3efab'),
    'web/src/scenes/FoggedWindow.tsx': ('788647ba5d4c110a977f6c22df2bef98c314aada', '928a7779a8d03929d8a2b38a3f74cfc8a2c101cc'),
    'web/src/scenes/SnowGlobe.tsx': ('07defb9a862107d79967c7ef3310912f6dc6081a', '601af206750e3994af4cab0f020c0c635ddf4040'),
    'web/src/scenes/TeaSteam.tsx': ('a0935a90a7a4c623414210570c54e41d42d9cbfe', 'e69d755f2f7491585ab8f2a80931c21c382d34e0'),
    '.github/workflows/web-browser-journeys.yml': ('d8f03d1f52df0db6019a887913644fc05429cc43', '17e48df65447503dc15969c8835951e9e2cdd6f6'),
}
def oid(text):
    data = text.encode()
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
source = {name: Path(name).read_text() for name in expected}
for name, (before, after) in expected.items():
    assert oid(source[name]) == before, 'Concurrent source change, refusing to overwrite: ' + name

def replace(name, old, new):
    assert source[name].count(old) == 1, 'Non-unique patch in ' + name + ': ' + old[:80]
    source[name] = source[name].replace(old, new)

p = 'web/src/lib/motion.ts'
replace(p, '/** Images, loaded once and shared between scenes. */', '''/** Touch screens: no hover, and a finger on a canvas usually scrolls the page. The scenes
    play on their own there instead of waiting for a pointer. */
export function useTouchScreen(): boolean {
  const query = '(hover: none), (pointer: coarse)'
  const [touch, setTouch] = useState(() => matchMedia(query).matches)
  useEffect(() => {
    const q = matchMedia(query)
    const on = () => setTouch(q.matches)
    q.addEventListener('change', on)
    return () => q.removeEventListener('change', on)
  }, [])
  return touch
}

/** Images, loaded once and shared between scenes. */''')

for name in ['Basket', 'FoggedWindow', 'SnowGlobe']:
    p = 'web/src/scenes/' + name + '.tsx'
    replace(p, "useReducedMotion } from '../lib/motion'", "useReducedMotion, useTouchScreen } from '../lib/motion'")
    replace(p, '  const reduced = useReducedMotion()', '  const reduced = useReducedMotion()\n  const touch = useTouchScreen()')

p = 'web/src/scenes/Basket.tsx'
replace(p, '''    if (!reduced) {
      for (let i = 1; i < N - 1; i++) {''', '''    if (!reduced) {
      // A slow draught moves the strand on every screen; a mouse drag still takes priority.
      const calm = Math.max(0, Math.sin(now * 0.42) * Math.sin(now * 0.17 + 1))
      const gust = H.grab < 0 ? (Math.sin(now * 1.53 + 1) * 0.6 + Math.sin(now * 0.66 + 2.1) * 0.4) * 0.5 + calm * calm * 1.6 : 0
      for (let i = 1; i < N - 1; i++) {''')
replace(p, '        p.y += vy + (target[i].y - p.y) * 1.3 * dt + 12 * dt * dt', '''        p.y += vy + (target[i].y - p.y) * 1.3 * dt + 12 * dt * dt
        if (gust) { const s = Math.sin(Math.PI * i / (N - 1)); p.x += gust * w * 0.034 * s * dt; p.y += Math.sin(now * 1.3 + i * 0.4) * gust * h * 0.004 * s * dt }''')
replace(p, "fps: matchMedia('(pointer: coarse)').matches ? 24 : 60", 'fps: touch ? 24 : 60')

p = 'web/src/scenes/FoggedWindow.tsx'
replace(p, '  advance(now: number, reduced: boolean) {', '''  /** Rain clears its own trails while the scene is idle, on touch and desktop. */
  running = false

  advance(now: number, reduced: boolean) {''')
replace(p, '    const fade = since > 7 ?', '    const fade = this.running && !reduced ? 1 - Math.exp(-dt / 2.4) : since > 7 ?')
replace(p, '''    if (this.nextMover <= 0 && this.movers.length < 14) {
      this.movers.push({ d: { x: rand(0.03, 0.97), y: rand(-0.02, 0.55), r: rand(3.6, 7.4) / U }, speed: 0, target: rand(30, 90), pause: rand(0.2, 1.5), travelled: 0, phase: rand(0, 9) })
      this.nextMover = rand(0.7, 1.8)''', '''    const many = this.running
    if (this.nextMover <= 0 && this.movers.length < (many ? 20 : 14)) {
      this.movers.push({ d: { x: rand(0.03, 0.97), y: rand(-0.02, many ? 0.45 : 0.55), r: rand(many ? 4.6 : 3.6, many ? 8.4 : 7.4) / U }, speed: 0, target: rand(30, 90), pause: rand(0.2, many ? 1.2 : 1.5), travelled: 0, phase: rand(0, 9) })
      this.nextMover = many ? rand(0.35, 0.9) : rand(0.7, 1.8)''')
replace(p, '      mv.travelled += dy', '''      mv.travelled += dy
      if (many) {
        // A running drop clears a trail through the fog, which fills in again behind it.
        this.stamp(mv.d.x, mv.d.y, mv.d.r * 1.25, 0.5)
        const reach = mv.d.r * 1.4
        this.drops = this.drops.filter((d) => !(Math.abs(d.x - mv.d.x) < reach && Math.abs(d.y - mv.d.y) * this.h / this.w < reach))
      }''')
replace(p, '    g.advance(t, reduced)', '    g.running = touch || g.lastPoint === null\n    g.advance(t, reduced)')
replace(p, "fps: reduced ? 2 : matchMedia('(pointer: coarse)').matches ? 22 : 30", 'fps: reduced ? 2 : touch ? 22 : 30')

p = 'web/src/scenes/SnowGlobe.tsx'
replace(p, '  const first = useRef(true)', '''  const first = useRef(true)
  const replay = useRef({ stage: -1, cycle: -1 })
  const litRef = useRef(lit)
  litRef.current = lit''')
replace(p, '''    const s = snow.current
    s.advance(now, reduced)''', '''    const s = snow.current
    if (!reduced && s.pointer === null) {
      // When idle on any screen, every 20 seconds the windows go down and light again,
      // one by one, up to the ones you have earned. With none earned yet the snow still swirls.
      const t = now % 20, cycle = Math.floor(now / 20), earned = litRef.current
      const stage = t < 2 ? 0 : t < 5.5 ? 1 : t < 9 ? 2 : t < 16 ? 3 : 0
      const r = replay.current
      if (stage !== r.stage || s.target !== Math.min(stage, earned)) {
        r.stage = stage
        if (earned === 0 && stage === 1 && cycle !== r.cycle) { r.cycle = cycle; s.kick(centre.x, centre.y, false) }
        s.light(Math.min(stage, earned), false)
      }
    }
    s.advance(now, reduced)''')
replace(p, "fps: matchMedia('(pointer: coarse)').matches ? 22 : 30", 'fps: touch ? 22 : 30')
replace(p, '        const p = toArt(e); snow.current.stir(p.x, p.y)', '        if (snow.current.pointer === null) snow.current.light(litRef.current, false)\n        const p = toArt(e); snow.current.stir(p.x, p.y)')

p = 'web/src/scenes/TeaSteam.tsx'
replace(p, '  useCanvasLoop(canvas, (ctx, w, h, now) => {', '  useCanvasLoop(canvas, (ctx, w, h, now) => {\n    if (reduced) { ctx.clearRect(0, 0, w, h); return }')
replace(p, "  }, { fps: matchMedia('(pointer: coarse)').matches ? 20 : 30 })", "  }, { fps: matchMedia('(pointer: coarse)').matches ? 20 : 30, still: reduced })")

p = 'web/src/components/Dock.tsx'
replace(p, "import { useEffect, useRef, useState } from 'react'", "import { useEffect, useRef, useState } from 'react'\nimport './DockMotion.css'")
replace(p, '''          <span className="dock-avatar" aria-hidden="true">{mobileSpeech ? '♪' : name[0]}</span>''', '''          <span className={`dock-avatar${playing ? ' speaking' : ''}`} aria-hidden="true">
            {[10, 18, 13, 7].map((height, i) => <i key={i} style={{ height, animationDelay: `${i * -0.35}s` }} />)}
          </span>''')

p = '.github/workflows/web-browser-journeys.yml'
replace(p, 'run: node scripts/browser-journeys.mjs', 'run: |\n          node scripts/browser-journeys.mjs\n          node scripts/scene-journeys.mjs')

for name, (before, after) in expected.items():
    assert oid(source[name]) == after, 'Transferred candidate differs from local verified version: ' + name + ' ' + oid(source[name])
for name, content in source.items():
    Path(name).write_text(content)
    print('Integrated', name, oid(content))
