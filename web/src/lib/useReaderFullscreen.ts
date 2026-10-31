import { useCallback, useLayoutEffect, useRef, useState } from 'react'

/** Native fullscreen when available; the same viewport reader works on iOS. */
export function useReaderFullscreen(positionKey: string) {
  const [immersive, setImmersive] = useState(false)
  const reader = useRef<HTMLDivElement>(null)
  const active = useRef(false)
  const ownsNative = useRef(false)
  const previousScroll = useRef(0)
  const previousReaderScroll = useRef(0)
  const enteredPosition = useRef(positionKey)
  const currentPosition = useRef(positionKey)
  currentPosition.current = positionKey
  const previousFocus = useRef<HTMLElement | null>(null)

  const exit = useCallback(() => {
    active.current = false
    setImmersive(false)
    if (ownsNative.current && document.fullscreenElement) {
      void document.exitFullscreen().catch(() => {})
    }
    ownsNative.current = false
  }, [])

  const toggle = useCallback(() => {
    if (active.current) { exit(); return }
    previousScroll.current = window.scrollY
    previousReaderScroll.current = reader.current?.querySelector<HTMLElement>('.reader-grid')?.scrollTop ?? 0
    enteredPosition.current = currentPosition.current
    previousFocus.current = document.activeElement as HTMLElement | null
    active.current = true
    setImmersive(true)
    // Invoke inside the click gesture, before effects or asynchronous work.
    if (document.fullscreenEnabled && !document.fullscreenElement) {
      void document.documentElement.requestFullscreen({ navigationUI: 'hide' }).then(() => {
        ownsNative.current = true
        if (!active.current) exit()
      }).catch(() => { /* iPhone and embedded browsers retain the CSS reader. */ })
    }
  }, [exit])

  useLayoutEffect(() => {
    if (!immersive) return
    const bodyStyle = document.body.style.cssText
    const html = document.documentElement
    const htmlOverflow = html.style.overflow
    const htmlOverscroll = html.style.overscrollBehavior
    const theme = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]')
    const themeColor = theme?.content
    const shell = reader.current
    const viewport = window.visualViewport
    const fit = () => {
      if (!shell) return
      shell.style.setProperty('--reader-viewport-top', `${viewport?.offsetTop ?? 0}px`)
      shell.style.setProperty('--reader-viewport-left', `${viewport?.offsetLeft ?? 0}px`)
      shell.style.setProperty('--reader-viewport-width', `${viewport?.width ?? innerWidth}px`)
      shell.style.setProperty('--reader-viewport-height', `${viewport?.height ?? innerHeight}px`)
    }
    const background = [...document.querySelectorAll<HTMLElement>('.topbar, .skip')]
      .map((element) => ({ element, inert: element.inert }))
    html.style.overflow = 'hidden'
    html.style.overscrollBehavior = 'none'
    Object.assign(document.body.style, { position: 'fixed', top: `-${previousScroll.current}px`, width: '100%', overflow: 'hidden', overscrollBehavior: 'none', background: '#FBF8F2' })
    if (theme) theme.content = '#FBF8F2'
    fit()
    viewport?.addEventListener('resize', fit)
    viewport?.addEventListener('scroll', fit)
    window.addEventListener('resize', fit)
    background.forEach(({ element }) => { element.inert = true })
    ;(shell?.querySelector<HTMLElement>('.paged-reader') ?? shell)?.focus({ preventScroll: true })

    const nativeChanged = () => {
      if (ownsNative.current && !document.fullscreenElement) exit()
    }
    const containFocus = (event: KeyboardEvent) => {
      if (event.key !== 'Tab' || document.querySelector('.scrim')) return
      const controls = [...reader.current!.querySelectorAll<HTMLElement>('a[href], button:not(:disabled), input:not(:disabled), [tabindex="0"]')]
        .filter((element) => !element.closest('[inert]') && element.getClientRects().length > 0 && getComputedStyle(element).visibility !== 'hidden')
      const first = controls[0], last = controls.at(-1)
      if (event.shiftKey && (document.activeElement === first || !reader.current?.contains(document.activeElement))) {
        event.preventDefault(); last?.focus()
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault(); first?.focus()
      }
    }
    document.addEventListener('fullscreenchange', nativeChanged)
    document.addEventListener('keydown', containFocus)
    return () => {
      document.removeEventListener('fullscreenchange', nativeChanged)
      document.removeEventListener('keydown', containFocus)
      viewport?.removeEventListener('resize', fit)
      viewport?.removeEventListener('scroll', fit)
      window.removeEventListener('resize', fit)
      for (const name of ['top', 'left', 'width', 'height']) shell?.style.removeProperty(`--reader-viewport-${name}`)
      document.body.style.cssText = bodyStyle
      html.style.overflow = htmlOverflow
      html.style.overscrollBehavior = htmlOverscroll
      if (theme && themeColor !== undefined) theme.content = themeColor
      background.forEach(({ element, inert }) => { element.inert = inert })
      window.scrollTo(0, previousScroll.current)
      const grid = shell?.querySelector<HTMLElement>('.reader-grid')
      if (grid) grid.scrollTop = enteredPosition.current === currentPosition.current ? previousReaderScroll.current : 0
      previousFocus.current?.focus({ preventScroll: true })
      active.current = false
      if (ownsNative.current && document.fullscreenElement) void document.exitFullscreen().catch(() => {})
      ownsNative.current = false
    }
  }, [immersive, exit])

  return { immersive, reader, toggle, exit }
}
