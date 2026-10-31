import { Progress, Swatch } from '../components/ui'
import { lastBook } from '../lib/library'
import { go } from '../lib/router'
import { readFraction, useStore } from '../lib/store'
import { NookScene } from '../scenes/NookScene'

function greeting(d = new Date()) {
  const h = d.getHours()
  return h >= 5 && h < 12 ? 'Good morning' : h < 17 && h >= 12 ? 'Good afternoon' : h >= 17 && h < 22 ? 'Good evening' : 'Late night'
}

/** Home (03): "We kept your spot warm." The book you were in, one way back, and the evening nook. */
export function Home({ onBring }: { onBring: () => void }) {
  const books = useStore((s) => s.books)
  const book = lastBook(books)
  const progress = book ? readFraction(book) : 0

  return (
    <div className="home-bleed">
    <div className="home fade-in">
      <section className="home-words">
        <p className="eyebrow" style={{ color: 'var(--secondary)' }}>{greeting()}</p>
        <h1 className="display home-title">We kept your spot warm.</h1>
        <p className="home-sub">{book ? 'Quilt, tea and a rainy evening.' : 'Bring a PDF and it will be waiting here.'}</p>
        {book && (
          <div className="home-book" aria-label={`${book.title}, page ${book.page} of ${book.pages}, ${Math.round(progress * 100)} percent read`}>
            <div className="row" style={{ gap: 12, alignItems: 'baseline' }}>
              <Swatch book={book} />
              <strong>{book.title}</strong>
              <span className="muted tabular">page {book.page} of {book.pages}</span>
            </div>
            <div style={{ paddingLeft: 22, marginTop: 12 }}><Progress value={progress} /></div>
          </div>
        )}
        <div className="row" style={{ gap: 22, marginTop: 30 }}>
          {book ? (
            <>
              <button className="btn ink" onClick={() => go({ name: 'read', id: book.id, page: book.page })}>Keep reading</button>
              <button className="quiet-link" onClick={() => go({ name: 'library' })}>Something else</button>
            </>
          ) : (
            <button className="btn ink" onClick={onBring}>Bring a PDF</button>
          )}
        </div>
      </section>
      <div className="home-scene"><NookScene /></div>
    </div>
    </div>
  )
}
