import { useLayoutEffect, type RefObject } from 'react'

/** Keep document content clear of the tools without repaginating on every tap. */
export function useReaderChromeInsets(reader: RefObject<HTMLDivElement | null>, immersive: boolean) {
  useLayoutEffect(() => {
    const shell = reader.current
    if (!shell) return
    const bar = shell.querySelector<HTMLElement>('.reader-bar')
    const foot = shell.querySelector<HTMLElement>('.reader-foot')
    if (!bar || !foot) return
    const measure = () => {
      shell.style.setProperty('--reader-chrome-top', `${Math.ceil(bar.getBoundingClientRect().height)}px`)
      shell.style.setProperty('--reader-chrome-bottom', `${Math.max(64, Math.ceil(foot.getBoundingClientRect().height))}px`)
      shell.style.setProperty('--reader-foot-height', `${Math.ceil(foot.getBoundingClientRect().height)}px`)
    }
    const observer = new ResizeObserver(measure)
    observer.observe(bar)
    observer.observe(foot)
    measure()
    return () => {
      observer.disconnect()
      shell.style.removeProperty('--reader-chrome-top')
      shell.style.removeProperty('--reader-chrome-bottom')
      shell.style.removeProperty('--reader-foot-height')
    }
  }, [reader, immersive])
}
