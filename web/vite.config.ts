import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

const isolation = { 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp' }

export default defineConfig({
  plugins: [react()],
  // Cross-origin isolation lets the voice run on several threads when WebGPU isn't available.
  server: { port: 5173, open: !process.env.CI && !process.env.NO_OPEN, headers: isolation },
  preview: { headers: isolation },
  worker: { format: 'es' },
  build: { chunkSizeWarningLimit: 2500 },
  // Pre-bundled up front, so the first PDF or the first spoken word never triggers a reload.
  optimizeDeps: { include: ['pdfjs-dist/legacy/build/pdf.mjs', 'kokoro-js', 'idb-keyval'] },
})
