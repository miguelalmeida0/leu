# Leu in the browser

A clickable desktop twin of the Felt design, for trying Leu without Xcode. It is a design and
test prototype, not the shipping app: everything runs in your browser and nothing is uploaded.

## Run it

```sh
cd web
npm install
npm run dev
```

Vite opens http://localhost:5173. Node 20.19+ or 22.12+ is needed.

Start with **or start with a sample book** (or *fill the shelf with all six samples*), or drop any
PDF onto the page. `npm run build && npm run preview` serves the production build.

## What's live

| Screen | What you can do |
|---|---|
| Welcome | Knitting basket whose loose strand of yarn you can brush, catch and tug; your intention is remembered and shown on Home. |
| Bring a PDF | Drop a PDF anywhere, ⌘O, or the button. Leu reads it with pdf.js, sews it in, finds books that share its ideas, and lets you shelve it. |
| Home | The nook: rain on the glass, fog you wipe with the pointer (it fogs back after ~7 s), tea steam, synthesised rain sound. |
| Library | The felt quilt, shelves, On the needle, find a book. |
| A book | Chapter strip from the PDF outline (or its headings), sections, where you left off, loose ends. |
| Reading | The page rebuilt for reading, or the original page drawn by pdf.js. Select text to keep a note, explain it or hear it. ← → turn pages. |
| Read aloud | Kokoro voices (kokoro-js, in a worker). The page follows along like synced lyrics: the sentence being heard fills word by word, and clicking any sentence reads from there. A player gives pause, sentence back/on, speed and stop, and at the end of a page Leu turns it and keeps reading. Fast start: once you've listened, the voice warms up in the background when you open a book, the first sentences of each page are rendered while you read, and the first sentence starts after just a few words. WebGPU runs the full model (~330 MB, once); elsewhere the 8-bit model (~90 MB) runs on WebAssembly threads. |
| Explain | A quiet sheet in the margin, beside the page, with the sentences it draws on marked there. There is no model in the browser, so it says so and keeps to the passage's own words. |
| In your own words | The snow globe. Each idea you get across lights a window; all of them light the third. Rest the pointer on the glass and a slow current lifts and turns the snow; a click lifts it all. Chrome and Safari can also take it spoken. |
| Study | The sentence planner and a recall session with spaced review. Nothing is scored. |
| Notes | A notebook spread of what you kept, each opening its page. |
| Explore / Trails | Ideas shared across your books, the passages that say them, and a walk you can make from them. |
| Search | ⌘K / Ctrl K. Best answer first, searched words marked, Return opens it. |

The wordmark: every few seconds a tiny book flutters out of the u, loops over the word and settles back.

Keyboard: while Leu reads, Space pauses and ← → step a sentence. ⌘1–⌘6 go to Home, Library, Study, Notes, Explore and Trails, as in the Mac app.

## Honest limits

- The idea check, explanations and concepts are word-overlap heuristics written for this
  prototype. The app compares against the source with its own on-device pipeline.
- Your library lives in this browser (localStorage for notes and progress, IndexedDB for the PDFs).
  Clearing site data clears it.
- Reduced motion is respected: the rain, snow and yarn hold still.
