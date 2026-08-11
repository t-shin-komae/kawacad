import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { appStrings, sharedLocalizationKeyMap } from "@/localization/appStrings";

function swiftStringValue(catalog: string, key: string): string | undefined {
  const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = catalog.match(new RegExp(`^"${escapedKey}"\\s*=\\s*"((?:\\\\.|[^"\\\\])*)";`, "m"));
  return match?.[1]?.replace(/\\"/g, '"').replace(/\\\\/g, "\\");
}

function tauriStringValue(path: string): string {
  let value: unknown = appStrings;
  for (const segment of path.split(".")) value = (value as Record<string, unknown>)[segment];
  expect(typeof value).toBe("string");
  return value as string;
}

describe("shared localization catalog", () => {
  it("keeps the shared semantic surface identical to Swift", () => {
    const catalogPath = resolve(process.cwd(), "../../macos/KawaCAD/Sources/KawaCADApp/Resources/Localizable.strings");
    const catalog = readFileSync(catalogPath, "utf8");
    for (const [swiftKey, tauriPath] of Object.entries(sharedLocalizationKeyMap)) {
      expect(tauriStringValue(tauriPath), swiftKey).toBe(swiftStringValue(catalog, swiftKey));
    }
  });
});
