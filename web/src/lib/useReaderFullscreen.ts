import { useCallback, useLayoutEffect, useRef, useState } from 'react'

/** Native fullscreen when available; the same viewport reader works on iOS. */
export function useReaderFullscreen() {
  const [immersive, setImmersive] = useState(false)
  const reader = useRef<HTMLDivElement>(null)
  const active = useRef(false)
  const ownsNative = useRef(false)
  const previousScroll = useRef(0)
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
    const htmlOverflow = document.documentElement.style.overflow
    const background = [...document.querySelectorAll<HTMLElement>('.topbar, .skip')]
      .map((element) => ({ element, inert: element.inert }))
    document.documentElement.style.overflow = 'hidden'
    Object.assign(document.body.style, { position: 'fixed', top: `-${previousScroll.current}px`, width: '100%', overflow: 'hidden' })
    background.forEach(({ element }) => { element.inert = true })
    reader.current?.querySelector<HTMLElement>('.reader-focus-toggle')?.focus({ preventScroll: true })

    const nativeChanged = () => {
      if (ownsNative.current && !document.fullscreenElement) exit()
    }
    const containFocus = (event: KeyboardEvent) => {
      if (event.key !== 'Tab' || document.querySelector('.scrim')) return
      const controls = [...reader.current!.querySelectorAll<HTMLElement>('a[href], button:not(:disabled), input:not(:disabled), [tabindex="0"]')]
        .filter((element) => element.getClientRects().length > 0)
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
      document.body.style.cssText = bodyStyle
      document.documentElement.style.overflow = htmlOverflow
      background.forEach(({ element, inert }) => { element.inert = inert })
      window.scrollTo(0, previousScroll.current)
      previousFocus.current?.focus({ preventScroll: true })
      active.current = false
      if (ownsNative.current && document.fullscreenElement) void document.exitFullscreen().catch(() => {})
      ownsNative.current = false
    }
  }, [immersive, exit])

  return { immersive, reader, toggle, exit }
}
