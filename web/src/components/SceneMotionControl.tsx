import { useState, type ReactNode } from 'react'
import { useReducedMotion } from '../lib/motion'
import { loadSceneMotionChoice, saveSceneMotionChoice, SceneMotionOverride, type SceneMotionChoice } from '../lib/sceneMotion'
import './SceneMotionControl.css'

/** An explicit way to start the illustration even when automatic motion is off.
 * The control is outside the illustration, so finger gestures still scroll. */
export function SceneMotionControl({ children }: { children: ReactNode }) {
  const deviceReduced = useReducedMotion()
  const [choice, setChoice] = useState(loadSceneMotionChoice)
  const paused = choice === 'auto' ? deviceReduced : choice === 'pause'
  const choose = (next: SceneMotionChoice) => {
    saveSceneMotionChoice(next)
    setChoice(next)
  }

  return (
    <div className="scene-motion" data-playback={paused ? 'paused' : 'playing'}>
      <div className="scene-motion-controls">
        <span className="scene-motion-label" role="status">
          {paused ? (choice === 'auto' ? 'Paused for reduced motion' : 'Animation paused') : 'Rain and steam'}
        </span>
        <button type="button" className="scene-motion-button"
          aria-label={paused ? 'Play animation' : 'Pause animation'}
          onClick={() => choose(paused ? 'play' : 'pause')}>
          <svg width="15" height="15" viewBox="0 0 24 24" aria-hidden="true">
            {paused
              ? <path d="M7 4.8v14.4a1 1 0 0 0 1.5.87l12-7.2a1 1 0 0 0 0-1.74l-12-7.2A1 1 0 0 0 7 4.8Z" fill="currentColor" />
              : <path d="M8 5v14M16 5v14" stroke="currentColor" strokeWidth="4" strokeLinecap="round" />}
          </svg>
          {paused ? 'Play animation' : 'Pause animation'}
        </button>
      </div>
      {choice !== 'auto' && (
        <button className="scene-motion-reset" type="button" onClick={() => choose('auto')}>Use device setting</button>
      )}
      <SceneMotionOverride.Provider value={paused}>{children}</SceneMotionOverride.Provider>
    </div>
  )
}
