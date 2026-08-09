import { describe, expect, it } from "vitest";
import {
  allPaletteTools,
  basicTools,
  defaultCollapsedToolGroups,
  detailedTools,
} from "@/features/canvas/components/ToolPalette";
import { appStrings } from "@/localization";

describe("ToolPalette progression", () => {
  it("classifies every Canvas tool once between basic and detailed", () => {
    expect(basicTools).toHaveLength(15);
    expect(detailedTools).toHaveLength(22);
    expect([...basicTools].filter((tool) => detailedTools.has(tool))).toEqual([]);
    expect(new Set([...basicTools, ...detailedTools])).toEqual(new Set(allPaletteTools));
  });

  it("starts with secondary groups collapsed while keeping the drawing group open", () => {
    expect(defaultCollapsedToolGroups).toEqual(new Set(["derived", "constraint", "measurement"]));
    expect(defaultCollapsedToolGroups.has("drawing")).toBe(false);
    expect(defaultCollapsedToolGroups.has("dimension")).toBe(false);
  });

  it("uses the SwiftUI palette subtitle", () => {
    expect(appStrings.palette.subtitle).toBe("補助パレット");
  });
});
