import { useRef } from 'react'
import { loadImage, useCanvasLoop, useReducedMotion } from '../lib/motion'

/* The knitting basket render with a strand of yarn drawn live from the needle to the loose
   ball (KnittingBasket in WelcomeScreen.swift). It sways a few pixels over many seconds. */

const tip = { x: 0.5535, y: 0.0356 }, ball = { x: 0.662, y: 0.624 }
let basket: HTMLImageElement | undefined
void loadImage('/art/basket.webp').then((i) => { basket = i })

export function Basket() {
  const canvas = useRef<HTMLCanvasElement>(null)
  const reduced = useReducedMotion()
  useCanvasLoop(canvas, (ctx, w, h, now) => {
    ctx.clearRect(0, 0, w, h)
    if (basket) ctx.drawImage(basket, 0, 0, w, h)
    const t = reduced ? 0 : now
    const sway = Math.sin(t * 0.45) * 0.006 + Math.sin(t * 0.21 + 1.3) * 0.004
    const path = () => {
      ctx.beginPath()
      ctx.moveTo(tip.x * w, tip.y * h)
      ctx.bezierCurveTo((tip.x + 0.008 + sway) * w, 0.42 * h, (ball.x - 0.07 - sway * 0.6) * w, (ball.y + 0.012) * h, ball.x * w, ball.y * h)
    }
    ctx.lineCap = 'round'
    path(); ctx.strokeStyle = '#C98476'; ctx.lineWidth = Math.max(1.5, w * 0.0024); ctx.stroke()
    path(); ctx.strokeStyle = '#EBB5A3'; ctx.lineWidth = Math.max(0.8, w * 0.0012); ctx.stroke()
  }, { fps: 20, still: reduced })
  return (
    <canvas
      ref={canvas}
      className="scene-canvas basket"
      role="img"
      aria-label="A knitting basket with yarn and a half-finished striped blanket"
    />
  )
}
