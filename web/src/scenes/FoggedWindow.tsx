import { useRef } from 'react'
import { loadImage, rand, smooth, useCanvasLoop, useReducedMotion } from '../lib/motion'

/* The rainy window over the evening city (a port of FoggedWindow.swift).
   Rain lands on the glass and a few drops slip down it. The pane is fogged; drawing on it with
   the pointer wipes it clear, and about seven seconds after you stop it slowly fogs over again.
   Under reduced motion the rain is still and nothing slides. Coordinates are fractions of the
   pane, and sizes are in design points on a 464-point-wide pane, as on iPad. */

interface Drop { x: number; y: number; r: number }
interface Mover { d: Drop; speed: number; target: number; pause: number; travelled: number; phase: number }
const U = 464

class Glass {
  drops: Drop[] = []
  movers: Mover[] = []
  mask = document.createElement('canvas') // where the pane has been wiped clear
  fog = document.createElement('canvas')
  lastWipe = -Infinity
  lastPoint: { x: number; y: number } | null = null
  nextMover = 0.4
  last = 0
  w = 0; h = 0

  seed(w: number, h: number) {
    this.w = w; this.h = h
    this.mask.width = Math.ceil(w / 2); this.mask.height = Math.ceil(h / 2)
    this.fog.width = Math.ceil(w); this.fog.height = Math.ceil(h)
    this.drops = Array.from({ length: 420 }, () => ({ x: Math.random(), y: Math.random(), r: radius(0.7, 2.8) }))
  }

  advance(now: number, reduced: boolean) {
    const dt = Math.min(0.1, now - (this.last || now)); this.last = now
    if (!reduced && Math.random() < dt * 26) {
      this.drops.push({ x: Math.random(), y: Math.random(), r: radius(0.6, 2.4) })
      if (this.drops.length > 520) this.drops.splice(0, this.drops.length - 520)
    }
    // The fog creeps back seven seconds after the last touch, over about ten seconds.
    const since = performance.now() / 1000 - this.lastWipe
    const m = this.mask.getContext('2d')!
    const fade = since > 7 ? (reduced ? 1 : (1 - Math.exp(-dt / 9)) * smooth((since - 7) / 3) * 2.2) : dt * 0.004
    if (fade > 0) {
      m.globalCompositeOperation = 'destination-out'
      m.fillStyle = `rgba(0,0,0,${Math.min(1, fade)})`
      m.fillRect(0, 0, this.mask.width, this.mask.height)
      m.globalCompositeOperation = 'source-over'
    }
    if (reduced) { this.movers = []; return }
    this.nextMover -= dt
    if (this.nextMover <= 0 && this.movers.length < 14) {
      this.movers.push({ d: { x: rand(0.03, 0.97), y: rand(-0.02, 0.55), r: rand(3.6, 7.4) / U }, speed: 0, target: rand(30, 90), pause: rand(0.2, 1.5), travelled: 0, phase: rand(0, 9) })
      this.nextMover = rand(0.7, 1.8)
    }
    const aspect = this.w / this.h
    for (let i = this.movers.length - 1; i >= 0; i--) {
      const mv = this.movers[i]
      if (mv.pause > 0) { mv.pause -= dt; mv.speed *= 0.9 } else {
        mv.speed += (mv.target * (mv.d.r * U / 6) - mv.speed) * Math.min(1, dt * 2.5)
        if (Math.random() < dt * 0.55) { mv.pause = rand(0.25, 1.4); mv.target = rand(30, 90) }
      }
      const dy = mv.speed * dt / U * aspect
      mv.d.y += dy
      mv.d.x += Math.sin(now * 1.3 + mv.phase) * dt * 3 / U * (mv.speed / 60)
      mv.travelled += dy
      if (mv.travelled > mv.d.r * 1.4 * aspect) {
        mv.travelled = 0
        this.stamp(mv.d.x, mv.d.y, mv.d.r * 2.2, 0.5)
        this.drops.push({ x: mv.d.x, y: mv.d.y - mv.d.r * 1.5 * aspect, r: rand(0.6, 1.3) / U })
        mv.d.r -= 0.035 / U
      }
      if (mv.d.y > 1.03 || mv.d.r * U < 2.4) this.movers.splice(i, 1)
    }
  }

  stamp(x: number, y: number, r: number, strength: number) {
    const m = this.mask.getContext('2d')!, mw = this.mask.width, mh = this.mask.height
    const cx = x * mw, cy = y * mh, rr = r * mw
    const g = m.createRadialGradient(cx, cy, 0, cx, cy, rr)
    g.addColorStop(0, `rgba(0,0,0,${strength})`)
    g.addColorStop(1, 'rgba(0,0,0,0)')
    m.fillStyle = g
    m.fillRect(cx - rr, cy - rr, rr * 2, rr * 2)
  }

