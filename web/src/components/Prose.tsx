import { memo, useEffect, useMemo, useRef } from 'react'
import type { Block } from '../lib/pdf'
import { useReducedMotion } from '../lib/motion'
import { position, speechPieces } from '../lib/voice'

/** The page as text you can follow by ear. While Leu reads, a soft butter band sits behind the
    sentence being heard, one rounded band per line, and glides to the next sentence as the voice
    moves on, growing or shrinking line by line. The text itself never changes colour, so it reads
    exactly as it did (ink on the band is above 12:1). Click any sentence to read from there. */
export function piecesOf(blocks: Block[]): string[] {
  return blocks.flatMap((b) => speechPieces(b.text))
}

const PAD_X = 5, PAD_Y = 2

/** One box per line of a sentence, in the wrapper's coordinates. */
function lineBoxes(s: HTMLElement, wrap: HTMLElement) {
  const origin = wrap.getBoundingClientRect()
  const lines: { left: number; right: number; top: number; bottom: number }[] = []
  for (const r of s.getClientRects()) {
    if (r.width < 1) continue
    const line = lines.find((l) => Math.abs(l.top - r.top) < r.height / 2)
    if (line) { line.left = Math.min(line.left, r.left); line.right = Math.max(line.right, r.right); line.bottom = Math.max(line.bottom, r.bottom) }
    else lines.push({ left: r.left, right: r.right, top: r.top, bottom: r.bottom })
  }
  return lines.map((l) => ({ x: l.left - origin.left - PAD_X, y: l.top - origin.top - PAD_Y, w: l.right - l.left + PAD_X * 2, h: l.bottom - l.top + PAD_Y * 2 }))
}

export const Prose = memo(function Prose({ blocks, reading, marked, onSeek }: { blocks: Block[]; reading: boolean; marked?: Set<number>; onSeek?: (index: number) => void }) {
  const wrap = useRef<HTMLDivElement>(null)
  const layer = useRef<HTMLDivElement>(null)
  const reduced = useReducedMotion()

  const layout = useMemo(() => {
    let n = 0
    return blocks.map((b) => ({ kind: b.kind, pieces: speechPieces(b.text).map((text) => ({ text, index: n++ })) }))
  }, [blocks])

  useEffect(() => {
    const el = wrap.current, bands = layer.current
    if (!el || !bands) return
    const hide = () => { for (const b of bands.children) (b as HTMLElement).style.opacity = '0' }
    if (!reading) { hide(); return }
    let frame = 0, index = -1

    const place = (scroll: boolean) => {
      const s = el.querySelector<HTMLElement>(`.s[data-s="${index}"]`)
      if (!s) { hide(); return }
      const boxes = lineBoxes(s, el)
      while (bands.children.length < boxes.length) {
        const b = document.createElement('div')
        b.className = 'read-band'
        // A new band grows out of where the last one is, so the movement stays continuous.
        const last = bands.lastElementChild as HTMLElement | null
        if (last) { b.style.cssText = last.style.cssText; b.style.opacity = '0' }
        bands.appendChild(b)
        void b.offsetWidth // let it start where the last band is
      }
      ;[...bands.children].forEach((node, i) => {
        const b = node as HTMLElement, box = boxes[Math.min(i, boxes.length - 1)]
        b.style.transform = `translate(${box.x}px, ${box.y}px)`
        b.style.width = `${box.w}px`
        b.style.height = `${box.h}px`
        b.style.opacity = i < boxes.length ? '1' : '0'
      })
      if (scroll) {
        const r = s.getBoundingClientRect()
        if (r.top < innerHeight * 0.22 || r.bottom > innerHeight * 0.7) window.scrollBy({ top: r.top - innerHeight * 0.36, behavior: reduced ? 'auto' : 'smooth' })
      }
    }

    const tick = () => {
      frame = requestAnimationFrame(tick)
      const pos = position()
      if (!pos || pos.index === index) return
      index = pos.index
      place(true)
    }
    frame = requestAnimationFrame(tick)
    const ro = new ResizeObserver(() => { if (index >= 0) place(false) })
    ro.observe(el)
    return () => { cancelAnimationFrame(frame); ro.disconnect(); hide() }
  }, [reading, layout, reduced])

  const click = (e: React.MouseEvent) => {
    if (!reading || !onSeek || window.getSelection()?.toString()) return
    const s = (e.target as HTMLElement).closest<HTMLElement>('.s')
    if (s) onSeek(Number(s.dataset.s))
  }

  return (
    <div className="prose-wrap" ref={wrap}>
      <div className="read-bands" ref={layer} aria-hidden="true" />
      <div className={`prose${reading ? ' reading' : ''}`} onClick={click}>
        {layout.map((b, i) => {
          const content = b.pieces.map((p, j) => (
            <span key={p.index}>
              {j > 0 && ' '}
              <span className={`s${marked?.has(p.index) ? ' marked' : ''}`} data-s={p.index}>{p.text}</span>
            </span>
          ))
          return b.kind === 'heading' ? <h2 key={i}>{content}</h2> : <p key={i}>{content}</p>
        })}
      </div>
    </div>
  )
})
