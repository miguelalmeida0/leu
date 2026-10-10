import { useEffect, useRef, useState } from 'react'
import { chooseVoice, pause, position, preferSystemSpeech, resume, seek, setSpeed, speak, systemVoices, useVoice, useVoiceId, voices } from '../lib/voice'

const speeds = [0.9, 1, 1.15, 1.3]
const mb = (n: number) => Math.round(n / 1e6)

/** The reading dock: always at the foot of the page. Listening and turning pages live in one
    place. Play starts the page from the top (or carries on where you paused); while Leu reads,
    the line along the top of the dock fills, the arrows step a sentence, and Space pauses. The
    voice chip picks a voice; the speed is remembered. */
export function Dock({ page, pages, canPlay, onPlay, onTurn }: { page: number; pages: number; canPlay: boolean; onPlay: () => void; onTurn: (page: number) => void }) {
  const voice = useVoice()
  const voiceId = useVoiceId()
  const [menu, setMenu] = useState(false)
  const [mobileSpeech, setMobileSpeech] = useState(preferSystemSpeech)
  const [nativeVoices, setNativeVoices] = useState(systemVoices)
  const line = useRef<HTMLSpanElement>(null)
  const menuRef = useRef<HTMLDivElement>(null)
  const availableVoices = mobileSpeech
    ? [{ id: 'system:default', name: 'Device default', note: 'Built-in voice' }, ...nativeVoices]
    : voices
  const selected = mobileSpeech
    ? availableVoices.find((v) => v.id === voiceId)?.name ?? 'Device voice'
    : voices.find((v) => v.id === voiceId)?.name ?? 'Heart'
  const name = selected
  const active = voice.status !== 'idle'
  const playing = voice.status === 'speaking'
  const waiting = voice.status === 'loading'

  useEffect(() => {
    const media = window.matchMedia('(max-width: 900px) and (pointer: coarse)')
    const refreshMode = () => setMobileSpeech(media.matches)
    media.addEventListener('change', refreshMode)
    refreshMode()
    const refreshVoices = () => setNativeVoices(systemVoices())
    refreshVoices()
    if ('speechSynthesis' in window) speechSynthesis.addEventListener('voiceschanged', refreshVoices)
    return () => {
      media.removeEventListener('change', refreshMode)
      if ('speechSynthesis' in window) speechSynthesis.removeEventListener('voiceschanged', refreshVoices)
    }
  }, [])

  // The listening line along the top of the dock.
  useEffect(() => {
    let frame = 0
    const tick = () => {
      frame = requestAnimationFrame(tick)
      const p = position(), el = line.current
      if (!el) return
      el.style.transform = `scaleX(${p ? Math.min(1, (p.index + p.fraction) / Math.max(1, voice.count)) : 0})`
    }
    frame = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frame)
  }, [voice.count])

  const toggle = () => { if (playing) pause(); else if (voice.status === 'paused') resume(); else if (!waiting && canPlay) onPlay() }
  const step = (d: number) => { const p = position(); if (p) seek(p.index + d) }

  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement).closest('input, textarea, button, select, [contenteditable]') || e.metaKey || e.ctrlKey || document.querySelector('.scrim')) return
      if (e.key === ' ') { e.preventDefault(); toggle() }
      if (active && (e.key === 'ArrowRight' || e.key === 'ArrowLeft')) { e.preventDefault(); e.stopImmediatePropagation(); step(e.key === 'ArrowRight' ? 1 : -1) }
    }
    window.addEventListener('keydown', key, true)
    return () => window.removeEventListener('keydown', key, true)
  })

  useEffect(() => {
    if (!menu) return
    const close = (e: PointerEvent) => { if (!menuRef.current?.contains(e.target as Node)) setMenu(false) }
    const escape = (e: KeyboardEvent) => { if (e.key === 'Escape') setMenu(false) }
    window.addEventListener('pointerdown', close, true)
    window.addEventListener('keydown', escape)
    return () => {
      window.removeEventListener('pointerdown', close, true)
      window.removeEventListener('keydown', escape)
    }
  }, [menu])

  const status = voice.download
    ? `Downloading the voice, once · ${mb(voice.download.loaded)} of ${mb(voice.download.total)} MB`
    : waiting ? (voice.kokoro === 'ready' ? 'Starting…' : 'Warming up the voice…')
      : playing ? (voice.speakingId === 'page' ? 'Reading this page' : 'Reading your selection')
        : voice.status === 'paused' ? 'Paused · Space to carry on'
          : canPlay ? 'Listen to this page' : 'Nothing to read on this page'

  return (
    <div className={`dock${active ? ' active' : ''}`} role="region" aria-label="Listening and pages">
      <span className="dock-line" aria-hidden="true">
        <span className="dock-line-fill" ref={line} style={voice.download ? { transform: `scaleX(${voice.download.loaded / voice.download.total})` } : undefined} />
      </span>

      <div className="dock-voice" ref={menuRef}>
        <button className="dock-chip" aria-haspopup="menu" aria-expanded={menu} onClick={() => setMenu((m) => !m)} aria-label={`Voice: ${name}. Change`}>
          <span className="dock-avatar" aria-hidden="true">{mobileSpeech ? '♪' : name[0]}</span>
          <span className="dock-who">
            <strong>{name} <svg width="10" height="10" viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" /></svg></strong>
            <span aria-live="polite">{status}</span>
          </span>
        </button>
        {menu && (
          <div className="dock-menu card" role="menu" aria-label="Voices">
            <p className="eyebrow paper" style={{ padding: '6px 12px 8px' }}>{mobileSpeech ? 'Voices on this device' : 'Kokoro voices'}</p>
            {availableVoices.map((v) => (
              <button key={v.id} role="menuitemradio" aria-checked={mobileSpeech ? (voiceId === v.id || (v.id === 'system:default' && !voiceId.startsWith('system:'))) : voiceId === v.id}
                className={voiceId === v.id ? 'on' : ''} onClick={() => {
                  chooseVoice(v.id); setMenu(false)
                  speak(`Hello, I'm ${v.name}. I'll read with you.`, 'preview')
                }}>
                <strong>{v.name}</strong><span className="muted small">{v.note}</span>
              </button>
            ))}
            <p className="muted small" style={{ padding: '8px 12px 4px', maxWidth: 270 }}>
              {mobileSpeech ? 'Read aloud uses the voice already installed on your device. No large download.' : 'Downloaded once, then available offline. The system voice is used if needed.'}
            </p>
          </div>
        )}
      </div>

      <div className="dock-controls">
        <button className="dock-btn" onClick={() => step(-1)} aria-label="Previous sentence" disabled={!active || waiting}>
          <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path d="M7 5v14" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" /><path d="M19 6.2v11.6a.9.9 0 0 1-1.4.75L9.3 12.75a.9.9 0 0 1 0-1.5l8.3-5.8A.9.9 0 0 1 19 6.2z" fill="currentColor" /></svg>
        </button>
        <button className="dock-play" onClick={toggle} aria-label={playing ? 'Pause' : voice.status === 'paused' ? 'Carry on reading' : 'Listen to this page'} aria-keyshortcuts="Space" disabled={!canPlay && !active}>
          {waiting ? <span className="dock-spin" aria-hidden="true" /> : playing
            ? <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><rect x="6" y="5" width="4.2" height="14" rx="1.3" fill="currentColor" /><rect x="13.8" y="5" width="4.2" height="14" rx="1.3" fill="currentColor" /></svg>
            : <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path d="M8 5.6v12.8a1 1 0 0 0 1.5.86l10.2-6.4a1 1 0 0 0 0-1.72L9.5 4.74A1 1 0 0 0 8 5.6z" fill="currentColor" /></svg>}
        </button>
        <button className="dock-btn" onClick={() => step(1)} aria-label="Next sentence" disabled={!active || waiting}>
          <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path d="M17 5v14" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" /><path d="M5 6.2v11.6a.9.9 0 0 0 1.4.75l8.3-5.8a.9.9 0 0 0 0-1.5L6.4 5.45A.9.9 0 0 0 5 6.2z" fill="currentColor" /></svg>
        </button>
      </div>

      <div className="dock-pages">
        <button className="dock-speed" onClick={() => setSpeed(speeds[(speeds.indexOf(voice.speed) + 1) % speeds.length] ?? 1)} aria-label={`Reading speed ${voice.speed} times. Change`}>{voice.speed}×</button>
        <span className="dock-sep" aria-hidden="true" />
        <button className="dock-btn" onClick={() => onTurn(page - 1)} disabled={page <= 1} aria-label="Previous page">
          <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path d="M15 5 8 12l7 7" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" /></svg>
        </button>
        <label className="dock-range">
          <span className="sr-only">Page</span>
          <input type="range" min={1} max={pages} value={page} onChange={(e) => onTurn(Number(e.target.value))} aria-valuetext={`Page ${page} of ${pages}`} style={{ ['--p' as string]: `${pages > 1 ? ((page - 1) / (pages - 1)) * 100 : 100}%` }} />
          <span className="tabular">{page} / {pages}</span>
        </label>
        <button className="dock-btn" onClick={() => onTurn(page + 1)} disabled={page >= pages} aria-label="Next page">
          <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path d="m9 5 7 7-7 7" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" /></svg>
        </button>
      </div>
    </div>
  )
}
