import { angleArcCounterclockwise } from "@/features/canvas/selectors/canvasRendering";
import { canvasProjectionFor } from "@/features/canvas/selectors/canvasProjection";
import { displayValue } from "@/features/canvas/domain/workspaceTools";
import type { CanvasProjection, RawEntity, State } from "@/shared/domain/coreWireTypes";

export type CanvasDisplayState = {
  projection: CanvasProjection;
  measurementLabels: Record<string, string>;
  measurementLabelOffsets: Record<string, { xMm: number; yMm: number }>;
  measurementArcCounterclockwise: Record<string, boolean>;
  dimensionLabels: Record<string, string>;
  dimensionLabelOffsets: Record<string, { xMm: number; yMm: number }>;
  dimensionArcCounterclockwise: Record<string, boolean>;
};

export function visibleEntitiesFor(state: State | undefined): RawEntity[] {
  if (!state) return [];
  const visibleLayerIds = new Set(state.layers.filter((layer) => layer.visible).map((layer) => layer.id));
  return state.entities.filter((entity) => !entity.layerId || visibleLayerIds.has(entity.layerId));
}

export function canvasDisplayStateFor(canvasState: State | undefined): CanvasDisplayState {
  const measurementEvaluations = canvasState?.measurementEvaluations ?? [];
  const measurements = canvasState?.measurementAnnotations ?? [];
  const constraints = canvasState?.constraints ?? [];
  return {
    projection: canvasProjectionFor(canvasState),
    measurementLabels: Object.fromEntries(
      measurementEvaluations.map((item) => [item.annotationId, displayValue(item.value)]),
    ),
    measurementLabelOffsets: Object.fromEntries(measurements.map((item) => [item.id, item.labelOffsetMm])),
    measurementArcCounterclockwise: Object.fromEntries(
      measurementEvaluations
        .filter((item) => typeof item.value.fixedDegrees === "number")
        .map((item) => [item.annotationId, Number(item.value.fixedDegrees) > 0]),
    ),
    dimensionLabels: Object.fromEntries(constraints.map((item) => [item.id, displayValue(item.value)])),
    dimensionLabelOffsets: Object.fromEntries(
      (canvasState?.dimensionConstraintAnnotations ?? []).map((item) => [item.constraintId, item.labelOffsetMm]),
    ),
    dimensionArcCounterclockwise: Object.fromEntries(
      constraints
        .filter((item) => item.kind === "angle")
        .flatMap((item) => {
          const fixedDegrees = item.value?.fixedDegrees;
          return typeof fixedDegrees === "number" ? [[item.id, angleArcCounterclockwise(fixedDegrees) ?? false]] : [];
        }),
    ),
  };
}
