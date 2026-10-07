import { FoggedWindow } from './FoggedWindow'
import { TeaSteam } from './TeaSteam'

/* The evening nook (HomeNookScene.swift): an arched window onto the rainy city, the daybed with
   its quilt, and a cup of tea steaming on the floor cushion. Laid out in the composition's own
   900 × 826 design space, in percentages, so it stays crisp at any width. */

const pct = (v: number, of: number) => `${(v / of) * 100}%`
const box = (x: number, y: number, w: number, h: number) => ({ left: pct(x, 900), top: pct(y, 826), width: pct(w, 900), height: pct(h, 826) })

export function NookScene() {
  return (
    <div className="nook" role="group" aria-label="Your reading corner">
      <div className="nook-frame" style={box(200, 0, 500, 420)} aria-hidden="true" />
      <div className="nook-glass" style={box(218, 18, 464, 384)}><FoggedWindow /></div>
      <div className="nook-wood" style={box(444, 18, 12, 384)} aria-hidden="true" />
      <div className="nook-wood" style={box(218, 18 + 384 * 0.42, 464, 12)} aria-hidden="true" />
      <img
        className="nook-room"
        src="/art/nook.webp"
        style={box(0, 266, 900, 560)}
        alt="A mustard daybed with a patchwork quilt, cushions, and a cup of tea on a floor cushion beside it"
        draggable={false}
      />
      <div style={{ position: 'absolute', ...box(679.4 - 130, 654.7 - 212, 260, 220), pointerEvents: 'none' }}><TeaSteam /></div>
    </div>
  )
}
