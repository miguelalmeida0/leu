import { useEffect, useMemo, useRef, useState } from 'react'
import { Empty } from '../components/ui'
import { go } from '../lib/router'
import { allText, memoryState, reviewMemory, upsertMemory, useStore, type Memory } from '../lib/store'
import { cloze, ideas } from '../lib/text'

type Way = 'remember' | 'explain' | 'questions'
const ways: { id: Way; label: string }[] = [
  { id: 'remember', label: 'remember what I read' },
  { id: 'explain', label: 'explain it my way' },
  { id: 'questions', label: 'answer a few questions' },
]
const times = [5, 10, 20]

/** A patch in the sentence that opens a small menu of choices. */
function Choice<T extends string | number>({ label, value, options, onChange }: { label: string; value: T; options: { id: T; label: string }[]; onChange: (v: T) => void }) {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLSpanElement>(null)
  useEffect(() => {
    if (!open) return
    const close = (e: PointerEvent) => { if (!ref.current?.contains(e.target as Node)) setOpen(false) }
    const escape = (e: KeyboardEvent) => { if (e.key === 'Escape') setOpen(false) }
    window.addEventListener('pointerdown', close, true)
    window.addEventListener('keydown', escape)
    return () => { window.removeEventListener('pointerdown', close, true); window.removeEventListener('keydown', escape) }
  }, [open])
  const current = options.find((o) => o.id === value)
  return (
    <span className="choice" ref={ref}>
      <button className="choice-patch" aria-haspopup="listbox" aria-expanded={open} aria-label={`${label}: ${current?.label}. Change`} onClick={() => setOpen((o) => !o)}>
        {current?.label}
        <svg width="14" height="14" viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" /></svg>
      </button>
      {open && (
        <span className="menu card choice-menu" role="listbox" aria-label={label}>
          {options.map((o) => (
            <button key={String(o.id)} role="option" aria-selected={o.id === value} className={o.id === value ? 'on' : ''} onClick={() => { onChange(o.id); setOpen(false) }}>{o.label}</button>
          ))}
        </span>
      )}
    </span>
  )
}

/** Study (09b): the session as one sentence of felt patches. Nothing is scored. */
export function Study() {
  const books = useStore((s) => s.books)
  const memory = useStore((s) => s.memory)
  const [way, setWay] = useState<Way>('remember')
  const [subject, setSubject] = useState<string>('all')
  const [minutes, setMinutes] = useState(10)
  const [session, setSession] = useState<Memory[] | null>(null)
  const [preparing, setPreparing] = useState(false)

  const subjects = useMemo(() => [{ id: 'all', label: 'anything I’ve read' }, ...books.map((b) => ({ id: b.id, label: b.title }))], [books])
  const pool = memory.filter((m) => subject === 'all' || m.bookId === subject)
  const due = pool.filter((m) => memoryState(m) !== 'held')
  const subjectName = subjects.find((s) => s.id === subject)?.label ?? 'your books'
  const count = way === 'questions' ? Math.max(3, Math.round(minutes / 2.5)) : Math.max(3, Math.round(minutes * 0.8))

  if (!books.length) return <div className="page"><Empty title="Nothing to study yet."><p className="muted">Bring a PDF and read a page or two first.</p></Empty></div>

  const start = async () => {
    if (way === 'explain') {
      const b = subject === 'all' ? [...books].sort((x, y) => (y.lastOpenedAt ?? 0) - (x.lastOpenedAt ?? 0))[0] : books.find((x) => x.id === subject)!
      go({ name: 'words', id: b.id, page: b.page })
      return
    }
    setPreparing(true)
    // Cards from what you've read; if there aren't enough yet, from the pages around where you are.
    if (due.length < count) {
      const lib = await allText()
      const extra: Memory[] = []
      for (const b of books.filter((x) => subject === 'all' || x.id === subject)) {
        const pages = lib.get(b.id) ?? []
        for (let p = 1; p <= Math.min(pages.length, Math.max(b.page, 3)); p++) {
          ideas(pages[p - 1], 2).forEach((idea, i) => {
            const c = cloze(idea.text, pages[p - 1])
            if (c) extra.push({ id: `${b.id}:${p}:${i}`, bookId: b.id, page: p, prompt: c.prompt, answer: c.answer, due: 0, strength: 0 })
          })
        }
      }
      upsertMemory(extra)
      const known = new Set(due.map((m) => m.id))
      setSession([...due, ...extra.filter((m) => !known.has(m.id))].slice(0, count))
    } else setSession(due.slice(0, count))
    setPreparing(false)
  }

  if (session) return <Session cards={session} way={way} onDone={() => setSession(null)} />

  const steps = way === 'remember'
    ? ['You see a prompt and bring the answer back before looking.', 'Then the page itself, so you can check what you remembered.', 'What you get right comes back later, spaced out so it sticks. Whatever slipped comes back sooner.']
    : way === 'questions'
      ? [`Leu asks ${count} open questions about ${subjectName}.`, 'Answer at your own pace, in your own words.', 'Every question links to the line it came from.']
      : ['You explain the bit you were reading, the way you’d tell a friend.', 'Leu listens for the ideas the page makes, and lights a window for each.', 'Anything you skipped is shown in the page’s own words.']

  return (
    <div className="study page fade-in">
      <p className="eyebrow">Plan your study</p>
      <h1 className="study-sentence display">
        I'd like to <Choice label="How to study" value={way} options={ways} onChange={setWay} /> using{' '}
        <Choice label="Subject" value={subject} options={subjects} onChange={setSubject} />, for about{' '}
        <Choice label="Time" value={minutes} options={times.map((t) => ({ id: t, label: `${t} minutes` }))} onChange={setMinutes} />.
      </h1>
      <div className="study-grid">
        <div className="card study-next">
          <p className="eyebrow paper">What happens next</p>
          <ol>{steps.map((s, i) => <li key={i}><span className="step-n" aria-hidden="true">{i + 1}</span>{s}</li>)}</ol>
          <div className="row" style={{ gap: 16, marginTop: 22 }}>
            <button className="btn ink" disabled={preparing} onClick={() => void start()}>
              {preparing ? 'Preparing study material from your books…' : way === 'explain' ? 'Start explaining' : way === 'remember' ? 'Start remembering' : `Start, about ${minutes} minutes`}
            </button>
          </div>
          <p className="muted small" style={{ marginTop: 14 }}>Nothing is scored. You can stop any time.</p>
        </div>
        <div className="study-memory">
          <p className="eyebrow">What you're holding</p>
          <ul className="memory-list">
            <li><span className="dot" style={{ background: 'var(--held)' }} />{countHeld(pool, 'held')} held</li>
            <li><span className="dot" style={{ background: 'var(--tomato)' }} />{countHeld(pool, 'fading') + countHeld(pool, 'due')} ready to come back</li>
            <li><span className="dot" style={{ background: 'var(--labs)' }} />{countHeld(pool, 'new')} not asked yet</li>
          </ul>
          <p className="muted small">Pages you stay on for a few seconds become things Leu can ask you later.</p>
        </div>
      </div>
    </div>
  )
}

