import type { Outline } from '../lib/store'

interface Props {
  entries: Outline[]
  selectedIndex: number
  onChoose: (index: number) => void
}

/** A short, usable chapter index. Search and deep outlines stay in Contents. */
export function BookChapterList({ entries, selectedIndex, onChoose }: Props) {
  const length = Math.min(7, entries.length)
  const start = Math.max(0, Math.min(
    selectedIndex - Math.floor(length / 2),
    entries.length - length,
  ))
  const shown = entries.slice(start, start + length)

  return (
    <div className="book-chapter-index">
      <ol className="book-chapter-list" aria-label="Browse chapters">
        {shown.map((entry, offset) => {
          const index = start + offset
          const chosen = index === selectedIndex
          return <li key={index}>
            <button type="button" aria-pressed={chosen}
              onClick={() => onChoose(index)}
              className="book-chapter-item"
              style={{ paddingInlineStart: 12 + Math.min(entry.depth, 2) * 10 }}>
              <span className="book-chapter-item-title">{entry.title}</span>
              <span className="book-chapter-page tabular">p. {entry.page}</span>
            </button>
          </li>
        })}
      </ol>
      {entries.length > length && <p className="book-chapter-index-hint">
        Chapters {start + 1}–{start + length} of {entries.length}. Use Contents to find another.
      </p>}
    </div>
  )
}
