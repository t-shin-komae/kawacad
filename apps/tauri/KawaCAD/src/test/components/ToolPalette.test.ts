import { describe, expect, it } from "vitest";
import { allPaletteTools, basicTools, detailedTools } from "@/features/canvas/components/ToolPalette";

describe("ToolPalette progression", () => {
  it("classifies every Canvas tool once between basic and detailed", () => {
    expect(basicTools).toHaveLength(15);
    expect(detailedTools).toHaveLength(22);
    expect([...basicTools].filter((tool) => detailedTools.has(tool))).toEqual([]);
    expect(new Set([...basicTools, ...detailedTools])).toEqual(new Set(allPaletteTools));
  });
});
