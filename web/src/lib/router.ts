import { useSyncExternalStore } from 'react'

/* A tiny hash router: #/library, #/book/abc, #/read/abc/12. Hash URLs keep `npm run dev`,
   `vite preview` and a plain static folder all working with no server rewrites. */

export type Route =
  | { name: 'home' }
  | { name: 'library'; shelf?: string }
  | { name: 'book'; id: string }
  | { name: 'read'; id: string; page: number }
  | { name: 'words'; id: string; page: number }
  | { name: 'study' }
  | { name: 'notes' }
  | { name: 'explore'; term?: string }
  | { name: 'trails'; id?: string }

export function parse(hash: string): Route {
  const [name, a, b] = hash.replace(/^#\/?/, '').split('/').map(decodeURIComponent)
  switch (name) {
    case 'library': return { name, shelf: a || undefined }
    case 'book': return a ? { name, id: a } : { name: 'library' }
    case 'read': return a ? { name, id: a, page: Math.max(1, Number(b) || 1) } : { name: 'library' }
    case 'words': return a ? { name, id: a, page: Math.max(1, Number(b) || 1) } : { name: 'library' }
    case 'study': case 'notes': return { name }
    case 'explore': return { name, term: a || undefined }
    case 'trails': return { name, id: a || undefined }
    default: return { name: 'home' }
  }
}

export function href(r: Route): string {
  const parts: (string | number | undefined)[] = [r.name]
  if (r.name === 'library') parts.push(r.shelf)
  if (r.name === 'book') parts.push(r.id)
  if (r.name === 'read' || r.name === 'words') parts.push(r.id, r.page)
  if (r.name === 'explore') parts.push(r.term)
  if (r.name === 'trails') parts.push(r.id)
  return '#/' + parts.filter((p) => p !== undefined && p !== '').map((p) => encodeURIComponent(String(p))).join('/')
}

export function go(r: Route, replace = false) {
  const next = href(r)
  if (replace) history.replaceState(null, '', next)
  else if (location.hash !== next) location.hash = next
  window.dispatchEvent(new HashChangeEvent('hashchange'))
}

let cached = { hash: '', route: parse('') as Route }
export function useRoute(): Route {
  return useSyncExternalStore(
    (l) => { window.addEventListener('hashchange', l); return () => window.removeEventListener('hashchange', l) },
    () => {
      if (cached.hash !== location.hash) cached = { hash: location.hash, route: parse(location.hash) }
      return cached.route
    },
  )
}
