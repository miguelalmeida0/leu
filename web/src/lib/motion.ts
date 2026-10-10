import { useContext, useEffect, useRef, useState, type RefObject } from 'react'
import { SceneMotionOverride } from './sceneMotion'

export function useReducedMotion(): boolean {
  const sceneOverride = useContext(SceneMotionOverride)
  const [reduced, setReduced] = useState(() => matchMedia('(prefers-reduced-motion: reduce)').matches)
  useEffect(() => {
    const q = matchMedia('(prefers-reduced-motion: reduce)')
    const on = () => setReduced(q.matches)
    q.addEventListener('change', on)
    return () => q.removeEventListener('change', on)
  }, [])
  return sceneOverride ?? reduced
}

/** Touch screens: no hover, and a finger on a canvas usually scrolls the page. The scenes
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

/** Images, loaded once and shared between scenes. */
const images = new Map<string, Promise<HTMLImageElement>>()
export function loadImage(src: string): Promise<HTMLImageElement> {
  if (!images.has(src)) {
    images.set(src, new Promise((resolve, reject) => {
      const img = new Image()
      img.decoding = 'async'
      img.onload = () => resolve(img)
      img.onerror = reject
      img.src = src
    }))
  }
  return images.get(src)!
}

/**
 * A canvas that redraws every frame at the element's real size and pixel density. `draw`
 * gets the context in CSS pixels. The loop sleeps while the canvas is off screen or the
 * tab is hidden, and runs at most `fps` frames a second.
 */
export function useCanvasLoop(
  canvas: RefObject<HTMLCanvasElement | null>,
  draw: (ctx: CanvasRenderingContext2D, w: number, h: number, t: number) => void,
  { fps = 30, still = false }: { fps?: number; still?: boolean } = {},
) {
  const drawRef = useRef(draw)
  drawRef.current = draw
  useEffect(() => {
    const el = canvas.current
    if (!el) return
    const ctx = el.getContext('2d')!
    let frame = 0, last = 0, visible = true, w = 0, h = 0
    const resize = () => {
      const r = el.getBoundingClientRect(), dpr = Math.min(window.devicePixelRatio || 1, 2)
      w = r.width; h = r.height
      el.width = Math.max(1, Math.round(w * dpr)); el.height = Math.max(1, Math.round(h * dpr))
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
      if (still) drawRef.current(ctx, w, h, performance.now() / 1000)
    }
    const ro = new ResizeObserver(resize)
    ro.observe(el)
    const io = new IntersectionObserver(([e]) => { visible = e.isIntersecting })
    io.observe(el)
    resize()
    const tick = (now: number) => {
      frame = requestAnimationFrame(tick)
      if (!visible || document.hidden || now - last < 1000 / fps - 2) return
      last = now
      if (w > 0 && h > 0) drawRef.current(ctx, w, h, now / 1000)
    }
    if (!still) frame = requestAnimationFrame(tick)
    else { const id = setInterval(() => w > 0 && drawRef.current(ctx, w, h, performance.now() / 1000), 500); return () => { clearInterval(id); ro.disconnect(); io.disconnect() } }
    return () => { cancelAnimationFrame(frame); ro.disconnect(); io.disconnect() }
  }, [canvas, fps, still])
}

export const smooth = (x: number) => { const t = Math.min(Math.max(x, 0), 1); return t * t * (3 - 2 * t) }
export const rand = (a: number, b: number) => a + Math.random() * (b - a)
