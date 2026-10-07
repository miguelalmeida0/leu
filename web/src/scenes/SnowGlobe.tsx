import { useEffect, useRef } from 'react'
import { loadImage, useCanvasLoop, useReducedMotion } from '../lib/motion'

/* A snow globe with a cottage inside (SnowGlobe.swift + GlobeSnow.swift). Each idea you get
   across lights one of its three windows; the third glows in slowly and gives the water a little
   swirl. The globe, cottage and base are a Blender render; snow, window light and glow are drawn
   live, projected with the render's own camera matrix. Move across the glass to stir the snow;
   click it (or press Enter) to give it a gentle shake. */

const ART = { w: 1155, h: 855 }
const crop = { x: 238, y: 77 }
const centre = { x: 512, y: 315.07 }, R = 301.25 * 0.985
const litRect = { x: 317, y: 190, w: 382, h: 262 }
const panes = [{ x: 440, y: 352, w: 29.5, h: 32.5 }, { x: 493, y: 353.5, w: 29, h: 31.5 }, { x: 547, y: 356, w: 29, h: 31 }]
const radius = 0.1, cz = 0.138

interface Flake { x: number; y: number; z: number; vx: number; vy: number; vz: number; size: number; phase: number; alpha: number; settle: number }

function project(x: number, y: number, z: number) {
  const w = -0.1557 * x + 1.2842 * y - 0.4242 * z + 1
  return { x: (2698.82 * x + 1304.43 * y - 318.13 * z + 750) / w - crop.x, y: (33.72 * x - 278.2 * y - 2892.87 * z + 768.34) / w - crop.y, depth: w }
}
function ground(r: number) {
  const p = [[0, 0.112], [0.03, 0.11], [0.055, 0.103], [0.068, 0.093], [0.072, 0.08]]
  for (let i = 1; i < p.length; i++) if (r <= p[i][0]) return p[i - 1][1] + (p[i][1] - p[i - 1][1]) * (r - p[i - 1][0]) / (p[i][0] - p[i - 1][0])
  return p[p.length - 1][1]
}
const inHouse = (x: number, y: number, z: number) => Math.abs(x) < 0.033 && Math.abs(y - 0.008) < 0.026 && z < 0.162 && z > 0.1
const noise = (t: number, s: number) => Math.sin(t * 1.7 + s) * 0.6 + Math.sin(t * 0.73 + s * 2.1) * 0.4
const smooth = (x: number) => x * x * (3 - 2 * x)
const clamp = (x: number) => Math.min(Math.max(x, 0), 1)
const u = (a: number, b: number) => a + Math.random() * (b - a)

function spawn(anywhere: boolean): Flake {
  const r = radius * 0.86
  let x, y, z
  do {
    x = u(-1, 1) * r; y = u(-1, 1) * r
    z = cz + (anywhere ? u(-1, 1) : u(0.35, 0.9)) * r
  } while (Math.hypot(x, y, z - cz) > r || z < ground(Math.hypot(x, y)) + 0.004)
  return { x, y, z, vx: 0, vy: 0, vz: 0, size: u(0.55, 1.45), phase: u(0, 30), alpha: anywhere ? 1 : 0, settle: 0 }
}

class Snow {
  flakes = Array.from({ length: 170 }, () => spawn(true))
  target = 0; shown = 0; swirl = 0; now = 0; last = 0
  pointer: { x: number; y: number } | null = null
  push = { dx: 0, dy: 0 }

