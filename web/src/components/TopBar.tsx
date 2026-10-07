import { go, href, type Route } from '../lib/router'
import { useStore } from '../lib/store'
import { lastBook } from '../lib/library'
import { Stitch } from './ui'

const places = [
  { name: 'library', label: 'Library' },
  { name: 'read', label: 'Reading' },
  { name: 'study', label: 'Study' },
  { name: 'notes', label: 'Notes' },
  { name: 'explore', label: 'Explore' },
  { name: 'trails', label: 'Trails' },
] as const

/** The desktop top bar: the wordmark (Home), the places with a red running stitch under the
    current one, and search. Reading opens the last book where you left it. */
export function TopBar({ route, onSearch }: { route: Route; onSearch: () => void }) {
  const books = useStore((s) => s.books)
  const last = lastBook(books)
  const current = route.name === 'book' ? 'library' : route.name === 'words' ? 'read' : route.name
  return (
    <header className="topbar">
      <a className="wordmark" href={href({ name: 'home' })} aria-label="Leu, home" aria-current={route.name === 'home' ? 'page' : undefined}>leu</a>
      <nav aria-label="Places">
        <ul>
          {places.map((p) => {
            const on = current === p.name
            const disabled = p.name === 'read' && !last
            const to: Route = p.name === 'read' ? (last ? { name: 'read', id: last.id, page: last.page } : { name: 'library' }) : { name: p.name }
            return (
              <li key={p.name}>
                <a
                  href={href(to)}
                  className={`place${on ? ' on' : ''}`}
                  aria-current={on ? 'page' : undefined}
                  aria-disabled={disabled || undefined}
                  title={p.name === 'read' ? (last ? `Back to ${last.title}, page ${last.page}` : 'Bring a PDF first') : undefined}
                  onClick={(e) => { if (disabled) { e.preventDefault(); go({ name: 'library' }) } }}
                >
                  {p.label}
                  <span className="place-stitch">{on && <Stitch />}</span>
                </a>
              </li>
            )
          })}
        </ul>
      </nav>
      <button className="search-pill" onClick={onSearch} aria-keyshortcuts="Meta+K Control+K">
        <svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true"><circle cx="10.5" cy="10.5" r="6.5" fill="none" stroke="currentColor" strokeWidth="2.2" /><path d="M15.5 15.5 20 20" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" /></svg>
        <span>Search your books</span>
        <kbd>{navigator.platform.includes('Mac') ? '⌘K' : 'Ctrl K'}</kbd>
      </button>
    </header>
  )
}
