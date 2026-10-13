import { useEffect, useRef, useState } from 'react'
import { go } from '../lib/router'
import { allText } from '../lib/store'
import { ideas, isIdeaWord, quoteAround, words } from '../lib/text'
import {
  explanationAvailability, generateLocalExplanation, passageContext, type Explanation, type ModelAvailability,
} from '../lib/explanation'
import { speak, stop, useVoice } from '../lib/voice'

/** Exact source sentences, used only for source highlighting—not as an explanation. */
export function gistOf(passage: string): string[] {
  const short = ideas(passage, 2)
  return short.length ? short.map((idea) => idea.text) : [passage.slice(0, 280)]
}

type Stage = 'checking' | 'working' | 'ready' | 'unavailable' | 'downloadable' | 'downloading' | 'error'

/** Explain beside the text, using a real on-device model when the browser supports it.
 * The source remains local; absent a model, do not misrepresent extracts as explanations. */
export function ExplainPanel({
  bookId, page, passage, pageText, onClose,
}: { bookId: string; page: number; passage: string; pageText: string; onClose: () => void }) {
  const voice = useVoice()
  const [terms, setTerms] = useState<{ term: string; page: number; line: string }[]>([])
  const [open, setOpen] = useState<string | null>(null)
  const [stage, setStage] = useState<Stage>('checking')
  const [lesson, setLesson] = useState<Explanation | null>(null)
  const [error, setError] = useState('')
  const [progress, setProgress] = useState<number | null>(null)
  const ref = useRef<HTMLElement>(null)
  const request = useRef(0)
  const active = useRef<AbortController | null>(null)

  const start = (controller: AbortController, ticket: number) => {
    setStage('working')
    setLesson(null)
    setError('')
    setProgress(null)
    void generateLocalExplanation(passage, passageContext(pageText, passage), controller.signal, (fraction) => {
      if (ticket === request.current && !controller.signal.aborted) setProgress(Math.min(1, Math.max(0, fraction)))
    }).then((result) => {
      if (ticket === request.current && !controller.signal.aborted) {
        setLesson(result)
        setStage('ready')
      }
    }).catch((reason: unknown) => {
      if (ticket === request.current && !controller.signal.aborted) {
        setError(reason instanceof Error ? reason.message : 'The explanation could not be generated.')
        setStage('error')
      }
    })
  }

  useEffect(() => {
    ref.current?.focus()
    const controller = new AbortController()
    active.current = controller
    const ticket = ++request.current
    setStage('checking')
    void explanationAvailability().then((availability: ModelAvailability) => {
      if (controller.signal.aborted || ticket !== request.current) return
      if (availability === 'available') start(controller, ticket)
      else setStage(availability)
    })
    return () => {
      active.current?.abort()
      controller.abort()
      request.current++
    }
  }, [passage, pageText])

  useEffect(() => {
    let live = true
    void allText().then((lib) => {
      const pages = lib.get(bookId) ?? []
      const candidates = [...new Set((passage.match(/\b[A-Za-z][A-Za-z-]{6,}\b/g) ?? []).map((w) => w.toLowerCase()))]
        .filter((w) => words(w).length && isIdeaWord(w)).slice(0, 12)
      const found: { term: string; page: number; line: string }[] = []
      for (const term of candidates) {
        const other = pages.findIndex((t, i) => i !== page - 1 && t.toLowerCase().includes(term))
        if (other >= 0) found.push({ term, page: other + 1, line: quoteAround(pages[other], term) })
        if (found.length === 3) break
      }
      if (live) setTerms(found)
    })
    return () => { live = false }
  }, [bookId, page, passage])

  const tryAgain = () => {
    active.current?.abort()
    const controller = new AbortController()
    active.current = controller
    start(controller, ++request.current)
  }
  const close = () => {
    request.current++
    active.current?.abort()
    stop()
    onClose()
  }

  useEffect(() => {
    const key = (event: KeyboardEvent) => { if (event.key === 'Escape') close() }
    window.addEventListener('keydown', key)
    return () => window.removeEventListener('keydown', key)
  })

  const speaking = voice.speakingId === 'explain'
  const lessonText = lesson ? [lesson.meaning, lesson.mechanism, lesson.example, lesson.caveat].filter(Boolean) : []

  return (
    <section className="explain-panel" ref={ref} tabIndex={-1} aria-label="Passage explanation">
      <div className="explain-head">
        <p className="eyebrow paper"><span className="dot" style={{ background: 'var(--butter)' }} /> {stage === 'ready' ? 'Explained on your device' : 'Your passage'} · p. {page}</p>
        <button className="icon-btn small" onClick={close} aria-label="Close and go back to reading">
          <svg width="14" height="14" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" /></svg>
        </button>
      </div>
      <h2 className="explain-title">{stage === 'ready' ? 'What this means' : stage === 'unavailable' ? 'Explanation unavailable' : 'Explain this passage'}</h2>

      {stage === 'ready' && lesson && (
        <div className="explain-lesson">
          <p className="explain-meaning serif">{lesson.meaning}</p>
          <h3>How it works</h3>
          <p>{lesson.mechanism}</p>
          {lesson.example && <><h3>For example</h3><p>{lesson.example}</p></>}
          {lesson.caveat && <p className="explain-caveat">{lesson.caveat}</p>}
          <p className="explain-where small">Generated on this device. Compare with the highlighted source.</p>
        </div>
      )}

      {(stage === 'checking' || stage === 'working') && (
        <div className="explain-state" role="status" aria-live="polite">
          <p>{stage === 'checking' ? 'Checking for an on-device model…'
            : progress === null ? 'Explaining this passage on your device…'
              : 'Setting up the local model · ' + Math.round(progress * 100) + '%'}</p>
          <p className="small">Your book stays in this browser.</p>
        </div>
      )}

      {(stage === 'downloadable' || stage === 'downloading') && (
        <div className="explain-state">
          <p>Leu can explain this with Chrome’s private on-device model. Chrome needs to download it before the first use.</p>
          <button type="button" className="btn ink" onClick={tryAgain}>Enable private explanations</button>
          <p className="small">The model download needs an internet connection; your PDF text never leaves the device.</p>
        </div>
      )}

      {stage === 'unavailable' && (
        <div className="explain-state" role="status">
          <p>On-device explanations aren't available in this browser or on this device.</p>
          <p className="small">Leu won't pass off copied sentences as an explanation or upload your book to another service.</p>
        </div>
      )}

      {stage === 'error' && (
        <div className="explain-state" role="alert">
          <p>{error}</p>
          <p className="small">Leu could not produce a useful explanation this time. The source is still available below.</p>
          <button type="button" className="btn soft" onClick={tryAgain}>Try again</button>
        </div>
      )}

      <details className="explain-source">
        <summary>Selected passage from page {page}</summary>
        <blockquote>{passage}</blockquote>
      </details>

      {terms.length > 0 && (
        <div className="explain-terms">
          <p className="eyebrow paper">Words to know</p>
          <ul>
            {terms.map((t) => (
              <li key={t.term}>
                <button aria-expanded={open === t.term} onClick={() => setOpen(open === t.term ? null : t.term)}>
                  <span>{t.term}</span><span className="muted small">p. {t.page}</span>
                </button>
                {open === t.term && <p className="serif term-line fade-in">“{t.line}”</p>}
              </li>
            ))}
          </ul>
        </div>
      )}

      <div className="explain-actions">
        <button className="btn ink" onClick={() => { close(); go({ name: 'words', id: bookId, page }) }}>Explain it in your own words</button>
        {lesson && <button className="btn soft" aria-pressed={speaking} onClick={() =>
          (speaking ? stop() : speak(lessonText, 'explain'))
        }>{speaking ? 'Stop reading' : 'Read explanation aloud'}</button>}
      </div>
    </section>
  )
}
