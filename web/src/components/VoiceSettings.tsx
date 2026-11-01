import { useEffect, useState } from 'react'
import { chooseVoice, preferSystemSpeech, speak, systemVoices, useVoiceId, voices } from '../lib/voice'
import './VoiceSettings.css'

/** Mobile readers keep one Play control. Voice choice stays available in settings. */
export function VoiceSettings() {
  const voiceId = useVoiceId()
  const [onDevice, setOnDevice] = useState(preferSystemSpeech)
  const [nativeVoices, setNativeVoices] = useState(systemVoices)

  useEffect(() => {
    const media = window.matchMedia('(max-width: 900px) and (pointer: coarse)')
    const sync = () => setOnDevice(media.matches)
    const syncVoices = () => setNativeVoices(systemVoices())
    sync()
    syncVoices()
    media.addEventListener('change', sync)
    if ('speechSynthesis' in window) speechSynthesis.addEventListener('voiceschanged', syncVoices)
    return () => {
      media.removeEventListener('change', sync)
      if ('speechSynthesis' in window) speechSynthesis.removeEventListener('voiceschanged', syncVoices)
    }
  }, [])

  const available = onDevice
    ? [{ id: 'system:default', name: 'Device default', note: 'Built-in voice' }, ...nativeVoices]
    : voices
  return <section className="reader-voice-settings">
    <h3>Reading voice</h3>
    <div role="radiogroup" aria-label="Reading voice" className="reader-voice-list">
      {available.map((option) => {
        const selected = voiceId === option.id || (onDevice && option.id === 'system:default' && !voiceId.startsWith('system:'))
        return <button key={option.id} type="button" role="radio" aria-checked={selected}
          onClick={() => {
            chooseVoice(option.id)
            speak(`Hello, I'm ${option.name}. I'll read with you.`, 'preview')
          }}>
          <span><strong>{option.name}</strong><small>{option.note}</small></span>
          <span className="reader-voice-check" aria-hidden="true">{selected ? '✓' : ''}</span>
        </button>
      })}
    </div>
  </section>
}
