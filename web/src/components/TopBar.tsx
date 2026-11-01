import { CaretLeftIcon } from '@phosphor-icons/react'
import { useEffect, useRef, useState } from 'react'
import { go, href, type Route } from '../lib/router'
import { useStore } from '../lib/store'
import { lastBook } from '../lib/library'
import { Stitch } from './ui'
import { Wordmark } from './Wordmark'
import { useResponsiveTopbar } from './useResponsiveTopbar'
import './TopBar.css'

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
  const readingBook = route.name === 'read' ? books.find((book) => book.id === route.id) : undefined
  const current = route.name === 'book' ? 'library' : route.name === 'words' ? 'read' : route.name
  const [menuOpen, setMenuOpen] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)
  const headerRef = useRef<HTMLElement>(null)
  const wordmarkRef = useRef<HTMLAnchorElement>(null)
  const navigationRef = useRef<HTMLElement>(null)
  const searchRef = useRef<HTMLButtonElement>(null)
  const compactNav = useResponsiveTopbar({ header: headerRef, wordmark: wordmarkRef, navigation: navigationRef, search: searchRef })
  const routeKey = href(route)

  useEffect(() => {
    const header = headerRef.current
    if (!header) return
    const measure = () => document.documentElement.style.setProperty('--topbar-height', `${header.getBoundingClientRect().height}px`)
    const observer = new ResizeObserver(measure)
    observer.observe(header)
    measure()
    return () => observer.disconnect()
  }, [])
  useEffect(() => setMenuOpen(false), [routeKey])
  useEffect(() => { if (!compactNav) setMenuOpen(false) }, [compactNav])
  useEffect(() => {
    if (!menuOpen) return
    const dismiss = (event: PointerEvent) => {
      if (!menuRef.current?.contains(event.target as Node)) setMenuOpen(false)
    }
    const escape = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return
      event.preventDefault()
      setMenuOpen(false)
      menuRef.current?.querySelector<HTMLButtonElement>('.mobile-menu-trigger')?.focus()
    }
    document.addEventListener('pointerdown', dismiss, true)
    document.addEventListener('keydown', escape)
    return () => {
      document.removeEventListener('pointerdown', dismiss, true)
      document.removeEventListener('keydown', escape)
    }
  }, [menuOpen])
  return (
    <header className={`topbar${compactNav ? ' compact-nav' : ''}`} ref={headerRef}>
      <a className={`wordmark${readingBook ? ' reader-top-title' : ''}`} ref={wordmarkRef}
        href={href(readingBook ? { name: 'book', id: readingBook.id } : { name: 'home' })}
        title={readingBook ? 'Book overview' : 'Home'} aria-current={route.name === 'home' ? 'page' : undefined}>
        {readingBook ? <><CaretLeftIcon size={18} aria-hidden="true" /><span>{readingBook.title}</span></> : <Wordmark />}
      </a>
      <nav className="desktop-places" ref={navigationRef} aria-label="Places">
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
      <div className="topbar-tools">
        <div className="mobile-places" ref={menuRef}>
          <button type="button" className="mobile-menu-trigger"
            aria-label={menuOpen ? 'Close navigation' : 'Open navigation'}
            aria-controls="mobile-nav" aria-expanded={menuOpen}
            onClick={() => setMenuOpen((open) => !open)}>
            <svg width="22" height="22" viewBox="0 0 24 24" aria-hidden="true">
              {menuOpen
                ? <path d="M5 5l14 14M19 5L5 19" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" />
                : <path d="M4 6h16M4 12h16M4 18h16" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" />}
            </svg>
          </button>
          <nav id="mobile-nav" aria-label="Mobile places" hidden={!menuOpen}>
            <a href={href({ name: 'home' })} onClick={() => setMenuOpen(false)} aria-current={route.name === 'home' ? 'page' : undefined}>Home</a>
            {places.map((p) => {
              const to: Route = p.name === 'read' ? (last ? { name: 'read', id: last.id, page: last.page } : { name: 'library' }) : { name: p.name }
              return <a key={p.name} href={href(to)} onClick={() => setMenuOpen(false)} aria-current={current === p.name ? 'page' : undefined}>{p.label}</a>
            })}
          </nav>
        </div>
        <button className="search-pill" ref={searchRef} onClick={onSearch} aria-labelledby="search-label" aria-keyshortcuts="Meta+K Control+K">
          <svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true"><circle cx="10.5" cy="10.5" r="6.5" fill="none" stroke="currentColor" strokeWidth="2.2" /><path d="M15.5 15.5 20 20" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" /></svg>
          <span id="search-label">Search your books</span>
          <kbd aria-hidden="true">{navigator.platform.includes('Mac') ? '⌘K' : 'Ctrl K'}</kbd>
        </button>
      </div>
    </header>
  )
}
