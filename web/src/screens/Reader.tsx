import { useCallback, useEffect, useRef, useState } from 'react'
import { Empty } from '../components/ui'
import { openPdf, pageBlocks, renderPage, type Block, type PDFDocumentProxy } from '../lib/pdf'
import { go, href } from '../lib/router'
import { addNote, loadOutline, loadPdf, patchBook, removeNote, upsertMemory, useStore, type Outline } from '../lib/store'
import { cloze, ideas } from '../lib/text'
import { chooseVoice, dismissNotice, speak, stop, useVoice, useVoiceId, voices } from '../lib/voice'
import { Explain } from './Explain'

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
  const [voiceMenu, setVoiceMenu] = useState(false)
  const [missing, setMissing] = useState(false)
  const paper = useRef<HTMLDivElement>(null)
  const canvas = useRef<HTMLCanvasElement>(null)
  const voice = useVoice()
  const voiceId = useVoiceId()
  const pages = book?.pages ?? 1
  const clamped = Math.min(Math.max(1, page), pages)

  useEffect(() => {
    let live = true, opened: PDFDocumentProxy | null = null
    void (async () => {
      const data = await loadPdf(id)
      if (!data) { if (live) setMissing(true); return }
      opened = await openPdf(data)
      if (live) setDoc(opened); else void opened.loadingTask.destroy()
      setOutline(await loadOutline(id))
    })()
    return () => { live = false; void opened?.loadingTask.destroy(); stop() }
  }, [id])

  useEffect(() => {
    if (!doc) return
    let live = true
    setBlocks(null)
    void pageBlocks(doc, clamped).then((b) => { if (live) setBlocks(b) })
    patchBook(id, { page: clamped, lastOpenedAt: Date.now() })
    if (book) document.title = `${book.title}, p. ${clamped} · Leu`
    // A page you stay on for a while becomes something Leu can ask you about later.
    const timer = setTimeout(async () => {
      const b = await pageBlocks(doc, clamped)
      const text = b.map((x) => x.text).join('\n\n')
      const cards = ideas(text, 2).map((idea, i) => ({ i, c: cloze(idea.text, text) })).filter((x) => x.c)
      upsertMemory(cards.map(({ i, c }) => ({ id: `${id}:${clamped}:${i}`, bookId: id, page: clamped, prompt: c!.prompt, answer: c!.answer, due: 0, strength: 0 })))
    }, 6000)
    return () => { live = false; clearTimeout(timer) }
  }, [doc, clamped, id]) // book title read once per page

  useEffect(() => {
    if (mode !== 'original' || !doc || !canvas.current || !paper.current) return
    const width = Math.min(paper.current.clientWidth - 2, 760)
    void renderPage(doc, clamped, canvas.current, width)
  }, [mode, doc, clamped])

  const turn = useCallback((to: number) => {
    stop(); setSelection(null); setDraft(null)
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

  const onMouseUp = () => {
    const s = window.getSelection()
    const text = s?.toString().replace(/\s+/g, ' ').trim() ?? ''
    if (!s || text.length < 4 || !paper.current?.contains(s.anchorNode)) { setSelection(null); return }
    const r = s.getRangeAt(0).getBoundingClientRect(), p = paper.current.getBoundingClientRect()
    setSelection({ text, x: r.left + r.width / 2 - p.left, y: r.top - p.top })
  }

  if (missing || !book) return <div className="page"><Empty title="This book isn't in this browser any more."><a className="link" href={href({ name: 'library' })}>Back to the library</a></Empty></div>

  const pageText = (blocks ?? []).map((b) => b.text).join('\n\n')
  const current = [...outline].reverse().find((o) => o.page <= clamped && o.depth === 0) ?? [...outline].reverse().find((o) => o.page <= clamped)
  const speaking = voice.speakingId === 'page'
  const voiceLabel = speaking ? (voice.status === 'loading' ? (voice.progress > 0 && voice.progress < 1 ? `Getting the voice ready · ${Math.round(voice.progress * 100)}%` : 'Getting the voice ready…') : 'Stop reading') : 'Read aloud'

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
        <div className="row" style={{ gap: 8, position: 'relative' }}>
          <button className="btn soft small-btn" aria-pressed={speaking} onClick={() => (speaking ? stop() : speak(pageText, 'page'))} disabled={!pageText}>
            <SpeakerIcon on={speaking} /> {voiceLabel}
          </button>
          <button className="icon-btn" aria-label="Choose a voice" aria-expanded={voiceMenu} onClick={() => setVoiceMenu((v) => !v)}>
            <svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" /></svg>
          </button>
          {voiceMenu && (
            <div className="menu card" role="menu" aria-label="Voices">
              <p className="eyebrow paper" style={{ padding: '6px 12px 8px' }}>Kokoro voices</p>
              {voices.map((v) => (
                <button key={v.id} role="menuitemradio" aria-checked={voiceId === v.id} className={voiceId === v.id ? 'on' : ''} onClick={() => { chooseVoice(v.id); setVoiceMenu(false); speak(`Hello, I'm ${v.name}. I'll read with you.`, 'preview') }}>
                  <strong>{v.name}</strong><span className="muted small">{v.note}</span>
                </button>
              ))}
              <p className="muted small" style={{ padding: '8px 12px 4px', maxWidth: 260 }}>The voice downloads once (about 90 MB) and then reads offline. Until then, your system voice reads.</p>
            </div>
          )}
        </div>
      </div>

      {voice.notice && (
        <p className="voice-notice" role="status">
          {voice.notice} <button className="link small" onClick={dismissNotice}>OK</button>
        </p>
      )}
      <div className="reader-grid">
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

        <article className="reader-paper" ref={paper} onMouseUp={onMouseUp} aria-label={`Page ${clamped} of ${pages}`}>
          <p className="eyebrow paper page-eyebrow">{current?.title ?? book.title} · page {clamped}</p>
          {mode === 'original' ? (
            <canvas ref={canvas} className="original-page" role="img" aria-label={`The original page ${clamped}`} />
          ) : blocks === null ? (
            <div className="paper-loading" aria-live="polite"><span className="sr-only">Opening the page…</span><i /><i /><i /></div>
          ) : blocks.length === 0 ? (
            <p className="muted">This page has no text Leu can read (it may be a picture). Try “Original page”.</p>
          ) : (
            <div className="prose">
              {blocks.map((b, i) => (b.kind === 'heading' ? <h2 key={i}>{b.text}</h2> : <p key={i}>{b.text}</p>))}
            </div>
          )}
          {selection && (
            <div className="selection-menu" style={{ left: selection.x, top: selection.y }} role="toolbar" aria-label="With this passage">
              <button onMouseDown={(e) => e.preventDefault()} onClick={() => { setDraft({ quote: selection.text, note: '' }); setSelection(null) }}>Keep a note</button>
              <button onMouseDown={(e) => e.preventDefault()} onClick={() => { setExplain(selection.text); setSelection(null) }}>Explain</button>
              <button onMouseDown={(e) => e.preventDefault()} onClick={() => { speak(selection.text, 'selection'); setSelection(null) }}>Read aloud</button>
            </div>
          )}
        </article>

        <aside className="margin" aria-label="In the margin">
          <p className="eyebrow">In the margin</p>
          {draft && (
            <form className="note-draft card" onSubmit={(e) => { e.preventDefault(); addNote({ bookId: id, page: clamped, quote: draft.quote, note: draft.note.trim() }); setDraft(null) }}>
              <blockquote className="serif">“{draft.quote.length > 220 ? draft.quote.slice(0, 220) + '…' : draft.quote}”</blockquote>
              <textarea className="field" autoFocus rows={3} placeholder="Your thought (optional)" value={draft.note} onChange={(e) => setDraft({ ...draft, note: e.target.value })} aria-label="Your note" />
              <div className="row" style={{ gap: 10, marginTop: 10 }}>
                <button className="btn ink small-btn" type="submit">Keep it</button>
                <button className="quiet-link small" type="button" onClick={() => setDraft(null)}>Cancel</button>
              </div>
            </form>
          )}
          {notes.map((n) => (
            <div key={n.id} className="margin-note">
              <blockquote className="serif">“{n.quote.length > 180 ? n.quote.slice(0, 180) + '…' : n.quote}”</blockquote>
              {n.note && <p>{n.note}</p>}
              <button className="quiet-link small" onClick={() => removeNote(n.id)} aria-label="Remove this note">Remove</button>
            </div>
          ))}
          {!draft && !notes.length && <p className="muted small">Select any line to keep a note, ask for an explanation, or hear it read.</p>}
          <div className="divider" style={{ margin: '20px 0' }} />
          <button className="btn butter-btn" style={{ width: '100%' }} onClick={() => setExplain(pageText)} disabled={!pageText}>Explain this page simply</button>
          <button className="btn soft" style={{ width: '100%', marginTop: 10 }} onClick={() => go({ name: 'words', id, page: clamped })}>Say it in your own words</button>
        </aside>
      </div>

      <div className="reader-foot">
        <button className="btn soft small-btn" onClick={() => turn(clamped - 1)} disabled={clamped <= 1} aria-label="Previous page">← Previous</button>
        <label className="page-slider">
          <span className="sr-only">Page</span>
          <input type="range" min={1} max={pages} value={clamped} onChange={(e) => turn(Number(e.target.value))} aria-valuetext={`Page ${clamped} of ${pages}`} />
          <span className="tabular">page {clamped} of {pages}</span>
        </label>
        <button className="btn ink small-btn" onClick={() => turn(clamped + 1)} disabled={clamped >= pages} aria-label="Next page">Next →</button>
      </div>

      {explain && <Explain bookId={id} bookTitle={book.title} page={clamped} passage={explain} onClose={() => setExplain(null)} />}
    </div>
  )
}

function SpeakerIcon({ on }: { on: boolean }) {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M4 9h4l5-4v14l-5-4H4z" fill="currentColor" />
      {on ? <path d="M16 9.5a4 4 0 0 1 0 5M18.5 7a7.5 7.5 0 0 1 0 10" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" /> : <path d="M16.5 9.5a3.5 3.5 0 0 1 0 5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />}
    </svg>
  )
}
