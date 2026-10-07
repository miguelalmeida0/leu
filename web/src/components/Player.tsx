import { useEffect, useRef } from 'react'
import { pause, position, resume, seek, setSpeed, stop, useVoice, useVoiceId, voices } from '../lib/voice'

const speeds = [0.9, 1, 1.15, 1.3]
const mb = (n: number) => Math.round(n / 1e6)

/** The player that appears while Leu reads: where you are on the page, pause, a sentence
    back or on, speed, and which voice. Space pauses; ← → step by sentence while it's open. */
export function Player({ where }: { where: string }) {
  const voice = useVoice()
  const voiceId = useVoiceId()
  const bar = useRef<HTMLSpanElement>(null)
  const name = voices.find((v) => v.id === voiceId)?.name ?? 'Heart'
  const playing = voice.status === 'speaking'
  const waiting = voice.status === 'loading'

  useEffect(() => {
    let frame = 0
    const tick = () => {
      frame = requestAnimationFrame(tick)
      const p = position()
      if (bar.current && p) bar.current.style.transform = `scaleX(${Math.min(1, (p.index + p.fraction) / Math.max(1, voice.count))})`
    }
    frame = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frame)
  }, [voice.count])

  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement).closest('input, textarea, button, [contenteditable]')) return
      if (e.key === ' ') { e.preventDefault(); if (playing) pause(); else resume() }
      if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
        e.preventDefault(); e.stopImmediatePropagation()
        const p = position(); if (p) seek(p.index + (e.key === 'ArrowRight' ? 1 : -1))
      }
    }
    window.addEventListener('keydown', key, true)
    return () => window.removeEventListener('keydown', key, true)
  }, [playing])

  const step = (d: number) => { const p = position(); if (p) seek(p.index + d) }
  const status = voice.download
    ? `Downloading the voice, once · ${mb(voice.download.loaded)} of ${mb(voice.download.total)} MB`
    : waiting ? (voice.kokoro === 'ready' ? 'Starting…' : 'Warming up the voice…') : where

  return (
    <div className="player" role="region" aria-label="Reading aloud">
      <div className="player-who">
        <span className="player-avatar" aria-hidden="true">{name[0]}</span>
        <span className="player-text">
          <strong>{name}</strong>
          <span className="small" aria-live="polite">{status}</span>
        </span>
      </div>
      <div className="player-main">
        <div className="player-controls">
          <button className="player-btn" onClick={() => step(-1)} aria-label="Previous sentence" disabled={waiting}>
            <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path d="M7 5v14" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" /><path d="M19 6.2v11.6a.9.9 0 0 1-1.4.75L9.3 12.75a.9.9 0 0 1 0-1.5l8.3-5.8A.9.9 0 0 1 19 6.2z" fill="currentColor" /></svg>
          </button>
          <button className="player-play" onClick={() => (playing ? pause() : resume())} aria-label={playing ? 'Pause' : 'Play'} disabled={waiting}>
            {waiting ? <span className="player-spin" aria-hidden="true" /> : playing
              ? <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><rect x="6" y="5" width="4.2" height="14" rx="1.3" fill="currentColor" /><rect x="13.8" y="5" width="4.2" height="14" rx="1.3" fill="currentColor" /></svg>
              : <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path d="M8 5.6v12.8a1 1 0 0 0 1.5.86l10.2-6.4a1 1 0 0 0 0-1.72L9.5 4.74A1 1 0 0 0 8 5.6z" fill="currentColor" /></svg>}
          </button>
          <button className="player-btn" onClick={() => step(1)} aria-label="Next sentence" disabled={waiting}>
            <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path d="M17 5v14" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" /><path d="M5 6.2v11.6a.9.9 0 0 0 1.4.75l8.3-5.8a.9.9 0 0 0 0-1.5L6.4 5.45A.9.9 0 0 0 5 6.2z" fill="currentColor" /></svg>
          </button>
        </div>
        <span className="player-track" aria-hidden="true">
          {voice.download
            ? <span className="player-fill" style={{ transform: `scaleX(${voice.download.loaded / voice.download.total})` }} />
            : <span className="player-fill" ref={bar} />}
        </span>
      </div>
      <div className="player-end">
        <button className="player-speed" onClick={() => setSpeed(speeds[(speeds.indexOf(voice.speed) + 1) % speeds.length] ?? 1)} aria-label={`Speed ${voice.speed} times. Change`}>
          {voice.speed}×
        </button>
        <button className="player-btn" onClick={stop} aria-label="Stop reading">
          <svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" /></svg>
        </button>
      </div>
    </div>
  )
}
