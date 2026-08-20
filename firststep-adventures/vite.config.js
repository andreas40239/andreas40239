import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { viteSingleFile } from 'vite-plugin-singlefile'

// https://vite.dev/config/
// Single-file output: the app has no external assets (icons/manifest are
// inlined as data URIs in index.html), so bundling everything into one
// HTML file lets it run standalone — as a downloaded file, or published
// to a static host — with no separate JS/CSS requests.
export default defineConfig({
  plugins: [react(), viteSingleFile()],
})
