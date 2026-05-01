import { defineConfig } from "vite";

export default defineConfig(({ command }) => ({
  base: command === "build" ? "/static/" : "/",
  build: {
    outDir: "../glot_backend/priv/static",
    emptyOutDir: true,
    rollupOptions: {
      output: {
        entryFileNames: "glot_frontend.js",
        assetFileNames: (assetInfo) => {
          const names = [
            assetInfo.name,
            ...assetInfo.names,
            ...assetInfo.originalFileNames,
          ].filter((name): name is string => name !== undefined);

          if (names.some((name) => name.endsWith(".css"))) {
            return "styles.css";
          }

          return "assets/[name]-[hash][extname]";
        },
        chunkFileNames: "assets/[name]-[hash].js",
      },
    },
  },
  server: {
    proxy: {
      "/api": {
        target: "http://127.0.0.1:3000",
        changeOrigin: true,
      },
    },
  },
}));
