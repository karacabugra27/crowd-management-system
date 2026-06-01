import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const API_URL = env.VITE_API_URL || 'http://localhost:8000'

  return {
    plugins: [react()],
    server: {
      port: 5173,
      proxy: {
        '/api': {
          target: API_URL,
          changeOrigin: true,
          secure: false,
        },
        '/ws': {
          target: API_URL.replace(/^http/, 'ws'),
          ws: true,
          changeOrigin: true,
        },
      },
    },
    build: {
      outDir: 'dist',
      sourcemap: false,
      rollupOptions: {
        output: {
          manualChunks(id) {
            if (!id.includes('node_modules')) return undefined
            if (id.match(/[\\/]node_modules[\\/](react|react-dom|react-router-dom|react-router|scheduler)[\\/]/)) {
              return 'vendor'
            }
            if (id.includes('recharts') || id.includes('d3-')) return 'charts'
            if (id.includes('leaflet')) return 'map'
            return undefined
          },
        },
      },
    },
  }
})