  light(n: number, reduced: boolean) {
    const next = Math.min(Math.max(n, 0), 3)
    if (next > this.target && !reduced) this.swirl = 1
    this.target = next
    if (reduced) this.shown = next
  }
  stir(x: number, y: number) {
    if (this.pointer) this.push = { dx: Math.max(-40, Math.min(40, x - this.pointer.x)), dy: Math.max(-40, Math.min(40, y - this.pointer.y)) }
    this.pointer = { x, y }
  }
  advance(time: number, reduced: boolean) {
    const dt = Math.min(Math.max(time - (this.last || time), 0), 1 / 15)
    this.last = time; this.now = time
    if (reduced) { this.shown = this.target; this.swirl = 0; return }
    this.push.dx *= Math.exp(-dt * 3); this.push.dy *= Math.exp(-dt * 3)
    this.swirl = Math.max(0, this.swirl - dt * 0.22)
    this.shown = this.shown < this.target ? Math.min(this.target, this.shown + dt / 2.6) : Math.max(this.target, this.shown - dt / 1.2)
    const spin = this.swirl * this.swirl
    for (let i = 0; i < this.flakes.length; i++) {
      const f = this.flakes[i]
      if (f.settle > 0) {
        f.settle += dt; f.alpha = Math.max(0, 1 - f.settle / 1.6)
        if (f.settle > 1.6) this.flakes[i] = spawn(false)
        continue
      }
      f.alpha = Math.min(1, f.alpha + dt / 1.2)
      const n1 = noise(this.now * 0.25 + f.phase, f.phase), n2 = noise(this.now * 0.25 + f.phase + 40, f.phase * 1.3)
      f.vx += (n1 * 0.004 - f.y * 1.6 * spin - f.vx * 1.4) * dt
      f.vy += (n2 * 0.004 + f.x * 1.6 * spin - f.vy * 1.4) * dt
      f.vz += (-0.0055 - f.vz * 1.4 + spin * 0.016 * (1 - (f.z - cz) / radius)) * dt
      if (this.pointer) {
        const q = project(f.x, f.y, f.z), d = Math.hypot(q.x - this.pointer.x, q.y - this.pointer.y)
        if (d < 80) { const k = (1 - d / 80) ** 2 * 0.00006; f.vx += this.push.dx * k; f.vz -= this.push.dy * k }
      }
      f.x += f.vx * dt; f.y += f.vy * dt; f.z += f.vz * dt
      const dist = Math.hypot(f.x, f.y, f.z - cz)
      if (dist > radius * 0.9) {
        const k = radius * 0.9 / dist
        f.x *= k; f.y *= k; f.z = cz + (f.z - cz) * k; f.vx *= -0.3; f.vy *= -0.3
      }
      if (f.z < ground(Math.hypot(f.x, f.y)) + 0.002 || inHouse(f.x, f.y, f.z)) f.settle = 0.001
    }
  }
}

const art: { base?: HTMLImageElement; interior?: HTMLImageElement; lit?: HTMLImageElement } = {}
void loadImage('/art/globe-base.webp').then((i) => { art.base = i })
void loadImage('/art/globe-interior.webp').then((i) => { art.interior = i })
void loadImage('/art/globe-lit.webp').then((i) => { art.lit = i })

function flake(ctx: CanvasRenderingContext2D, f: Flake, k: number, now: number, reduced: boolean) {
  const q = project(f.x, f.y, f.z)
  const r = f.size * 2.5 * (1.25 - q.depth * 0.25) * k
  const a = f.alpha * (reduced ? 0.75 : 0.55 + 0.35 * Math.sin(now * 0.7 + f.phase))
  if (a <= 0.02 || r <= 0.2) return
  const x = q.x * k, y = q.y * k
  ctx.fillStyle = `rgba(255,255,255,${a * 0.3})`
  ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.fill()
  ctx.fillStyle = `rgba(255,255,255,${a * 0.9})`
  ctx.beginPath(); ctx.arc(x, y, r * 0.45, 0, 7); ctx.fill()
}

