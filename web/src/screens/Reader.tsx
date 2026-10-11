import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import { Prose, piecesOf } from '../components/Prose'
import { Empty, Modal } from '../components/ui'
import { openPdf, pageBlocks, pdfDeadline, renderPage, type Block, type PDFDocumentProxy } from '../lib/pdf'
import { go, href } from '../lib/router'
import { addNote, loadOutline, loadPdf, patchBook, removeNote, upsertMemory, useStore, type Outline } from '../lib/store'
import { cloze, ideas } from '../lib/text'
import { Dock } from '../components/Dock'
import { captureDockFlight, completeDockFlight, type DockFlight } from '../lib/focusDockTransition'
import './FocusListening.css'
import { dismissNotice, prefetch, seek, speak, stop, useVoice, warmVoice } from '../lib/voice'
import { ExplainPanel, gistOf } from './Explain'

const limitZoom = (value: number) => Math.min(2.75, Math.max(0.8, Math.round(value * 20) / 20))
const pinchDistance = (touches: ArrayLike<{ clientX: number; clientY: number }>) => {
  const a = touches[0], b = touches[1]
  return a && b ? Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY) : 0
}

/** Reading (06): the chapter rail, the page as paper (rebuilt for reading, or the original),
    and the margin with your notes. Select any line to keep a note, explain it, or hear it. */
export function Reader({ id, page }: { id: string; page: number }) {
  const book = useStore((s) => s.books.find((b) => b.id === id))
  const allNotes = useStore((s) => s.notes)
  con¶»§q«^