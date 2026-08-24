import type { Tool } from "@/features/canvas/domain/canvasDomainModels";

export type CanvasCursorClass =
  | "canvas-cursor-arrow"
  | "canvas-cursor-crosshair"
  | "canvas-cursor-ibeam"
  | "canvas-cursor-open-hand"
  | "canvas-cursor-closed-hand"
  | "canvas-cursor-pointing-hand"
  | "canvas-cursor-operation-not-allowed";

export type CanvasCursorInput = {
  tool: Tool;
  outputPreview: boolean;
  pointerOver: boolean;
  hasTarget: boolean;
  editingFreeText: boolean;
  settingPartOrigin: boolean;
  dragging: boolean;
};

const targetTools: ReadonlySet<Tool> = new Set([
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
]);

const placementTools: ReadonlySet<Tool> = new Set([
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
]);

export function canvasCursorClass(input: CanvasCursorInput): CanvasCursorClass {
  if (input.outputPreview || !input.pointerOver) return "canvas-cursor-arrow";
  if (input.dragging) return "canvas-cursor-closed-hand";
  if (input.editingFreeText) return "canvas-cursor-ibeam";
  if (input.settingPartOrigin) return "canvas-cursor-crosshair";

  if (input.tool === "select") {
    return input.hasTarget ? "canvas-cursor-open-hand" : "canvas-cursor-arrow";
  }
  if (input.tool === "freeText") return "canvas-cursor-crosshair";
  if (placementTools.has(input.tool)) return "canvas-cursor-crosshair";
  if (targetTools.has(input.tool)) {
    return input.hasTarget ? "canvas-cursor-pointing-hand" : "canvas-cursor-operation-not-allowed";
  }
  return "canvas-cursor-arrow";
}
