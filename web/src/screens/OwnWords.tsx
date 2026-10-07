import { useEffect, useMemo, useRef, useState } from 'react'
import { Empty } from '../components/ui'
import { go, href } from '../lib/router'
import { loadText, saveAttempt, useStore } from '../lib/store'
import { compare, ideas, label, type Idea } from '../lib/text'
import { SnowGlobe } from '../scenes/SnowGlobe'

type Recognition = { start(): void; stop(): void; continuous: boolean; interimResults: boolean; lang: string; onresult: (e: { results: ArrayLike<ArrayLike<{ transcript: string }> & { isFinal: boolean }> }) => void; onend: () => void }
const SpeechRecognition = (window as unknown as { SpeechRecognition?: new () => Recognition; webkitSpeechRecognition?: new () => Recognition }).SpeechRecognition
  ?? (window as unknown as { webkitSpeechRecognition?: new () => Recognition }).webkitSpeechRecognition

/** In your own words (08 / 10b): explain the page like you'd tell a curious friend. Each idea
    that gets across lights a window in the snow globe; only every idea lights the third. */
export function OwnWords({ id, page }: { id: string; page: number }) {
  const book = useStore((s) => s.books.find((b) => b.id === id))
  const key = `${id}:${page}`
  const saved = useStore((s) => s.attempts[key])
  const [list, setList] = useState<Idea[] | null>(null)
  const [text, setText] = useState(saved?.text ?? '')
  const [result, setResult] = useState<{ across: Idea[]; loose: Idea[] } | null>(null)
  const [checking, setChecking] = useState(false)
  const [listening, setListening] = useState(false)
  const [peek, setPeek] = useState(false)
  const [pageText, setPageText] = useState('')
  const rec = useRef<Recognition | null>(null)
  const area = useRef<HTMLTextAreaElement>(null)

  useEffect(() => {
    void loadText(id).then((pages) => {
      // Find a page with enough to say, starting from the one asked for.
      let n = page
      while (n <= pages.length && ideas(pages[n - 1] ?? '').length < 2) n++
      const at = n <= pages.length ? n : page
      if (at !== page) { go({ name: 'words', id, page: at }, true); return }
      setPageText(pages[at - 1] ?? '')
      setList(ideas(pages[at - 1] ?? ''))
    })
  }, [id, page])

  useEffect(() => {
    if (saved?.checkedAt && list) setResult({ across: list.filter((i) => saved.across.includes(i.id)), loose: list.filter((i) => !saved.across.includes(i.id)) })
  }, [list]) // restore a previous check once the ideas are known

  const lit = useMemo(() => {
    if (!result || !list?.length) return 0
    const n = result.across.length, total = list.length
    return n >= total ? 3 : Math.min(2, Math.floor((n / total) * 3))
  }, [result, list])

  if (!book) return <div className="page"><Empty title="That book isn't here any more." /></div>

  const check = () => {
    if (!list) return
    setChecking(true)
    setTimeout(() => {
      const r = compare(text, list)
      setResult(r)
      setChecking(false)
      saveAttempt({ key, text, across: r.across.map((i) => i.id), checkedAt: Date.now() })
    }, 900)
  }

  const listen = () => {
    if (!SpeechRecognition) return
    if (listening) { rec.current?.stop(); return }
    const r = new SpeechRecognition()
    r.continuous = true; r.interimResults = false; r.lang = 'en-US'
    const before = text
    r.onresult = (e) => {
      const said = Array.from(e.results).map((x) => x[0].transcript).join(' ')
      setText((before ? before.trimEnd() + ' ' : '') + said)
    }
    r.onend = () => setListening(false)
    rec.current = r
    r.start(); setListening(true)
  }

  const allAcross = result && list && result.across.length === list.length
  return (
    <div className="words page fade-in">
      <nav className="crumbs" aria-label="Breadcrumb">
        <a href={href({ name: 'book', id })}>{book.title}</a><span aria-hidden="true">/</span>
        <a href={href({ name: 'read', id, page })}>page {page}</a>
      </nav>
      <div className="words-grid">
        <section className="words-globe">
          <SnowGlobe lit={lit} />
          <p className="globe-caption" aria-live="polite">
            {!result ? 'Each idea you get across lights a window.' : allAcross ? 'Every idea got across. The whole cottage is lit.' : result.across.length ? `${result.across.length} of ${list!.length} ideas got across. Every idea lights the last window.` : 'No window yet. Peek at the page, then say it again.'}
          </p>
        </section>

        <section className="words-write">
          <p className="eyebrow">In your own words · page {page}</p>
          <h1 className="display" style={{ fontSize: 46, marginTop: 10 }}>Tell it to a curious friend.</h1>
          <p className="lede" style={{ marginTop: 12 }}>Say it the way you'd tell a curious friend. No need for the right words, just the right idea.</p>

          <div className="listening card">
            <p className="eyebrow paper">What Leu is listening for</p>
            <ol>
              {(list ?? []).map((idea) => {
                const across = result?.across.includes(idea)
                return (
                  <li key={idea.id} className={across ? 'across' : result ? 'loose' : ''}>
                    <span className="idea-dot" aria-hidden="true" />
                    <span>{result ? label(idea) : `Something about ${hint(idea)}`}{result && <span className="sr-only">{across ? ', got across' : ', not yet'}</span>}</span>
                  </li>
                )
              })}
            </ol>
          </div>

          <label className="sr-only" htmlFor="explanation">Your explanation</label>
          <textarea
            id="explanation"
            ref={area}
            className="field explanation serif"
            rows={7}
            placeholder="Start anywhere. What happens, and why?"
            value={text}
            onChange={(e) => setText(e.target.value)}
          />
          <div className="row" style={{ gap: 12, marginTop: 14, flexWrap: 'wrap' }}>
            <button className="btn ink" disabled={text.trim().split(/\s+/).length < 5 || checking || !list} onClick={check}>{checking ? 'Comparing with the page…' : result ? 'Check again' : 'See what got across'}</button>
            {SpeechRecognition && <button className="btn soft" aria-pressed={listening} onClick={listen}>{listening ? 'Listening… tap to stop' : 'Say it instead'}</button>}
            <button className="quiet-link" aria-expanded={peek} onClick={() => setPeek((p) => !p)}>{peek ? 'Hide the page' : `Peek at page ${page}`}</button>
          </div>

          {result && result.loose.length > 0 && (
            <div className="from-source fade-in">
              <p className="eyebrow">From your source</p>
              {result.loose.map((idea) => <blockquote key={idea.id} className="serif">“{idea.text}”</blockquote>)}
              <button className="link small" onClick={() => area.current?.focus()}>Say it again</button>
            </div>
          )}
          {allAcross && (
            <div className="row fade-in" style={{ gap: 14, marginTop: 22 }}>
              <button className="btn soft" onClick={() => go({ name: 'words', id, page: page + 1 })}>Try the next page</button>
              <button className="quiet-link" onClick={() => go({ name: 'read', id, page })}>Back to reading</button>
            </div>
          )}
          {peek && <blockquote className="peek serif fade-in">{pageText}</blockquote>}
          <p className="muted small" style={{ marginTop: 18 }}>Compared in this browser by the words each idea needs, in any order. The app checks against the source on your device.</p>
        </section>
      </div>
    </div>
  )
}

/** A nudge, not the answer: the idea's most specific word, as the page spells it. */
function hint(idea: Idea): string {
  const key = [...idea.keys].sort((a, b) => b.length - a.length)[0] ?? ''
  const word = idea.text.match(new RegExp(`\\b${key}[a-z]*`, 'i'))?.[0] ?? key
  return word.toLowerCase()
}
