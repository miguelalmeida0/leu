import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'

// Safari/WebKit requires an explicit CORP response for the pdf.js module worker.
const isolation = { 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp', 'Cross-Origin-Resource-Policy': 'same-origin' }

// Install before static-file middleware: its 304 fast path skips setHeaders,
// which otherwise strips worker isolation headers when Safari revalidates.
const preserveIsolation: Plugin = {
  name: 'leu-preserve-isolation',
  configureServer(server) {
    server.middlewares.use((_request, response, next) => {
      for (const [name, value] of Object.entries(isolation)) response.setHeader(name, value)
      next()
    })
  },
  configurePreviewServer(server) {
    server.middlewares.use((_request, response, next) => {
      for (const [name, value] of Object.entries(isolation)) response.setHeader(name, value)
      next()
    })
  },
}

export default defineConfig({
  plugins: [preserveIsolation, react()],
  // Cross-origin isolation lets the voice run on several threads when WebGPU isn't available.
  server: { port: 5173, open: !process.env.CI && !process.env.NO_OPEN, headers: isolation },
  preview: { headers: isolation },
  worker: { format: 'es' },
  build: { chunkSizeWarningLimit: 2500 },
  // Pre-bundled up front, so the first PDF or the first spoken word never triggers a reload.
  optimizeDeps: { include: ['pdfjs-dist/legacy/build/pdf.mjs', 'kokoro-js', 'idb-keyval'] },
})
