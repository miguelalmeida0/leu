import { ArrowsInIcon, ArrowsOutIcon, TextAaIcon } from '@phosphor-icons/react'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { ReaderContents, currentOutlineIndex } from '../components/ReaderContents'
import { Prose, piecesOf } from '../components/Prose'
import { Empty, Modal } from '../components/ui'
import { openPdf, pageBlocks, pdfDeadline, renderPage, type Block, type PDFDocumentProxy } from '../lib/pdf'
import { go, href } from '../lib/router'
import { addNote, loadOutline, loadPdf, patchBook, removeNote, upsertMemory, useStore, type Outline } from '../lib/store'
import { cloze, ideas } from '../lib/text'
import { Dock } from '../components/Dock'
import { VoiceSettings } from '../components/VoiceSettings'
import './FocusListening.css'
import './ReaderLayout.css'
import './ReaderChrome.css'
import { PagedReader, type PagedReaderHandle, type ReadingPosition } from '../components/paged-reader/PagedReader'
import { hapticFeedback } from '../lib/haptics'
import { useReaderFullscreen } from '../lib/useReaderFullscreen'
import { dismissNotice, prefetch, seek, speak, stop, useVoice, warmVoice } from '../lib/voice'
import { ExplainPanel, gistOf } from './Explain'

const limitZoom = (value: number) => Math.min(2.75, Math.max(0.8, Math.round(value * 20) / 20))


/** Reading (06): the chapter rail, the page as paper (rebuilt for reading, or the original),
    and the margin with your notes. Select any line to keep a note, explain it, or hear it. */
