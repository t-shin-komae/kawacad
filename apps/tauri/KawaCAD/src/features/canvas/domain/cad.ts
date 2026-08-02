import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
import { appStrings } from "@/localization";

export type PointMm = { xMm: number; yMm: number };
export type Viewport = { zoom: number; panX: number; panY: number };

/** PDF/PostScript points per millimeter. The editing canvas uses this
 * device-independent document scale at 100%; backing pixels are separate. */
export const displayPointsPerMillimeter = 72 / 25.4;

export function displayScale(viewport: Viewport) {
  return displayPointsPerMillimeter * viewport.zoom;
}

export type RawEntity = { id: string; layerId?: string | null; styleId?: string | null; kind: Record<string, unknown> };
export type ConstraintTarget =
  | { entity: string }
  | {
      controlPoint:
        | { entityId: string; point: "start" | "end" | "center" }
        | { entity_id: string; point: "start" | "end" | "center" };
    };

/** Converts the UI's ergonomic control-point shape to the Core wire shape.
 * Core intentionally keeps `entity_id` for this externally-tagged payload;
 * keeping the conversion at the transport boundary prevents UI state and
 * hit-testing code from being coupled to that serialization detail. */
export function coreConstraintTarget(target: ConstraintTarget) {
  if ("entity" in target) return target;
  const entityId = controlPointEntityId(target.controlPoint);
  return { controlPoint: { entity_id: entityId, point: target.controlPoint.point } };
}

export function controlPointEntityId(value: { entityId?: string; entity_id?: string }) {
  return value.entityId ?? value.entity_id;
}
export type Geometry =
  | { tag: "point"; point: PointMm }
  | { tag: "lineSegment" | "centerLine"; start: PointMm; end: PointMm }
  | { tag: "circle"; center: PointMm; radiusMm: number }
  | { tag: "arc"; center: PointMm; radiusMm: number; startAngleRad: number; sweepAngleRad: number };

// SwiftUI's canvas opens at its 100% document scale.  Keep the model unit
// scale separate from device pixel ratio, which CadCanvas applies at render.
export const defaultViewport: Viewport = { zoom: 1, panX: 0, panY: 0 };

export function geometryOf(entity: RawEntity): Geometry | undefined {
  const [tag, raw] = Object.entries(entity.kind)[0] ?? [];
  if (!raw || typeof raw !== "object") return undefined;
  const value = raw as Record<string, unknown>;
  if (tag === "point" && point(value)) return { tag, point: point(value)! };
  if ((tag === "lineSegment" || tag === "centerLine") && point(value.start) && point(value.end))
    return { tag, start: point(value.start)!, end: point(value.end)! };
  if (tag === "circle" && point(value.center) && typeof value.radiusMm === "number")
    return { tag, center: point(value.center)!, radiusMm: value.radiusMm };
  if (
    tag === "arc" &&
    point(value.center) &&
    typeof value.radiusMm === "number" &&
    typeof value.startAngleRad === "number" &&
    typeof value.sweepAngleRad === "number"
  )
    return {
      tag,
      center: point(value.center)!,
      radiusMm: value.radiusMm,
      startAngleRad: value.startAngleRad,
      sweepAngleRad: value.sweepAngleRad,
    };
  return undefined;
}

/** Matches SwiftUI's text hit area in model space closely enough to select an
 * annotation before falling through to the underlying geometry. */
export function hitFreeText(
  point: PointMm,
  freeTexts: Array<{ id: string; content: string; positionMm: PointMm; fontSizeMm: number }>,
) {
  for (const item of [...freeTexts].reverse()) {
    const fontSizeMm = Math.max(1, item.fontSizeMm);
    const widthMm = Math.max(fontSizeMm, item.content.length * fontSizeMm * 0.62);
    if (
      point.xMm >= item.positionMm.xMm &&
      point.xMm <= item.positionMm.xMm + widthMm &&
      point.yMm >= item.positionMm.yMm - fontSizeMm &&
      point.yMm <= item.positionMm.yMm + fontSizeMm * 0.25
    )
      return item.id;
  }
  return undefined;
}

export function hitProjectedPoint(
  point: PointMm,
  items: Array<{ id: string; positionMm: PointMm; visible?: boolean }>,
  viewport: Viewport,
  tolerancePx = 8,
) {
  const toleranceMm = tolerancePx / Math.max(displayScale(viewport), 0.01);
  return [...items]
    .reverse()
    .find(
      (item) =>
        item.visible !== false &&
        Math.hypot(point.xMm - item.positionMm.xMm, point.yMm - item.positionMm.yMm) <= toleranceMm,
    )?.id;
}

