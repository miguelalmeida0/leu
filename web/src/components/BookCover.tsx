import { palettes, type Book } from '../lib/store'

/** Live title text preserves imported document names and their palette. */
export function BookCover({ book }: { book: Book }) {
  const palette = palettes[book.palette]
  return <span className="book-cover" style={{ backgroundColor: palette.bg, color: palette.fg }} aria-hidden="true">
    {book.palette === 'denim' && <img src="/art/book-denim.webp" alt="" draggable={false} />}
    <span className="book-cover-title">{book.title}</span>
  </span>
}
