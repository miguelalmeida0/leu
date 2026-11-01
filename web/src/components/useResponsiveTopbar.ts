import { useLayoutEffect, useState, type RefObject } from 'react'

type Refs = {
  header: RefObject<HTMLElement | null>
  wordmark: RefObject<HTMLAnchorElement | null>
  navigation: RefObject<HTMLElement | null>
  search: RefObject<HTMLButtonElement | null>
}

/** Measure the actual nav labels even when the mobile disclosure is shown.
 * The hidden clone never enters the tab order or affects the header's layout. */
function contentWidth(header: HTMLElement, element: HTMLElement) {
  const probe = element.cloneNode(true) as HTMLElement
  probe.setAttribute('aria-hidden', 'true')
  probe.querySelectorAll('[id]').forEach((node) => node.removeAttribute('id'))
  Object.assign(probe.style, {
    display: 'block', position: 'absolute', top: '0', left: '0',
    width: 'max-content', maxWidth: 'none', height: 'auto',
    visibility: 'hidden', pointerEvents: 'none', whiteSpace: 'nowrap',
  })
  header.appendChild(probe)
  const width = probe.getBoundingClientRect().width
  probe.remove()
  return width
}

/** Keep the six centered links on medium and wide screens. Fall back to the
 * accessible disclosure only when the labels genuinely cannot fit. */
export function useResponsiveTopbar(refs: Refs) {
  const [compact, setCompact] = useState(
    () => typeof window !== 'undefined' && matchMedia('(max-width: 700px)').matches,
  )
  useLayoutEffect(() => {
    const header = refs.header.current
    const title = refs.wordmark.current
    const navigation = refs.navigation.current
    const search = refs.search.current
    if (!header || !title || !navigation || !search) return
    let active = true
    let frame = 0

    const measure = () => {
      if (!active) return
      if (matchMedia('(max-width: 700px)').matches) { setCompact(true); return }
      const css = getComputedStyle(header)
      const horizontalPadding = parseFloat(css.paddingLeft) + parseFloat(css.paddingRight)
      const gap = parseFloat(css.columnGap) || 0
      const navWidth = contentWidth(header, navigation)
      const side = Math.max(title.getBoundingClientRect().width, search.getBoundingClientRect().width)
      setCompact(navWidth + 2 * side + 2 * gap + 8 > header.clientWidth - horizontalPadding)
    }
    const schedule = () => {
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(measure)
    }
    const resize = new ResizeObserver(schedule)
    for (const el of [header, title, navigation, search]) resize.observe(el)
    const mutation = new MutationObserver(measure)
    for (const el of [title, navigation, search]) {
      mutation.observe(el, { childList: true, subtree: true, characterData: true })
    }
    window.addEventListener('resize', schedule)
    void document.fonts?.ready.then(schedule)
    measure()
    return () => {
      active = false
      cancelAnimationFrame(frame)
      resize.disconnect()
      mutation.disconnect()
      window.removeEventListener('resize', schedule)
    }
  }, [refs.header, refs.wordmark, refs.navigation, refs.search])
  return compact
}
