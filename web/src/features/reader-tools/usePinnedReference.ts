import { useState } from 'react'
import { validReference, type PinnedReference } from './models'

export function usePinnedReference(bookId: string, pages: number) {
  const key = `leu.reference.${bookId}`
  const [reference, setReference] = useState<PinnedReference | null>(() => {
    try {
      const saved: unknown = JSON.parse(localStorage.getItem(key) ?? 'null')
      return validReference(saved, pages) ? saved : null
    } catch { return null }
  })
  const [expanded, setExpanded] = useState(true)
  const [notice, setNotice] = useState('')
  const pin = (next: PinnedReference | null) => {
    if (next && !validReference(next, pages)) return
    setReference(next)
    setExpanded(true)
    try {
      if (next) localStorage.setItem(key, JSON.stringify(next))
      else localStorage.removeItem(key)
      setNotice('')
    } catch { setNotice('This reference is available for this visit, but could not be saved on this device.') }
  }
  return { reference, expanded, setExpanded, pin, notice }
}
