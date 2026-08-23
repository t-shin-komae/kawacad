import { describe, expect, it } from "vitest";
import {
  allPaletteTools,
  basicTools,
  defaultCollapsedToolGroups,
  detailedTools,
} from "@/features/canvas/components/ToolPalette";

describe("ToolPalette progression", () => {
  it("classifies every Canvas tool once between basic and detailed", () => {
    expect(basicTools).toHaveLength(15);
    expect(detailedTools).toHaveLength(20);
    expect([...basicTools].filter((tool) => detailedTools.has(tool))).toEqual([]);
    expect(new Set([...basicTools, ...detailedTools])).toEqual(new Set(allPaletteTools));
    expect(allPaletteTools).not.toContain("horizontalCenterLine");
    expect(allPaletteTools).not.toContain("verticalCenterLine");
  });

  it("starts with secondary groups collapsed while keeping the drawing group open", () => {
    expect(defaultCollapsedToolGroups).toEqual(new Set(["derived", "constraint", "measurement"]));
    expect(defaultCollapsedToolGroups.has("drawing")).toBe(false);
    expect(defaultCollapsedToolGroups.has("dimension")).toBe(false);
  });
});
