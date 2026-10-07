import { useEffect, useState } from 'react'
import { Modal } from '../components/ui'
import { go } from '../lib/router'
import { allText } from '../lib/store'
import { ideas, isIdeaWord, quoteAround, words } from '../lib/text'
import { speak, stop, useVoice } from '../lib/voice'

/** Explain (07): the butter card. In the app this is written on device from the passage only;
    the browser has no model, so it says so and shows the sentences that carry the passage. */
export function Explain({ bookId, bookTitle, page, passage, onClose }: { bookId: string; bookTitle: string; page: number; passage: string; onClose: () => void }) {
  const voice = useVoice()
  const [terms, setTerms] = useState<{ term: string; where: string }[]>([])
  const [showOriginal, setShowOriginal] = useState(false)
  const short = ideas(passage, 2)
  const gist = short.length ? short.map((i) => i.text) : [passage.slice(0, 280)]

  useEffect(() => {
    // Words to know: the passage's longest content words, said elsewhere in the same book.
    void allText().then((lib) => {
      const pages = lib.get(bookId) ?? []
      const candidates = [...new Set((passage.match(/\b[A-Za-z][A-Za-z-]{6,}\b/g) ?? []).map((w) => w.toLowerCase()))]
        .filter((w) => words(w).length && isIdeaWord(w)).slice(0, 12)
      const found: { term: string; where: string }[] = []
      for (const term of candidates) {
        const other = pages.findIndex((t, i) => i !== page - 1 && t.toLowerCase().includes(term))
        if (other >= 0) found.push({ term, where: `p. ${other + 1}: ${quoteAround(pages[other], term)}` })
        if (found.length === 3) break
      }
      setTerms(found)
    })
  }, [bookId, page, passage])

  const speaking = voice.speakingId === 'explain'
  return (
    <Modal label="Explain simply" onClose={() => { stop(); onClose() }} width={680} tone="butter">
      <div className="explain">
        <p className="eyebrow" style={{ color: '#4A3A10' }}>Explained simply · {bookTitle} · p. {page}</p>
        <h2 className="display" style={{ fontSize: 34, marginTop: 10 }}>The short version</h2>
        <div className="explain-gist serif">{gist.map((g, i) => <p key={i}>{g}</p>)}</div>
        {terms.length > 0 && (
          <>
            <p className="eyebrow" style={{ color: '#4A3A10', marginTop: 22 }}>Words to know</p>
            <dl className="terms">
              {terms.map((t) => <div key={t.term}><dt>{t.term}</dt><dd>{t.where}</dd></div>)}
            </dl>
          </>
        )}
        <button className="link small" style={{ marginTop: 16 }} aria-expanded={showOriginal} onClick={() => setShowOriginal((s) => !s)}>{showOriginal ? 'Hide original passage' : 'Show original passage'}</button>
        {showOriginal && <blockquote className="serif original">{passage}</blockquote>}
        <p className="explain-note small">Browser preview: there is no on-device model here, so these are the passage's own key sentences. In the app, Leu writes the explanation on your device from this passage only.</p>
        <p className="eyebrow" style={{ color: '#4A3A10', marginTop: 18 }}>What next</p>
        <div className="row" style={{ gap: 12, marginTop: 10, flexWrap: 'wrap' }}>
          <button className="btn ink" onClick={() => { stop(); onClose(); go({ name: 'words', id: bookId, page }) }}>Explain it in your own words</button>
          <button className="btn cream" onClick={() => (speaking ? stop() : speak(gist.join(' '), 'explain'))}>{speaking ? 'Stop reading' : 'Read it aloud'}</button>
          <button className="quiet-link" onClick={() => { stop(); onClose() }}>Back to reading</button>
        </div>
      </div>
    </Modal>
  )
}
