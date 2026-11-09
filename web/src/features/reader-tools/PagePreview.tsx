import { useEffect, useRef, useState } from 'react'
import { renderPage, type PDFDocumentProxy } from '../../lib/pdf'
import { wholePage, type Crop } from './models'

/** Render offscreen first so a page switch cannot race PDF.js on the visible canvas. */
export function PagePreview({ doc, page, crop = wholePage, onReady }: {
  doc: PDFDocumentProxy; page: number; crop?: Crop; onReady?: () => void
}) {
  const canvas = useRef<HTMLCanvasElement>(null)
  const [status, setStatus] = useState('Opening reference…')
  const [retry, setRetry] = useState(0)
  const ready = useRef(onReady)
  ready.current = onReady
  useEffect(() => {
    let live = true
    setStatus('Opening reference…')
    const scratch = document.createElement('canvas')
    void renderPage(doc, page, scratch, 900).then(() => {
      if (!live || !canvas.current) return
      const output = canvas.current
      const x = Math.floor(scratch.width * crop.x), y = Math.floor(scratch.height * crop.y)
      output.width = Math.max(1, Math.floor(scratch.width * crop.width))
      output.height = Math.max(1, Math.floor(scratch.height * crop.height))
      const ctx = output.getContext('2d')
      if (!ctx) throw new Error('Canvas unavailable')
      ctx.drawImage(scratch, x, y, output.width, output.height, 0, 0, output.width, output.height)
      setStatus('')
      ready.current?.()
    }).catch(() => { if (live) setStatus('This reference could not be displayed.') })
    return () => { live = false }
  }, [doc, page, crop.x, crop.y, crop.width, crop.height, retry])
  return <>
    {status && <p role="status">{status}{status.includes('could not') && <button className="link" onClick={() => setRetry(n => n + 1)}>Try again</button>}</p>}
    <canvas ref={canvas} hidden={!!status} className="reference-preview" role="img" aria-label={`Pinned source image from page ${page}`} />
  </>
}
