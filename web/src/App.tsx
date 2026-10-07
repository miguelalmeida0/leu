import { useCallback, useEffect, useRef, useState } from 'react'
import { TopBar } from './components/TopBar'
import { importFiles, useSewing } from './lib/library'
import { go, useRoute } from './lib/router'
import { useStore } from './lib/store'
import { stopRain } from './scenes/rain'
import { BookOverview } from './screens/BookOverview'
import { Explore } from './screens/Explore'
import { Home } from './screens/Home'
import { Library } from './screens/Library'
import { Notes } from './screens/Notes'
import { OwnWords } from './screens/OwnWords'
import { Reader } from './screens/Reader'
import { Search } from './screens/Search'
import { Sewn } from './screens/Sewn'
import { Study } from './screens/Study'
import { Trails } from './screens/Trails'
import { Welcome } from './screens/Welcome'

export default function App() {
  const route = useRoute()
  const empty = useStore((s) => s.books.length === 0)
  const sewing = useSewing()
  const [searching, setSearching] = useState(false)
  const [dragging, setDragging] = useState(false)
  const picker = useRef<HTMLInputElement>(null)
  const depth = useRef(0)

  // Keyboard: ⌘K search, ⌘O bring a PDF, ⌘1–⌘6 places (as in the Mac app's Go menu).
  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      const mod = e.metaKey || e.ctrlKey
      if (!mod) return
      if (e.key.toLowerCase() === 'k') { e.preventDefault(); setSearching((s) => !s) }
      if (e.key.toLowerCase() === 'o') { e.preventDefault(); picker.current?.click() }
      const places = ['home', 'library', 'study', 'notes', 'explore', 'trails'] as const
      const n = Number(e.key)
      if (n >= 1 && n <= 6 && !e.shiftKey) { e.preventDefault(); go({ name: places[n - 1] }) }
    }
    window.addEventListener('keydown', key)
    return () => window.removeEventListener('keydown', key)
  }, [])

  useEffect(() => { if (route.name !== 'home') stopRain() }, [route.name])
  useEffect(() => { window.scrollTo(0, 0) }, [route.name])

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
    <div className="app" onDragEnter={onDrag} onDragOver={onDrag} onDragLeave={onDrag} onDrop={onDrop}>
      <a className="skip" href="#main">Skip to content</a>
      <TopBar route={route} onSearch={() => setSearching(true)} />
      <main id="main" tabIndex={-1}>
        {welcome ? <Welcome onBring={bring} /> : <Screen route={route} onBring={bring} />}
      </main>
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
          <div className="dropzone-card stitched"><span className="display" style={{ fontSize: 34 }}>Drop it here.</span><span className="muted">Leu reads it on this computer and puts it on your shelf.</span></div>
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
    case 'explore': return <Explore term={route.term} />
    case 'trails': return <Trails id={route.id} />
  }
}
