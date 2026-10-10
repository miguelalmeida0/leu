import { useRef } from 'react'
import { rand, smooth, useCanvasLoop, useReducedMotion } from '../lib/motion'

/* Steam from the cup (a port of TeaSteam.swift): wisps born at the rim rise, lean with a slow
   draft, curl, widen and thin out. Decorative, so hidden from assistive tech. The canvas is
   laid out in design points (260 × 220) with the rim at (130, 212). */

interface Wisp { born: number; life: number; x0: number; lean: number; phase: number; curl: number; width: number }

export function TeaSteam() {
  const canvas = useRef<HTMLCanvasElement>(null)
  const wisps = useRef<Wisp[]>([])
  const next = useRef(0)
  const reduced = useReducedMotion()

  useCanvasLoop(canvas, (ctx, w, h, now) => {
    const k = w / 260, rimR = 9
    if (now > next.current) {
      wisps.current.push({ born: now, life: reduced ? 9 : rand(6.2, 7.8), x0: rand(-1, 1) * rimR * 0.7, lean: rand(-1, 1) * 16 + 8, phase: rand(0, 9), curl: rand(0.8, 1.4), width: rand(0.8, 1.3) })
      next.current = now + (reduced ? 3.2 : rand(1.25, 1.85))
    }
    wisps.current = wisps.current.filter((x) => (now - x.born) / x.life < 1)
    ctx.clearRect(0, 0, w, h)
    ctx.save(); ctx.scale(k, k)
    const t = now * (reduced ? 0.3 : 1), tall = 150
    for (const wisp of wisps.current) {
      const age = (now - wisp.born) / wisp.life
      const head = smooth(age * 1.25) * tall
      const envelope = smooth(age / 0.12) * (1 - smooth((age - 0.45) / 0.55))
      for (let step = 0; step < 28; step++) {
        const f = step / 27, y = head * f
        if (y < 1) continue
        const rise = y / tall
        const drift = wisp.lean * rise * rise + Math.sin(t * 0.35 + wisp.phase) * 6 * rise
        const curl = (Math.sin(rise * 5.5 * wisp.curl - t + wisp.phase) * 17 + Math.sin(rise * 2.6 - t * 0.4 + wisp.phase * 1.7) * 14) * rise ** 0.95
        const x = 130 + wisp.x0 * (1 - rise) + drift + curl
        const yy = 212 - 4 - y
        const r = (3.5 + 15.5 * rise ** 0.9) * wisp.width
        const alpha = envelope * Math.sin(Math.PI * Math.min(1, f * 1.05)) * smooth(rise / 0.12) * (1 - rise * 0.6) * 0.2
        if (alpha <= 0.003) continue
        const g = ctx.createRadialGradient(x, yy, 0, x, yy, r)
        g.addColorStop(0, `rgba(255,253,248,${alpha})`)
        g.addColorStop(0.35, `rgba(255,253,248,${alpha * 0.55})`)
        g.addColorStop(1, 'rgba(255,253,248,0)')
        ctx.fillStyle = g
        ctx.fillRect(x - r, yy - r, r * 2, r * 2)
      }
    }
    ctx.restore()
  }, { fps: matchMedia('(pointer: coarse)').matches ? 20 : 30 })

  return <canvas ref={canvas} className="scene-canvas" aria-hidden="true" style={{ pointerEvents: 'none' }} />
}
