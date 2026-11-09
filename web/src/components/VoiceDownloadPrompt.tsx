import { cancelVoiceDownload, confirmVoiceDownload, useVoice } from '../lib/voice'
import { Modal } from './ui'

export function VoiceDownloadPrompt() {
  const { awaitingDownload } = useVoice()
  if (!awaitingDownload) return null
  return <Modal label="Download the reading voice" onClose={cancelVoiceDownload} width={420}>
    <h2 className="display" style={{ fontSize: 24 }}>Download the reading voice?</h2>
    <p style={{ marginTop: 16 }}>About 92 MB on first use. It stays on this device for offline reading. Your book is never uploaded.</p>
    <p className="muted small" style={{ marginTop: 12 }}>You can cancel while it loads.</p>
    <div className="row" style={{ gap: 12, marginTop: 24, flexWrap: 'wrap' }}>
      <button className="btn ink" onClick={confirmVoiceDownload}>Download and listen</button>
      <button className="quiet-link" onClick={cancelVoiceDownload}>Not now</button>
    </div>
  </Modal>
}
