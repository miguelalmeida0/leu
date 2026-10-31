import { forwardRef, useCallback, useEffect, useImperativeHandle, useLayoutEffect, useRef, useState } from 'react'
import { flushSync } from 'react-dom'
import { useReducedMotionPreference } from '../../lib/motion'
import { PagePanel } from './PagePanel'
import { usePageWindow } from './usePageWindow'
import { hapticFeedback } from '../../lib/haptics'
import { useReaderDismiss } from './useReaderDismiss'
import { usePageGesture } from './usePageGesture'
import type { Direction, PageMetrics, PagedReaderHandle, PagedReaderProps } from './types'
import './styles.css'

export type { PagedReaderHandle, ReadingPosition } from './types'

/** A screen-sized deck. Source PDF pages may contain several reflowed screens. */
export const PagedReader = forwardRef<PagedReaderHandle, PagedReaderProps>(function PagedReader(props, ref) {
  const root = useRef<HTMLDivElement>(null), track = useRef<HTMLDivElement>(null)
  const stage = useRef<HTMLDivElement>(null), dismissHint = useRef<HTMLSpanElement>(null)
  const pages = usePageWindow(props.doc, props.page)
  const metrics = useRef(new Map<number, PageMetrics>())
  const [revision, setRevision] = useState(0), [part, setPart] = useState(0), [settled, setSettled] = useState(true)
  const [pan, setPan] = useState({ x: 0, y: 0 })
  const anchor = useRef(props.bookmark?.page === props.page ? props.bookmark : { sentence: 0, fraction: 0 })
  const restoredPart = useRef(0)
  const owner = useRef(props.page), layoutKey = useRef(''), pending = useRef<{ page: number; last: boolean } | null>(null)
  const busy = useRef(false), animation = useRef<Animation | null>(null), live = useRef(true)
  const reduced = useReducedMotionPreference()
  const dismiss = useReaderDismiss(root, stage, dismissHint, reduced, props.onExit)
  const currentMetrics = metrics.current.get(props.page)
  const parts = props.mode === 'original' ? 1 : currentMetrics?.parts ?? 1
  const leaf = Math.min(part, parts - 1)
  const previous = !!pages.get(props.page) && (leaf > 0 || props.page > 1)
  const next = !!pages.get(props.page) && (leaf < parts - 1 || props.page < props.doc.numPages)
  const latest = useRef({ props, part: leaf, parts, previous, next, reduced })
  latest.current = { props, part: leaf, parts, previous, next, reduced }

  const measured = useCallback((page: number, value: PageMetrics) => {
    if (metrics.current.get(page)?.key === value.key) return
    metrics.current.set(page, value)
    setRevision((n) => n + 1)
  }, [])
  const remember = (index: number) => {
    const state = latest.current, metric = metrics.current.get(state.props.page)
    if (state.props.mode === 'rebuilt') anchor.current = {
      sentence: metric?.starts[index] ?? 0, fraction: state.parts > 1 ? index / (state.parts - 1) : 0,
    }
    restoredPart.current = index
    setPart(index)
  }

  useLayoutEffect(() => {
    if (owner.current !== props.page) {
      owner.current = props.page
      anchor.current = pending.current?.page === props.page && pending.current.last ? { sentence: Infinity, fraction: 1 } : { sentence: 0, fraction: 0 }
      pending.current = null
      layoutKey.current = ''
    }
    const metric = metrics.current.get(props.page)
    if (!metric || layoutKey.current === metric.key) return
    layoutKey.current = metric.key
    if (props.mode === 'original') { restoredPart.current = 0; setPart(0); return }
    const column = metric.columns[anchor.current.sentence]
    const fraction = Math.round(anchor.current.fraction * (metric.parts - 1))
    // A sentence may start on the previous screen and continue onto this one.
    // Keep the stored screen within that sentence's full fragment range.
    const target = column === undefined ? fraction : Math.max(column, Math.min(metric.ends[anchor.current.sentence] ?? column, fraction))
    restoredPart.current = Math.max(0, Math.min(metric.parts - 1, target))
    setPart(restoredPart.current)
  }, [props.page, props.mode, revision])

  useLayoutEffect(() => {
    const metric = metrics.current.get(props.page)
    if (!metric || !pages.get(props.page) || owner.current !== props.page
      || layoutKey.current !== metric.key || parts !== metric.parts || leaf !== restoredPart.current) return
    const saved = anchor.current.sentence
    // A saved sentence can be inside a screen rather than its first fragment.
    // Keep that passage anchor through reload/reflow while it remains visible.
    const anchored = metric.columns[saved] !== undefined && leaf >= metric.columns[saved] && leaf <= metric.ends[saved]
    // Publish only the committed restored screen, before paint or a reload can
    // observe a bookmark from the previous layout's screen index.
    root.current?.setAttribute('data-layout', `${props.page}:${metric.key}`)
    props.onPosition({ page: props.page, sentence: props.mode === 'rebuilt' ? anchored ? saved : metric.starts[leaf] ?? 0 : saved,
      fraction: props.mode === 'rebuilt' ? (parts > 1 ? leaf / (parts - 1) : 0) : anchor.current.fraction,
      part: leaf, parts, previous, next })
  }, [props.page, props.mode, props.onPosition, leaf, parts, previous, next, revision, pages])

  const settle = useCallback((direction: Direction | 0) => {
    if (busy.current || !root.current || !track.current) return
    const state = latest.current
    if (direction && !(direction < 0 ? state.previous : state.next)) direction = 0
    if (direction) hapticFeedback('light')
    busy.current = true
    setSettled(false)
    root.current.dataset.settled = 'false'
    const finish = () => {
      if (!live.current) return
      flushSync(() => {
        const current = latest.current
        if (direction && current.part + direction >= 0 && current.part + direction < current.parts) remember(current.part + direction)
        else if (direction) {
          pending.current = { page: current.props.page + direction, last: direction < 0 }
          current.props.onTurn(current.props.page + direction)
        }
        setSettled(true)
      })
      animation.current?.cancel(); animation.current = null
      if (track.current) track.current.style.transform = 'translate3d(0,0,0)'
      if (root.current) root.current.dataset.settled = 'true'
      busy.current = false
    }
    if (state.reduced) { finish(); return }
    animation.current = track.current.animate([
      { transform: getComputedStyle(track.current).transform },
      { transform: `translate3d(${-direction * root.current.clientWidth}px,0,0)` },
    ], { duration: direction ? 230 : 180, easing: 'cubic-bezier(.22,.8,.25,1)', fill: 'forwards' })
    void animation.current.finished.then(finish).catch(() => {})
  }, [])

  useImperativeHandle(ref, () => ({ step: settle, goToPage: (page) => {
    pending.current = { page, last: false }
    if (page === latest.current.props.page) { remember(0); return }
    latest.current.props.onTurn(page)
  } }), [settle])
  useLayoutEffect(() => {
    dismiss.cancel()
    animation.current?.cancel(); animation.current = null
    if (track.current) track.current.style.transform = 'translate3d(0,0,0)'
    busy.current = false; setSettled(true); setPan({ x: 0, y: 0 })
  }, [props.page, props.mode, props.zoom, props.originalFit, dismiss.cancel])
  useEffect(() => {
    live.current = true
    return () => { live.current = false; animation.current?.cancel() }
  }, [])
  useEffect(() => {
    const resetPan = () => setPan((value) => value.x || value.y ? { x: 0, y: 0 } : value)
    window.addEventListener('resize', resetPan)
    window.visualViewport?.addEventListener('resize', resetPan)
    return () => { window.removeEventListener('resize', resetPan); window.visualViewport?.removeEventListener('resize', resetPan) }
  }, [])
  useEffect(() => {
    for (const page of metrics.current.keys()) if (Math.abs(page - props.page) > 1) metrics.current.delete(page)
  }, [props.page])

  const panTo = (value: { x: number; y: number }) => {
    const area = root.current?.querySelector<HTMLElement>('.paged-current .paged-original')
    const canvas = area?.querySelector('canvas')
    if (!area || !canvas) return
    const x = Math.max(0, (canvas.getBoundingClientRect().width - area.clientWidth) / 2)
    const y = Math.max(0, (canvas.getBoundingClientRect().height - area.clientHeight) / 2)
    setPan({ x: Math.max(-x, Math.min(x, value.x)), y: Math.max(-y, Math.min(y, value.y)) })
  }
  usePageGesture({ root, track, busy: () => busy.current || dismiss.busy(), dismiss, turn: settle, available: (direction) => direction < 0 ? latest.current.previous : latest.current.next,
    originalScroll: () => latest.current.props.mode === 'original' && latest.current.props.originalFit === 'width' && latest.current.props.zoom <= 1.05
      ? root.current?.querySelector<HTMLElement>('.paged-current .paged-original') ?? null : null,
    allowPull: () => {
      if (latest.current.props.zoom > 1.05) return false
      const area = root.current?.querySelector<HTMLElement>('.paged-current .paged-original')
      const canvas = area?.querySelector('canvas')
      return latest.current.props.mode === 'rebuilt' || (!!area && !!canvas && canvas.getBoundingClientRect().top >= area.getBoundingClientRect().top - 2)
    },
    tap: props.onToggleControls, sentenceTap: (index) => {
      if (!props.reading || !props.controls) return false
      props.onSeek(index); return true
    }, zoom: props.zoom, onZoom: props.onZoom, panning: props.mode === 'original' && props.zoom > 1.05, pan, onPan: panTo })
  const follow = useCallback((index: number) => {
    const state = latest.current
    const target = metrics.current.get(state.props.page)?.columns[index]
    if (target !== undefined && target !== state.part) remember(target)
  }, [])

  const before = leaf > 0 ? { page: props.page, part: leaf - 1 } : { page: props.page - 1, part: 'last' as const }
  const after = leaf < parts - 1 ? { page: props.page, part: leaf + 1 } : { page: props.page + 1, part: 0 }
  return <div ref={root} className="paged-reader" role="region" aria-label="Reading pages" tabIndex={0}
    data-mode={props.mode} data-location={`${props.page}:${leaf}`} data-part={leaf} data-parts={parts} data-settled={settled ? 'true' : 'false'}
    aria-keyshortcuts="ArrowLeft ArrowRight PageUp PageDown"
    aria-description="Swipe sideways to turn pages. Pinch to zoom original pages, then drag to pan. Use edge taps, page buttons, or Left and Right arrow keys to turn source pages. Pull down from the top to exit full-screen reading.">
    <div className="paged-dismiss-hint" aria-hidden="true"><svg width="14" height="14" viewBox="0 0 24 24"><path d="m6 9 6 6 6-6" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></svg><span ref={dismissHint}>Pull down to exit</span></div>
    <div ref={stage} className="paged-dismiss-stage">
    <div ref={track} className="paged-motion">
      {([{ ...before, side: 'before' }, { page: props.page, part: leaf, side: 'current' }, { ...after, side: 'after' }] as const).map((panel) =>
        panel.page >= 1 && panel.page <= props.doc.numPages && <PagePanel key={panel.side} doc={props.doc} number={panel.page} data={pages.get(panel.page)}
          part={panel.part} side={panel.side} active={panel.side === 'current'} mode={props.mode} zoom={props.zoom} originalFit={props.originalFit} onPan={panTo}
          paper={props.activePaper} reading={panel.side === 'current' && props.reading} marked={panel.side === 'current' ? props.marked : undefined}
          pan={panel.side === 'current' ? pan : { x: 0, y: 0 }} onSeek={props.onSeek} onFollow={follow} onMetrics={measured} />)}
    </div>
    <p className="paged-position" aria-live="polite">{props.page} / {props.doc.numPages}{parts > 1 ? ` · ${leaf + 1} of ${parts}` : ''}</p>
    </div>
    <button className="paged-access" type="button" onClick={props.onToggleControls}>Show reading controls</button>
  </div>
})
