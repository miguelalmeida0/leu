// One spatial transition for a focused reading surface. The clone is inert,
// so the real Dock remains mounted with unchanged playback, seek and settings.
export interface DockFlight { ghost: HTMLElement; first: DOMRect }
export function captureDockFlight(dock: HTMLElement | null): DockFlight | null {
  if (!dock || typeof dock.animate !== 'function' || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return null
  const first = dock.getBoundingClientRect()
  if (first.width <= 0 || first.height <= 0 || first.bottom < 0 || first.top > innerHeight) return null
  const ghost = dock.cloneNode(true) as HTMLElement
  ghost.classList.add('reader-dock-flight')
  ghost.setAttribute('aria-hidden', 'true')
  ghost.setAttribute('inert', '')
  Object.assign(ghost.style, {
    position: 'fixed', left: first.left + 'px', top: first.top + 'px',
    width: first.width + 'px', height: first.height + 'px',
    transformOrigin: 'top left', pointerEvents: 'none',
  })
  document.body.appendChild(ghost)
  return { ghost, first }
}
export function completeDockFlight(flight: DockFlight, dock: HTMLElement | null, focused: boolean): () => void {
  if (!dock || !dock.isConnected) { flight.ghost.remove(); return () => {} }
  const last = dock.getBoundingClientRect()
  if (!last.width || !last.height || !dock.animate) { flight.ghost.remove(); return () => {} }
  const duration = focused ? 440 : 380
  const easing = 'cubic-bezier(.16, 1, .3, 1)'
  const dx = last.left - flight.first.left
¶»§q«^