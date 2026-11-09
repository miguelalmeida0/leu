import { useEffect, useRef, useState } from 'react'
import { Modal } from '../../components/ui'
import type { PDFDocumentProxy } from '../../lib/pdf'
import { CollectionLab } from './CollectionLab'
import { ReferenceLab } from './ReferenceLab'
import { RegionPicker } from './RegionPicker'
import { labs, matchingLabs, wholePage, type LabKind, type PinnedReference } from './models'

export interface ToolSource { page: number; text: string; initialLab?: LabKind }
export function ReadingTools({ doc, source, replacing, onPin, onClose }: {
  doc: PDFDocumentProxy; source: ToolSource; replacing: boolean; onPin: (reference: PinnedReference) => void; onClose: () => void
}) {
  const [view, setView] = useState<'home' | 'region' | LabKind>(source.initialLab ?? 'home')
  const heading = useRef<HTMLHeadingElement>(null)
  const matches = matchingLabs(source.text)
  const lab = view !== 'home' && view !== 'region' ? view : null
  useEffect(() => { heading.current?.focus() }, [view])
  const pin = (reference: PinnedReference) => { onPin(reference); onClose() }
  return <Modal label="Reading tools" onClose={onClose} width={640} className="reading-tools">
    <p className="eyebrow paper">From page {source.page}</p>
    <h2 ref={heading} tabIndex={-1} className="display tools-heading">{lab ? labs[lab].title : view === 'region' ? 'Choose a reference' : 'Keep the page close'}</h2>
    {view !== 'home' && <button className="quiet-link tools-back" onClick={() => setView('home')}>Back to reading tools</button>}
    {view === 'home' && <>
      <section aria-label="Pin a reference" className="tool-section">
        <p>Keep a page or figure beside you as you read.</p>
        {replacing && <p className="small muted">Pinning here replaces this book’s current reference.</p>}
        <div className="tool-actions">
          <button className="btn ink" onClick={() => pin({ page: source.page, crop: wholePage })}>{replacing ? 'Replace with this page' : 'Pin this page'}</button>
          <button className="btn soft" onClick={() => setView('region')}>Choose a region</button>
        </div>
      </section>
      <section className="tool-section" aria-label="Interactive examples">
        <h3>Try the idea</h3>
        {matches.length ? <div className="lab-choices">{matches.map(kind => <button key={kind} onClick={() => setView(kind)}>
          <strong>{labs[kind].title}</strong><span>{labs[kind].description}</span>
        </button>)}</div> : <p className="muted small">No interactive example matches this page. Leu currently supports stacks, queues, and shared object references.</p>}
      </section>
    </>}
    {view === 'region' && <RegionPicker doc={doc} page={source.page} replacing={replacing} onPin={crop => pin({ page: source.page, crop })} />}
    {lab && <>
      {lab === 'references' ? <ReferenceLab /> : <CollectionLab key={lab} kind={lab} />}
      <details className="lab-source"><summary>Source passage · page {source.page}</summary><blockquote className="serif">{source.text}</blockquote></details>
      <p className="muted small">A built-in teaching example, matched to this passage.</p>
    </>}
  </Modal>
}
