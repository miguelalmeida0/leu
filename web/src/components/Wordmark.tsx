import { useId } from 'react'

const THREAD = 'M1 30.5 C 7 31.5, 15 31, 21.5 27.5 C 13 22, 9.5 15.5, 12 11 C 14.5 6.5, 20 7.5, 21.5 12 C 23.5 7.2, 29.5 6.5, 31.5 11 C 34 16, 30 22.5, 21.5 27.5 C 26 30, 31 31.5, 36 30'

/** The leu wordmark: the word, and the red thread running out of its last letter to stitch a
    small heart. It is sewn in, stitch by stitch, when Leu opens and again whenever you come
    near it, and the heart gives one slow beat. The link around it says "Leu, home". */
export function Wordmark() {
  const mask = useId().replace(/:/g, '')
  return (
    <span className="wordmark-inner" aria-hidden="true">
      <span className="wm-word">leu</span>
      <svg className="wm-thread" viewBox="0 0 40 34" width="34" height="29">
        <defs>
          <mask id={mask} maskUnits="userSpaceOnUse" x="-2" y="0" width="44" height="36">
            <path className="wm-reveal" d={THREAD} pathLength={1} />
          </mask>
        </defs>
        <g mask={`url(#${mask})`}>
          <path className="wm-stitch" d={THREAD} />
        </g>
        <circle className="wm-knot" cx="36.6" cy="29.9" r="1.5" />
      </svg>
    </span>
  )
}