/** Hit-tests the label-shaped affordance rendered for a constraint marker.
 * SwiftUI lets users click the marker label as well as its anchor point; the
 * React canvas uses the same screen-space box so the affordance remains
 * usable at every zoom level. */
export function hitConstraintMarker(
  point: PointMm,
  items: Array<{
    id: string;
    positionMm: PointMm;
    visible?: boolean;
    label?: string;
    icon?: string;
    stackIndex?: number;
  }>,
  viewport: Viewport,
  tolerancePx = 8,
) {
  for (const item of [...items].reverse()) {
    if (item.visible === false) continue;
    const stackIndex = item.stackIndex ?? 0;
    const markerWidthPx = Math.max(22, ((item.label?.length ?? 2) + (item.icon ? 2 : 0)) * 6 + 10);
    const x = 10 + stackIndex * 5;
    const y = -20 - stackIndex * 5;
    // The marker is anchored at the item's model position. Compare the
    // screen-space offset after translating to that anchor.
    const offset = {
      x: (point.xMm - item.positionMm.xMm) * displayScale(viewport),
      y: -(point.yMm - item.positionMm.yMm) * displayScale(viewport),
    };
    const labelHit =
      offset.x >= x - tolerancePx &&
      offset.x <= x + markerWidthPx + tolerancePx &&
      offset.y >= y - tolerancePx &&
      offset.y <= y + 16 + tolerancePx;
    if (labelHit || Math.hypot(offset.x, offset.y) <= tolerancePx) return item.id;
  }
  return undefined;
}

/** Select a visible projected measurement or dimension by its displayed line.
 * The tolerance is expressed in screen pixels, matching the other canvas
 * affordances while remaining stable as the document is zoomed. */
export function hitProjectedAnnotation(
  point: PointMm,
  items: Array<{ id: string; visible: boolean; startMm?: PointMm; endMm?: PointMm }>,
  viewport: Viewport,
  tolerancePx = 8,
) {
  return hitProjectedAnnotationDetail(point, items, viewport, {}, {}, tolerancePx)?.id;
}

/** Distinguishes a label hit from a dimension line hit so Core can persist
 * either a label-only offset or an overall annotation offset. */
export function hitProjectedAnnotationDetail(
  point: PointMm,
  items: Array<{ id: string; visible: boolean; arc?: boolean; centerMm?: PointMm; startMm?: PointMm; endMm?: PointMm }>,
  viewport: Viewport,
  labels: Record<string, string>,
  labelOffsets: Record<string, PointMm>,
  tolerancePx = 8,
) {
  const toleranceMm = tolerancePx / Math.max(displayScale(viewport), 0.01);
  for (const item of [...items].reverse()) {
    const startMm = item.startMm;
    const endMm = item.endMm;
    if (!item.visible || !startMm || !endMm) continue;
    if (
      labelContains(
        point,
        { startMm, endMm, arc: item.arc, centerMm: item.centerMm },
        viewport,
        labels[item.id],
        labelOffsets[item.id],
      )
    )
      return { id: item.id, labelOnly: true };
    if (
      item.arc && item.centerMm
        ? distanceToArc(
            point,
            item.centerMm,
            startMm,
            endMm,
            Boolean(arcDirectionFromEndpoints(item.centerMm, startMm, endMm)),
          ) <= toleranceMm
        : distanceToSegment(point, startMm, endMm) <= toleranceMm
    )
      return { id: item.id, labelOnly: false };
  }
  return undefined;
}

function arcDirectionFromEndpoints(center: PointMm, start: PointMm, end: PointMm) {
  const startAngle = Math.atan2(start.yMm - center.yMm, start.xMm - center.xMm);
  const endAngle = Math.atan2(end.yMm - center.yMm, end.xMm - center.xMm);
  let sweep = endAngle - startAngle;
  while (sweep <= -Math.PI) sweep += Math.PI * 2;
  while (sweep > Math.PI) sweep -= Math.PI * 2;
  return sweep > 0;
}

