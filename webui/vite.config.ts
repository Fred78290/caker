import react from '@vitejs/plugin-react';
import { resolve } from 'path';
import { defineConfig } from 'vite';

// Target caked REST server: override with VITE_API_TARGET env var (e.g. https://localhost:8443)
const apiTarget = process.env.VITE_API_TARGET ?? 'http://127.0.0.1:8080'

export default defineConfig({
  plugins: [react()],

  // Built assets are served under /ui/ by caked's Vapor server
  base: '/ui/',

  resolve: {
    alias: { '@': resolve(__dirname, './src') },
  },

  server: {
    port: 5173,
    proxy: {
      '/1.0': {
        target: apiTarget,
        changeOrigin: true,
        secure: false,
        ws: true,
      },
    },
  },

  build: {
    outDir: 'dist',
    emptyOutDir: true,
    // noVNC uses top-level await — require a modern target.
    target: 'esnext',
  },
})
