import { useEffect, useRef, type ReactNode } from 'react'
import { palettes, readFraction, type Book } from '../lib/store'

/** A red running stitch, the Felt mark for "you are here". */
export function Stitch({ width = '100%', color = 'var(--red-thread)' }: { width?: number | string; color?: string }) {
  return (
    <svg className="stitch" width={width} height="4" aria-hidden="true" preserveAspectRatio="none">
      <line x1="1" y1="2" x2="100%" y2="2" stroke={color} strokeWidth="2.2" strokeLinecap="round" strokeDasharray="7 5" />
    </svg>
  )
}

/** A book as a felt patch: dyed felt, a stitched edge, the title set in its own ink. */
export function Patch({ book, size = 'm', onClick, children, label }: { book: Book; size?: 's' | 'm' | 'l'; onClick?: () => void; children?: ReactNode; label?: string }) {
  const p = palettes[book.palette]
  const progress = readFraction(book)
  const inner = (
    <>
      <span className="patch-title">{book.title}</span>
      {children ?? <span className="patch-meta" style={{ color: p.muted }}>{book.pages} pages{progress > 0.02 ? ` · ${Math.round(progress * 100)}% read` : ''}</span>}
    </>
  )
  const style = { background: p.bg, color: p.fg }
  return onClick ? (
    <button className={`patch patch-${size}`} style={style} onClick={onClick} aria-label={label}>{inner}</button>
  ) : (
    <div className={`patch patch-${size}`} style={style}>{inner}</div>
  )
}

export function Swatch({ book, size = 10 }: { book: Book; size?: number }) {
  return <span className="swatch" style={{ background: palettes[book.palette].bg, width: size, height: size * 1.35 }} aria-hidden="true" />
}

export function Progress({ value, width = 240 }: { value: number; width?: number }) {
  return (
    <span className="progress" style={{ width }} aria-hidden="true">
      <span style={{ width: `${Math.min(Math.max(value, 0.02), 1) * 100}%` }} />
    </span>
  )
}

/** A dialog over the felt: Escape or the scrim closes it, focus moves in and comes back. */
export function Modal({ label, onClose, children, width = 640, tone = 'cream' }: { label: string; onClose: () => void; children: ReactNode; width?: number; tone?: 'cream' | 'butter' }) {
  const ref = useRef<HTMLDivElement>(null)
  const close = useRef(onClose)
  close.current = onClose
  // Focus moves in once, when the dialog opens, and returns to where it was when it closes.
  useEffect(() => {
    const before = document.activeElement as HTMLElement | null
    const first = ref.current?.querySelector<HTMLElement>('[autofocus], input, textarea, button, [href]')
    first?.focus()
    const key = (e: KeyboardEvent) => {
      if (e.key === 'Escape') { e.stopPropagation(); close.current() }
      if (e.key === 'Tab' && ref.current) {
        const items = [...ref.current.querySelectorAll<HTMLElement>('button, [href], input, textarea, select, [tabindex]:not([tabindex="-1"])')].filter((x) => !x.hasAttribute('disabled'))
        if (!items.length) return
        const [a, z] = [items[0], items[items.length - 1]]
        if (e.shiftKey && document.activeElement === a) { e.preventDefault(); z.focus() }
        else if (!e.shiftKey && document.activeElement === z) { e.preventDefault(); a.focus() }
      }
    }
    window.addEventListener('keydown', key, true)
    return () => { window.removeEventListener('keydown', key, true); before?.focus?.() }
  }, [])
  return (
    <div className="scrim" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <div ref={ref} className={`modal ${tone}`} role="dialog" aria-modal="true" aria-label={label} style={{ maxWidth: width }}>
        {children}
      </div>
    </div>
  )
}

export function Empty({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="empty fade-in">
      <h2 className="display" style={{ fontSize: 32 }}>{title}</h2>
      {children}
    </div>
  )
}

/** Numbers in words, the way Leu says them. */
export function countWords(n: number, one: string, many = one + 's') {
  const w = ['No', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve']
  return `${n < w.length ? w[n] : n} ${n === 1 ? one : many}`
}

export function fractionWords(f: number) {
  if (f <= 0) return 'none'
  if (f < 0.2) return 'a little'
  if (f < 0.4) return 'about a third'
  if (f < 0.6) return 'about half'
  if (f < 0.85) return 'most'
  if (f < 1) return 'nearly all'
  return 'all'
}