function distanceToArc(point: PointMm, center: PointMm, start: PointMm, end: PointMm, counterclockwise: boolean) {
  const radius = Math.hypot(start.xMm - center.xMm, start.yMm - center.yMm);
  if (radius <= 0.0001) return Math.hypot(point.xMm - center.xMm, point.yMm - center.yMm);
  const pointAngle = Math.atan2(point.yMm - center.yMm, point.xMm - center.xMm);
  const startAngle = Math.atan2(start.yMm - center.yMm, start.xMm - center.xMm);
  const endAngle = Math.atan2(end.yMm - center.yMm, end.xMm - center.xMm);
  const normalize = (value: number) => {
    const full = Math.PI * 2;
    return ((value % full) + full) % full;
  };
  const swept = counterclockwise ? normalize(endAngle - startAngle) : normalize(startAngle - endAngle);
  const travelled = counterclockwise ? normalize(pointAngle - startAngle) : normalize(startAngle - pointAngle);
  const onSweep = travelled <= swept + 0.0001;
  if (!onSweep)
    return Math.min(
      Math.hypot(point.xMm - start.xMm, point.yMm - start.yMm),
      Math.hypot(point.xMm - end.xMm, point.yMm - end.yMm),
    );
  return Math.abs(Math.hypot(point.xMm - center.xMm, point.yMm - center.yMm) - radius);
}

function labelContains(
  point: PointMm,
  item: { startMm: PointMm; endMm: PointMm; arc?: boolean; centerMm?: PointMm },
  viewport: Viewport,
  label: string | undefined,
  labelOffset: PointMm | undefined,
) {
  if (!label) return false;
  const offset = labelOffset ?? { xMm: 0, yMm: 0 };
  const midpoint =
    item.arc && item.centerMm
      ? annotationArcMidpoint(item.centerMm, item.startMm, item.endMm)
      : {
          xMm: (item.startMm.xMm + item.endMm.xMm) / 2,
          yMm: (item.startMm.yMm + item.endMm.yMm) / 2,
        };
  const center = {
    xMm: midpoint.xMm + offset.xMm + 5 / displayScale(viewport),
    yMm: midpoint.yMm + offset.yMm + 5 / displayScale(viewport),
  };
  return (
    Math.abs(point.xMm - center.xMm) <= (label.length * 3.5 + 4) / displayScale(viewport) &&
    Math.abs(point.yMm - center.yMm) <= 8 / displayScale(viewport)
  );
}

function annotationArcMidpoint(center: PointMm, start: PointMm, end: PointMm) {
  const radius = Math.hypot(start.xMm - center.xMm, start.yMm - center.yMm);
  if (radius <= 0.0001) return start;
  const startAngle = Math.atan2(start.yMm - center.yMm, start.xMm - center.xMm);
  const endAngle = Math.atan2(end.yMm - center.yMm, end.xMm - center.xMm);
  let sweep = endAngle - startAngle;
  while (sweep <= -Math.PI) sweep += Math.PI * 2;
  while (sweep > Math.PI) sweep -= Math.PI * 2;
  const angle = startAngle + sweep / 2;
  return { xMm: center.xMm + radius * Math.cos(angle), yMm: center.yMm + radius * Math.sin(angle) };
}

function distanceToSegment(point: PointMm, start: PointMm, end: PointMm) {
  const dx = end.xMm - start.xMm;
  const dy = end.yMm - start.yMm;
  const lengthSquared = dx * dx + dy * dy;
  if (lengthSquared === 0) return Math.hypot(point.xMm - start.xMm, point.yMm - start.yMm);
  const position = Math.max(
    0,
    Math.min(1, ((point.xMm - start.xMm) * dx + (point.yMm - start.yMm) * dy) / lengthSquared),
  );
  return Math.hypot(point.xMm - (start.xMm + position * dx), point.yMm - (start.yMm + position * dy));
}

function point(value: unknown): PointMm | undefined {
  if (!value || typeof value !== "object") return undefined;
  const point = value as Record<string, unknown>;
  return typeof point.xMm === "number" && typeof point.yMm === "number"
    ? { xMm: point.xMm, yMm: point.yMm }
    : undefined;
}

export function screenPoint(point: PointMm, width: number, height: number, viewport: Viewport) {
  const scale = displayScale(viewport);
  return {
    x: width / 2 + viewport.panX + point.xMm * scale,
    y: height / 2 + viewport.panY - point.yMm * scale,
  };
}

export function modelPoint(
  screen: { x: number; y: number },
  width: number,
  height: number,
  viewport: Viewport,
): PointMm {
  const scale = displayScale(viewport);
  return {
    xMm: (screen.x - width / 2 - viewport.panX) / scale,
    yMm: -(screen.y - height / 2 - viewport.panY) / scale,
  };
}

export type A4Orientation = "portrait" | "landscape";

