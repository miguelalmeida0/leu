/** Lock a vertical gesture to scrolling if it starts within the PDF or moves up.
 * Reaching the top during that gesture must never hand it over to dismissal. */
export function originalScrollGesture(area: HTMLElement | null): ((distance: number) => boolean) | null {
  if (!area) return null
  const top = area.scrollTop
  let scrolling: boolean | undefined
  return (distance) => {
    scrolling ??= top > 0 || distance < 0
    if (!scrolling) return false
    area.scrollTop = top - distance
    return true
  }
}
