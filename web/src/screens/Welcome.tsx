import { useState } from 'react'
import { importAllSamples, importSample } from '../lib/library'
import { update, useStore } from '../lib/store'
import { Basket } from '../scenes/Basket'

const suggestions = ['the book I gave up on', 'my thesis papers', 'how money actually works', 'lecture notes from this term']

/** Welcome (01): an empty library. A knitting basket, what you'd like to understand, two ways in. */
export function Welcome({ onBring }: { onBring: () => void }) {
  const intention = useStore((s) => s.intention)
  const set = (v: string) => update((s) => ({ ...s, intention: v }))
  const [busy, setBusy] = useState(false)
  const [importError, setImportError] = useState('')
  const addSamples = async (all: boolean) => {
    setBusy(true); setImportError('')
    try {
      if (all) await importAllSamples()
      else await importSample('Computer Science Essentials')
    } catch (error) {
      console.warn('[leu] Sample import failed:', error)
      setImportError('Could not add the sample. Check your connection and available device storage, then try again.')
    } finally { setBusy(false) }
  }
  const trimmed = intention.trim()
  return (
    <div className="welcome page fade-in">
      <figure className="welcome-art"><Basket /><figcaption className="tug" aria-hidden="true"><span className="tug-desktop">Give the yarn a little tug.</span><span className="tug-mobile">The yarn moves gently on its own.</span></figcaption></figure>
      <div className="welcome-words">
        <p className="eyebrow">Hello, and welcome</p>
        <h1 className="display" style={{ fontSize: 'clamp(40px, 4.4vw, 60px)', marginTop: 12 }}>Make yourself comfortable.</h1>
        <p className="lede">Leu is a quiet place to read the things you actually want to understand. It keeps you company, remembers where you got stuck, and always takes you back to the page.</p>
        <label className="eyebrow" htmlFor="intention" style={{ display: 'block', marginTop: 30, fontSize: 10 }}>Something you've been meaning to understand</label>
        <input
          id="intention"
          className="field serif intention"
          placeholder="why the sky is blue"
          value={intention}
          onChange={(e) => set(e.target.value)}
          aria-describedby="intention-hint"
        />
        <span id="intention-hint" className="sr-only">Optional. Leu keeps it in this browser and reminds you of it on Home.</span>
        <div className="chips" style={{ marginTop: 12 }}>
          {suggestions.map((s) => <button key={s} className="chip" onClick={() => set(s)}>{s}</button>)}
        </div>
        <div className="row" style={{ marginTop: 30, gap: 20 }}>
          <button className="btn ink" onClick={onBring}>{trimmed ? 'Bring a PDF about it' : 'Bring a PDF'}</button>
          <button className="link" disabled={busy} onClick={() => void addSamples(false)}>
            {busy ? 'Opening the sample…' : 'or start with a sample book'}
          </button>
        </div>
        {importError && <p className="import-error" role="alert">{importError}</p>}
        <p className="muted small" style={{ marginTop: 22 }}>
          Everything stays in this browser, including Leu's reading. You can also drop a PDF anywhere on this page, or{' '}
          <button className="link small" disabled={busy} onClick={() => void addSamples(true)}>fill the shelf with all six samples</button>.
        </p>
      </div>
    </div>
  )
}
