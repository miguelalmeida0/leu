import { useState } from 'react'

export function ReferenceLab() {
  const [a, setA] = useState(1)
  const [b, setB] = useState(1)
  const [shared, setShared] = useState(true)
  const [message, setMessage] = useState('A and B point to the same object. Try changing it through B.')
  const changeB = () => {
    if (shared) setA(n => n + 1)
    setB(n => n + 1)
    setMessage(shared ? 'A sees the change too. Both names refer to the same object.' : 'Only B changes. Its copy is a separate object.')
  }
  return <div>
    <p className="lab-rule">{shared ? 'Two names. One object.' : 'Two names. Separate objects.'}</p>
    <div className="reference-model" role="group" aria-label="Object references">
      <div className="reference-names"><span>A → {shared ? 'shared object' : 'original object'}</span><span>B → {shared ? 'shared object' : 'copied object'}</span></div>
      <div className="reference-objects"><div><strong>{shared ? 'Shared object' : 'Original object'}</strong><code>count: {a}</code></div>
        {!shared && <div><strong>Copied object</strong><code>count: {b}</code></div>}</div>
    </div>
    <p className="lab-values">A reads <output aria-label="Value through A">{a}</output> · B reads <output aria-label="Value through B">{b}</output></p>
    <div className="tool-actions">
      <button className="btn ink" onClick={changeB}>Increase through B</button>
      <button className="btn soft" disabled={!shared} onClick={() => { setShared(false); setMessage('B now points to a shallow copy. Change B again and compare.') }}>Give B a copy</button>
      <button className="quiet-link" onClick={() => { setA(1); setB(1); setShared(true); setMessage('Reset. Both names point to the same object again.') }}>Reset example</button>
    </div>
    <p className="lab-feedback" role="status">{message}</p>
    <p className="small muted">This example uses one numeric property. A shallow copy can still share nested objects.</p>
  </div>
}