export function Reader({ id, page }: { id: string; page: number }) {
  const book = useStore((s) => s.books.find((b) => b.id === id))
  const allNotes = useStore((s) => s.notes)
  const notes = allNotes.filter((n) => n.bookId === id && n.page === page)
  const [doc, setDoc] = useState<PDFDocumentProxy | null>(null)
  const [outline, setOutline] = useState<Outline[]>([])
  const [blocks, setBlocks] = useState<Block[] | null>(null)
  const [preferredMode, setMode] = useState<'rebuilt' | 'original'>('original')
  const [mobileReader, setMobileReader] = useState(() =>
    typeof window !== 'undefined' && window.matchMedia('(max-width: 720px), (max-height: 500px) and (pointer: coarse)').matches)
  // Phones always render the source sheet. A resized desktop reader cannot leave
  // a hidden reflow mode active once its mode selector disappears.
  const mode = mobileReader ? 'original' : preferredMode
  const [originalFit, setOriginalFit] = useState<'page' | 'width'>('page')
  const { immersive, reader, toggle: toggleFullscreen, exit: exitFullscreen } = useReaderFullscreen(`${id}:${page}`)
  const paged = useRef<PagedReaderHandle>(null)
  const [controls, setControls] = useState(false)
  const [focusHelpDismissed, setFocusHelpDismissed] = useState(false)
  const [position, setPosition] = useState<ReadingPosition | null>(null)
  const toggleControls = useCallback(() => { setFocusHelpDismissed(true); setControls((shown) => !shown) }, [])
  const [zoom, setZoom] = useState(1)
  const [settings, setSettings] = useState(false)
  const [selection, setSelection] = useState<{ text: string; page: number; x: number; y: number } | null>(null)
  const [draft, setDraft] = useState<{ quote: string; note: string; page: number } | null>(null)
  const [explain, setExplain] = useState<string | null>(null)
  const [missing, setMissing] = useState(false)
  const [loadError, setLoadError] = useState('')
  const [originalError, setOriginalError] = useState('')
  const paper = useRef<HTMLElement>(null)
  const canvas = useRef<HTMLCanvasElement>(null)
  const originalStage = useRef<HTMLDivElement>(null)
  const renderQueue = useRef<Promise<void>>(Promise.resolve())
  const selectionToolbar = useRef<HTMLDivElement>(null)
  const selectingToolbar = useRef(false)
  const swipeStart = useRef<{ x: number; y: number; at: number } | null>(null)
  const voice = useVoice()
  const continuing = useRef(false)
  const pages = book?.pages ?? 1
  const clamped = Math.min(Math.max(1, page), pages)
  const changeZoom = useCallback((next: number) => setZoom(limitZoom(next)), [])

  useEffect(() => {
    const media = window.matchMedia('(max-width: 720px), (max-height: 500px) and (pointer: coarse)')
    const update = () => setMobileReader(media.matches)
    update()
    media.addEventListener('change', update)
    return () => media.removeEventListener('change', update)
  }, [])

  const toggleFocus = () => {
    hapticFeedback(immersive ? 'confirm' : 'light')
    setControls(false)
    if (immersive) setFocusHelpDismissed(true)
    toggleFullscreen()
  }
  const reportPosition = useCallback((next: ReadingPosition) => {
    setPosition((old) => old && old.page === next.page && old.part === next.part && old.parts === next.parts && old.previous === next.previous && old.next === next.next ? old : next)
    if (mode === 'rebuilt' && Number.isFinite(next.sentence)) {
      const previous = book?.readingPosition
      if (!previous || previous.page !== next.page || previous.sentence !== next.sentence || previous.fraction !== next.fraction) {
        patchBook(id, { readingPosition: { page: next.page, sentence: next.sentence, fraction: next.fraction } })
      }
    }
  }, [id, mode, book?.readingPosition])

  useEffect(() => {
    if (!immersive) return
    const keyboard = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement
      if (target.closest('input, textarea, [contenteditable]') || document.querySelector('.scrim')) return
      if (event.key === 'Escape') {
        if (draft || explain) return
        event.preventDefault()
        exitFullscreen()
      } else if (event.key === '+' || event.key === '=') {
        event.preventDefault()
        setZoom((value) => limitZoom(value + 0.25))
      } else if (event.key === '-') {
        event.preventDefault()
        setZoom((value) => limitZoom(value - 0.25))
      } else if (event.key === '0') {
        event.preventDefault()
        setOriginalFit('page'); setZoom(1)
      }
    }
    window.addEventListener('keydown', keyboard)
    return () => window.removeEventListener('keydown', keyboard)
  }, [immersive, draft, explain, exitFullscreen])

  useEffect(() => {
    let live = true, opened: PDFDocumentProxy | null = null
    void (async () => {
      try {
        const data = await loadPdf(id)
        if (!data) { if (live) setMissing(true); return }
        opened = await openPdf(data)
        if (live) setDoc(opened); else void opened.loadingTask.destroy()
        const items = await loadOutline(id)
        if (live) setOutline(items)
      } catch (error) {
        console.warn('[leu] Could not open PDF:', error)
        if (live) setLoadError('This PDF could not be opened on this device. Try reimporting it from your library.')
      }
    })()
    // If you've listened before, the voice wakes up quietly while the book opens.
    warmVoice()
    return () => { live = false; void opened?.loadingTask.destroy(); stop() }
  }, [id])

  useEffect(() => {
    if (!doc) return
    let live = true
    setBlocks(null)
    void pdfDeadline(pageBlocks(doc, clamped), 12000)
      .then((b) => { if (live) setBlocks(b) })
      .catch((error) => {
        console.warn('[leu] Could not rebuild PDF page; switching to the original:', error)
        if (live) { setBlocks([]); setMode('original') }
      })
    patchBook(id, { page: clamped, lastOpenedAt: Date.now() })
    if (book) document.title = `${book.title}, p. ${clamped} · Leu`
    // A page you stay on for a while becomes something Leu can ask you about later.
    const timer = setTimeout(() => {
      void pdfDeadline(pageBlocks(doc, clamped), 12000).then((b) => {
        if (!live) return
        const text = b.map((x) => x.text).join('\n\n')
        const cards = ideas(text, 2).map((idea, i) => ({ i, c: cloze(idea.text, text) })).filter((x) => x.c)
        upsertMemory(cards.map(({ i, c }) => ({ id: `${id}:${clamped}:${i}`, bookId: id, page: clamped, prompt: c!.prompt, answer: c!.answer, due: 0, strength: 0 })))
      }).catch((error) => console.warn('[leu] Could not prepare page memory:', error))
    }, 6000)
    return () => { live = false; clearTimeout(timer) }
  }, [doc, clamped, id]) // book title read once per page

  useEffect(() => {
    if (immersive || mode !== 'original' || !doc || !canvas.current || !originalStage.current) return
    const destination = canvas.current
    const availableWidth = Math.max(150, Math.min(originalStage.current.clientWidth, 900))
    const width = Math.round(availableWidth)
    let active = true
    setOriginalError('')
    // PDF.js cannot render twice into the same canvas at once. Keep zoom renders
    // serialized and drop superseded requests rather than crashing on quick pinches.
    const next = renderQueue.current.catch(() => undefined).then(async () => {
      if (!active) return
      await renderPage(doc, clamped, destination, width)
    })
    renderQueue.current = next
    void next.catch((error) => {
      if (!active) return
      console.warn('[leu] Could not render original PDF page:', error)
      setOriginalError('This page could not be displayed. Try another page or reimport the PDF.')
    })
    return () => { active = false }
  }, [mode, doc, clamped, immersive])

  const turn = useCallback((to: number, keepReading = false) => {
    if (immersive) setFocusHelpDismissed(true)
    stop(); setSelection(null); setDraft(null); setExplain(null); window.getSelection()?.removeAllRanges()
    continuing.current = keepReading
    go({ name: 'read', id, page: Math.min(Math.max(1, to), pages) }, true)
    if (!immersive) {
      reader.current?.querySelector<HTMLElement>('.reader-grid')?.scrollTo({ top: 0 })
      window.scrollTo({ top: 0 })
    }
  }, [id, pages, immersive])

  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      const typing = (e.target as HTMLElement).closest('input, textarea, [contenteditable]')
      if (typing || e.metaKey || e.ctrlKey || document.querySelector('.scrim')) return
      if (immersive && ['ArrowRight', 'ArrowLeft', 'PageDown', 'PageUp'].includes(e.key)) {
        e.preventDefault()
        paged.current?.step(e.key === 'ArrowRight' || e.key === 'PageDown' ? 1 : -1)
        return
      }
      if (e.key === 'ArrowRight' || e.key === 'PageDown') { e.preventDefault(); turn(clamped + 1) }
      if (e.key === 'ArrowLeft' || e.key === 'PageUp') { e.preventDefault(); turn(clamped - 1) }
    }
    window.addEventListener('keydown', key)
    return () => window.removeEventListener('keydown', key)
  }, [clamped, turn, immersive, reader])

  // Read the page from a sentence; at the end, turn the page and carry on reading.
  const readPage = useCallback((from: number) => {
    if (!blocks) return
    speak(piecesOf(blocks), 'page', from, () => { if (clamped < pages) turn(clamped + 1, true) })
  }, [blocks, clamped, pages, turn])

  useEffect(() => {
    if (!blocks) return
    if (continuing.current) { continuing.current = false; readPage(0) }
    else prefetch(piecesOf(blocks)) // so Read aloud starts at once
  }, [blocks]) // runs when a page's text arrives

  // The sentences an explanation draws on, marked on the page beside it.
  const marked = useMemo(() => {
    if (!explain || !blocks) return undefined
    const key = (t: string) => t.replace(/\s+/g, ' ').trim().slice(0, 40).toLowerCase()
    const want = new Set(gistOf(explain).map(key))
    const set = new Set<number>()
    piecesOf(blocks).forEach((p, i) => { if (want.has(key(p))) set.add(i) })
    return set
  }, [explain, blocks])

  // iOS native long-press updates the Selection asynchronously; mouseup is not reliable.
  useEffect(() => {
    const pageElement = paper.current
    if (!pageElement || mode !== 'rebuilt') { setSelection(null); return }
    let pending: ReturnType<typeof setTimeout> | undefined
    const capture = () => {
      if (selectingToolbar.current) return
      const selected = window.getSelection()
      if (!selected || selected.isCollapsed || !selected.rangeCount) { setSelection(null); return }
      const range = selected.getRangeAt(0)
      const start = range.startContainer.nodeType === Node.ELEMENT_NODE ? range.startContainer as Element : range.startContainer.parentElement
      const content = start?.closest('.prose')
      if (!content || !reader.current?.contains(content) || !content.contains(range.endContainer)) { setSelection(null); return }
      const sourcePage = Number(content.closest<HTMLElement>('[data-page]')?.dataset.page ?? clamped)
      const text = selected.toString().replace(/\s+/g, ' ').trim()
      if (text.length < 3) { setSelection(null); return }
      const rect = range.getBoundingClientRect()
      if (!Number.isFinite(rect.left) || !Number.isFinite(rect.top)) return
      setSelection({
        text, page: sourcePage,
        x: Math.max(175, Math.min(window.innerWidth - 175, rect.left + rect.width / 2)),
        y: Math.max(100, rect.top),
      })
    }
    const schedule = () => {
      if (pending !== undefined) clearTimeout(pending)
      pending = setTimeout(capture, 110)
    }
    const dismissOutside = (event: PointerEvent) => {
      if (selectionToolbar.current?.contains(event.target as Node)) return
      if (!pageElement.contains(event.target as Node)) {
        selectingToolbar.current = false
        setSelection(null)
      }
    }
    document.addEventListener('selectionchange', schedule)
    pageElement.addEventListener('pointerup', schedule)
    pageElement.addEventListener('touchend', schedule)
    document.addEventListener('pointerdown', dismissOutside, true)
    return () => {
      if (pending !== undefined) clearTimeout(pending)
      document.removeEventListener('selectionchange', schedule)
      pageElement.removeEventListener('pointerup', schedule)
      pageElement.removeEventListener('touchend', schedule)
      document.removeEventListener('pointerdown', dismissOutside, true)
    }
  }, [mode, clamped, id, blocks, immersive])

  // Horizontal touch swipes turn pages, but vertical scrolling and native text
  // selection remain exclusively under the browser's control.
  const onSwipeStart = (event: React.TouchEvent<HTMLElement>) => {
    swipeStart.current = null
    if (event.touches.length !== 1 || selection || draft || explain || window.getSelection()?.toString().trim()) return
    if ((event.target as HTMLElement).closest('button, a, input, textarea, [contenteditable], .selection-menu')) return
    const touch = event.touches[0]
    swipeStart.current = { x: touch.clientX, y: touch.clientY, at: Date.now() }
  }
  const onSwipeEnd = (event: React.TouchEvent<HTMLElement>) => {
    const start = swipeStart.current
    swipeStart.current = null
    if (!start || !event.changedTouches.length || selection || window.getSelection()?.toString().trim()) return
    if (Date.now() - start.at > 650) return
    const touch = event.changedTouches[0]
    const dx = touch.clientX - start.x
    const dy = touch.clientY - start.y
    if (Math.abs(dx) < 64 || Math.abs(dx) < Math.abs(dy) * 1.6) return
    if (dx < 0 && clamped < pages) turn(clamped + 1)
    else if (dx > 0 && clamped > 1) turn(clamped - 1)
  }

  const actOnSelection = (action: 'note' | 'explain' | 'speak') => {
    if (!selection) return
    const quote = selection.text
    const sourcePage = selection.page
    selectingToolbar.current = false
    setSelection(null)
    window.getSelection()?.removeAllRanges()
    if (action === 'note') setDraft({ quote, note: '', page: sourcePage })
    if (action === 'explain') {
      if (sourcePage !== clamped) go({ name: 'read', id, page: sourcePage }, true)
      setExplain(quote)
    }
    if (action === 'speak') speak(quote, 'selection')
  }

  if (missing || !book || loadError) return <div className="page"><Empty title={loadError || "This book isn't in this browser any more."}><a className="link" href={href({ name: 'library' })}>Back to the library</a></Empty></div>

  const pageText = (blocks ?? []).map((b) => b.text).join('\n\n')
  const entries = outline.length ? outline : [{ title: 'Beginning', page: 1, depth: 0 }]
  const currentIndex = currentOutlineIndex(entries, clamped)
  const current = entries[currentIndex]
  const speaking = voice.speakingId === 'page'
  const zoomControls = <div className="reader-zoom-controls" role="group" aria-label="Reading zoom">
              {mode === 'original' && <div className="reader-original-fit" role="group" aria-label="Original page fit">
                {([['page', 'Fit page'], ['width', 'Fit width']] as const).map(([value, label]) =>
                  <button key={value} type="button" aria-pressed={originalFit === value}
                    onClick={() => { setOriginalFit(value); setZoom(1); hapticFeedback('light') }}>{label}</button>)}
              </div>}
              <button type="button" aria-label="Zoom out" disabled={zoom <= 0.8}
                onClick={() => changeZoom(zoom - 0.25)}>−</button>
              <button type="button" className="reader-zoom-level" aria-label="Reset zoom"
                onClick={() => { setOriginalFit('page'); changeZoom(1) }}>{Math.round(zoom * 100)}%</button>
              <button type="button" aria-label="Zoom in" disabled={zoom >= 2.75}
                onClick={() => changeZoom(zoom + 0.25)}>+</button>
            </div>
  const focusButton = <button type="button" className="reader-focus-toggle"
    aria-label={immersive ? 'Exit full-screen reading' : 'Enter full-screen reading'}
    aria-pressed={immersive} onClick={toggleFocus}>
    <span>{immersive ? 'Done' : 'Full screen'}</span>
    {immersive ? <ArrowsInIcon size={19} aria-hidden="true" /> : <ArrowsOutIcon size={19} aria-hidden="true" />}
  </button>

  return (
    <div ref={reader} role={immersive ? 'dialog' : undefined} aria-modal={immersive || undefined}
      aria-label={immersive ? `${book.title} · full-screen reader` : undefined}
      data-controls={immersive ? controls ? 'shown' : 'hidden' : undefined} tabIndex={immersive ? -1 : undefined}
      className={`reader fade-in${immersive ? ' reader-immersive' : ''}`}
      style={{ ['--reader-zoom' as string]: zoom }}>
      <div className="reader-bar" inert={immersive && !controls} aria-hidden={immersive && !controls || undefined}>
        <a className="reader-back" href={href({ name: 'book', id })} aria-label="Back to book overview">
          <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path d="M15 5 8 12l7 7" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" /></svg>
          <span>{book.title}</span>
        </a>
        {!mobileReader && <div className="segmented" role="group" aria-label="How to show the page">
          <button type="button" aria-pressed={mode === 'rebuilt'} className={mode === 'rebuilt' ? 'on' : ''} onClick={() => setMode('rebuilt')}>For reading</button>
          <button type="button" aria-pressed={mode === 'original'} className={mode === 'original' ? 'on' : ''} onClick={() => setMode('original')}>Original page</button>
        </div>}
        <div className="reader-view-controls">
          <ReaderContents entries={entries} currentIndex={currentIndex}
            onChoose={(index) => turn(entries[index].page)} onAppearance={() => setSettings(true)} />
          <div className="reader-focus-tools">{focusButton}</div>
          {immersive && zoomControls}
          {!immersive && !mobileReader && <button type="button" className="reader-type-toggle" aria-label="Reading settings" onClick={() => setSettings(true)}><TextAaIcon size={23} aria-hidden="true" /></button>}
        </div>
      </div>

      {voice.notice && (
        <p className="voice-notice" role="status">
          {voice.notice} <button className="link small" onClick={dismissNotice}>OK</button>
        </p>
      )}
      <div className={`reader-grid${explain ? ' explaining' : ''}`}>


        {immersive && doc ? <PagedReader ref={paged} doc={doc} page={clamped} mode={mode} zoom={zoom} originalFit={originalFit}
          controls={controls}
          activePaper={paper} onTurn={turn} onZoom={changeZoom} onToggleControls={toggleControls} onExit={exitFullscreen}
          onPosition={reportPosition} bookmark={book.readingPosition}
          reading={speaking && (voice.status === 'speaking' || voice.status === 'paused')} marked={marked} onSeek={seek} /> :
        <article key={clamped} className="reader-paper" ref={paper}
          onTouchStart={onSwipeStart} onTouchEnd={onSwipeEnd}
          onTouchCancel={() => { swipeStart.current = null }}
          aria-label={`Page ${clamped} of ${pages}`}>
          <p className="eyebrow paper page-eyebrow">{current?.title ?? book.title} · page {clamped}</p>
          {mode === 'original' ? (
            <>
              <div className="original-stage" ref={originalStage}>
                <canvas ref={canvas} className="original-page" role="img"
                  aria-label={mobileReader
                    ? `Original PDF page ${clamped} of ${pages}`
                    : `Visual rendering of page ${clamped} of ${pages}. Choose For reading to access the extracted text.`}
 />
              </div>
              {!mobileReader && <p className="muted small original-selection-hint">
                For selectable text and notes, use “For reading”.
              </p>}
              {originalError && <p className="muted" role="alert">{originalError}</p>}
            </>
          ) : blocks === null ? (
            <div className="paper-loading" aria-live="polite"><span className="sr-only">Opening the page…</span><i /><i /><i /></div>
          ) : blocks.length === 0 ? (
            <p className="muted">This page has no text Leu can read (it may be a picture). Try “Original page”.</p>
          ) : (
            <Prose blocks={blocks} omitHeading={book.title} reading={speaking && (voice.status === 'speaking' || voice.status === 'paused')} marked={marked} onSeek={seek} />
          )}
        </article>}

          {selection && (
            <div ref={selectionToolbar} className="selection-menu" style={{ left: selection.x, top: selection.y }}
              role="toolbar" aria-label="Actions for selected text"
              onPointerDownCapture={(event) => {
                selectingToolbar.current = true
                if (event.pointerType === 'mouse') event.preventDefault()
              }}>
              <button type="button" onClick={() => actOnSelection('note')}>Keep a note</button>
              <button type="button" onClick={() => actOnSelection('explain')}>Explain</button>
              <button type="button" onClick={() => actOnSelection('speak')}>Read aloud</button>
              <button type="button" className="selection-dismiss" aria-label="Dismiss text actions" onClick={() => {
                selectingToolbar.current = false
                setSelection(null)
                window.getSelection()?.removeAllRanges()
              }}>×</button>
            </div>
          )}


        <aside className="margin" aria-label={explain ? 'Passage explanation' : 'In the margin'}>
          {explain && !immersive ? <ExplainPanel key={explain} bookId={id} page={clamped} passage={explain} pageText={pageText} onClose={() => setExplain(null)} /> : <>
          <p className="eyebrow">In the margin</p>
          {notes.map((n) => (
            <div key={n.id} className="margin-note">
              <blockquote className="serif">“{n.quote.length > 180 ? n.quote.slice(0, 180) + '…' : n.quote}”</blockquote>
              {n.note && <p>{n.note}</p>}
              <button className="quiet-link small" onClick={() => removeNote(n.id)} aria-label="Remove this note">Remove</button>
            </div>
          ))}
          {!notes.length && <p className="muted small">Select a passage to keep a note, ask for an explanation, or hear it read.</p>}
          <div className="divider" style={{ margin: '20px 0' }} />
          <button className="btn cream" style={{ width: '100%' }} onClick={() => setExplain(pageText)} disabled={!pageText}><span className="dot" style={{ background: 'var(--butter)' }} />Explain this page simply</button>
          <button className="btn soft" style={{ width: '100%', marginTop: 10 }} onClick={() => go({ name: 'words', id, page: clamped })}>Say it in your own words</button>
          </>}
        </aside>
      </div>

      <div className="reader-foot" inert={immersive && !controls} aria-hidden={immersive && !controls || undefined}>
        <Dock page={clamped} pages={pages} canPlay={!!pageText} onPlay={() => readPage(0)} onTurn={(n) => turn(n)} compact={immersive} />
      </div>
      {immersive && <>
        <div className="reader-focus-shortcuts" role="toolbar" aria-label="Full-screen shortcuts">
          <button type="button" onClick={toggleControls} aria-expanded={controls}
            aria-label={controls ? 'Hide reader tools' : 'Show reader tools'}>Tools</button>
          <button type="button" onClick={toggleFocus} aria-label="Leave full-screen">Done</button>
        </div>
        {!focusHelpDismissed && !controls && <p className="reader-focus-hint">Swipe to turn pages · Tap the page for controls</p>}
        <nav className="reader-page-nav" aria-label="Full-screen pages">
          <button type="button" aria-label="Previous page" disabled={!(position?.previous ?? clamped > 1)}
            onClick={() => { setFocusHelpDismissed(true); paged.current?.step(-1) }}>
            <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path d="m15 5-7 7 7 7" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" /></svg>
          </button>
          <span className="reader-focus-page tabular" aria-live="polite">Page {clamped} of {pages}</span>
          <button type="button" aria-label="Next page" disabled={!(position?.next ?? clamped < pages)}
            onClick={() => { setFocusHelpDismissed(true); paged.current?.step(1) }}>
            <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path d="m9 5 7 7-7 7" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" /></svg>
          </button>
        </nav>
      </>}
      {settings && <Modal label="Reading settings" onClose={() => setSettings(false)} width={360}>
        <h2 className="display" style={{ fontSize: 24, marginBottom: 20 }}>Reading settings</h2>
        <p className="muted">Text size</p>
        {zoomControls}
        <VoiceSettings />
      </Modal>}
      {immersive && explain && (
        <Modal label="Passage explanation" onClose={() => setExplain(null)} width={540}>
          <ExplainPanel key={explain} bookId={id} page={clamped} passage={explain} pageText={pageText} onClose={() => setExplain(null)} />
        </Modal>
      )}
      {draft && (
        <Modal label={`Keep a note from ${book.title}, page ${draft.page}`} onClose={() => setDraft(null)} width={540}>
          <form className="note-compose" onSubmit={(event) => {
            event.preventDefault()
            addNote({ bookId: id, page: draft.page, quote: draft.quote, note: draft.note.trim() })
            setDraft(null)
          }}>
            <p className="eyebrow paper">Keep this passage · p. {draft.page}</p>
            <h2 className="display note-compose-title">A note to come back to.</h2>
            <blockquote className="serif note-quote">“{draft.quote}”</blockquote>
            <label className="note-label" htmlFor="note-body">Your thought (optional)</label>
            <textarea id="note-body" className="field" autoFocus rows={4}
              placeholder="What do you want to remember?"
              value={draft.note} onChange={(event) => setDraft({ ...draft, note: event.target.value })} />
            <div className="row note-actions">
              <button className="btn ink" type="submit">Save note</button>
              <button className="quiet-link" type="button" onClick={() => setDraft(null)}>Cancel</button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  )
}
