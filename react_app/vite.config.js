import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Front-end calls /api/* which is proxied to the Node server (server/server.js).
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:8787',
    },
  },
})