/**
 * SwiftUI's `CanvasCoordinateSpace` limits direct drawing input to the
 * centered five-by-five A4 working grid.  Keep this separate from viewport
 * panning so display navigation remains unconstrained.
 */
export function a4GridBounds(orientation: A4Orientation = "portrait") {
  const pageWidthMm = orientation === "landscape" ? 297 : 210;
  const pageHeightMm = orientation === "landscape" ? 210 : 297;
  return {
    pageWidthMm,
    pageHeightMm,
    minXmm: -(pageWidthMm * 5) / 2,
    maxXmm: (pageWidthMm * 5) / 2,
    minYmm: -(pageHeightMm * 5) / 2,
    maxYmm: (pageHeightMm * 5) / 2,
  };
}

export function clampToA4Grid(point: PointMm, orientation: A4Orientation = "portrait"): PointMm {
  const bounds = a4GridBounds(orientation);
  return {
    xMm: Math.max(bounds.minXmm, Math.min(bounds.maxXmm, point.xMm)),
    yMm: Math.max(bounds.minYmm, Math.min(bounds.maxYmm, point.yMm)),
  };
}

export function modelPointInA4Grid(
  screen: { x: number; y: number },
  width: number,
  height: number,
  viewport: Viewport,
  orientation: A4Orientation = "portrait",
): PointMm {
  return clampToA4Grid(modelPoint(screen, width, height, viewport), orientation);
}

export function snapToGrid(point: PointMm, enabled: boolean, stepMm = 5): PointMm {
  if (!enabled) return point;
  return { xMm: Math.round(point.xMm / stepMm) * stepMm, yMm: Math.round(point.yMm / stepMm) * stepMm };
}

export const arcAngleSnapStepRad = Math.PI / 12;

/** The shortest signed turn from `startAngleRad` to `endAngleRad`. */
export function normalizedSignedSweepAngle(startAngleRad: number, endAngleRad: number) {
  const fullTurn = Math.PI * 2;
  let sweep = (endAngleRad - startAngleRad) % fullTurn;
  if (sweep <= -Math.PI) sweep += fullTurn;
  if (sweep > Math.PI) sweep -= fullTurn;
  return sweep;
}

/**
 * Mirrors SwiftUI's three-point arc placement.  The previous sweep is kept
 * while the pointer moves so a user can intentionally cross 180 degrees
 * without Core reducing the result to the smaller arc.
 */
export function arcPlacementEndPoint(
  center: PointMm,
  start: PointMm,
  candidate: PointMm,
  previousSweepAngleRad: number | undefined,
  snapAngle: boolean,
) {
  const radiusMm = Math.hypot(start.xMm - center.xMm, start.yMm - center.yMm);
  if (radiusMm <= 0.0001) return undefined;

  const startAngleRad = Math.atan2(start.yMm - center.yMm, start.xMm - center.xMm);
  const candidateAngleRad = Math.atan2(candidate.yMm - center.yMm, candidate.xMm - center.xMm);
  let sweepAngleRad =
    previousSweepAngleRad === undefined
      ? normalizedSignedSweepAngle(startAngleRad, candidateAngleRad)
      : previousSweepAngleRad + normalizedSignedSweepAngle(startAngleRad + previousSweepAngleRad, candidateAngleRad);
  if (snapAngle) sweepAngleRad = Math.round(sweepAngleRad / arcAngleSnapStepRad) * arcAngleSnapStepRad;

  const fullTurn = Math.PI * 2;
  if (
    Math.abs(sweepAngleRad) <= 0.0001 ||
    Math.abs(Math.abs(sweepAngleRad) - fullTurn) <= 0.0001 ||
    Math.abs(sweepAngleRad) >= fullTurn
  )
    return undefined;

  const endAngleRad = startAngleRad + sweepAngleRad;
  return {
    point: {
      xMm: center.xMm + radiusMm * Math.cos(endAngleRad),
      yMm: center.yMm + radiusMm * Math.sin(endAngleRad),
    },
    sweepAngleRad,
  };
}

/** The concise CAD label shown in the canvas marker for a Core constraint. */
export function constraintMarkerLabel(kind: string): string | undefined {
  const labels: Record<string, string> = {
    ...appStrings.toolNames,
    equalSegmentLength: appStrings.toolNames.equalLength,
    pointLineDistance: appStrings.toolNames.distance,
    lineLineDistance: appStrings.constraintLabels.lineLineDistance,
  };
  return labels[kind];
}

