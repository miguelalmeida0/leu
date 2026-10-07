import { memo, useEffect, useMemo, useRef } from 'react'
import type { Block } from '../lib/pdf'
import { useReducedMotion } from '../lib/motion'
import { position, speechPieces } from '../lib/voice'

/** The page as text you can follow by ear. Every sentence is one spoken piece and every word
    its own span, so while Leu reads, a soft marker sweeps under the words as they are heard,
    line by line, and lifts again once the sentence is behind you. */
export function piecesOf(blocks: Block[]): string[] {
  return blocks.flatMap((b) => speechPieces(b.text))
}

export const Prose = memo(function Prose({ blocks, reading, marked }: { blocks: Block[]; reading: boolean; marked?: Set<number> }) {
  const root = useRef<HTMLDivElement>(null)
  const reduced = useReducedMotion()

  const layout = useMemo(() => {
    let n = 0
    return blocks.map((b) => {
      const pieces = speechPieces(b.text).map((text) => ({ text, index: n++ }))
      return { kind: b.kind, pieces }
    })
  }, [blocks])

  useEffect(() => {
    const el = root.current
    if (!el) return
    const clear = () => el.querySelectorAll('.now, .heard, .said').forEach((x) => x.classList.remove('now', 'heard', 'said'))
    if (!reading) { clear(); return }
    let frame = 0, index = -1, said = 0
    let words: { el: HTMLElement; at: number }[] = []
    const tick = () => {
      frame = requestAnimationFrame(tick)
      const pos = position()
      if (!pos) return
      if (pos.index !== index) {
        el.querySelectorAll('.s.now').forEach((x) => { x.classList.remove('now'); x.classList.add('heard') })
        const s = el.querySelector<HTMLElement>(`.s[data-s="${pos.index}"]`)
        index = pos.index; said = 0; words = []
        if (!s) return
        s.classList.remove('heard'); s.classList.add('now')
        // Each word starts at its share of the sentence's characters.
        const list = [...s.querySelectorAll<HTMLElement>('.w')]
        const total = list.reduce((t, w) => t + (w.textContent?.length ?? 0), 0) || 1
        let run = 0
        words = list.map((w) => { const at = run / total; run += w.textContent?.length ?? 0; return { el: w, at } })
        // Keep the line being read comfortably in view.
        const r = s.getBoundingClientRect()
        if (r.top < 120 || r.top > innerHeight * 0.7) window.scrollBy({ top: r.top - innerHeight * 0.36, behavior: reduced ? 'auto' : 'smooth' })
      }
      while (said < words.length && words[said].at <= pos.fraction + 0.02) words[said++].el.classList.add('said')
    }
    frame = requestAnimationFrame(tick)
    return () => { cancelAnimationFrame(frame); clear() }
  }, [reading, layout, reduced])

  return (
    <div className={`prose${reading ? ' reading' : ''}`} ref={root}>
      {layout.map((b, i) => {
        const content = b.pieces.map((p, j) => (
          <span key={p.index}>
            {j > 0 && ' '}
            <span className={`s${marked?.has(p.index) ? ' marked' : ''}`} data-s={p.index}>
              {p.text.split(/(?<=\s)/).map((w, k) => <span className="w" key={k}>{w}</span>)}
            </span>
          </span>
        ))
        return b.kind === 'heading' ? <h2 key={i}>{content}</h2> : <p key={i}>{content}</p>
      })}
    </div>
  )
})
