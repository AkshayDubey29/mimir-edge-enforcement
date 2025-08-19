import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
    target: 'es2020',
    // Increase chunk size warning limit
    chunkSizeWarningLimit: 1000,
    rollupOptions: {
      output: {
        // Manual chunking for better optimization
        manualChunks: {
          // Vendor chunk for external dependencies
          vendor: ['react', 'react-dom'],
          // Router chunk
          router: ['react-router-dom'],
          // UI components chunk
          ui: ['@radix-ui/react-alert-dialog', '@radix-ui/react-avatar', '@radix-ui/react-checkbox', '@radix-ui/react-dialog'],
          // Query chunk
          query: ['@tanstack/react-query'],
          // Utils chunk
          utils: ['clsx', 'class-variance-authority', 'tailwind-merge']
        }
      }
    }
  },
  server: {
    port: 3000,
    host: true,
    proxy: {
      '/api': {
        target: 'http://localhost:8082',
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path.replace(/^\/api/, '/api')
      }
    }
  },
})
