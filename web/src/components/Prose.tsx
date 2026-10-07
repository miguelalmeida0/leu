import { memo, useEffect, useMemo, useRef } from 'react'
import type { Block } from '../lib/pdf'
import { useReducedMotion } from '../lib/motion'
import { position, speechPieces } from '../lib/voice'

/** The page as text you can follow by ear, the way synced lyrics work: while Leu reads, the
    sentence being heard is set in full ink and fills word by word as it's spoken, what's been
    read rests a step lighter, what's ahead waits lighter still, and the page glides to keep the
    line being read in view. Click any sentence to have Leu read from there. */
export function piecesOf(blocks: Block[]): string[] {
  return blocks.flatMap((b) => speechPieces(b.text))
}

export const Prose = memo(function Prose({ blocks, reading, marked, onSeek }: { blocks: Block[]; reading: boolean; marked?: Set<number>; onSeek?: (index: number) => void }) {
  const root = useRef<HTMLDivElement>(null)
  const reduced = useReducedMotion()

  const layout = useMemo(() => {
    let n = 0
    return blocks.map((b) => ({ kind: b.kind, pieces: speechPieces(b.text).map((text) => ({ text, index: n++ })) }))
  }, [blocks])

  useEffect(() => {
    const el = root.current
    if (!el) return
    const all = [...el.querySelectorAll<HTMLElement>('.s')]
    const clear = () => { all.forEach((s) => s.classList.remove('now', 'heard')); el.querySelectorAll('.w.said').forEach((w) => w.classList.remove('said')) }
    if (!reading) { clear(); return }
    let frame = 0, index = -1, said = 0
    let words: { el: HTMLElement; at: number }[] = []
    const tick = () => {
      frame = requestAnimationFrame(tick)
      const pos = position()
      if (!pos) return
      if (pos.index !== index) {
        index = pos.index; said = 0; words = []
        el.querySelectorAll('.w.said').forEach((w) => w.classList.remove('said'))
        let current: HTMLElement | null = null
        for (const s of all) {
          const i = Number(s.dataset.s)
          s.classList.toggle('heard', i < index)
          s.classList.toggle('now', i === index)
          if (i === index) current = s
        }
        if (!current) return
        // Each word begins at its share of the sentence's letters.
        const list = [...current.querySelectorAll<HTMLElement>('.w')]
        const total = list.reduce((t, w) => t + (w.textContent?.length ?? 0), 0) || 1
        let run = 0
        words = list.map((w) => { const at = run / total; run += w.textContent?.length ?? 0; return { el: w, at } })
        // Glide so the line being read sits a little above the middle of the window.
        const r = current.getBoundingClientRect()
        if (r.top < innerHeight * 0.22 || r.bottom > innerHeight * 0.72) window.scrollBy({ top: r.top - innerHeight * 0.38, behavior: reduced ? 'auto' : 'smooth' })
      }
      while (said < words.length && words[said].at <= pos.fraction) words[said++].el.classList.add('said')
    }
    frame = requestAnimationFrame(tick)
    return () => { cancelAnimationFrame(frame); clear() }
  }, [reading, layout, reduced])

  const click = (e: React.MouseEvent) => {
    if (!reading || !onSeek || window.getSelection()?.toString()) return
    const s = (e.target as HTMLElement).closest<HTMLElement>('.s')
    if (s) onSeek(Number(s.dataset.s))
  }

  return (
    <div className={`prose${reading ? ' reading' : ''}`} ref={root} onClick={click}>
      {layout.map((b, i) => {
        const content = b.pieces.map((p, j) => (
          <span key={p.index}>
            {j > 0 && ' '}
            <span className={`s${marked?.has(p.index) ? ' marked' : ''}`} data-s={p.index} title={reading ? 'Read from here' : undefined}>
              {p.text.split(/(?<=\s)/).map((w, k) => <span className="w" key={k}>{w}</span>)}
            </span>
          </span>
        ))
        return b.kind === 'heading' ? <h2 key={i}>{content}</h2> : <p key={i}>{content}</p>
      })}
    </div>
  )
})