/** Compact, text-safe symbols for constraint markers. These use Unicode
 * glyphs instead of a platform-specific SF Symbol so the same marker remains
 * legible in Windows and Linux WebViews. */
export function constraintMarkerIcon(kind: string): string | undefined {
  const icons: Record<string, string> = {
    coincident: "⊙",
    horizontal: "—",
    vertical: "│",
    parallel: "∥",
    perpendicular: "⟂",
    tangent: "⌒",
    equalLength: "=",
    equalSegmentLength: "=",
    symmetric: "⇄",
    pointOnLine: "⊢",
    fixed: "⚑",
    distance: "↔",
    pointLineDistance: "↔",
    horizontalDistance: "↔",
    verticalDistance: "↕",
    lineLineDistance: "↔",
    segmentLength: "↔",
    angle: "∠",
    diameter: "⌀",
    radius: "R",
  };
  return icons[kind];
}

/** Returns the closest exposed control point in screen-space tolerance. */
export function snapToEntityPoint(point: PointMm, entities: RawEntity[], viewport: Viewport): PointMm {
  const tolerance = 9 / displayScale(viewport);
  let closest: PointMm | undefined;
  let closestDistance = tolerance;
  for (const entity of entities) {
    const geometry = geometryOf(entity);
    if (!geometry) continue;
    for (const candidate of geometrySnapPoints(geometry)) {
      const candidateDistance = distance(point, candidate);
      if (candidateDistance <= closestDistance) {
        closest = candidate;
        closestDistance = candidateDistance;
      }
    }
  }
  return closest ?? point;
}

export function hitEntity(point: PointMm, entities: RawEntity[], viewport: Viewport): string | undefined {
  const tolerance = 7 / displayScale(viewport);
  let derivedHit: string | undefined;
  for (const entity of [...entities].reverse()) {
    if (!isEntityHit(point, entity, tolerance)) continue;
    if (!entity.id.startsWith("derived:")) return entity.id;
    derivedHit ??= entity.id;
  }
  return derivedHit;
}

/**
 * Resolves Select-tool hits with the same control-point priority as the
 * SwiftUI canvas.  Keeping a selected control in front of an overlapping
 * entity body prevents a drag from unexpectedly switching its target.
 */
export function preferredEntitySelectionHit(
  point: PointMm,
  entities: RawEntity[],
  viewport: Viewport,
  selectedIds: Set<string> = new Set(),
): string | undefined {
  const selectedControls = closestControlTarget(
    point,
    entities.filter((entity) => selectedIds.has(entity.id)),
    viewport,
  );
  if (selectedControls) return constraintTargetEntityId(selectedControls);
  const control = closestControlTarget(point, entities, viewport);
  return control ? constraintTargetEntityId(control) : hitEntity(point, entities, viewport);
}

function hitOffsetEntity(point: PointMm, entities: RawEntity[], viewport: Viewport): string | undefined {
  const tolerance = 7 / displayScale(viewport);
  let baseHit: string | undefined;
  let derivedHit: string | undefined;
  for (const entity of [...entities].reverse()) {
    if (!isEntityHit(point, entity, tolerance)) continue;
    if (entity.id.startsWith("derived:fillet-") && entity.id.includes(":resolved:")) return entity.id;
    if (entity.id.startsWith("derived:")) derivedHit ??= entity.id;
    else baseHit ??= entity.id;
  }
  return baseHit ?? derivedHit;
}

function isEntityHit(point: PointMm, entity: RawEntity, tolerance: number): boolean {
  const geometry = geometryOf(entity);
  if (!geometry) return false;
  return (
    (geometry.tag === "point" && distance(point, geometry.point) <= tolerance) ||
    ((geometry.tag === "lineSegment" || geometry.tag === "centerLine") &&
      pointLineDistance(point, geometry.start, geometry.end) <= tolerance) ||
    (geometry.tag === "circle" && Math.abs(distance(point, geometry.center) - geometry.radiusMm) <= tolerance) ||
    (geometry.tag === "arc" &&
      Math.abs(distance(point, geometry.center) - geometry.radiusMm) <= tolerance &&
      isOnArc(point, geometry))
  );
}

/**
 * Resolves a click to the same entity/control-point shape expected by the
 * Rust `ConstraintTarget` enum. Prefer explicit controls so a line's two
 * endpoints can be constrained independently.
 */
