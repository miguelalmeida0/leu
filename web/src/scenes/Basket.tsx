import { useRef } from 'react'
import { loadImage, useCanvasLoop, useReducedMotion, useTouchScreen } from '../lib/motion'

/* The knitting basket render with a loose strand of yarn running from the needle to the ball.
   The strand is a little rope, as calm as wool: brush past it and it drifts a little, catch it
   (press and drag) and it follows your hand softly, let go and it settles back slowly.
   Keyboard: Enter or Space gives it a small sway. Under reduced motion it hangs still. */

const tip = { x: 0.5535, y: 0.0356 }, ball = { x: 0.662, y: 0.624 }
const N = 26
let basket: HTMLImageElement | undefined
void loadImage('/art/basket.webp').then((i) => { basket = i })

interface P { x: number; y: number; px: number; py: number }

/** Where the strand hangs at rest, swaying a little with time. */
function rest(t: number, w: number, h: number) {
  const sway = Math.sin(t * 0.45) * 0.006 + Math.sin(t * 0.21 + 1.3) * 0.004
  const a = { x: tip.x * w, y: tip.y * h }, d = { x: ball.x * w, y: ball.y * h }
  const b = { x: (tip.x + 0.008 + sway) * w, y: 0.42 * h }, c = { x: (ball.x - 0.07 - sway * 0.6) * w, y: (ball.y + 0.012) * h }
  return Array.from({ length: N }, (_, i) => {
    const s = i / (N - 1), r = 1 - s
    return {
      x: r * r * r * a.x + 3 * r * r * s * b.x + 3 * r * s * s * c.x + s * s * s * d.x,
      y: r * r * r * a.y + 3 * r * r * s * b.y + 3 * r * s * s * c.y + s * s * s * d.y,
    }
  })
}

