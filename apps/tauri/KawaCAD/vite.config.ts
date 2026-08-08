import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import fs from "node:fs";
import { fileURLToPath, URL } from "node:url";

const productInfo = JSON.parse(
  fs.readFileSync(fileURLToPath(new URL("../../../config/product.json", import.meta.url)), "utf8"),
);
const isReleaseBuild = process.env.KAWACAD_RELEASE === "1";

export function productInfoForBuild(release: boolean) {
  return {
    ...productInfo,
    displayVersion: release ? productInfo.version : `${productInfo.version}-dev`,
  };
}

export default defineConfig({
  plugins: [react()],
  define: {
    __KAWACAD_PRODUCT__: JSON.stringify(productInfoForBuild(isReleaseBuild)),
  },
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  test: {
    environment: "jsdom",
    setupFiles: ["./src/test/setup.ts"],
    exclude: ["e2e/**", "node_modules/**", "dist/**", "test-results/**"],
  },
  clearScreen: false,
  server: {
    port: 1420,
    strictPort: true,
  },
});
