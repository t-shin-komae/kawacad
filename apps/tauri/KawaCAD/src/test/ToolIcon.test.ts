import { describe, expect, it } from "vitest";
import { toolIcons } from "@/features/canvas/components/ToolIcon";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";

const allTools: Tool[] = [
  "select",
  "point",
  "line",
  "circle",
  "arc",
  "freeText",
  "centerLine",
  "horizontalCenterLine",
  "verticalCenterLine",
  "roundHole",
  "stitchStartPoint",
  "offset",
  "fillet",
  "coincident",
  "horizontal",
  "vertical",
  "parallel",
  "perpendicular",
  "tangent",
  "equalLength",
  "angle",
  "symmetric",
  "pointOnLine",
  "fixed",
  "distance",
  "horizontalDistance",
  "verticalDistance",
  "lineLineDistance",
  "segmentLength",
  "diameter",
  "radius",
  "measureDistance",
  "measureSegmentLength",
  "measureAngle",
  "measureRadius",
  "measureDiameter",
  "measureArcSweepAngle",
];

const identity = (tool: Tool) => toolIcons[tool].displayName || toolIcons[tool].name;

describe("Tool icon parity", () => {
  it("provides an OSS display icon for every palette tool", () => {
    expect(Object.keys(toolIcons).sort()).toEqual([...allTools].sort());
    allTools.forEach((tool) => expect(identity(tool)).not.toBeFalsy());
  });
  it("uses distinct icons within the primary drawing palette", () => {
    const group: Tool[] = [
      "select",
      "point",
      "line",
      "circle",
      "arc",
      "centerLine",
      "horizontalCenterLine",
      "verticalCenterLine",
      "offset",
      "fillet",
    ];
    expect(new Set(group.map(identity)).size).toBe(group.length);
  });
  it("includes the tangent constraint tool in the palette icon registry", () => {
    expect(toolIcons.tangent).toBeDefined();
  });
  it("keeps all declared tools available without a category-only registry", () => {
    expect(Object.keys(toolIcons)).toHaveLength(allTools.length);
  });
  it("uses the expected directional OSS icons for restored constraints", () => {
    expect(identity("horizontal")).toContain("ArrowLeftRight");
    expect(identity("vertical")).toContain("ArrowUpDown");
    expect(identity("parallel")).toContain("Equal");
    expect(identity("equalLength")).toContain("Ruler");
  });
  it("distinguishes CAD-specific constraint and dimension symbols", () => {
    expect(identity("symmetric")).not.toBe(identity("horizontal"));
    expect(identity("equalLength")).not.toBe(identity("segmentLength"));
    expect(identity("segmentLength")).not.toBe(identity("radius"));
    expect(identity("perpendicular")).not.toBe(identity("angle"));
  });
});
