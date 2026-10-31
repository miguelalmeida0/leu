/** Small semantic ticks only. Unsupported hardware must never affect an action. */
let lastPulse = -Infinity
export function hapticFeedback(kind: 'light' | 'confirm') {
  if (document.visibilityState !== 'visible' || typeof navigator.vibrate !== 'function') return
  const now = performance.now()
  if (now - lastPulse < 80) return
  lastPulse = now
  try { navigator.vibrate(kind === 'light' ? 6 : 12) } catch { /* Browser or device policy can reject vibration. */ }
}
