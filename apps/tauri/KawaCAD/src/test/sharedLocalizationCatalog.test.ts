import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { alignedLocalizationKeyMap, appStrings, sharedLocalizationKeyMap } from "@/localization/appStrings";

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

function tauriValue(path: string): unknown {
  let value: unknown = appStrings;
  for (const segment of path.split(".")) value = (value as Record<string, unknown>)[segment];
  return value;
}

function normalizeKey(key: string): string {
  return key
    .split(".")
    .map((segment) => segment.replace(/_([a-z])/g, (_, character: string) => character.toUpperCase()))
    .join(".");
}

function renderSwiftTemplate(template: string, arguments_: readonly number[]): string {
  let argumentIndex = 0;
  return template.replace(/%d/g, () => String(arguments_[argumentIndex++]));
}

describe("shared localization catalog", () => {
  it("keeps the shared semantic surface identical to Swift", () => {
    const catalogPath = resolve(process.cwd(), "../../macos/KawaCAD/Sources/KawaCADApp/Resources/Localizable.strings");
    const catalog = readFileSync(catalogPath, "utf8");
    for (const [swiftKey, tauriPath] of Object.entries(sharedLocalizationKeyMap)) {
      expect(tauriStringValue(tauriPath), swiftKey).toBe(swiftStringValue(catalog, swiftKey));
    }
  });

  it("keeps aligned fixed-string keys equivalent after naming normalization", () => {
    const catalogPath = resolve(process.cwd(), "../../macos/KawaCAD/Sources/KawaCADApp/Resources/Localizable.strings");
    const catalog = readFileSync(catalogPath, "utf8");
    const entries = Object.entries(alignedLocalizationKeyMap);
    expect(new Set(entries.map(([swiftKey]) => normalizeKey(swiftKey))).size).toBe(entries.length);
    expect(new Set(entries.map(([, tauriPath]) => tauriPath)).size).toBe(entries.length);
    for (const [swiftKey, tauriPath] of entries) {
      const tauriValueAtPath = tauriValue(tauriPath);
      expect(tauriValueAtPath, tauriPath).not.toBeUndefined();
      expect(normalizeKey(tauriPath), swiftKey).toBe(normalizeKey(swiftKey));
      const swiftValue = swiftStringValue(catalog, swiftKey) ?? "";
      const sentinelArguments = [17, 29] as const;
      const renderedTauriValue =
        typeof tauriValueAtPath === "function" ? tauriValueAtPath(...sentinelArguments) : (tauriValueAtPath as string);
      expect(renderedTauriValue, swiftKey).toBe(renderSwiftTemplate(swiftValue, sentinelArguments));
    }
  });
});
