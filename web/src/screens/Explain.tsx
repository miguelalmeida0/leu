import { useEffect, useRef, useState } from 'react'
import { go } from '../lib/router'
import { allText } from '../lib/store'
import { ideas, isIdeaWord, quoteAround, words } from '../lib/text'
import { speak, stop, useVoice } from '../lib/voice'

/** The short version of a passage. */
export function gistOf(passage: string): string[] {
  const short = ideas(passage, 2)
  return short.length ? short.map((i) => i.text) : [passage.slice(0, 280)]
}

/** Explain (07), as a quiet sheet in the margin beside the page it explains, so the passage
    stays in view (the sentences it draws on are marked there). The browser has no model, so it
    says so and keeps to the passage's own words. */
export function ExplainPanel({ bookId, page, passage, onClose }: { bookId: string; page: number; passage: string; onClose: () => void }) {
  const voice = useVoice()
  const [terms, setTerms] = useState<{ term: string; page: number; line: string }[]>([])
  const [open, setOpen] = useState<string | null>(null)
  const ref = useRef<HTMLElement>(null)
  const gist = gistOf(passage)

  useEffect(() => { ref.current?.focus() }, [passage])
  useEffect(() => {
    const key = (e: KeyboardEvent) => { if (e.key === 'Escape') { stop(); onClose() } }
    window.addEventListener('keydown', key)
    return () => window.removeEventListener('keydown', key)
  }, [onClose])

  useEffect(() => {
    // Words to know: the passage's most specific words, where else this book uses them.
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
      setTerms(found)
    })
  }, [bookId, page, passage])

  const speaking = voice.speakingId === 'explain'
  const close = () => { stop(); onClose() }
  return (
    <section className="explain-panel" ref={ref} tabIndex={-1} aria-label="Explained simply" aria-live="polite">
      <div className="explain-head">
        <p className="eyebrow paper"><span className="dot" style={{ background: 'var(--butter)' }} /> Explained simply · p. {page}</p>
        <button className="icon-btn small" onClick={close} aria-label="Close and go back to reading">
          <svg width="14" height="14" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" /></svg>
        </button>
      </div>
      <h2 className="explain-title">The short version</h2>
      <div className="explain-gist serif">{gist.map((g, i) => <p key={i}>{g}</p>)}</div>
      <p className="explain-where small">Marked on the page, so you can see where it comes from.</p>

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
        <button className="btn soft" aria-pressed={speaking} onClick={() => (speaking ? stop() : speak(gist, 'explain'))}>{speaking ? 'Stop reading' : 'Read it aloud'}</button>
      </div>
      <p className="explain-note small">This browser preview has no model, so these are the passage's own key sentences. The app writes the explanation on your device, from this passage only.</p>
    </section>
  )
}
