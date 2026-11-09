import { useRef, useState } from 'react'
import type { PDFDocumentProxy } from '../../lib/pdf'
import { PagePreview } from './PagePreview'
import { wholePage, type Crop } from './models'

export function RegionPicker({ doc, page, replacing, onPin }: {
  doc: PDFDocumentProxy; page: number; replacing: boolean; onPin: (crop: Crop) => void
}) {
  const [crop, setCrop] = useState<Crop>(wholePage)
  const [ready, setReady] = useState(false)
  const start = useRef<{ x: number; y: number } | null>(null)
  const position = (event: React.PointerEvent<HTMLDivElement>) => {
    const rect = event.currentTarget.getBoundingClientRect()
    return { x: Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width)), y: Math.max(0, Math.min(1, (event.clientY - rect.top) / rect.height)) }
  }
  const move = (event: React.PointerEvent<HTMLDivElement>) => {
    if (!start.current) return
    const end = position(event)
    const x = Math.min(.99, start.current.x, end.x), y = Math.min(.99, start.current.y, end.y)
    setCrop({ x, y, width: Math.max(.01, Math.min(1 - x, Math.abs(start.current.x - end.x))), height: Math.max(.01, Math.min(1 - y, Math.abs(start.current.y - end.y))) })
  }
  const update = (key: keyof Crop, value: number) => {
    if (!Number.isFinite(value)) return
    setCrop(old => {
      const next = { ...old, [key]: value / 100 }
      next.x = Math.min(.99, Math.max(0, next.x)); next.y = Math.min(.99, Math.max(0, next.y))
      next.width = Math.max(.01, Math.min(1 - next.x, next.width))
      next.height = Math.max(.01, Math.min(1 - next.y, next.height))
      return next
    })
  }
  return <>
    <p className="muted small">Drag around a figure or use the percentage fields. The original page stays unchanged.</p>
    <div className="region-picker" data-ready={ready}
      onPointerDown={event => { if (!ready || event.button !== 0) return; event.currentTarget.setPointerCapture(event.pointerId); start.current = position(event) }}
      onPointerMove={move} onPointerUp={event => { move(event); start.current = null }} onPointerCancel={() => { start.current = null }}>
      <PagePreview doc={doc} page={page} onReady={() => setReady(true)} />
      {ready && <div className="region-outline" aria-hidden="true" style={{ left: `${crop.x * 100}%`, top: `${crop.y * 100}%`, width: `${crop.width * 100}%`, height: `${crop.height * 100}%` }} />}
    </div>
    <div className="crop-fields">
      {([['x', 'Left'], ['y', 'Top'], ['width', 'Width'], ['height', 'Height']] as const).map(([key, label]) =>
        <label key={key}>{label} (%)<input type="number" min={key === 'x' || key === 'y' ? 0 : 1} max={100} step={1}
          value={Math.round(crop[key] * 100)} onChange={event => update(key, event.target.valueAsNumber)} /></label>)}
    </div>
    <div className="tool-actions">
      <button className="btn ink" disabled={!ready} onClick={() => onPin(crop)}>{replacing ? 'Replace pinned reference' : 'Pin this region'}</button>
      <button className="quiet-link" onClick={() => setCrop(wholePage)}>Select whole page</button>
    </div>
  </>
}
