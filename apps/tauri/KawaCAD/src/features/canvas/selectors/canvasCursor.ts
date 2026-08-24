import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
import { constraintTools, drawingTools, measurementKinds } from "@/features/canvas/domain/workspaceTools";

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
  hasTarget: boolean;
  editingFreeText: boolean;
  settingPartOrigin: boolean;
  movingContent: boolean;
};

export function canvasCursorClass(input: CanvasCursorInput): CanvasCursorClass {
  if (input.outputPreview) return "canvas-cursor-arrow";
  if (input.movingContent) return "canvas-cursor-closed-hand";
  if (input.editingFreeText) return "canvas-cursor-ibeam";
  if (input.settingPartOrigin) return "canvas-cursor-crosshair";

  if (input.tool === "select") {
    return input.hasTarget ? "canvas-cursor-open-hand" : "canvas-cursor-arrow";
  }
  if (drawingTools.has(input.tool)) return "canvas-cursor-crosshair";
  if (
    input.tool === "offset" ||
    input.tool === "fillet" ||
    constraintTools.has(input.tool) ||
    Boolean(measurementKinds[input.tool])
  ) {
    return input.hasTarget ? "canvas-cursor-pointing-hand" : "canvas-cursor-operation-not-allowed";
  }
  return "canvas-cursor-arrow";
}
