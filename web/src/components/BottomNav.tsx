import { BooksIcon, HouseIcon } from '@phosphor-icons/react'
import { href, type Route } from '../lib/router'

export function BottomNav({ route }: { route: Route }) {
  if (route.name !== 'home' && route.name !== 'library') return null
  return <nav className="bottom-nav" aria-label="Home and library">
    <a href={href({ name: 'home' })} aria-current={route.name === 'home' ? 'page' : undefined}><HouseIcon size={25} weight={route.name === 'home' ? 'fill' : 'regular'} aria-hidden="true" /><span>Home</span></a>
    <a href={href({ name: 'library' })} aria-current={route.name === 'library' ? 'page' : undefined}><BooksIcon size={25} weight={route.name === 'library' ? 'fill' : 'regular'} aria-hidden="true" /><span>Library</span></a>
  </nav>
}
