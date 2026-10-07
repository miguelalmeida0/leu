import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: { port: 5173, open: !process.env.CI && !process.env.NO_OPEN },
  worker: { format: 'es' },
  build: { chunkSizeWarningLimit: 2500 },
  // Pre-bundled up front, so the first PDF or the first spoken word never triggers a reload.
  optimizeDeps: { include: ['pdfjs-dist/legacy/build/pdf.mjs', 'kokoro-js', 'idb-keyval'] },
})
