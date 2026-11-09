import { useCallback, useState } from 'react'

type ReadingMode = 'original' | 'rebuilt'
const key = 'leu.reader.mode'

export function useReaderPreferences() {
  const [mode, updateMode] = useState<ReadingMode>(() => {
    try { return localStorage.getItem(key) === 'rebuilt' ? 'rebuilt' : 'original' }
    catch { return 'original' }
  })
  const setMode = useCallback((next: ReadingMode) => {
    updateMode(next)
    try { localStorage.setItem(key, next) } catch { /* The current session still works. */ }
  }, [])
  return [mode, setMode] as const
}
