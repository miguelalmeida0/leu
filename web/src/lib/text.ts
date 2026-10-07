/* Reading the text of your books, in the browser and without a model: sentences, the words
   that carry a page, the ideas a page makes, and how much of them an explanation got across.
   These are honest heuristics for the web prototype; the app checks against the source on device. */

const STOP = new Set(`a about above after again against all also am an and any are as at be because been before being below
between both but by can could did do does doing down during each few for from further had has have having he her here hers
him his how i if in into is it its itself just me more most my no nor not now of off on once only or other our ours out over
own same she should so some such than that the their them then there these they this those through to too under until up
very was we were what when where which while who whom why will with would you your yours one two may might must shall also
use used using like get gets got make makes made way ways thing things often every many much each still even yet however`.split(/\s+/))

export const isStop = (w: string) => STOP.has(w.toLowerCase())
/** A word that could name an idea: not filler, not an everyday word. */
export const isIdeaWord = (w: string) => !STOP.has(w.toLowerCase()) && !PLAIN.has(w.toLowerCase())

/** Sentences, never running across a paragraph or heading break. */
export function sentences(text: string): string[] {
  return text
    .split(/\n{2,}/)
    .flatMap((block) => block.replace(/\s+/g, ' ').split(/(?<=[.!?])\s+(?=[A-Z0-9"“(])/))
    .map((s) => s.trim())
    .filter((s) => s.length > 2)
}

/** Lower-case content words, with a light stem so "rendering" meets "render". */
export function words(text: string): string[] {
  return (text.toLowerCase().match(/[a-z][a-z0-9'-]+/g) ?? [])
    .map((w) => w.replace(/'s$/, ''))
    .filter((w) => w.length > 2 && !STOP.has(w))
    .map(stem)
}

export function stem(w: string): string {
  for (const suffix of ['ations', 'ation', 'ings', 'ing', 'edly', 'ed', 'ies', 'es', 's', 'ly']) {
    if (w.length - suffix.length >= 4 && w.endsWith(suffix)) return suffix === 'ies' ? w.slice(0, -3) + 'y' : w.slice(0, -suffix.length)
  }
  return w
}

export interface Idea { id: string; text: string; keys: string[] }

/** The ideas a page makes: its most self-contained, word-dense sentences, in reading order. */
export function ideas(pageText: string, limit = 3): Idea[] {
  const all = sentences(pageText).filter((s) => s.length >= 40 && s.length <= 260 && /[.!?][\"”')]?$/.test(s) && !/^(figure|table)\b/i.test(s) && !/[{};=]{2,}|=>/.test(s))
  const scored = all.map((text, index) => {
    const keys = [...new Set(words(text))]
    return { text, index, keys, score: keys.length / Math.sqrt(text.length) }
  })
  return scored
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .sort((a, b) => a.index - b.index)
    .map((s) => ({ id: `${s.index}:${s.text.slice(0, 24)}`, text: s.text, keys: s.keys }))
}

/** Which ideas an explanation covers: enough of an idea's own words, in any order. */
export function compare(explanation: string, list: Idea[]): { across: Idea[]; loose: Idea[] } {
  const said = new Set(words(explanation))
  const across: Idea[] = [], loose: Idea[] = []
  for (const idea of list) {
    const hit = idea.keys.filter((k) => said.has(k)).length
    ;(hit >= Math.max(2, Math.ceil(idea.keys.length * 0.4)) ? across : loose).push(idea)
  }
  return { across, loose }
}

/** Short labels for an idea: its first few content words. */
export function label(idea: Idea): string {
  const plain = idea.text.replace(/[“”"]/g, '').replace(/^(for example|for instance|in short|in other words|so|but|and|also),?\s+/i, '')
  const cut = plain.split(/[,;:]/)[0]
  if (cut.split(' ').length >= 3 && cut.length <= 46) return cut
  const words = plain.split(' ')
  return words.slice(0, 7).join(' ').replace(/[.,;:]$/, '') + (words.length > 7 ? '…' : '')
}

/** Terms that run across a library: words strong in a few pages of more than one book. */
export function concepts(library: Map<string, string[]>, limit = 8): { term: string; hits: { bookId: string; page: number; text: string }[] }[] {
  const df = new Map<string, Set<string>>()
  const where = new Map<string, { bookId: string; page: number; text: string }[]>()
  let docs = 0
  for (const [bookId, pages] of library) {
    pages.forEach((text, i) => {
      docs++
      for (const term of new Set(phrases(text))) {
        if (!df.has(term)) df.set(term, new Set())
        df.get(term)!.add(`${bookId}:${i}`)
        const list = where.get(term) ?? []
        if (list.length < 12) list.push({ bookId, page: i + 1, text })
        where.set(term, list)
      }
    })
  }
  return [...df.entries()]
    .map(([term, set]) => ({ term, pages: set.size, books: new Set([...set].map((k) => k.split(':')[0])).size }))
    .filter((t) => t.books >= 2 && t.pages <= Math.max(3, docs * 0.4))
    // Shared by more books first; a two-word phrase says more than a single word.
    .map((t) => ({ ...t, score: t.books * (t.term.includes(' ') ? 1.6 : 1) + t.pages * 0.1 }))
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map((t) => ({ term: t.term, hits: where.get(t.term) ?? [] }))
}

/** Everyday words that run through any book without being an idea of their own. */
const PLAIN = new Set(`without within rather before after while another other others first second third last next given
small large simple better best short long original sample samples notes note shelf include includes included including
example examples following different same good great keep keeps kept change changes changed changing useful usually
always never called means mean shows show shown work works working worked able around across each instead whether
start starts started end ends ended part parts place places point points case cases kind kinds sort type types number
numbers line lines page pages time times something anything everything nothing someone people person really quite
enough little often already almost actually based because become becomes need needs needed want wants wanted
try tries tried call calls happen happens important clear clearly easy easier hard harder small smaller larger
write writes written writing read reads reading section chapter book books both either neither several certain
whole entire later earlier still though although perhaps simply return returns returned separate separately
answer answers question questions ask asks asked idea ideas thing things make makes made take takes took give gives
find finds found look looks looked come comes came seem seems turn turns move moves set sets put puts run runs
version versions avoid avoids against why what which whose help helps helped helping should could would`.split(/\s+/))

/** One- and two-word noun-like phrases worth naming. */
function phrases(text: string): string[] {
  const plain = text.replace(/\b(?:https?:\/\/)?[\w-]+(?:\.[\w-]+)+(?:\/\S*)?/g, ' ')
  const tokens = (plain.toLowerCase().match(/[a-z][a-z-]+/g) ?? []).filter((t) => !/^[a-z]{2}-[a-z]{2}$/.test(t))
  const out: string[] = []
  const fine = (w: string) => !STOP.has(w) && !PLAIN.has(w)
  for (let i = 0; i < tokens.length; i++) {
    const a = tokens[i], b = tokens[i + 1]
    if (a.length > 4 && fine(a)) out.push(a)
    if (b && fine(a) && fine(b) && a.length > 3 && b.length > 3) out.push(`${a} ${b}`)
  }
  return out
}

/** The sentence around a term, for quoting where a book says it. */
export function quoteAround(text: string, term: string): string {
  const hit = sentences(text).find((s) => s.toLowerCase().includes(term))
  return hit ?? sentences(text)[0] ?? text.slice(0, 200)
}

/** Search: pages ranked by how many query words they hold, with the best sentence. */
export function search(library: Map<string, string[]>, query: string) {
  const q = words(query)
  if (!q.length) return []
  const results: { bookId: string; page: number; score: number; snippet: string }[] = []
  for (const [bookId, pages] of library) {
    pages.forEach((text, i) => {
      const w = words(text)
      const score = q.reduce((n, k) => n + w.filter((x) => x === k).length, 0)
      if (!score) return
      const best = sentences(text)
        .map((s) => ({ s, n: q.filter((k) => words(s).includes(k)).length }))
        .sort((a, b) => b.n - a.n)[0]
      results.push({ bookId, page: i + 1, score, snippet: best?.s ?? text.slice(0, 180) })
    })
  }
  return results.sort((a, b) => b.score - a.score).slice(0, 30)
}

/** A gap-fill recall card from a sentence. The blank is the word the page leans on most
    (the one it repeats), so the card asks for the idea, not for a stray adjective. */
export function cloze(sentence: string, context = ''): { prompt: string; answer: string } | null {
  const candidates = [...new Set(sentence.match(/\b[A-Za-z][A-Za-z-]{3,}\b/g) ?? [])].filter((w) => isIdeaWord(w))
  if (!candidates.length) return null
  const around = words(context)
  const weight = (w: string) => around.filter((x) => x === stem(w.toLowerCase())).length * 3 + Math.min(w.length, 10) / 10
  const answer = candidates.sort((a, b) => weight(b) - weight(a))[0]
  return { prompt: sentence.replace(new RegExp(`\\b${answer}\\b`), '_____'), answer }
}
