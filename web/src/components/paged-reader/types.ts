import type { RefObject } from 'react'
import type { Block, PDFDocumentProxy } from '../../lib/pdf'

export type Direction = -1 | 1
export interface ReadingPosition {
  page: number
  sentence: number
  fraction: number
  part: number
  parts: number
  previous: boolean
  next: boolean
}
export interface PageMetrics { fontsReady: boolean; parts: number; starts: number[]; columns: number[]; ends: number[]; key: string }
export interface PageData { blocks: Block[]; aspect: number; error?: string; textError?: string }
export interface PagedReaderHandle { step: (direction: Direction) => void; goToPage: (page: number) => void }
export interface PagedReaderProps {
  doc: PDFDocumentProxy
  page: number
  mode: 'rebuilt' | 'original'
  originalFit: 'page' | 'width'
  zoom: number
  bookmark?: { page: number; sentence: number; fraction: number }
  activePaper: RefObject<HTMLElement | null>
  reading: boolean
  controls: boolean
  marked?: Set<number>
  onSeek: (index: number) => void
  onTurn: (page: number) => void
  onZoom: (zoom: number) => void
  onExit: () => void
  onToggleControls: () => void
  onPosition: (position: ReadingPosition) => void
}
