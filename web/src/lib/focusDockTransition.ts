// A visual-only FLIP transition. The mounted Dock owns the actual playback.
export interface DockFlight { ghost: HTMLElement; first: DOMRect }
export function captureDockFlight(dock: HTMLElement | null): DockFlight | null {
  if (!dock || typeof dock.animate !== 'function' || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return null
  const first = dock.getBoundingClientRect()
  if (first.width < 1 || first.height < 1 || first.bottom < 0 || first.top > window.innerHeight) return null
  const ghost = dock.cloneNode(true) as HTMLElement
  ghost.classList.add('reader-dock-flight')
  ghost.setAttribute('aria-hidden', 'true')
  ghost.setAttribute('inert', '')
  Object.assign(ghost.style, {
    position: 'fixed', left: first.left + 'px', top: first.top + 'px',
    width: first.width + 'px', height: first.height + 'px',
    transformOrigin: 'top left', pointerEvents: 'none', zIndex: '120',
  })
  document.body.appendChild(ghost)
  return { ghost, first }
}
export function completeDockFlight(flight: DockFlight, dock: HTMLElement | null, focused: boolean): () => void {
  if (!dock || !dock.isConnected || typeof dock.animate !== 'function') { flight.ghost.remove(); return () => {} }
  const last = dock.getBoundingClientRect()
  if (last.width < 1 || last.height < 1) { flight.ghost.remove(); return () => {} }
  const dx = last.left - flight.first.left
  const dy = last.top - flight.first.top
  const sx = last.width / flight.first.width
  const sy = last.height / flight.first.height
  const previousVisibility = dock.style.visibility
  dock.style.visibility = 'hidden'
  const animation = flight.ghost.animate([
    { transform: 'translate(0, 0) scale(1, 1)', opacity: 1 },
    { transform: `translate(${dx}px, ${dy}px) scale(${sx}, ${sy})`, opacity: focused ? 0.25 : 0.45 },
  ], { duration: focused ? 440 : 380, easing: 'cubic-bezier(.16, 1, .3, 1)', fill: 'forwards' })
  let finished = false
  const finish = () => {
    if (finished) return
    finished = true
    dock.style.visibility = previousVisibility
    flight.ghost.remove()
  }
  void animation.finished.then(finish, finish)
  return () => { animation.cancel(); finish() }
}
