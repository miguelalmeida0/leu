import { memo, useEffect, useLayoutEffect, useRef, useState } from 'react'
import { Prose } from '../Prose'
import { renderPage, type PDFDocumentProxy } from '../../lib/pdf'
import type { PageData, PageMetrics, PagedReaderProps } from './types'

interface Props {
  doc: PDFDocumentProxy; number: number; data?: PageData; part: number | 'last'
  active: boolean; side: 'before' | 'current' | 'after'; mode: PagedReaderProps['mode']; zoom: number
  originalFit: PagedReaderProps['originalFit']; onPan: (value: { x: number; y: number }) => void
  paper: PagedReaderProps['activePaper']; reading: boolean; marked?: Set<number>
  pan: { x: number; y: number }; onSeek: (index: number) => void
  onFollow: (index: number) => void; onMetrics: (page: number, metrics: PageMetrics) => void
}

export const PagePanel = memo(function PagePanel(props: Props) {
  const { doc, number, data, part, active, mode, zoom, originalFit, onMetrics } = props
  const article = useRef<HTMLElement>(null), area = useRef<HTMLDivElement>(null), canvas = useRef<HTMLCanvasElement>(null)
  const queue = useRef<Promise<void>>(Promise.resolve())
  const [layout, setLayout] = useState({ width: 0, height: 0, parts: 1, stride: 0 })
  const [renderError, setRenderError] = useState('')
  useLayoutEffect(() => { if (area.current) area.current.scrollTop = 0 }, [number, mode, zoom, originalFit])
  useLayoutEffect(() => { if (active) props.paper.current = article.current }, [active, props.paper])

  useLayoutEffect(() => {
    const target = area.current
    if (!target) return
    let live = true
    const measure = () => {
      if (!live) return
      const width = target.clientWidth, height = target.clientHeight
      if (!width || !height) return
      const prose = target.querySelector<HTMLElement>('.prose')
      target.style.setProperty('--paged-column-width', `${width}px`)
      const stride = width + 32
      const parts = mode === 'rebuilt' && prose ? Math.max(1, Math.round((prose.scrollWidth + 32) / stride)) : 1
      const starts = Array<number>(parts).fill(-1), columns: number[] = [], ends: number[] = []
      if (prose) {
        const origin = prose.getBoundingClientRect().left
        for (const sentence of prose.querySelectorAll<HTMLElement>('.s')) {
          const index = Number(sentence.dataset.s)
          for (const rect of sentence.getClientRects()) {
            const column = Math.max(0, Math.min(parts - 1, Math.floor((rect.left - origin + .5) / stride)))
            if (columns[index] === undefined) columns[index] = column
            ends[index] = Math.max(ends[index] ?? column, column)
            if (starts[column] < 0) starts[column] = index
          }
        }
      }
      for (let i = 0; i < starts.length; i++) if (starts[i] < 0) starts[i] = starts[i - 1] ?? 0
      setLayout((old) => old.width === width && old.height === height && old.parts === parts ? old : { width, height, parts, stride })
      onMetrics(number, { parts, starts, columns, ends, key: `${width}:${height}:${zoom}:${mode}:${parts}:${starts.join(',')}:${columns.join(',')}:${ends.join(',')}` })
    }
    const observer = new ResizeObserver(measure)
    observer.observe(target)
    measure()
    void document.fonts.ready.then(measure)
    document.fonts.addEventListener('loadingdone', measure)
    return () => { live = false; observer.disconnect(); document.fonts.removeEventListener('loadingdone', measure) }
  }, [data, mode, zoom, number, onMetrics])

  useEffect(() => {
    const target = canvas.current
    if (mode !== 'original' || !target || !data || !layout.width || !layout.height) return
    let live = true
    setRenderError('')
    const fitted = originalFit === 'cover' ? Math.max(layout.width, layout.height * data.aspect) : layout.width
    const width = Math.max(1, fitted * zoom)
    const work = queue.current.catch(() => {}).then(async () => {
      if (live) await renderPage(doc, number, target, Math.min(1800, width), width)
    })
    queue.current = work
    void work.catch(() => { if (live) setRenderError('This page could not be displayed. Try For reading.') })
    return () => {
      live = false
      void work.finally(() => { if (!target.isConnected) { target.width = 0; target.height = 0 } }).catch(() => {})
    }
  }, [data, doc, number, mode, zoom, originalFit, layout.width, layout.height])

  const leaf = Math.max(0, Math.min(layout.parts - 1, part === 'last' ? layout.parts - 1 : part))
  return <article ref={article} className={`reader-paper paged-panel paged-${props.side}`}
    data-mode={mode} data-page={number} data-active={active ? 'true' : undefined} aria-label={`Page ${number} of ${doc.numPages}`}
    aria-hidden={!active || undefined} inert={!active}>
    <div ref={area} className={mode === 'rebuilt' ? 'paged-text' : 'paged-original'} data-zoomed={zoom > 1.05 || undefined} data-fit={originalFit}
      role={mode === 'original' ? 'region' : undefined} aria-label={mode === 'original' ? 'Original PDF page' : undefined}
      tabIndex={mode === 'original' ? 0 : undefined}
      aria-description={mode === 'original' && originalFit === 'cover' ? 'Drag to pan. Up and Down arrows pan vertically. Shift plus Left and Right arrows pan horizontally. Left and Right arrows turn source pages.' : undefined}
      onKeyDown={(event) => {
        if (mode !== 'original' || (originalFit !== 'cover' && zoom <= 1.05)) return
        const vertical = event.key === 'ArrowUp' || event.key === 'ArrowDown'
        const horizontal = event.shiftKey && (event.key === 'ArrowLeft' || event.key === 'ArrowRight')
        if (!vertical && !horizontal) return
        event.preventDefault(); event.stopPropagation()
        props.onPan({ x: props.pan.x + (horizontal ? event.key === 'ArrowLeft' ? 48 : -48 : 0),
          y: props.pan.y + (vertical ? event.key === 'ArrowUp' ? 48 : -48 : 0) })
      }}>
      {!data ? <p className="paged-loading" role={active ? 'status' : undefined}>Opening page…</p> : data.error ?
        <p className="paged-loading" role="alert">{data.error}</p> : mode === 'original' ? <>
          <canvas ref={canvas} className="original-page" role="img" style={{ transform: `translate(calc(-50% + ${props.pan.x}px), ${originalFit === 'cover' || zoom > 1.05 ? `calc(-50% + ${props.pan.y}px)` : '0px'})` }}
            aria-label={`Visual rendering of page ${number} of ${doc.numPages}. Choose For reading to access the extracted text.`} />
          {renderError && <p className="paged-loading" role="alert">{renderError}</p>}
        </> : data.textError ? <p className="paged-loading" role="alert">{data.textError}</p> : data.blocks.length ? <div className="paged-columns" style={{ transform: `translate3d(${-leaf * layout.stride}px, 0, 0)` }}>
          <Prose blocks={data.blocks} reading={active && props.reading} marked={props.marked} onSeek={props.onSeek} onFollow={active ? props.onFollow : undefined} />
        </div> : <p className="paged-loading">No readable text on this page. Choose Original page.</p>}
    </div>
  </article>
})
