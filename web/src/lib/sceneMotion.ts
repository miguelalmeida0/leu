import { createContext } from 'react'

/** Only illustration descendants may opt into motion. Reading/UI accessibility
 * preferences stay under the device's control outside this provider. */
export const SceneMotionOverride = createContext<boolean | undefined>(undefined)

export type SceneMotionChoice = 'auto' | 'play' | 'pause'
const key = 'leu.scene-motion.v1'

export function loadSceneMotionChoice(): SceneMotionChoice {
  try {
    const saved = window.localStorage.getItem(key)
    return saved === 'play' || saved === 'pause' ? saved : 'auto'
  } catch {
    return 'auto'
  }
}

export function saveSceneMotionChoice(choice: SceneMotionChoice): void {
  try {
    if (choice === 'auto') window.localStorage.removeItem(key)
    else window.localStorage.setItem(key, choice)
  } catch {
    // Playback still works for this visit when browser storage is unavailable.
  }
}
