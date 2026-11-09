import { useEffect, useState } from 'react'
import { CaretDownIcon, CaretUpIcon, XIcon } from '@phosphor-icons/react'
import type { PDFDocumentProxy } from '../../lib/pdf'
import type { PinnedReference as Reference } from './models'
import { PagePreview } from './PagePreview'

export function PinnedReference({ doc, reference, expanded, onExpand, onRemove, onTurn, page, notice }: {
  doc: PDFDocumentProxy; reference: Reference; expanded: boolean; onExpand: (value: boolean) => void
  onRemove: () => void; onTurn: (page: number) => void; page: number; notice: string
}) {
  const [returnPage, setReturnPage] = useState<number | null>(null)
  const [zoom, setZoom] = useState(1)
  useEffect(() => { setZoom(1); setReturnPage(null) }, [reference])
  return <aside className="pinned-reference" aria-label={`Pinned reference from page ${reference.page}`}
    onKeyDown={event => { if (['ArrowLeft', 'ArrowRight', 'PageDown', 'PageUp'].includes(event.key)) event.stopPropagation() }}>
    <header>
      <button type="button" className="reference-disclosure" aria-expanded={expanded} aria-controls="pinned-reference-body" onClick={() => onExpand(!expanded)}>
        <span>Pinned · page {reference.page}</span>{expanded ? <CaretDownIcon size={18} /> : <CaretUpIcon size={18} />}
      </button>
      <button type="button" className="reference-remove" aria-label="Unpin reference" onClick={onRemove}><XIcon size={18} /></button>
    </header>
    {expanded && <div id="pinned-reference-body" className="reference-body" tabIndex={0} aria-label="Reference content">
      {reference.quote ? <blockquote className="serif">{reference.quote}</blockquote> : <>
        <div className="reference-zoom" role="group" aria-label="Reference zoom">
          <button aria-label="Reduce reference" disabled={zoom <= 1} onClick={() => setZoom(n => n - .5)}>−</button>
          <button aria-label="Reset reference zoom" onClick={() => setZoom(1)}>{zoom * 100}%</button>
          <button aria-label="Enlarge reference" disabled={zoom >= 3} onClick={() => setZoom(n => n + .5)}>+</button>
        </div>
        <div className="reference-image-frame" style={{ width: `${zoom * 100}%` }}><PagePreview doc={doc} page={reference.page} crop={reference.crop} /></div>
      </>}
      <div className="reference-links">
        <button className="link small" disabled={page === reference.page} onClick={() => { setReturnPage(page); onTurn(reference.page) }}>Open source page {reference.page}</button>
        {returnPage !== null && page !== returnPage && <button className="link small" onClick={() => { onTurn(returnPage); setReturnPage(null) }}>Back to reading page {returnPage}</button>}
      </div>
      {notice && <p role="status" className="small">{notice}</p>}
    </div>}
  </aside>
}
