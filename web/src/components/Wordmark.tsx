/** The leu lockup: a small ink tile holding an open book, and the word. Every few seconds one
    page lifts and turns over, slowly, with the light moving across it, the way a page turns
    when someone is reading beside you. It never reacts to the pointer; under reduced motion
    the book simply lies open. The link around it says "Leu, home". */
export function Wordmark() {
  return (
    <span className="wordmark-inner" aria-hidden="true">
      <span className="wm-tile">
        <span className="wm-book">
          <span className="wm-page wm-left" />
          <span className="wm-page wm-right" />
          <span className="wm-turn"><span className="wm-face wm-front" /><span className="wm-face wm-back" /></span>
          <span className="wm-ribbon" />
        </span>
      </span>
      <span className="wm-word">leu</span>
    </span>
  )
}
