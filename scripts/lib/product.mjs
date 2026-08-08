import fs from "node:fs";
import path from "node:path";
import { paths } from "./paths.mjs";

const productFile = path.join(paths.repositoryRoot, "config", "product.json");

export const productInfo = JSON.parse(fs.readFileSync(productFile, "utf8"));

if (
  typeof productInfo.name !== "string" ||
  typeof productInfo.version !== "string" ||
  typeof productInfo.copyright !== "string"
) {
  throw new Error(`${productFile} must define name, version, and copyright strings`);
}

export function productDisplayVersion({ release = false } = {}) {
  return release ? productInfo.version : `${productInfo.version}-dev`;
}