export function hitConstraintTarget(
  point: PointMm,
  entities: RawEntity[],
  viewport: Viewport,
): ConstraintTarget | undefined {
  const tolerance = 9 / displayScale(viewport);
  let closest: { target: ConstraintTarget; distance: number } | undefined;
  for (const entity of [...entities].reverse()) {
    const geometry = geometryOf(entity);
    if (!geometry) continue;
    const controls = controlPointsOf(geometry);
    for (const control of controls) {
      const candidateDistance = distance(point, control.point);
      if (candidateDistance <= tolerance && (!closest || candidateDistance < closest.distance)) {
        closest = {
          target: { controlPoint: { entityId: entity.id, point: control.kind } },
          distance: candidateDistance,
        };
      }
    }
  }
  if (closest) return closest.target;
  const entityId = hitEntity(point, entities, viewport);
  return entityId ? { entity: entityId } : undefined;
}

/**
 * Selects the same target shape the SwiftUI canvas exposes for each tool.
 * It deliberately stays at the UI boundary: Core still validates target
 * combinations, while React makes overlapping endpoint/body clicks useful.
 */
export function preferredConstraintTarget(
  point: PointMm,
  entities: RawEntity[],
  viewport: Viewport,
  tool: Tool,
  pendingTargets: ConstraintTarget[] = [],
): ConstraintTarget | undefined {
  const pointTarget = closestControlTarget(point, entities, viewport);
  const entityTarget =
    tool === "offset" ? hitOffsetEntity(point, entities, viewport) : hitEntity(point, entities, viewport);
  const entity = entityTarget ? entities.find((item) => item.id === entityTarget) : undefined;
  const geometry = entity && geometryOf(entity);
  const lineTarget =
    entityTarget && geometry && (geometry.tag === "lineSegment" || geometry.tag === "centerLine")
      ? ({ entity: entityTarget } satisfies ConstraintTarget)
      : undefined;
  const bodyTarget = entityTarget ? ({ entity: entityTarget } satisfies ConstraintTarget) : undefined;
  const pointOnly = new Set<Tool>([
    "horizontalDistance",
    "verticalDistance",
    "measureDistance",
    "coincident",
    "fixed",
    "tangent",
  ]);
  const lineOnly = new Set<Tool>([
    "parallel",
    "perpendicular",
    "equalLength",
    "lineLineDistance",
    "measureAngle",
    "measureSegmentLength",
    "segmentLength",
  ]);

  if (tool === "pointOnLine") return pendingTargets.length ? (lineTarget ?? pointTarget) : (pointTarget ?? lineTarget);
  if (tool === "symmetric" && pendingTargets.length >= 2) return lineTarget;
  if (tool === "offset") return lineTarget ?? bodyTarget;
  if (tool === "measureArcSweepAngle") return geometry?.tag === "arc" ? bodyTarget : undefined;
  if (tool === "diameter") return geometry?.tag === "circle" ? bodyTarget : undefined;
  if (tool === "measureRadius" || tool === "measureDiameter")
    return geometry?.tag === "circle" || geometry?.tag === "arc" ? bodyTarget : undefined;
  if (lineOnly.has(tool)) return lineTarget;
  if (tool === "angle") return lineTarget ?? (geometry?.tag === "arc" ? bodyTarget : undefined);
  if (tool === "horizontal" || tool === "vertical") return lineTarget ?? pointTarget;
  if (tool === "tangent") {
    const pendingEntityIds = new Set(pendingTargets.map(constraintTargetEntityId));
    return (
      (pointTarget && !pendingEntityIds.has(constraintTargetEntityId(pointTarget)) ? pointTarget : undefined) ??
      pointTarget
    );
  }
  if (pointOnly.has(tool)) return pointTarget;
  if (tool === "distance") return pointTarget ?? lineTarget;
  if (tool === "radius")
    return pointTarget ?? (geometry?.tag === "circle" || geometry?.tag === "arc" ? bodyTarget : undefined);
  return pointTarget ?? bodyTarget;
}

function closestControlTarget(point: PointMm, entities: RawEntity[], viewport: Viewport): ConstraintTarget | undefined {
  const tolerance = 9 / displayScale(viewport);
  let closest: { target: ConstraintTarget; distance: number; derived: boolean } | undefined;
  for (const entity of entities) {
    const geometry = geometryOf(entity);
    if (!geometry) continue;
    for (const control of controlPointsOf(geometry)) {
      const candidateDistance = distance(point, control.point);
      const candidate = { target: { controlPoint: { entityId: entity.id, point: control.kind } }, candidateDistance };
      if (
        candidateDistance <= tolerance &&
        (!closest ||
          candidateDistance < closest.distance ||
          (candidateDistance === closest.distance && closest.derived && !entity.id.startsWith("derived:")))
      ) {
        closest = {
          target: candidate.target,
          distance: candidate.candidateDistance,
          derived: entity.id.startsWith("derived:"),
        };
      }
    }
  }
  return closest?.target;
}

