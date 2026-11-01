import { useLayoutEffect, useState, type RefObject } from 'react'

type Refs = {
  header: RefObject<HTMLElement | null>
  wordmark: RefObject<HTMLAnchorElement | null>
  navigation: RefObject<HTMLElement | null>
  search: RefObject<HTMLButtonElement | null>
}

// Measure the real labels with their computed styles, even while the compact menu is shown.
// A temporary off-flow clone avoids permanently duplicating navigation or changing tab order.
function intrinsicWidth(header: HTMLElement, source: HTMLElement, search = false) {
  const probe = source.cloneNode(true) as HTMLElement
  probe.setAttribute('aria-hidden', 'true')
  probe.querySelectorAll('[id]').forEach((node) => node.removeAttribute('id'))
  Object.assign(probe.style, {
    position: 'absolute', top: '0', left: '0', display: search ? 'inline-flex' : 'block',
    width: 'max-content', maxWidth: 'none', height: 'auto', overflow: 'visible',
    visibility: 'hidden', pointerEvents: 'none', whiteSpace: 'nowrap',
  })
  if (search) probe.querySelectorAll('span, kbd').forEach((node) => {
    (node as HTMLElement).style.display = 'inline'
  })
  header.appendChild(probe)
  const width = probe.getBoundingClientRect().width
  probe.remove()
  return width
}

export function useResponsiveTopbar(refs: Refs) {
  const [compact, setCompact] = useState(() => typeof window !== 'undefined' && window.matchMedia('(max-width: 760px)').matches)

  useLayoutEffect(() => {
    const header = refs.header.current
    const wordmark = refs.wordmark.current
    const navigation = refs.navigation.current
    const search = refs.search.current
    if (!header || !wordmark || !navigation || !search) return
    let frame = 0
    let active = true

    const measure = () => {
      if (!active) return
      const width = header.getBoundingClientRect().width
      if (window.matchMedia('(max-width: 760px)').matches) { setCompact(true); return }
      const style = getComputedStyle(header)
      const padding = parseFloat(style.paddingLeft) + parseFloat(style.paddingRight)
      const gap = parseFloat(style.columnGap) || 0
      const linksWidth = intrinsicWidth(header, navigation)
      // Between 761 and 1100px the search is intentionally an icon-only control.
      const searchWidth = window.matchMedia('(max-width: 1100px)').matches ? 44 : intrinsicWidth(header, search, true)
      const side = Math.max(wordmark.getBoundingClientRect().width, searchWidth)
      setCompact(linksWidth + 2 * side + 2 * gap + 8 > width - padding)
    }
    const schedule = () => {
      if (!active) return
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(measure)
    }
    const resize = new ResizeObserver(schedule)
    for (const node of [header, wordmark, navigation, search]) resize.observe(node)
    const changes = new MutationObserver(schedule)
    const options: MutationObserverInit = { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ['style', 'class'] }
    changes.observe(navigation, options)
    changes.observe(search, options)
    changes.observe(wordmark, options)
    window.addEventListener('resize', schedule)
    void document.fonts?.ready.then(schedule)
    measure()
    return () => {
      active = false
      cancelAnimationFrame(frame)
      resize.disconnect()
      changes.disconnect()
      window.removeEventListener('resize', schedule)
    }
  }, [refs.header, refs.wordmark, refs.navigation, refs.search])

  return compact
}
