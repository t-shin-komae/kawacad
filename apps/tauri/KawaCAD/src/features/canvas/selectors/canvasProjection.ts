import { constraintMarkerIcon, constraintMarkerLabel, geometryOf } from "@/features/canvas/domain/cad";
import type {
  CanvasProjection,
  DerivedElement,
  EditControlTarget,
  PointMm,
  RawEntity,
  State,
  Viewport,
} from "@/shared/domain/coreWireTypes";

const emptyCanvasProjection: CanvasProjection = {
  stitchStartPoints: [],
  measurementAnnotations: [],
  dimensionConstraints: [],
  constraintMarkers: [],
};

function translatedGeometry<T extends { centerMm?: PointMm; startMm?: PointMm; endMm?: PointMm; visible: boolean }>(
  geometry: T,
  offset: PointMm | undefined,
  annotationVisible = true,
) {
  if (!offset) return { ...geometry, visible: geometry.visible && annotationVisible };
  const translate = (point: PointMm | undefined) =>
    point && { xMm: point.xMm + offset.xMm, yMm: point.yMm + offset.yMm };
  return {
    ...geometry,
    visible: geometry.visible && annotationVisible,
    centerMm: translate(geometry.centerMm),
    startMm: translate(geometry.startMm),
    endMm: translate(geometry.endMm),
  };
}

export function canvasProjectionFor(
  state:
    | Pick<State, "canvasProjection" | "constraints" | "measurementAnnotations" | "dimensionConstraintAnnotations">
    | undefined,
): CanvasProjection {
  if (!state) return emptyCanvasProjection;
  const projection = state.canvasProjection ?? emptyCanvasProjection;
  const measurements = new Map(state.measurementAnnotations.map((item) => [item.id, item]));
  const dimensions = new Map((state.dimensionConstraintAnnotations ?? []).map((item) => [item.constraintId, item]));
  const constraints = new Map(state.constraints.map((item) => [item.id, item]));
  const markerStacks = new Map<string, number>();
  return {
    ...projection,
    measurementAnnotations: projection.measurementAnnotations.map((item) => {
      const annotation = measurements.get(item.id);
      return translatedGeometry(item, annotation?.overallOffsetMm, annotation?.visible);
    }),
    dimensionConstraints: projection.dimensionConstraints.map((item) => {
      const annotation = dimensions.get(item.id);
      return translatedGeometry(item, annotation?.overallOffsetMm, annotation?.visible);
    }),
    constraintMarkers: projection.constraintMarkers.flatMap((item) => {
      const kind = constraints.get(item.id)?.kind ?? "";
      const label = constraintMarkerLabel(kind);
      if (!label) return [];
      const key = `${item.positionMm.xMm}:${item.positionMm.yMm}`;
      const stackIndex = markerStacks.get(key) ?? 0;
      markerStacks.set(key, stackIndex + 1);
      return [{ ...item, label, icon: constraintMarkerIcon(kind), stackIndex }];
    }),
  };
}

export function selectedSourceArcId(
  selected: Set<string>,
  entities: RawEntity[],
  drawingEntityMetadata: State["drawingEntityMetadata"],
) {
  if (selected.size !== 1) return undefined;
  const entityId = [...selected][0];
  const entity = entities.find((item) => item.id === entityId);
  if (!entity || geometryOf(entity)?.tag !== "arc") return undefined;
  return drawingEntityMetadata.some((item) => item.entityId === entityId && item.derivedElementId)
    ? undefined
    : entityId;
}

export function hitDerivedRadiusControl(
  point: PointMm,
  entities: RawEntity[],
  metadata: State["drawingEntityMetadata"] | undefined,
  viewport: Viewport,
  derivedElements?: DerivedElement[],
) {
  const tolerance = 9 / viewport.zoom;
  let closest: { target: EditControlTarget; distance: number } | undefined;
  for (const entity of [...entities].reverse()) {
    const join = (metadata ?? []).find((item) => item.entityId === entity.id);
    if (!join?.derivedElementId || typeof join.resolvedIndex !== "number") continue;
    if (derivedElements && !derivedElements.some((item) => item.id === join.derivedElementId && item.kind.fillet))
      continue;
    const geometry = geometryOf(entity);
    if (!geometry || (geometry.tag !== "circle" && geometry.tag !== "arc")) continue;
    const angle = geometry.tag === "arc" ? geometry.startAngleRad + geometry.sweepAngleRad / 2 : 0;
    const handle = {
      xMm: geometry.center.xMm + geometry.radiusMm * Math.cos(angle),
      yMm: geometry.center.yMm + geometry.radiusMm * Math.sin(angle),
    };
    const distance = Math.hypot(point.xMm - handle.xMm, point.yMm - handle.yMm);
    if (distance <= tolerance && (!closest || distance < closest.distance))
      closest = { target: { controlPoint: { entityId: entity.id, point: "radius" } }, distance };
  }
  return closest?.target;
}
