import { Empty, countWords } from '../components/ui'
import { go, href } from '../lib/router'
import { palettes, saveTrail, useStore, type Trail } from '../lib/store'

/** Trails (13): a walk of felt patches joined by thread. Each stop is a passage in one of
    your books; walking it means reading them in order. */
export function Trails({ id }: { id?: string }) {
  const trails = useStore((s) => s.trails)
  if (!trails.length) {
    return (
      <div className="page"><Empty title="No trails yet.">
        <p className="muted">A trail walks one idea through your books, a passage at a time. Make one from Explore.</p>
        <a className="btn ink" href={href({ name: 'explore' })} style={{ marginTop: 16 }}>Go to Explore</a>
      </Empty></div>
    )
  }
  const trail = trails.find((t) => t.id === id) ?? trails[0]
  return (
    <div className="trails page fade-in">
      <aside className="trail-list" aria-label="Your trails">
        <p className="eyebrow">Your trails</p>
        <ul>
          {trails.map((t) => (
            <li key={t.id}>
              <a href={href({ name: 'trails', id: t.id })} aria-current={t === trail ? 'page' : undefined}>
                <strong>{t.title}</strong>
                <span className="muted small">{countWords(t.stops.length, 'stop')}{t.current >= t.stops.length ? ' · walked' : t.current ? ` · at stop ${t.current + 1}` : ''}</span>
              </a>
            </li>
          ))}
        </ul>
      </aside>
      <Walk trail={trail} />
    </div>
  )
}

function Walk({ trail }: { trail: Trail }) {
  const books = useStore((s) => s.books)
  const n = trail.stops.length
  // A gentle zigzag, laid out in a 1000-wide space; the thread runs through each patch's centre.
  const W = 1000, rowH = 170, cols = 3
  const points = trail.stops.map((_, i) => {
    const row = Math.floor(i / cols), col = i % cols
    const x = 150 + (row % 2 ? cols - 1 - col : col) * 350
    return { x, y: 90 + row * rowH }
  })
  const H = 90 + Math.ceil(n / cols) * rowH
  const thread = (pts: typeof points) => pts.reduce((d, p, i) => {
    if (!i) return `M ${p.x} ${p.y}`
    const q = pts[i - 1], mx = (q.x + p.x) / 2
    return q.y === p.y
      ? `${d} C ${mx} ${p.y - 40}, ${mx} ${p.y + 40}, ${p.x} ${p.y}`
      : `${d} C ${q.x + (q.x > 500 ? 160 : -160)} ${q.y}, ${p.x + (p.x > 500 ? 160 : -160)} ${p.y}, ${p.x} ${p.y}`
  }, '')
  const path = thread(points)
  const walkedPath = thread(points.slice(0, Math.min(trail.current, n - 1) + 1))
  const status = (i: number) => (i < trail.current ? 'Walked' : i === trail.current ? 'You are here' : 'Further on')
  const walked = trail.current >= n

  return (
    <section className="walk" aria-labelledby="walk-h">
      <p className="eyebrow">The walk, {countWords(n, 'stop').toLowerCase()}</p>
      <h1 id="walk-h" className="display" style={{ fontSize: 50, marginTop: 8 }}>{trail.title}</h1>
      <div className="walk-map" style={{ aspectRatio: `${W} / ${H}` }}>
        <svg viewBox={`0 0 ${W} ${H}`} className="walk-thread" aria-hidden="true">
          <path d={path} fill="none" stroke="rgba(36,48,31,.22)" strokeWidth="3" strokeDasharray="9 7" strokeLinecap="round" />
          {trail.current > 0 && <path d={walkedPath} fill="none" stroke="var(--red-thread)" strokeWidth="3.2" strokeDasharray="9 7" strokeLinecap="round" />}
        </svg>
        <ol>
          {trail.stops.map((stop, i) => {
            const book = books.find((b) => b.id === stop.bookId)
            const p = book ? palettes[book.palette] : palettes.oat
            const here = i === trail.current
            return (
              <li key={stop.id} className={`stop${here ? ' here' : ''}${i < trail.current ? ' walked' : ''}`} style={{ left: `${(points[i].x / W) * 100}%`, top: `${(points[i].y / H) * 100}%` }}>
                <a
                  href={book ? href({ name: 'read', id: stop.bookId, page: stop.page }) : undefined}
                  className="stop-patch"
                  style={{ background: p.bg, color: p.fg }}
                  aria-label={`Stop ${i + 1} of ${n}: ${stop.title}, ${book?.title ?? 'Source unavailable'} page ${stop.page}. ${status(i)}.`}
                  onClick={() => { if (i >= trail.current) saveTrail({ ...trail, current: i }) }}
                >
                  <span className="stop-n" style={{ color: p.muted }}>{here ? 'You are here' : `Stop ${i + 1}`}</span>
                  <span className="stop-title">{book?.title ?? 'Source unavailable'}</span>
                  <span className="stop-page" style={{ color: p.muted }}>p. {stop.page}</span>
                </a>
              </li>
            )
          })}
        </ol>
      </div>
      <div className="walk-foot card">
        {walked ? (
          <>
            <p className="eyebrow paper">The end of the walk</p>
            <p className="serif" style={{ fontSize: 19, margin: '8px 0 16px' }}>You've read {trail.title.toLowerCase()} in {countWords(n, 'place').toLowerCase()}.</p>
            <div className="row" style={{ gap: 14 }}>
              <button className="btn ink" onClick={() => go({ name: 'study' })}>Explain it in your own words</button>
              <button className="quiet-link" onClick={() => saveTrail({ ...trail, current: 0 })}>Walk it again</button>
            </div>
          </>
        ) : (
          <>
            <p className="eyebrow paper">{trail.current === 0 ? 'Start here' : `Next · stop ${trail.current + 1}`}</p>
            <p className="serif" style={{ fontSize: 19, margin: '8px 0 16px' }}>“{trail.stops[trail.current].title}”</p>
            <div className="row" style={{ gap: 14 }}>
              <button className="btn ink" onClick={() => { const s = trail.stops[trail.current]; saveTrail({ ...trail, current: trail.current + 1 }); go({ name: 'read', id: s.bookId, page: s.page }) }}>Read this stop</button>
              <button className="quiet-link" onClick={() => saveTrail({ ...trail, current: trail.current + 1 })}>Skip to the next</button>
            </div>
          </>
        )}
      </div>
    </section>
  )
}