export function constraintTargetEntityId(target: ConstraintTarget): string {
  if ("entity" in target) return target.entity;
  return controlPointEntityId(target.controlPoint)!;
}

/** UI-side eligibility mirrors SwiftUI's preflight guard; the Core remains
 * authoritative for semantic validation and normalization. */
export function supportsOffsetTarget(entity: RawEntity | undefined) {
  const geometry = entity && geometryOf(entity);
  return Boolean(geometry && ["lineSegment", "centerLine", "circle", "arc"].includes(geometry.tag));
}

export function allowsDerivedTarget(tool: Tool, entity: RawEntity | undefined) {
  if (!entity?.id.startsWith("derived:")) return true;
  if (tool === "offset" || tool === "fillet") return true;
  if (
    [
      "measureDistance",
      "measureSegmentLength",
      "measureAngle",
      "measureRadius",
      "measureDiameter",
      "measureArcSweepAngle",
    ].includes(tool)
  )
    return true;
  if (tool !== "radius") return false;
  const geometry = geometryOf(entity);
  return geometry?.tag === "arc" && entity.id.includes(":fillet-");
}

export function selectionInRect(entities: RawEntity[], first: PointMm, second: PointMm, crossing: boolean): string[] {
  const left = Math.min(first.xMm, second.xMm),
    right = Math.max(first.xMm, second.xMm);
  const bottom = Math.min(first.yMm, second.yMm),
    top = Math.max(first.yMm, second.yMm);
  return entities
    .filter((entity) => {
      if (/^derived:fillet-[^:]+:resolved:/.test(entity.id)) return false;
      const g = geometryOf(entity);
      if (!g) return false;
      const rect = { left, right, bottom, top };
      return crossing ? geometryIntersectsRect(g, rect) : geometryContainedInRect(g, rect);
    })
    .map((entity) => entity.id);
}

type ModelRect = { left: number; right: number; bottom: number; top: number };

export function normalizedScreenRect(first: { x: number; y: number }, second: { x: number; y: number }) {
  return {
    x: Math.min(first.x, second.x),
    y: Math.min(first.y, second.y),
    width: Math.abs(second.x - first.x),
    height: Math.abs(second.y - first.y),
  };
}

export function hasMeaningfulModelMovement(first: PointMm, second: PointMm, toleranceMm = 0.0001) {
  return Math.hypot(second.xMm - first.xMm, second.yMm - first.yMm) >= toleranceMm;
}

function geometryContainedInRect(geometry: Geometry, rect: ModelRect) {
  return geometrySamples(geometry).every((point) => isInsideRect(point, rect));
}

function geometryIntersectsRect(geometry: Geometry, rect: ModelRect) {
  if (geometry.tag === "point") return isInsideRect(geometry.point, rect);
  if (geometry.tag === "lineSegment" || geometry.tag === "centerLine")
    return segmentIntersectsRect(geometry.start, geometry.end, rect);
  const samples = geometrySamples(geometry);
  return (
    samples.some((point) => isInsideRect(point, rect)) ||
    samples.some((point, index) => {
      const next = samples[index + 1];
      return next ? segmentIntersectsRect(point, next, rect) : false;
    })
  );
}

function geometrySamples(geometry: Geometry): PointMm[] {
  if (geometry.tag === "point") return [geometry.point];
  if (geometry.tag === "lineSegment" || geometry.tag === "centerLine") return [geometry.start, geometry.end];
  if (geometry.tag === "circle") return sampledArc(geometry.center, geometry.radiusMm, 0, Math.PI * 2, 48, true);
  if (geometry.tag === "arc")
    return sampledArc(geometry.center, geometry.radiusMm, geometry.startAngleRad, geometry.sweepAngleRad, 48, false);
  return [];
}

function sampledArc(
  center: PointMm,
  radiusMm: number,
  startAngleRad: number,
  sweepAngleRad: number,
  maximumSegments: number,
  closed: boolean,
) {
  const segments = Math.max(1, Math.ceil((Math.abs(sweepAngleRad) / (Math.PI * 2)) * maximumSegments));
  const points = Array.from({ length: segments + 1 }, (_, index) => {
    const angle = startAngleRad + (sweepAngleRad * index) / segments;
    return { xMm: center.xMm + radiusMm * Math.cos(angle), yMm: center.yMm + radiusMm * Math.sin(angle) };
  });
  return closed ? [...points, points[0]] : points;
}

