import { useEffect, useRef, type RefObject } from 'react'
import type { Direction } from './types'
import type { ReaderDismissGesture } from './useReaderDismiss'
import { originalScrollGesture } from './originalScrollGesture'

interface Options {
  root: RefObject<HTMLDivElement | null>; track: RefObject<HTMLDivElement | null>
  contextKey: string
  busy: () => boolean; turn: (direction: Direction | 0) => void
  available: (direction: Direction) => boolean; tap: () => void
  sentenceTap: (index: number) => boolean
  dismiss: ReaderDismissGesture
  originalScroll: () => HTMLElement | null
  allowPull: () => boolean
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
    let gesture: { x: number; y: number; at: number; lastX: number; lastAt: number; velocity: number; axis: 'x' | 'y' | null; selecting: boolean; sentence?: number; pan: { x: number; y: number }; scroll: ReturnType<typeof originalScrollGesture>; pullAllowed: boolean; panning?: boolean } | null = null
    let pinch: { distance: number; zoom: number } | null = null
    let pinched = false, wheelLatched = false, wheelTimer: ReturnType<typeof setTimeout> | undefined
    let wheelAxis: 'x' | 'y' | null = null, wheelPull = 0, wheelX = 0, wheelY = 0
    let wheelContext = latest.current.contextKey
    let wheelScroll: ReturnType<typeof originalScrollGesture> = null
    let ignoredClick: { until: number; x: number; y: number } | null = null
    const freshPointer = () => { ignoredClick = null }
    const suppressClick = (event: PointerEvent) => { ignoredClick = { until: performance.now() + 500, x: event.clientX, y: event.clientY } }
    const click = (event: MouseEvent) => {
      // A touch can reveal chrome beneath the pointer before the compatibility
      // click is dispatched. Consume that click before it activates a control.
      if (!event.detail || !ignoredClick || performance.now() > ignoredClick.until || Math.hypot(event.clientX - ignoredClick.x, event.clientY - ignoredClick.y) > 12) return
      ignoredClick = null
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
        current.dismiss.cancel()
        root.dataset.settled = 'false'
        pinch = { distance: distance(), zoom: current.zoom }; pinched = true
        if (current.track.current) current.track.current.style.transform = 'translate3d(0,0,0)'
        return
      }
      if (points.size !== 1) return
      gesture = { x: event.clientX, y: event.clientY, at: performance.now(), lastX: event.clientX,
        lastAt: performance.now(), velocity: 0, axis: null,
        sentence: (event.target as HTMLElement).closest<HTMLElement>('.s')?.dataset.s === undefined ? undefined : Number((event.target as HTMLElement).closest<HTMLElement>('.s')!.dataset.s),
        selecting: event.pointerType === 'mouse' && !!(event.target as HTMLElement).closest('.prose'), pan: current.pan, scroll: originalScrollGesture(current.originalScroll()), pullAllowed: current.allowPull() }
      if (!gesture.selecting) {
        // Margin drags are navigation. Stop mouse selection before its first
        // sub-threshold move; prose and native touch selection stay available.
        if (event.pointerType === 'mouse') event.preventDefault()
        root.setPointerCapture(event.pointerId)
      }
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
      if (!gesture.axis && Math.max(Math.abs(dx), Math.abs(dy)) > 9) {
        if (Math.abs(dx) > Math.abs(dy) * .85) gesture.axis = 'x'
        else if (Math.abs(dy) > Math.abs(dx) * 1.2) gesture.axis = 'y'
      }
      if (!gesture.axis) return
      if (event.cancelable) event.preventDefault()
      if (current.panning) {
        // Zoom owns the whole gesture, even at a pan boundary. Only a reset
        // restores page turns and pull-to-exit.
        gesture.panning = true
        current.onPan({ x: gesture.pan.x + dx, y: gesture.pan.y + dy })
        return
      }
      if (gesture.axis === 'y') {
        if (!gesture.scroll?.(dy) && gesture.pullAllowed) current.dismiss.pull(Math.max(0, dy))
        return
      }
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
        suppressClick(event)
        if (!points.size) { reset(); current.turn(0) }
        return
      }
      const start = gesture
      reset()
      if (!start || selection()) { current.dismiss.cancel(); current.turn(0); return }
      const dx = event.clientX - start.x, dy = event.clientY - start.y
      if (start.panning && Math.hypot(dx, dy) > 7) { suppressClick(event); current.turn(0); return }
      if (start.axis === 'y') {
        suppressClick(event)
        if (start.scroll?.(dy)) current.turn(0)
        else current.dismiss.release(current.dismiss.pull(Math.max(0, dy)))
      } else if (start.axis === 'x') {
        suppressClick(event)
        const fast = performance.now() - start.lastAt < 100 && Math.abs(start.velocity) > .45 && Math.abs(dx) > 24
        const committed = Math.abs(dx) > root.clientWidth * .18 || fast
        const direction: Direction = dx < 0 ? 1 : -1
        current.turn(committed && current.available(direction) ? direction : 0)
      } else {
        root.dataset.settled = 'true'
        if (Math.abs(dx) > 7 || Math.abs(dy) > 7 || performance.now() - start.at > 350) return
        suppressClick(event)
        const x = (event.clientX - root.getBoundingClientRect().left) / root.clientWidth
        if (x < .2 && current.available(-1)) current.turn(-1)
        else if (x > .8 && current.available(1)) current.turn(1)
        else {
          if (start.sentence !== undefined) current.sentenceTap(start.sentence)
          current.tap()
        }
      }
    }
    const resetWheel = () => {
      clearTimeout(wheelTimer)
      wheelAxis = null; wheelPull = 0; wheelX = 0; wheelY = 0; wheelLatched = false; wheelScroll = null
    }
    const cancel = () => {
      const pending = points.size > 0
      reset(); latest.current.dismiss.cancel(); resetWheel()
      if (pending) latest.current.turn(0)
    }
    const wheel = (event: WheelEvent) => {
      if (event.cancelable) event.preventDefault()
      const current = latest.current
      // Gesture listeners must survive a live pinch; only reset wheel state.
      if (wheelContext !== current.contextKey) { resetWheel(); wheelContext = current.contextKey }
      // Desktop trackpad pinch sends ctrl+wheel; it zooms the PDF and never exits.
      if (event.ctrlKey) {
        resetWheel(); current.dismiss.cancel()
        current.onZoom(current.zoom * Math.exp(-event.deltaY / 240))
        return
      }
      if (current.panning) {
        current.onPan({ x: current.pan.x - event.deltaX, y: current.pan.y - event.deltaY })
        return
      }
      if (selection()) return
      const unit = event.deltaMode === WheelEvent.DOM_DELTA_LINE ? 16
        : event.deltaMode === WheelEvent.DOM_DELTA_PAGE ? root.clientHeight : 1
      const dx = (event.shiftKey ? event.deltaY : event.deltaX) * unit
      const dy = (event.shiftKey ? 0 : event.deltaY) * unit
      clearTimeout(wheelTimer)
      wheelTimer = setTimeout(() => {
        if (wheelAxis === 'y' && !wheelLatched) latest.current.dismiss.release(false)
        resetWheel()
      }, 220)
      // Lock intent for the complete trackpad burst, including its momentum.
      // A few pixels of horizontal jitter must not turn an entire source sheet.
      if (current.busy()) return
      wheelX += dx; wheelY += dy
      if (!wheelAxis) {
        if (Math.abs(wheelX) >= 16 && Math.abs(wheelX) > Math.abs(wheelY) * 1.15) wheelAxis = 'x'
        else if (Math.abs(wheelY) >= 16 && Math.abs(wheelY) > Math.abs(wheelX) * 1.2) {
          wheelAxis = 'y'; wheelScroll = originalScrollGesture(current.originalScroll())
        }
      }
      if (wheelLatched) return
      if (wheelAxis === 'y') {
        wheelPull = wheelScroll ? wheelPull + dy : Math.max(0, wheelPull + dy)
        if (wheelScroll?.(-wheelPull)) return
        const distance = wheelScroll ? -wheelPull : wheelPull
        if (current.dismiss.pull(Math.max(0, distance))) { wheelLatched = true; current.dismiss.release(true) }
      } else if (wheelAxis === 'x' && Math.abs(wheelX) >= 48) {
        wheelLatched = true
        const direction: Direction = wheelX > 0 ? 1 : -1
        if (current.available(direction)) current.turn(direction)
      }
    }

    root.addEventListener('pointerdown', down)
    document.addEventListener('pointerdown', freshPointer, true)
    document.addEventListener('click', click, true)
    window.addEventListener('pointermove', move, { passive: false })
    window.addEventListener('pointerup', up)
    window.addEventListener('pointercancel', cancel)
    window.addEventListener('resize', cancel)
    window.addEventListener('blur', cancel)
    root.addEventListener('wheel', wheel, { passive: false })
    return () => {
      clearTimeout(wheelTimer)
      root.removeEventListener('pointerdown', down)
      const removeClickShield = () => {
        document.removeEventListener('pointerdown', freshPointer, true)
        document.removeEventListener('click', click, true)
      }
      // Reduced-motion dismissal can unmount before the compatibility click.
      // Keep only this short-lived shield; a new intentional press clears it.
      if (ignoredClick && ignoredClick.until > performance.now()) setTimeout(removeClickShield, ignoredClick.until - performance.now())
      else removeClickShield()
      window.removeEventListener('pointermove', move)
      window.removeEventListener('pointerup', up)
      window.removeEventListener('pointercancel', cancel)
      window.removeEventListener('resize', cancel)
      window.removeEventListener('blur', cancel)
      root.removeEventListener('wheel', wheel)
    }
  }, [options.root, options.track])
}