export function SnowGlobe({ lit, label }: { lit: number; label?: string }) {
  const canvas = useRef<HTMLCanvasElement>(null)
  const snow = useRef(new Snow())
  const back = useRef(document.createElement('canvas'))
  const reduced = useReducedMotion()
  const first = useRef(true)

  useEffect(() => {
    if (first.current) { snow.current.target = snow.current.shown = lit; first.current = false }
    else snow.current.light(lit, reduced)
  }, [lit, reduced])

  useCanvasLoop(canvas, (ctx, w, h, now) => {
    const s = snow.current
    s.advance(now, reduced)
    const k = w / ART.w
    ctx.clearRect(0, 0, w, h)
    if (!art.base || !art.interior || !art.lit) return
    ctx.drawImage(art.base, 0, 0, w, h)
    ctx.save()
    ctx.beginPath(); ctx.arc(centre.x * k, centre.y * k, R * k, 0, Math.PI * 2); ctx.clip()
    // Snow behind the cottage, hidden wherever the cottage, trees and hill stand.
    const b = back.current, dpr = ctx.getTransform().a
    if (b.width !== ctx.canvas.width || b.height !== ctx.canvas.height) { b.width = ctx.canvas.width; b.height = ctx.canvas.height }
    const bc = b.getContext('2d')!
    bc.setTransform(dpr, 0, 0, dpr, 0, 0)
    bc.globalCompositeOperation = 'source-over'
    bc.clearRect(0, 0, w, h)
    for (const f of s.flakes) if (f.y > 0.006) flake(bc, f, k, s.now, reduced)
    bc.globalCompositeOperation = 'destination-out'
    bc.drawImage(art.interior, 0, 0, w, h)
    ctx.drawImage(b, 0, 0, w, h)
    // The first two windows are lit in the render: dark glass covers them until earned.
    for (let i = 0; i < 2; i++) {
      const dark = clamp(i + 1 - s.shown)
      if (dark <= 0) continue
      const p = panes[i]
      ctx.globalAlpha = dark
      ctx.fillStyle = '#2C2A2D'
      ctx.beginPath(); ctx.roundRect(p.x * k, p.y * k, p.w * k, p.h * k, 1.5 * k); ctx.fill()
      ctx.strokeStyle = '#E2D6BE'; ctx.lineWidth = 2.7 * k
      ctx.beginPath()
      ctx.moveTo((p.x + p.w / 2) * k, p.y * k); ctx.lineTo((p.x + p.w / 2) * k, (p.y + p.h) * k)
      ctx.moveTo(p.x * k, (p.y + p.h / 2) * k); ctx.lineTo((p.x + p.w) * k, (p.y + p.h / 2) * k)
      ctx.stroke()
      ctx.globalAlpha = 1
    }
    const third = smooth(clamp(s.shown - 2))
    if (third > 0) { ctx.globalAlpha = third; ctx.drawImage(art.lit, litRect.x * k, litRect.y * k, litRect.w * k, litRect.h * k); ctx.globalAlpha = 1 }
    // A soft breathing glow in every lit window.
    ctx.globalCompositeOperation = 'lighter'
    panes.forEach((p, i) => {
      const on = smooth(clamp(s.shown - i))
      if (on <= 0) return
      const t = s.now
      const flicker = reduced ? 0.85 : 0.75 + 0.25 * Math.sin(t * (1.1 + i * 0.23) + i * 2) * Math.sin(t * 0.37 + i)
      const bloom = i === 2 ? 1.6 * (1 - Math.abs(on * 2 - 1)) : 0
      const r = 25.9 * (2.4 + bloom) * k, cx = (p.x + p.w / 2) * k, cy = (p.y + p.h / 2) * k
      const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
      g.addColorStop(0, `rgba(255,205,120,${0.22 * on * flicker})`); g.addColorStop(1, 'rgba(255,205,120,0)')
      ctx.fillStyle = g
      ctx.fillRect(cx - r, cy - r, r * 2, r * 2)
    })
    ctx.globalCompositeOperation = 'source-over'
    for (const f of s.flakes) if (f.y <= 0.006) flake(ctx, f, k, s.now, reduced)
    ctx.restore()
  })

  const toArt = (e: React.PointerEvent<HTMLCanvasElement>) => {
    const r = e.currentTarget.getBoundingClientRect(), k = r.width / ART.w
    return { x: (e.clientX - r.left) / k, y: (e.clientY - r.top) / k }
  }
  const down = useRef<{ x: number; y: number } | null>(null)
  const value = lit === 0 ? 'No windows lit yet' : lit === 3 ? 'All three windows lit' : `${lit} of 3 windows lit`

  return (
    <canvas
      ref={canvas}
      className="scene-canvas globe"
      role="img"
      tabIndex={0}
      aria-label={`${label ?? 'A snow globe with a little cottage inside'}. ${value}. Each idea you get across lights a window. Press Enter to shake it.`}
      style={{ aspectRatio: `${ART.w} / ${ART.h}`, touchAction: 'none' }}
      onPointerMove={(e) => { const p = toArt(e); snow.current.stir(p.x, p.y) }}
      onPointerLeave={() => { snow.current.pointer = null }}
      onPointerDown={(e) => { down.current = { x: e.clientX, y: e.clientY } }}
      onPointerUp={(e) => {
        const d = down.current
        if (d && Math.hypot(e.clientX - d.x, e.clientY - d.y) < 6 && !reduced) snow.current.swirl = 1
        down.current = null
      }}
      onKeyDown={(e) => { if ((e.key === 'Enter' || e.key === ' ') && !reduced) { e.preventDefault(); snow.current.swirl = 1 } }}
    />
  )
}
