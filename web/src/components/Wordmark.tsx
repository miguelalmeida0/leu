/** The leu wordmark. Every few seconds a tiny book flutters out of the u, its pages beating
    like wings, takes a slow loop over the word and settles back in. It never reacts to the
    pointer, and under reduced motion it stays home. The link around it says "Leu, home". */
export function Wordmark() {
  return (
    <span className="wordmark-inner" aria-hidden="true">
      <span className="wm-word">le<span className="wm-u">u
        <span className="wm-book">
          <svg viewBox="0 0 20 14" width="13" height="9.5">
            <g className="wm-wing wm-left"><path d="M10 12.5 C 7.5 11, 4.5 10.6, 1.2 11.2 L 1.2 3.2 C 4.5 2.6, 7.5 3, 10 4.5 Z" /><path className="wm-lines" d="M3.4 6.2 C 5 5.9, 6.6 6.1, 8 6.8 M3.4 8.3 C 5 8, 6.6 8.2, 8 8.9" /></g>
            <g className="wm-wing wm-right"><path d="M10 12.5 C 12.5 11, 15.5 10.6, 18.8 11.2 L 18.8 3.2 C 15.5 2.6, 12.5 3, 10 4.5 Z" /><path className="wm-lines" d="M16.6 6.2 C 15 5.9, 13.4 6.1, 12 6.8 M16.6 8.3 C 15 8, 13.4 8.2, 12 8.9" /></g>
            <path className="wm-spine" d="M10 4.5 V 12.5" />
          </svg>
        </span>
      </span></span>
    </span>
  )
}
