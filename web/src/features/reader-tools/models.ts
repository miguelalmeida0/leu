export type LabKind = 'stack' | 'queue' | 'references'
export const labs: Record<LabKind, { title: string; description: string }> = {
  stack: { title: 'Try a stack', description: 'Push an item, then see which one comes back.' },
  queue: { title: 'Try a queue', description: 'Add items and follow the order they leave.' },
  references: { title: 'Try shared references', description: 'Change an object through two different names.' },
}

/** Deliberately narrow matches: never pretend an arbitrary paragraph is executable. */
export function matchingLabs(text: string): LabKind[] {
  const result: LabKind[] = []
  if (/\bstack\b/i.test(text) && /\b(push|pop|last.in.first.out|lifo)\b/i.test(text)) result.push('stack')
  if (/\bqueue\b/i.test(text) && /\b(enqueue|dequeue|first.in.first.out|fifo)\b/i.test(text)) result.push('queue')
  if (/\b(reference[sd]?|alias(?:ing)?)\b/i.test(text) && /\b(object|mutat\w*|shared?)\b/i.test(text)) result.push('references')
  return result
}

export interface Crop { x: number; y: number; width: number; height: number }
export const wholePage: Crop = { x: 0, y: 0, width: 1, height: 1 }
export interface PinnedReference { page: number; quote?: string; crop: Crop }

export function validReference(value: unknown, pages: number): value is PinnedReference {
  if (!value || typeof value !== 'object') return false
  const r = value as PinnedReference
  const c = r.crop
  return Number.isInteger(r.page) && r.page >= 1 && r.page <= pages &&
    (r.quote === undefined || (typeof r.quote === 'string' && r.quote.length <= 12000)) &&
    !!c && [c.x, c.y, c.width, c.height].every(Number.isFinite) &&
    c.x >= 0 && c.y >= 0 && c.width >= .01 && c.height >= .01 &&
    c.x + c.width <= 1.001 && c.y + c.height <= 1.001
}