const countHeld = (pool: Memory[], s: ReturnType<typeof memoryState>) => pool.filter((m) => memoryState(m) === s).length

function Session({ cards, way, onDone }: { cards: Memory[]; way: Way; onDone: () => void }) {
  const books = useStore((s) => s.books)
  const [i, setI] = useState(0)
  const [shown, setShown] = useState(false)
  const [answer, setAnswer] = useState('')
  const [kept, setKept] = useState(0)
  const card = cards[i]

  if (!cards.length) return <div className="page"><Empty title="Nothing to study on this subject yet."><p className="muted">Try anything you've read.</p><button className="btn soft" onClick={onDone}>Back</button></Empty></div>
  if (!card) {
    return (
      <div className="page fade-in session-end">
        <p className="eyebrow">That's the session</p>
        <h1 className="display" style={{ fontSize: 48, marginTop: 10 }}>{kept === cards.length ? 'Every one came back.' : kept ? `${kept} came back. The rest return sooner.` : 'Those return sooner. That’s how it sticks.'}</h1>
        <div className="row" style={{ gap: 16, marginTop: 26 }}>
          <button className="btn ink" onClick={onDone}>Done</button>
          <button className="quiet-link" onClick={() => go({ name: 'read', id: cards[0].bookId, page: cards[0].page })}>Back to reading</button>
        </div>
      </div>
    )
  }
  const book = books.find((b) => b.id === card.bookId)
  const next = (remembered: boolean) => { reviewMemory(card.id, remembered); if (remembered) setKept((k) => k + 1); setShown(false); setAnswer(''); setI((n) => n + 1) }
  const close = answer.trim().toLowerCase().replace(/[^a-z]/g, '') === card.answer.toLowerCase().replace(/[^a-z]/g, '')

  return (
    <div className="session page fade-in">
      <div className="row" style={{ justifyContent: 'space-between' }}>
        <p className="eyebrow">{way === 'questions' ? 'A question' : 'From memory'} · {i + 1} of {cards.length}</p>
        <button className="quiet-link small" onClick={onDone}>Stop for now</button>
      </div>
      <div className="session-dots" aria-hidden="true">{cards.map((_, n) => <span key={n} className={n < i ? 'done' : n === i ? 'on' : ''} />)}</div>
      <div className="card recall">
        <p className="eyebrow paper">{book?.title} · p. {card.page}</p>
        <p className="recall-prompt serif">{card.prompt.split('_____').map((part, n, all) => <span key={n}>{part}{n < all.length - 1 && <span className="blank">{shown ? card.answer : '   '}</span>}</span>)}</p>
        {!shown ? (
          <form onSubmit={(e) => { e.preventDefault(); setShown(true) }} className="row" style={{ gap: 12, marginTop: 20 }}>
            <input className="field" style={{ maxWidth: 320 }} autoFocus value={answer} onChange={(e) => setAnswer(e.target.value)} placeholder="The missing word" aria-label="The missing word" />
            <button className="btn ink" type="submit">Show the page's words</button>
          </form>
        ) : (
          <div className="fade-in" style={{ marginTop: 20 }}>
            {answer && <p className={close ? 'held-text' : 'muted'}>{close ? 'That’s the word the page uses.' : `You said “${answer}”. The page says “${card.answer}”.`}</p>}
            <div className="row" style={{ gap: 12, marginTop: 14 }}>
              <button className="btn ink" autoFocus onClick={() => next(true)}>I had it</button>
              <button className="btn soft" onClick={() => next(false)}>Not yet</button>
              <a className="quiet-link" href={`#/read/${card.bookId}/${card.page}`}>Open page {card.page}</a>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
