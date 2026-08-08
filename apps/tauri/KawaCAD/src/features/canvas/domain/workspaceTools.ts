import { defaultCollapsedToolGroups, toolGroupPreferenceIds } from "@/features/canvas/components/ToolPalette";
import { appStrings } from "@/localization";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
import type { ConstraintTarget, PointMm } from "@/features/canvas/domain/cad";

export const toolPaletteWidthRange = { min: 176, max: 260 };

export { defaultCollapsedToolGroups, toolGroupPreferenceIds };

export const toolNames = appStrings.toolNames;

export const drawingTools = new Set<Tool>([
  "point",
  "line",
  "circle",
  "arc",
  "centerLine",
  "horizontalCenterLine",
  "verticalCenterLine",
  "roundHole",
  "freeText",
  "stitchStartPoint",
]);
export const constraintTools = new Set<Tool>([
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
]);
export const measurementKinds: Partial<Record<Tool, string>> = {
  measureDistance: "distance",
  measureSegmentLength: "segmentLength",
  measureAngle: "angle",
  measureRadius: "radius",
  measureDiameter: "diameter",
  measureArcSweepAngle: "arcSweepAngle",
};
export const constraintKinds: Partial<Record<Tool, string>> = { equalLength: "equalSegmentLength" };
export const targetCount: Partial<Record<Tool, number>> = {
  coincident: 2,
  horizontal: 1,
  vertical: 1,
  parallel: 2,
  perpendicular: 2,
  tangent: 2,
  equalLength: 2,
  angle: 2,
  symmetric: 3,
  pointOnLine: 2,
  fixed: 1,
  distance: 2,
  horizontalDistance: 2,
  verticalDistance: 2,
  lineLineDistance: 2,
  segmentLength: 1,
  diameter: 1,
  radius: 1,
  measureDistance: 2,
  measureSegmentLength: 1,
  measureAngle: 2,
  measureRadius: 1,
  measureDiameter: 1,
  measureArcSweepAngle: 1,
  offset: 1,
  fillet: 2,
};

export function id(prefix: string) {
  return `${prefix}:${crypto.randomUUID()}`;
}

export function fixedValue(value: number, degrees = false) {
  return degrees ? { fixedDegrees: value } : { fixedMm: value };
}

export function displayValue(value?: Record<string, number | string>) {
  if (!value) return "";
  if (typeof value.fixedMm === "number") return `${value.fixedMm.toFixed(2)} mm`;
  if (typeof value.fixedDegrees === "number") return `${value.fixedDegrees.toFixed(1)}°`;
  return typeof value.parameter === "string" ? value.parameter : "";
}

/** Mirrors the SwiftUI canvas's line-placement assistance while keeping the
 * final coincidence/orientation constraints Core-owned in the gesture command. */
export function assistLine(start: PointMm, candidate: PointMm, forceAxis: boolean, snappedTarget?: ConstraintTarget) {
  const dx = candidate.xMm - start.xMm,
    dy = candidate.yMm - start.yMm,
    length = Math.hypot(dx, dy);
  if (length <= 0.001) return { point: candidate, axis: undefined };
  if (snappedTarget) {
    if (Math.abs(dy) <= 0.001) return { point: candidate, axis: "horizontal" };
    if (Math.abs(dx) <= 0.001) return { point: candidate, axis: "vertical" };
    return { point: candidate, axis: undefined };
  }
  const horizontal = forceAxis ? Math.abs(dx) >= Math.abs(dy) : Math.abs(dy) <= Math.max(1, length * 0.035);
  const vertical = forceAxis ? !horizontal : Math.abs(dx) <= Math.max(1, length * 0.035);
  if (horizontal) return { point: { xMm: candidate.xMm, yMm: start.yMm }, axis: "horizontal" };
  if (vertical) return { point: { xMm: start.xMm, yMm: candidate.yMm }, axis: "vertical" };
  return { point: candidate, axis: undefined };
}
