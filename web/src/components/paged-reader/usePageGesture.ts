import { useEffect, useRef, type RefObject } from 'react'
import type { Direction } from './types'

interface Options {
  root: RefObject<HTMLDivElement | null>; track: RefObject<HTMLDivElement | null>
  busy: () => boolean; turn: (direction: Direction | 0) => void
  available: (direction: Direction) => boolean; tap: () => void
  sentenceTap: (index: number) => boolean
  zoom: number; onZoom: (zoom: number) => void; panning: boolean
  pan: { x: number; y: number }; onPan: (pan: { x: number; y: number }) => void
}

/** Own the touch gesture before Safari can turn a diagonal swipe into page pan. */
export function usePageGesture(options: Options) {
  const latest = useRef(options)
  latest.current = options
  useEffect(() => {
    const root = options.root.current
    if (!root) return
    const points = new Map<number, { x: number; y: number }>()
    let gesture: { x: number; y: number; at: number; lastX: number; lastAt: number; velocity: number; horizontal: boolean; selecting: boolean; sentence?: number; pan: { x: number; y: number } } | null = null
    let pinch: { distance: number; zoom: number } | null = null
    let pinched = false, wheelLatched = false, wheelTimer: ReturnType<typeof setTimeout> | undefined
    let ignoreClickUntil = 0
    const suppressClick = () => { ignoreClickUntil = performance.now() + 500 }
    const click = (event: MouseEvent) => {
      // A touch can reveal chrome beneath the pointer before the compatibility
      // click is dispatched. Consume that click before it activates a control.
      if (!event.detail || performance.now() > ignoreClickUntil) return
      ignoreClickUntil = 0
      event.preventDefault(); event.stopImmediatePropagation()
    }
    const distance = () => {
      const [a, b] = [...points.values()]
      return a && b ? Math.hypot(a.x - b.x, a.y - b.y) : 0
    }
    const selection = () => !!window.getSelection()?.toString().trim()
    const reset = () => { points.clear(); gesture = null; pinch = null; pinched = false }
    const down = (event: PointerEvent) => {
      const current = latest.current
      if (current.busy() || (event.target as HTMLElement).closest('button, a, input, textarea, [contenteditable]') || selection()) return
      points.set(event.pointerId, { x: event.clientX, y: event.clientY })
      root.dataset.settled = 'false'
      if (points.size === 2) {
        pinch = { distance: distance(), zoom: current.zoom }; pinched = true
        if (current.track.current) current.track.current.style.transform = 'translate3d(0,0,0)'
        return
      }
      if (points.size !== 1) return
      gesture = { x: event.clientX, y: event.clientY, at: performance.now(), lastX: event.clientX,
        lastAt: performance.now(), velocity: 0, horizontal: false,
        sentence: (event.target as HTMLElement).closest<HTMLElement>('.s')?.dataset.s === undefined ? undefined : Number((event.target as HTMLElement).closest<HTMLElement>('.s')!.dataset.s),
        selecting: event.pointerType === 'mouse' && !!(event.target as HTMLElement).closest('.prose'), pan: current.pan }
      if (!gesture.selecting) root.setPointerCapture(event.pointerId)
    }
    const move = (event: PointerEvent) => {
      if (!points.has(event.pointerId)) return
      points.set(event.pointerId, { x: event.clientX, y: event.clientY })
      const current = latest.current
      if (pinch && points.size >= 2) {
        if (event.cancelable) event.preventDefault()
        if (pinch.distance) current.onZoom(pinch.zoom * distance() / pinch.distance)
        return
      }
      if (!gesture || pinched || gesture.selecting || selection()) return
      const dx = event.clientX - gesture.x, dy = event.clientY - gesture.y
      if (current.panning) {
        if (event.cancelable) event.preventDefault()
        current.onPan({ x: gesture.pan.x + dx, y: gesture.pan.y + dy })
        return
      }
      if (!gesture.horizontal && Math.abs(dx) > 7 && Math.abs(dx) > Math.abs(dy) * .85) gesture.horizontal = true
      if (!gesture.horizontal) return
      if (event.cancelable) event.preventDefault()
      const now = performance.now(), elapsed = now - gesture.lastAt
      if (elapsed > 0) gesture.velocity = (event.clientX - gesture.lastX) / elapsed
      gesture.lastX = event.clientX; gesture.lastAt = now
      const direction: Direction = dx < 0 ? 1 : -1
      const offset = current.available(direction) ? dx : dx * .2
      if (current.track.current) current.track.current.style.transform = `translate3d(${offset}px, 0, 0)`
    }
    const up = (event: PointerEvent) => {
      if (!points.has(event.pointerId)) return
      const current = latest.current
      points.delete(event.pointerId)
      if (pinched) {
        suppressClick()
        if (!points.size) { reset(); current.turn(0) }
        return
      }
      const start = gesture
      reset()
      if (!start || selection()) { current.turn(0); return }
      const dx = event.clientX - start.x, dy = event.clientY - start.y
      if (current.panning && Math.hypot(dx, dy) > 7) { suppressClick(); current.turn(0); return }
      if (start.horizontal) {
        suppressClick()
        const fast = performance.now() - start.lastAt < 100 && Math.abs(start.velocity) > .45 && Math.abs(dx) > 24
        const committed = Math.abs(dx) > root.clientWidth * .18 || fast
        const direction: Direction = dx < 0 ? 1 : -1
        current.turn(committed && current.available(direction) ? direction : 0)
      } else {
        root.dataset.settled = 'true'
        if (Math.abs(dx) > 7 || Math.abs(dy) > 7 || performance.now() - start.at > 350) return
        suppressClick()
        const x = (event.clientX - root.getBoundingClientRect().left) / root.clientWidth
        if (x < .2 && current.available(-1)) current.turn(-1)
        else if (x > .8 && current.available(1)) current.turn(1)
        else {
          if (start.sentence !== undefined) current.sentenceTap(start.sentence)
          current.tap()
        }
      }
    }
    const cancel = () => { if (points.size) { reset(); latest.current.turn(0) } }
    const wheel = (event: WheelEvent) => {
      if (event.cancelable) event.preventDefault()
      if (latest.current.panning) {
        latest.current.onPan({ x: latest.current.pan.x - event.deltaX, y: latest.current.pan.y - event.deltaY })
        return
      }
      const delta = event.shiftKey ? event.deltaY : event.deltaX
      if (Math.abs(delta) < 3 || (!event.shiftKey && Math.abs(delta) < Math.abs(event.deltaY))) return
      clearTimeout(wheelTimer)
      wheelTimer = setTimeout(() => { wheelLatched = false }, 180)
      if (wheelLatched || latest.current.busy()) return
      wheelLatched = true
      const direction: Direction = delta > 0 ? 1 : -1
      if (latest.current.available(direction)) latest.current.turn(direction)
    }
    root.addEventListener('pointerdown', down)
    document.addEventListener('click', click, true)
    window.addEventListener('pointermove', move, { passive: false })
    window.addEventListener('pointerup', up)
    window.addEventListener('pointercancel', cancel)
    root.addEventListener('wheel', wheel, { passive: false })
    return () => {
      clearTimeout(wheelTimer)
      root.removeEventListener('pointerdown', down)
      document.removeEventListener('click', click, true)
      window.removeEventListener('pointermove', move)
      window.removeEventListener('pointerup', up)
      window.removeEventListener('pointercancel', cancel)
      root.removeEventListener('wheel', wheel)
    }
  }, [options.root, options.track])
}
