import { useCallback, useEffect, useRef, type RefObject } from 'react'
import { hapticFeedback } from '../../lib/haptics'

export interface ReaderDismissGesture {
  pull: (distance: number) => boolean
  release: (commit: boolean) => void
  cancel: () => void
  busy: () => boolean
}

/** A separate transform keeps dismissal independent of horizontal pagination. */
export function useReaderDismiss(root: RefObject<HTMLDivElement | null>, stage: RefObject<HTMLDivElement | null>, hint: RefObject<HTMLSpanElement | null>, reduced: boolean, onExit: () => void): ReaderDismissGesture {
  const latest = useRef({ reduced, onExit })
  latest.current = { reduced, onExit }
  const animation = useRef<Animation | null>(null), active = useRef(false), closing = useRef(false), ticked = useRef(false)
  const live = useRef(true)
  const clear = useCallback(() => {
    animation.current?.cancel(); animation.current = null
    active.current = false; closing.current = false; ticked.current = false
    if (stage.current) { stage.current.style.transform = ''; stage.current.style.opacity = ''; stage.current.style.willChange = '' }
    if (root.current) {
      delete root.current.dataset.pullState
      root.current.style.removeProperty('--pull-progress')
      root.current.dataset.settled = 'true'
    }
  }, [root, stage])
  useEffect(() => {
    live.current = true
    return () => { live.current = false; clear() }
  }, [clear])
  const pull = useCallback((distance: number) => {
    const el = root.current, paper = stage.current
    if (!el || !paper || closing.current) return false
    const dy = Math.max(0, distance), threshold = Math.min(140, Math.max(96, el.clientHeight * .18))
    const ready = dy >= threshold
    active.current = true
    el.dataset.pullState = ready ? 'ready' : 'tracking'
    el.dataset.settled = 'false'
    el.style.setProperty('--pull-progress', String(Math.min(1, dy / threshold)))
    if (hint.current) hint.current.textContent = ready ? 'Release to exit' : 'Pull down to exit'
    if (!latest.current.reduced) {
      const offset = dy * .58 / (1 + dy / (el.clientHeight * .85))
      paper.style.willChange = 'transform'
      paper.style.transform = `translate3d(0,${offset}px,0)`
    } else paper.style.transform = ''
    if (ready && !ticked.current) { ticked.current = true; hapticFeedback('light') }
    return ready
  }, [root, stage, hint])
  const release = useCallback((commit: boolean) => {
    const el = root.current, paper = stage.current
    if (!el || !paper || closing.current || !active.current) return
    closing.current = true
    el.dataset.pullState = commit ? 'exiting' : 'settling'
    if (commit) hapticFeedback('confirm')
    const finish = () => {
      if (!live.current) return
      if (commit) latest.current.onExit()
      else clear()
    }
    if (latest.current.reduced) { finish(); return }
    const transform = getComputedStyle(paper).transform
    const y = new DOMMatrixReadOnly(transform).m42
    animation.current = paper.animate([
      { transform, opacity: 1 },
      { transform: `translate3d(0,${commit ? y + 48 : 0}px,0)`, opacity: commit ? 0 : 1 },
    ], { duration: commit ? 150 : 190, easing: 'cubic-bezier(.2,.8,.25,1)', fill: 'forwards' })
    void animation.current.finished.then(finish).catch(() => {})
  }, [root, stage, clear])
  return { pull, release, cancel: clear, busy: () => closing.current }
}