  /** Wipes along the pointer's path in small overlapping stamps, so a fast stroke stays continuous. */
  wipe(px: number, py: number) {
    if (!this.w) return
    const from = this.lastPoint ?? { x: px, y: py }
    const steps = Math.max(1, Math.ceil(Math.hypot(px - from.x, py - from.y) / 9))
    for (let s = 1; s <= steps; s++) {
      const t = s / steps
      const x = (from.x + (px - from.x) * t) / this.w, y = (from.y + (py - from.y) * t) / this.h
      this.stamp(x, y, 30 / U, 0.9)
      const reach = 11 / U
      this.drops = this.drops.filter((d) => !(Math.abs(d.x - x) < reach && Math.abs(d.y - y) * this.h / this.w < reach))
    }
    this.lastPoint = { x: px, y: py }
    this.lastWipe = performance.now() / 1000
  }

  wipeBand() {
    this.lastPoint = null
    for (let s = 0; s <= 24; s++) this.wipe(this.w * (0.1 + 0.8 * s / 24), this.h * 0.55)
    this.lastPoint = null
  }
}

function radius(base: number, spread: number) { return (base + Math.random() ** 3 * spread) / U }

function drop(ctx: CanvasRenderingContext2D, d: Drop, w: number, h: number, stretch: number) {
  const r = d.r * w
  if (r <= 0.3) return
  const x = d.x * w, y = d.y * h
  ctx.fillStyle = 'rgba(18,26,18,.26)'
  ctx.beginPath(); ctx.ellipse(x, y + r * 0.18, r, r * stretch, 0, 0, 7); ctx.fill()
  ctx.fillStyle = 'rgba(255,255,255,.13)'
  ctx.beginPath(); ctx.ellipse(x, y, r * 0.88, r * stretch * 0.88, 0, 0, 7); ctx.fill()
  ctx.fillStyle = 'rgba(255,255,255,.6)'
  ctx.beginPath(); ctx.ellipse(x - r * 0.33, y - r * 0.42 * stretch, Math.max(0.35, r * 0.2), Math.max(0.3, r * 0.14), 0, 0, 7); ctx.fill()
}

export function FoggedWindow() {
  const canvas = useRef<HTMLCanvasElement>(null)
  const glass = useRef<Glass | null>(null)
  const art = useRef<{ clear?: HTMLImageElement; fog?: HTMLImageElement }>({})
  const reduced = useReducedMotion()
  if (!art.current.clear) {
    void loadImage('/art/window-clear.webp').then((i) => { art.current.clear = i })
    void loadImage('/art/window-fog.webp').then((i) => { art.current.fog = i })
  }

  useCanvasLoop(canvas, (ctx, w, h, t) => {
    const g = (glass.current ??= new Glass())
    if (g.w !== w || g.h !== h) g.seed(w, h)
    g.advance(t, reduced)
    const { clear, fog } = art.current
    ctx.clearRect(0, 0, w, h)
    if (clear) cover(ctx, clear, w, h)
    if (fog) {
      const f = g.fog.getContext('2d')!
      f.globalCompositeOperation = 'source-over'
      f.clearRect(0, 0, g.fog.width, g.fog.height)
      cover(f, fog, g.fog.width, g.fog.height)
      f.globalCompositeOperation = 'destination-out'
      f.drawImage(g.mask, 0, 0, g.fog.width, g.fog.height)
      ctx.drawImage(g.fog, 0, 0, w, h)
    }
    for (const d of g.drops) drop(ctx, d, w, h, 1)
    for (const m of g.movers) drop(ctx, m.d, w, h, 1.14)
    // Warm lamplight from the room, falling across the top-left of the pane.
    const lamp = ctx.createRadialGradient(w * 0.09, h * 0.1, 4, w * 0.09, h * 0.1, w * 1.1)
    lamp.addColorStop(0, 'rgba(255,226,160,.22)'); lamp.addColorStop(1, 'rgba(255,226,160,0)')
    ctx.fillStyle = lamp
    ctx.fillRect(0, 0, w, h)
  }, { fps: reduced ? 2 : 30 })

  const point = (e: React.PointerEvent<HTMLCanvasElement>) => {
    const r = e.currentTarget.getBoundingClientRect()
    glass.current?.wipe(e.clientX - r.left, e.clientY - r.top)
  }
  const lift = () => { if (glass.current) glass.current.lastPoint = null }

  return (
    <canvas
      ref={canvas}
      className="scene-canvas"
      role="img"
      aria-label="A rainy window over the city at night. Move the pointer over the fogged glass to wipe it clear; it slowly fogs up again."
      tabIndex={0}
      onPointerMove={point}
      onPointerDown={point}
      onPointerLeave={lift}
      onPointerUp={lift}
      onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); glass.current?.wipeBand() } }}
      style={{ touchAction: 'none', cursor: 'crosshair' }}
    />
  )
}

/** Draws an image to fill a box, cropping like `object-fit: cover`. */
export function cover(ctx: CanvasRenderingContext2D, img: HTMLImageElement, w: number, h: number) {
  const s = Math.max(w / img.width, h / img.height)
  const iw = img.width * s, ih = img.height * s
  ctx.drawImage(img, (w - iw) / 2, (h - ih) / 2, iw, ih)
}