function isInsideRect(point: PointMm, rect: ModelRect) {
  return point.xMm >= rect.left && point.xMm <= rect.right && point.yMm >= rect.bottom && point.yMm <= rect.top;
}

function segmentIntersectsRect(first: PointMm, second: PointMm, rect: ModelRect) {
  if (isInsideRect(first, rect) || isInsideRect(second, rect)) return true;
  const corners = [
    { xMm: rect.left, yMm: rect.bottom },
    { xMm: rect.right, yMm: rect.bottom },
    { xMm: rect.right, yMm: rect.top },
    { xMm: rect.left, yMm: rect.top },
  ];
  return corners.some((corner, index) =>
    segmentsIntersect(first, second, corner, corners[(index + 1) % corners.length]),
  );
}

function segmentsIntersect(first: PointMm, second: PointMm, third: PointMm, fourth: PointMm) {
  const cross = (origin: PointMm, one: PointMm, two: PointMm) =>
    (one.xMm - origin.xMm) * (two.yMm - origin.yMm) - (one.yMm - origin.yMm) * (two.xMm - origin.xMm);
  const firstSide = cross(first, second, third);
  const secondSide = cross(first, second, fourth);
  const thirdSide = cross(third, fourth, first);
  const fourthSide = cross(third, fourth, second);
  return firstSide * secondSide <= 0 && thirdSide * fourthSide <= 0;
}

function geometrySnapPoints(geometry: Geometry): PointMm[] {
  if (geometry.tag === "point") return [geometry.point];
  if (geometry.tag === "lineSegment" || geometry.tag === "centerLine") return [geometry.start, geometry.end];
  if (geometry.tag === "circle" || geometry.tag === "arc") return [geometry.center];
  return [];
}

export function controlPointsOf(geometry: Geometry): Array<{ point: PointMm; kind: "start" | "end" | "center" }> {
  if (geometry.tag === "point") return [{ point: geometry.point, kind: "center" }];
  if (geometry.tag === "lineSegment" || geometry.tag === "centerLine")
    return [
      { point: geometry.start, kind: "start" },
      { point: geometry.end, kind: "end" },
    ];
  if (geometry.tag === "circle") return [{ point: geometry.center, kind: "center" }];
  if (geometry.tag === "arc")
    return [
      { point: geometry.center, kind: "center" },
      {
        point: {
          xMm: geometry.center.xMm + geometry.radiusMm * Math.cos(geometry.startAngleRad),
          yMm: geometry.center.yMm + geometry.radiusMm * Math.sin(geometry.startAngleRad),
        },
        kind: "start",
      },
      {
        point: {
          xMm: geometry.center.xMm + geometry.radiusMm * Math.cos(geometry.startAngleRad + geometry.sweepAngleRad),
          yMm: geometry.center.yMm + geometry.radiusMm * Math.sin(geometry.startAngleRad + geometry.sweepAngleRad),
        },
        kind: "end",
      },
    ];
  return [];
}

function pointLineDistance(point: PointMm, start: PointMm, end: PointMm): number {
  const dx = end.xMm - start.xMm,
    dy = end.yMm - start.yMm,
    lengthSquared = dx * dx + dy * dy;
  const t =
    lengthSquared === 0
      ? 0
      : Math.max(0, Math.min(1, ((point.xMm - start.xMm) * dx + (point.yMm - start.yMm) * dy) / lengthSquared));
  return distance(point, { xMm: start.xMm + dx * t, yMm: start.yMm + dy * t });
}
function distance(first: PointMm, second: PointMm) {
  return Math.hypot(first.xMm - second.xMm, first.yMm - second.yMm);
}
function isOnArc(point: PointMm, arc: Extract<Geometry, { tag: "arc" }>) {
  const angle = Math.atan2(point.yMm - arc.center.yMm, point.xMm - arc.center.xMm);
  const fullTurn = Math.PI * 2;
  const positive = (value: number) => ((value % fullTurn) + fullTurn) % fullTurn;
  if (arc.sweepAngleRad >= 0) return positive(angle - arc.startAngleRad) <= arc.sweepAngleRad + 1e-6;
  return positive(arc.startAngleRad - angle) <= -arc.sweepAngleRad + 1e-6;
}