export function Basket() {
  const canvas = useRef<HTMLCanvasElement>(null)
  const reduced = useReducedMotion()
  const touch = useTouchScreen()
  const rope = useRef<{ pts: P[]; w: number; h: number; seg: number }>({ pts: [], w: 0, h: 0, seg: 0 })
  const hand = useRef<{ x: number; y: number; vx: number; vy: number; svx: number; svy: number; down: boolean; grab: number; inside: boolean }>({ x: 0, y: 0, vx: 0, vy: 0, svx: 0, svy: 0, down: false, grab: -1, inside: false })
  const last = useRef(0)

  useCanvasLoop(canvas, (ctx, w, h, now) => {
    const R = rope.current, H = hand.current
    const t = reduced ? 0 : now
    const target = rest(t, w, h)
    if (R.w !== w || R.h !== h || !R.pts.length) {
      R.pts = target.map((p) => ({ x: p.x, y: p.y, px: p.x, py: p.y }))
      R.w = w; R.h = h
      R.seg = target.reduce((n, p, i) => (i ? n + Math.hypot(p.x - target[i - 1].x, p.y - target[i - 1].y) : 0), 0) / (N - 1)
    }
    const dt = Math.min(0.05, now - (last.current || now)); last.current = now
    const pts = R.pts
    if (!reduced) {
      // A slow draught moves the strand on every screen; a mouse drag still takes priority.
      const calm = Math.max(0, Math.sin(now * 0.42) * Math.sin(now * 0.17 + 1))
      const gust = H.grab < 0 ? (Math.sin(now * 1.53 + 1) * 0.6 + Math.sin(now * 0.66 + 2.1) * 0.4) * 0.5 + calm * calm * 1.6 : 0
      for (let i = 1; i < N - 1; i++) {
        const p = pts[i]
        const vx = (p.x - p.px) * 0.9, vy = (p.y - p.py) * 0.9 // wool in still air: calm, no whip
        p.px = p.x; p.py = p.y
        // A soft, slow pull back toward where the strand hangs, so it always settles.
        p.x += vx + (target[i].x - p.x) * 1.3 * dt
        p.y += vy + (target[i].y - p.y) * 1.3 * dt + 12 * dt * dt
        if (gust) { const s = Math.sin(Math.PI * i / (N - 1)); p.x += gust * w * 0.034 * s * dt; p.y += Math.sin(now * 1.3 + i * 0.4) * gust * h * 0.004 * s * dt }
        // Brushing past it nudges the strand a little the way the pointer drifts.
        if (H.inside && H.grab < 0) {
          const d = Math.hypot(p.x - H.x, p.y - H.y), reach = w * 0.07
          if (d < reach) { const k = (1 - d / reach) ** 3; p.x += H.svx * k * 0.16; p.y += H.svy * k * 0.16 }
        }
      }
      if (H.grab > 0) {
        // The held point follows your hand softly, and the wool only stretches so far.
        const t = target[H.grab], max = w * 0.12
        let gx = H.x - t.x, gy = H.y - t.y
        const len = Math.hypot(gx, gy)
        if (len > max) { const k = max * (1 + Math.log(len / max) * 0.25) / len; gx *= k; gy *= k }
        const p = pts[H.grab]
        p.x += (t.x + gx - p.x) * 0.12; p.y += (t.y + gy - p.y) * 0.12
      }
      // Keep the strand's length (wool has plenty of give), ends pinned to needle and ball.
      for (let k = 0; k < 10; k++) {
        pts[0].x = target[0].x; pts[0].y = target[0].y; pts[N - 1].x = target[N - 1].x; pts[N - 1].y = target[N - 1].y
        for (let i = 0; i < N - 1; i++) {
          const a = pts[i], b = pts[i + 1]
          const dx = b.x - a.x, dy = b.y - a.y, d = Math.hypot(dx, dy) || 1
          const limit = R.seg * 1.32
          if (d <= limit) continue
          const diff = (d - limit) / d / 2
          const ma = i === 0 || i === H.grab ? 0 : 1, mb = i + 1 === N - 1 || i + 1 === H.grab ? 0 : 1
          const sum = ma + mb || 1
          a.x += dx * diff * 2 * (ma / sum); a.y += dy * diff * 2 * (ma / sum)
          b.x -= dx * diff * 2 * (mb / sum); b.y -= dy * diff * 2 * (mb / sum)
        }
      }
      // The pointer's drift, smoothed and capped, so a flick never yanks the yarn.
      const cap = (v: number) => Math.max(-4, Math.min(4, v))
      H.svx += (cap(H.vx) - H.svx) * 0.2; H.svy += (cap(H.vy) - H.svy) * 0.2
      H.vx *= 0.5; H.vy *= 0.5
    } else {
      for (let i = 0; i < N; i++) { pts[i].x = target[i].x; pts[i].y = target[i].y }
    }

    ctx.clearRect(0, 0, w, h)
    if (basket) ctx.drawImage(basket, 0, 0, w, h)
    const path = () => {
      ctx.beginPath()
      ctx.moveTo(pts[0].x, pts[0].y)
      for (let i = 1; i < N - 1; i++) {
        const mx = (pts[i].x + pts[i + 1].x) / 2, my = (pts[i].y + pts[i + 1].y) / 2
        ctx.quadraticCurveTo(pts[i].x, pts[i].y, mx, my)
      }
      ctx.lineTo(pts[N - 1].x, pts[N - 1].y)
    }
    ctx.lineCap = 'round'; ctx.lineJoin = 'round'
    path(); ctx.strokeStyle = '#C98476'; ctx.lineWidth = Math.max(1.6, w * 0.0026); ctx.stroke()
    path(); ctx.strokeStyle = '#EBB5A3'; ctx.lineWidth = Math.max(0.8, w * 0.0012); ctx.stroke()
  }, { fps: touch ? 24 : 60, still: reduced })

  const at = (e: React.PointerEvent<HTMLCanvasElement>) => {
    const r = e.currentTarget.getBoundingClientRect()
    return { x: e.clientX - r.left, y: e.clientY - r.top }
  }
  const nearest = (x: number, y: number) => {
    let best = -1, bestD = Infinity
    rope.current.pts.forEach((p, i) => { const d = Math.hypot(p.x - x, p.y - y); if (i > 0 && i < N - 1 && d < bestD) { bestD = d; best = i } })
    return { index: best, d: bestD }
  }
  const pluck = () => {
    const pts = rope.current.pts, w = rope.current.w
    pts.forEach((p, i) => { if (i > 0 && i < N - 1) { const s = Math.sin((i / (N - 1)) * Math.PI); p.px = p.x - s * w * 0.008 } })
  }

  return (
    <canvas
      ref={canvas}
      className="scene-canvas basket"
      role="img"
      tabIndex={0}
      aria-label="A knitting basket with yarn and a half-finished striped blanket. A loose strand of yarn runs to a ball on the floor; press Enter to give it a pluck."
      style={{ touchAction: 'auto' }}
      onPointerMove={(e) => {
        if (e.pointerType !== 'mouse') return
        const H = hand.current, p = at(e)
        H.vx = p.x - H.x; H.vy = p.y - H.y; H.x = p.x; H.y = p.y; H.inside = true
        const near = nearest(p.x, p.y).d < rope.current.w * 0.03
        e.currentTarget.style.cursor = H.grab > 0 ? 'grabbing' : near ? 'grab' : 'default'
      }}
      onPointerDown={(e) => {
        if (e.pointerType !== 'mouse') return
        const H = hand.current, p = at(e), n = nearest(p.x, p.y)
        H.x = p.x; H.y = p.y; H.vx = 0; H.vy = 0; H.down = true
        if (n.d < rope.current.w * 0.035) { H.grab = n.index; e.currentTarget.setPointerCapture(e.pointerId); e.currentTarget.style.cursor = 'grabbing' }
      }}
      onPointerUp={(e) => { if (e.pointerType !== 'mouse') return; const H = hand.current; H.down = false; H.grab = -1; e.currentTarget.style.cursor = 'grab' }}
      onPointerLeave={() => { const H = hand.current; H.inside = false; if (!H.down) H.grab = -1 }}
      onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); if (!reduced) pluck() } }}
    />
  )
}
