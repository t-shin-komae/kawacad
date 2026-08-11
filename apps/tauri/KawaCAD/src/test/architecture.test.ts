import { describe, expect, it } from "vitest";

declare global {
  interface ImportMeta {
    glob(pattern: string, options: { eager: boolean; query: string; import: string }): Record<string, string>;
  }
}

const sharedSources = import.meta.glob("../shared/**/*.{ts,tsx}", {
  eager: true,
  query: "?raw",
  import: "default",
}) as Record<string, string>;
const adapterSources = import.meta.glob("../adapters/**/*.{ts,tsx}", {
  eager: true,
  query: "?raw",
  import: "default",
}) as Record<string, string>;

describe("dependency direction", () => {
  it("keeps shared code independent from feature components", () => {
    const violations = Object.values(sharedSources)
      .flatMap((source) => source.match(/@\/features\/[^\"']+/g) ?? [])
      .filter((importPath) => importPath.includes("/components/"));
    expect(violations).toEqual([]);
  });

  it("keeps adapters independent from view components", () => {
    const violations = Object.values(adapterSources)
      .flatMap((source) => source.match(/@\/features\/[^\"']+/g) ?? [])
      .filter((importPath) => importPath.includes("/components/"));
    expect(violations).toEqual([]);
  });

  it("keeps the wire model free of React and component imports", () => {
    const wireModel =
      Object.entries(sharedSources).find(([path]) => path.endsWith("shared/domain/coreWireTypes.ts"))?.[1] ?? "";
    expect(wireModel).not.toMatch(/from ["']react["']/);
    expect(wireModel).not.toMatch(/\/components\//);
  });
});
