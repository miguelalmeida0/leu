import { useEffect, useRef, useState } from 'react'
import './DockMotion.css'
import { chooseVoice, pause, position, preferSystemSpeech, resume, seek, setSpeed, speak, systemVoices, useVoice, useVoiceId, voices } from '../lib/voice'

const speeds = [0.9, 1, 1.15, 1.3]
const mb = (n: number) => Math.round(n / 1e6)

/** The reading dock: always at the foot of the page. Listening and turning pages live in one
    place. Play starts the page from the top (or carries on where you paused); while Leu reads,
    the line along the top of the dock fills, the arrows step a sentence, and Space pauses. The
    voice chip picks a voice; the speed is remembered. */
export function Dock({ page, pages, canPlay, onPlay, onTurn, compact = false }: { page: number; pages: number; canPlay: boolean; onPlay: () => void; onTurn: (page: number) => void; compact?: boolean }) {
  const voice = useVoice()
  const voiceId = useVoiceId()
  const [menu, setMenu] = useState(false)
  const [mobileSpeech, setMobileSpeech] = useState(preferSystemSpeech)
  const [nativeVoices, setNativeVoices] = useState(systemVoices)
  const line = useRef<HTMLSpanElement>(null)
  const menuRef = useRef<HTMLDivElement>(null)
  useEffect(() => { if (compact) setMenu(false) }, [compact])
  const availableVoices = mobileSpeech
    ? [{ id: 'system:default', name: 'Device default', note: 'Built-in voice' }, ...nativeVoices]
    : voices
  const selected = mobileSpeech
    ? availableVoices.find((v) => v.id === voiceId)?.name ?? 'De¶»§q«^