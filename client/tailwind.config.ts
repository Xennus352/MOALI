import { defineConfig } from 'tailwindcss'

export default defineConfig({
  content: [
    './index.html',
    './src/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: '#1B4D3E',
        secondary: '#E67E22',
        background: '#F4F6F4',
        neutral: '#2C3E50',
        muted: '#6B7280',
        foreground: '#1E293B',
        card: '#FFFFFF',
        border: '#E5E7EB',
      },
    },
  },
  plugins: [],
})