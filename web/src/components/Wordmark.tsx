/** The leu wordmark: the word and its full stop. Every few seconds the full stop gives two
    small hops, squashing a little as it lands, with its shadow tightening under it. That's
    all. Nothing happens on hover; under reduced motion it sits still. */
export function Wordmark() {
  return (
    <span className="wordmark-inner">
      <span className="wm-word">leu</span>
      <span className="wm-stop" aria-hidden="true">
        <span className="wm-shadow" />
        <span className="wm-dot" />
      </span>
    </span>
  )
}
