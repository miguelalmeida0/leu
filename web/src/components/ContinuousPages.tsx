import { forwardRef, memo, useEffect, useImperativeHandle, useLayoutEffect, useRef, useState, type RefObject } from 'react'
import { pageBlocks, pdfDeadline, renderPage, type Block, type PDFDocumentProxy } from '../lib/pdf'
import { Prose } from './Prose'

export interface ContinuousPagesHandle { scrollToPage: (page: number) => void }
interface Props {
  doc: PDFDocumentProxy
  page: number
  mode: 'rebuilt' | 'original'
  zoom: number
  title: string
  activePaper: RefObject<HTMLElement | null>
  reading: boolean
  marked?: Set<number>
  onSeek: (index: number) => void
  onPageChange: (page: number) => void
}

/** Keep page geometry in the document; only nearby pages own text/canvases. */
export const ContinuousPages = forwardRef<ContinuousPagesHandle, Props>(function ContinuousPages(props, ref) {
  const pages = useRef<HTMLDivElement>(null)
  const initialPage = useRef(props.page)
  const latest = useRef(props)
  const anchor = useRef({ page: props.page, offset: 0 })
  const scrollPosition = useRef(0)
  const scrollOriginPage = useRef<number | null>(null)
  const userScrolling = useRef(false)
  const scrollFrame = useRef(0)
  latest.current = props
  const jump = (page: number) => {
    userScrolling.current = false
    cancelAnimationFrame(scrollFrame.current)
    scrollFrame.current = 0
    const scroller = pages.current?.parentElement
    const target = pages.current?.children[page - 1]
    if (scroller && target) {
      scroller.scrollTo({ top: scroller.scrollTop + target.getBoundingClientRect().top - scroller.getBoundingClientRect().top, behavior: 'instant' })
      anchor.current = { page, offset: target.getBoundingClientRect().top - scroller.getBoundingClientRect().top }
      scrollPosition.current = scroller.scrollTop
    }
  }
  useImperativeHandle(ref, () => ({ scrollToPage: jump }), [])
  useLayoutEffect(() => {
    const scroller = pages.current!.parentElement!
    const size = () => pages.current?.style.setProperty('--reader-page-height', `${scroller.clientHeight}px`)
    size()
    jump(initialPage.current)
    const observer = new ResizeObserver(size)
    observer.observe(scroller)
    return () => observer.disconnect()
  }, [])
  useLayoutEffect(() => {
    if (scrollOriginPage.current === props.page) scrollOriginPage.current = null
    else jump(props.page)
  }, [props.page])
  useLayoutEffect(() => { jump(latest.current.page) }, [props.mode])

  // Safari does not anchor lazy document content consistently. Keep the same
  // visible page offset when an earlier page finishes rendering or changes size.
  useLayoutEffect(() => {
    const scroller = pages.current!.parentElement!
    const observer = new ResizeObserver(() => {
      const target = pages.current?.children[anchor.current.page - 1]
      if (!target) return
      const offset = target.getBoundingClientRect().top - scroller.getBoundingClientRect().top
      scroller.scrollTop += offset - anchor.current.offset
      scrollPosition.current = scroller.scrollTop
    })
    for (const page of pages.current!.children) observer.observe(page)
    return () => observer.disconnect()
  }, [])

  useEffect(() => {
    const scroller = pages.current?.parentElement
    if (!scroller) return
    const update = () => {
      scrollFrame.current = 0
      if (!userScrolling.current) return
      const children = pages.current!.children
      const line = scroller.getBoundingClientRect().top + Math.min(120, scroller.clientHeight * .2)
      // Binary search avoids measuring every page in a long book on each scroll.
      let low = 0, high = children.length - 1
      while (low < high) {
        const mid = Math.ceil((low + high) / 2)
        if (children[mid].getBoundingClientRect().top <= line) low = mid
        else high = mid - 1
      }
      anchor.current = { page: low + 1, offset: children[low].getBoundingClientRect().top - scroller.getBoundingClientRect().top }
      if (low + 1 !== latest.current.page) {
        scrollOriginPage.current = low + 1
        latest.current.onPageChange(low + 1)
      }
    }
    const onScroll = () => {
      const delta = scroller.scrollTop - scrollPosition.current
      if (Math.abs(delta) < .5) return
      if (userScrolling.current) anchor.current.offset -= delta
      scrollPosition.current = scroller.scrollTop
      if (!userScrolling.current) return
      // Resize observers settle lazy-page geometry before the active-page read.
      if (!scrollFrame.current) scrollFrame.current = requestAnimationFrame(() => { scrollFrame.current = requestAnimationFrame(update) })
    }
    const wheel = () => { userScrolling.current = true }
    const touch = (event: TouchEvent) => { userScrolling.current = event.touches.length === 1 }
    const key = (event: KeyboardEvent) => {
      if (document.querySelector('.scrim') || (event.target as HTMLElement).closest('input, textarea, [contenteditable]')) return
      if (['PageDown', 'PageUp', 'ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) userScrolling.current = true
    }
    scroller.addEventListener('scroll', onScroll, { passive: true })
    scroller.addEventListener('wheel', wheel, { passive: true })
    scroller.addEventListener('touchstart', touch, { passive: true })
    scroller.addEventListener('pointerdown', wheel, { passive: true })
    window.addEventListener('keydown', key, true)
    return () => {
      scroller.removeEventListener('scroll', onScroll)
      scroller.removeEventListener('wheel', wheel)
      scroller.removeEventListener('touchstart', touch)
      scroller.removeEventListener('pointerdown', wheel)
      window.removeEventListener('keydown', key, true)
      cancelAnimationFrame(scrollFrame.current)
    }
  }, [])

  return <div className="continuous-pages" ref={pages}>
    {Array.from({ length: props.doc.numPages }, (_, index) => {
      const page = index + 1
      const active = page === props.page
      return <ContinuousPage key={page} doc={props.doc} number={page} mode={props.mode} zoom={props.zoom}
        title={props.title} active={active} activePaper={props.activePaper}
        reading={active && props.reading} marked={active ? props.marked : undefined} onSeek={props.onSeek}
        initiallyNear={Math.abs(page - initialPage.current) <= 1} />
    })}
  </div>
})

const ContinuousPage = memo(function ContinuousPage({ doc, number, active, initiallyNear, activePaper, mode, zoom, title, reading, marked, onSeek }: Omit<Props, 'page' | 'onPageChange'> & {
  number: number; active: boolean; initiallyNear: boolean
}) {
  const element = useRef<HTMLElement>(null)
  const canvas = useRef<HTMLCanvasElement>(null)
  const stage = useRef<HTMLDivElement>(null)
  const queue = useRef<Promise<void>>(Promise.resolve())
  const measuredHeight = useRef(900)
  const [near, setNear] = useState(initiallyNear)
  const [blocks, setBlocks] = useState<Block[] | null>(null)
  const [textError, setTextError] = useState('')
  const [renderError, setRenderError] = useState('')
  const [width, setWidth] = useState(0)

  useLayoutEffect(() => { if (active) activePaper.current = element.current }, [active, activePaper])
  useEffect(() => {
    const paper = element.current!
    const observer = new IntersectionObserver(([entry]) => {
      if (!entry.isIntersecting && paper.offsetHeight) measuredHeight.current = paper.offsetHeight
      setNear(entry.isIntersecting)
    }, { root: paper.closest('.reader-grid'), rootMargin: '100% 0px' })
    observer.observe(paper)
    return () => observer.disconnect()
  }, [])

  useEffect(() => {
    if (!near || mode !== 'rebuilt' || blocks !== null) return
    let live = true
    setTextError('')
    void pdfDeadline(pageBlocks(doc, number), 12000)
      .then((value) => { if (live) setBlocks(value) })
      .catch(() => { if (live) setTextError('This page could not be read. Try Original page.') })
    return () => { live = false }
  }, [doc, number, near, mode, blocks])

  useEffect(() => {
    const target = stage.current
    if (!near || mode !== 'original' || !target) return
    const observer = new ResizeObserver(() => setWidth(Math.round(target.clientWidth)))
    observer.observe(target)
    return () => observer.disconnect()
  }, [near, mode])

  useEffect(() => {
    const target = canvas.current
    if (!near || mode !== 'original' || !target || !width) return
    let live = true
    setRenderError('')
    const work = queue.current.catch(() => {}).then(async () => {
      if (!live) return
      await renderPage(doc, number, target, Math.min(1800, Math.min(width, 900) * zoom))
      // Release backing pixels after an offscreen render finishes as well.
      if (!live && !target.isConnected) { target.width = 0; target.height = 0 }
    })
    queue.current = work
    void work.catch(() => { if (live) setRenderError('This page could not be displayed. Try For reading.') })
    return () => {
      live = false
      void work.finally(() => { if (!target.isConnected) { target.width = 0; target.height = 0 } }).catch(() => {})
    }
  }, [doc, number, mode, zoom, near, width])

  return <article className="reader-paper continuous-page" ref={element} data-page={number}
    data-active={active ? 'true' : undefined} aria-label={`Page ${number} of ${doc.numPages}`}
    style={!near ? { height: measuredHeight.current } : undefined}>
    {near ? <>
      <p className="eyebrow paper page-eyebrow">{title} · page {number}</p>
      {mode === 'original' ? <>
        <div className="original-stage" ref={stage}>
          <canvas ref={canvas} className="original-page" role="img"
            aria-label={`Visual rendering of page ${number} of ${doc.numPages}. Choose For reading to access the extracted text.`} />
        </div>
        {renderError && <p role="alert">{renderError}</p>}
        </> : textError ? <p role="alert">{textError}</p> : blocks === null ?
          <div className="paper-loading" aria-live="polite"><span className="sr-only">Opening page {number}…</span><i /><i /><i /></div> :
          blocks.length ? <Prose blocks={blocks} reading={active && reading} marked={active ? marked : undefined} onSeek={onSeek} /> :
            <p className="muted">This page has no readable text. Try Original page.</p>}
    </> : <span className="sr-only">Page {number}</span>}
  </article>
})
