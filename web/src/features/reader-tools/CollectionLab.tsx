import { useState } from 'react'

export function CollectionLab({ kind }: { kind: 'stack' | 'queue' }) {
  const [items, setItems] = useState(['A', 'B'])
  const [next, setNext] = useState(2)
  const [history, setHistory] = useState<string[]>([])
  const [message, setMessage] = useState('Two items added: A, then B. Which one leaves first?')
  const stack = kind === 'stack'
  const record = (text: string) => { setMessage(text); setHistory(old => [...old.slice(-4), text]) }
  const add = () => {
    if (items.length >= 6) return
    const label = next < 26 ? String.fromCharCode(65 + next) : `Item ${next + 1}`
    setItems(old => [...old, label]); setNext(n => n + 1)
    record(`${stack ? 'Pushed' : 'Enqueued'} ${label}. ${stack ? label : items[0] ?? label} leaves next.`)
  }
  const remove = () => {
    if (!items.length) return
    const label = stack ? items.at(-1)! : items[0]
    setItems(old => stack ? old.slice(0, -1) : old.slice(1))
    record(`${stack ? 'Popped' : 'Dequeued'} ${label}: it was added ${stack ? 'last' : 'first'}.`)
  }
  return <div className="collection-lab">
    <p className="lab-rule">{stack ? 'Last in, first out' : 'First in, first out'}</p>
    <ol className={`lab-items ${kind}`} aria-label={`${stack ? 'Stack' : 'Queue'} contents, in arrival order`}>
      {items.map((item, index) => <li key={item} data-next={index === (stack ? items.length - 1 : 0)}>
        <strong>{item}</strong><span>{index === (stack ? items.length - 1 : 0) ? 'Leaves next' : 'Waiting'}</span>
      </li>)}
    </ol>
    {!items.length && <p className="lab-empty">Empty. Add an item to start again.</p>}
    <div className="tool-actions">
      <button className="btn ink" onClick={add} disabled={items.length >= 6}>{stack ? 'Push' : 'Enqueue'} an item</button>
      <button className="btn soft" onClick={remove} disabled={!items.length}>{stack ? 'Pop' : 'Dequeue'} an item</button>
      <button className="quiet-link" onClick={() => { setItems(['A', 'B']); setNext(2); setHistory([]); setMessage('Reset. A arrived before B.') }}>Reset example</button>
    </div>
    {items.length >= 6 && <p className="small">Six items fit in this example. Remove one to add another.</p>}
    <p className="lab-feedback" role="status" aria-live="polite">{message}</p>
    {!!history.length && <details><summary>Recent steps</summary><ol className="lab-history">{history.map((entry, i) => <li key={i}>{entry}</li>)}</ol></details>}
  </div>
}
