import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Prose, piecesOf } from '../components/Prose'
import { Empty, Modal } from '../components/ui'
import { openPdf, pageBlocks, pdfDeadline, renderPage, type Block, type PDFDocumentProxy } from '../lib/pdf'
import { go, href } from '../lib/router'
import { addNote, loadOutline, loadPdf, patchBook, removeNote, upsertMemory, useStore, type Outline } from '../lib/store'
import { cloze, ideas } from '../lib/text'
import { Dock } from '../components/Dock'
import { dismissNotice, prefetch, seek, speak, stop, useVoice, warmVoice } from '../lib/voice'
import { ExplainPanel, gistOf } from './Explain'

/** Reading (06): the chapter rail, the page as paper (rebuilt for reading, or the original),
    and the margin with your notes. Select any line to keep a note, explain it, or hear it. */
export function Reader({ id, page }: { id: string; page: number }) {
  const book = useStore((s) => s.books.find((b) => b.id === id))
  const allNotes = useStore((s) => s.notes)
  const notes = allNotes.filter((n) => n.bookId === id && n.page === page)
  const [doc, setDoc] = useState<PDFDocumentProxy | null>(null)
  const [outline, setOutline] = useState<Outline[]>([])
  const [blocks, setBlocks] = useState<Block[] | null>(null)
  const [mode, setMode] = useState<'rebuilt' | 'original'>('rebuilt')
  const [selection, setSelection] = useState<{ text: string; x: number; y: number } | null>(null)
  const [draft, setDraft] = useState<{ quote: string; note: string } | null>(null)
  const [explain, setExplain] = useState<string | null>(null)
  const [missing, setMissing] = useState(false)
  const [loadError, setLoadError] = useState('')
  const [originalError, setOriginalError] = useState('')
  const paper = useRef<HTMLDivElement>(null)
  const canvas = useRef<HTMLCanvasElement>(null)
  const selectionToolbar = useRef<HTMLDivElement>(null)
  const selectingToolbar = useRef(false)
  const voice = useVoice()
  const continuing = useRef(false)
  const pages = book?.pages ?? 1
  const clamped = Math.min(Math.max(1, page), pages)

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
    if (mode !== 'original' || !doc || !canvas.current || !paper.current) return
    const width = Math.max(1, Math.min(paper.current.clientWidth - 2, 760))
    setOriginalError('')
    void renderPage(doc, clamped, canvas.current, width).catch((error) => {
      console.warn('[leu] Could not render original PDF page:', error)
      setOriginalError('This page could not be displayed. Try another page or reimport the PDF.')
    })
  }, [mode, doc, clamped])

  const turn = useCallback((to: number, keepReading = false) => {
    stop(); setSelection(null); setDraft(null); setExplain(null); window.getSelection()?.removeAllRanges()
    continuing.current = keepReading
    go({ name: 'read', id, page: Math.min(Math.max(1, to), pages) }, true)
    document.querySelector('.reader-paper')?.scrollTo({ top: 0 })
    window.scrollTo({ top: 0 })
  }, [id, pages])

  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      const typing = (e.target as HTMLElement).closest('input, textarea, [contenteditable]')
      if (typing || e.metaKey || e.ctrlKey || document.querySelector('.scrim')) return
      if (e.key === 'ArrowRight' || e.key === 'PageDown') { e.preventDefault(); turn(clamped + 1) }
      if (e.key === 'ArrowLeft' || e.key === 'PageUp') { e.preventDefault(); turn(clamped - 1) }
    }
    window.addEventListener('keydown', key)
    return () => window.removeEventListener('keydown', key)
  }, [clamped, turn])

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
      const content = pageElement.querySelector('.prose')
      if (!selected || selected.isCollapsed || !selected.rangeCount || !content) { setSelection(null); return }
      const range = selected.getRangeAt(0)
      if (!content.contains(range.startContainer) || !content.contains(range.endContainer)) { setSelection(null); return }
      const text = selected.toString().replace(/\s+/g, ' ').trim()
      if (text.length < 3) { setSelection(null); return }
      const rect = range.getBoundingClientRect()
      if (!Number.isFinite(rect.left) || !Number.isFinite(rect.top)) return
      setSelection({
        text,
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
  }, [mode, clamped, id, blocks])

  const actOnSelection = (action: 'note' | 'explain' | 'speak') => {
    if (!selection) return
    const quote = selection.text
    selectingToolbar.current = false
    setSelection(null)
    window.getSelection()?.removeAllRanges()
    if (action === 'note') setDraft({ quote, note: '' })
    if (action === 'explain') setExplain(quote)
    if (action === 'speak') speak(quote, 'selection')
  }

  if (missing || !book || loadError) return <div className="page"><Empty title={loadError || "This book isn't in this browser any more."}><a className="link" href={href({ name: 'library' })}>Back to the library</a></Empty></div>

  const pageText = (blocks ?? []).map((b) => b.text).join('\n\n')
  const current = [...outline].reverse().find((o) => o.page <= clamped && o.depth === 0) ?? [...outline].reverse().find((o) => o.page <= clamped)
  const speaking = voice.speakingId === 'page'

  return (
    <div className="reader fade-in">
      <div className="reader-bar">
        <a className="reader-back" href={href({ name: 'book', id })}>
          <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path d="M15 5 8 12l7 7" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" /></svg>
          <span>{book.title}</span>
        </a>
        <div className="segmented" role="radiogroup" aria-label="How to show the page">
          <button role="radio" aria-checked={mode === 'rebuilt'} className={mode === 'rebuilt' ? 'on' : ''} onClick={() => setMode('rebuilt')}>For reading</button>
          <button role="radio" aria-checked={mode === 'original'} className={mode === 'original' ? 'on' : ''} onClick={() => setMode('original')}>Original page</button>
        </div>
        <span aria-hidden="true" />
      </div>

      {voice.notice && (
        <p className="voice-notice" role="status">
          {voice.notice} <button className="link small" onClick={dismissNotice}>OK</button>
        </p>
      )}
      <div className={`reader-grid${explain ? ' explaining' : ''}`}>
        <nav className="rail" aria-label="Chapters">
          <p className="eyebrow">Chapters</p>
          <ol>
            {(outline.length ? outline : [{ title: 'Beginning', page: 1, depth: 0 }]).slice(0, 40).map((o, i) => (
              <li key={i} className={`depth-${Math.min(o.depth, 2)}`}>
                <a href={href({ name: 'read', id, page: o.page })} aria-current={o === current ? 'location' : undefined} onClick={(e) => { e.preventDefault(); turn(o.page) }}>
                  <span>{o.title}</span><span className="tabular muted">{o.page}</span>
                </a>
              </li>
            ))}
          </ol>
        </nav>

        <article className="reader-paper" ref={paper} aria-label={`Page ${clamped} of ${pages}`}>
          <p className="eyebrow paper page-eyebrow">{current?.title ?? book.title} · page {clamped}</p>
          {mode === 'original' ? (
            <>
              <canvas ref={canvas} className="original-page" role="img" aria-label={`The original page ${clamped}`} />
              <p className="muted small original-selection-hint">To select text or keep notes, switch to “For reading”.</p>
              {originalError && <p className="muted" role="alert">{originalError}</p>}
            </>
          ) : blocks === null ? (
            <div className="paper-loading" aria-live="polite"><span className="sr-only">Opening the page…</span><i /><i /><i /></div>
          ) : blocks.length === 0 ? (
            <p className="muted">This page has no text Leu can read (it may be a picture). Try “Original page”.</p>
          ) : (
            <Prose blocks={blocks} reading={speaking && (voice.status === 'speaking' || voice.status === 'paused')} marked={marked} onSeek={seek} />
          )}
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
        </article>

        <aside className="margin" aria-label={explain ? 'Explained simply' : 'In the margin'}>
          {explain ? <ExplainPanel key={explain} bookId={id} page={clamped} passage={explain} onClose={() => setExplain(null)} /> : <>
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

      <div className="reader-foot">
        <Dock page={clamped} pages={pages} canPlay={!!pageText} onPlay={() => readPage(0)} onTurn={(n) => turn(n)} />
      </div>
      {draft && (
        <Modal label={`Keep a note from ${book.title}, page ${clamped}`} onClose={() => setDraft(null)} width={540}>
          <form className="note-compose" onSubmit={(event) => {
            event.preventDefault()
            addNote({ bookId: id, page: clamped, quote: draft.quote, note: draft.note.trim() })
            setDraft(null)
          }}>
            <p className="eyebrow paper">Keep this passage · p. {clamped}</p>
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
