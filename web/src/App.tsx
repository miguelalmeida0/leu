import { useCallback, useEffect, useRef, useState } from 'react'
import { BottomNav } from './components/BottomNav'
import { TopBar } from './components/TopBar'
import { importFiles, useSewing } from './lib/library'
import { go, href, useRoute } from './lib/router'
import { useStore } from './lib/store'
import { BookOverview } from './screens/BookOverview'
import { Home } from './screens/Home'
import { Library } from './screens/Library'
import { Notes } from './screens/Notes'
import { OwnWords } from './screens/OwnWords'
import { Reader } from './screens/Reader'
import { Search } from './screens/Search'
import { Sewn } from './screens/Sewn'
import { Study } from './screens/Study'
import { Welcome } from './screens/Welcome'

export default function App() {
  const route = useRoute()
  const empty = useStore((s) => s.books.length === 0)
  const sewing = useSewing()
  const [searching, setSearching] = useState(false)
  const [dragging, setDragging] = useState(false)
  const picker = useRef<HTMLInputElement>(null)
  const mainRef = useRef<HTMLElement>(null)
  const previousRoute = useRef<string | null>(null)
  const routeKey = href(route)
  const depth = useRef(0)

  // Keyboard: ⌘K search, ⌘O bring a PDF, ⌘1–⌘4 visible places.
  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      const mod = e.metaKey || e.ctrlKey
      if (!mod) return
      if (e.key.toLowerCase() === 'k') { e.preventDefault(); setSearching((s) => !s) }
      if (e.key.toLowerCase() === 'o') { e.preventDefault(); picker.current?.click() }
      const places = ['home', 'library', 'study', 'notes'] as const
      const n = Number(e.key)
      if (n >= 1 && n <= places.length && !e.shiftKey) { e.preventDefault(); go({ name: places[n - 1] }) }
    }
    window.addEventListener('keydown', key)
    return () => window.removeEventListener('keydown', key)
  }, [])

  useEffect(() => { window.scrollTo(0, 0) }, [route.name])
  useEffect(() => {
    if (previousRoute.current !== null && previousRoute.current !== routeKey) {
      if (!document.querySelector('.reader-immersive')) mainRef.current?.focus({ preventScroll: true })
    }
    previousRoute.current = routeKey
  }, [routeKey])

  useEffect(() => {
    const titles: Record<string, string> = { home: 'Leu', library: 'Library · Leu', study: 'Study · Leu', notes: 'Notes · Leu', explore: 'Explore · Leu', trails: 'Trails · Leu' }
    if (titles[route.name]) document.title = titles[route.name]
  }, [route.name])

  const bring = useCallback(() => picker.current?.click(), [])

  // Drop a PDF anywhere on the page to bring it in.
  const onDrag = (e: React.DragEvent) => {
    if (!e.dataTransfer.types.includes('Files')) return
    e.preventDefault()
    if (e.type === 'dragenter') { depth.current++; setDragging(true) }
    if (e.type === 'dragleave' && --depth.current <= 0) { depth.current = 0; setDragging(false) }
  }
  const onDrop = (e: React.DragEvent) => {
    e.preventDefault(); depth.current = 0; setDragging(false)
    void importFiles([...e.dataTransfer.files])
  }

  const welcome = empty && !sewing && (route.name === 'home' || route.name === 'library')

  return (
    <div className="app" data-route={route.name} onDragEnter={onDrag} onDragOver={onDrag} onDragLeave={onDrag} onDrop={onDrop}>
      <a className="skip" href="#main">Skip to content</a>
      <TopBar route={route} onSearch={() => setSearching(true)} />
      <main id="main" ref={mainRef} tabIndex={-1} aria-label={route.name === 'read' ? 'PDF reader' : undefined}
        onFocusCapture={(event) => {
          const target = event.target as HTMLElement
          if (target === event.currentTarget || !target.matches(':focus-visible') || target.closest('.reader-immersive')) return
          const bounds = target.getBoundingClientRect()
          const headerBottom = document.querySelector('.topbar')?.getBoundingClientRect().bottom ?? 0
          if (bounds.top < headerBottom + 12 || bounds.bottom > window.innerHeight - 12) {
            target.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'instant' })
          }
        }}>
        {welcome ? <Welcome onBring={bring} /> : <Screen route={route} onBring={bring} />}
      </main>
      {!welcome && <BottomNav route={route} />}
      <input
        ref={picker}
        type="file"
        accept="application/pdf,.pdf"
        multiple
        hidden
        onChange={(e) => { void importFiles([...(e.target.files ?? [])]); e.target.value = '' }}
      />
      {dragging && (
        <div className="dropzone" aria-hidden="true">
          <div className="dropzone-card stitched"><span className="display" style={{ fontSize: 34 }}>Drop it here.</span><span className="muted">Leu reads it on this computer and adds it to your library.</span></div>
        </div>
      )}
      {sewing && <Sewn sewing={sewing} />}
      {searching && <Search onClose={() => setSearching(false)} />}
    </div>
  )
}

function Screen({ route, onBring }: { route: ReturnType<typeof useRoute>; onBring: () => void }) {
  switch (route.name) {
    case 'home': return <Home onBring={onBring} />
    case 'library': return <Library shelf={route.shelf} onBring={onBring} />
    case 'book': return <BookOverview id={route.id} />
    case 'read': return <Reader key={route.id} id={route.id} page={route.page} />
    case 'words': return <OwnWords key={`${route.id}:${route.page}`} id={route.id} page={route.page} />
    case 'study': return <Study />
    case 'notes': return <Notes />
    case 'explore': case 'trails': return <Library onBring={onBring} />
  }
}
