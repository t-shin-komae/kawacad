import type { DerivedElement, Part } from "@/features/inspector/components/InspectorPanel";
import {
  constraintMarkerIcon,
  constraintMarkerLabel,
  geometryOf,
  type PointMm,
  type RawEntity,
  type Viewport,
} from "@/features/canvas/domain/cad";
import type { OutputPreviewPage } from "@/features/canvas/components/CadCanvas";
import type { CanvasViewMode } from "@/features/canvas/domain/canvasDomainModels";
import { appStrings } from "@/localization";

type Stroke = { red: number; green: number; blue: number; alpha: number };
type LineStyle = { stroke: Stroke; strokeWidthMm: number; pattern: string };
type Layer = { id: string; name: string; visible: boolean; printable: boolean; kind: string; style: LineStyle };
type SharedStyle = { id: string; name: string; style: LineStyle };
type Parameter = { id: string; name: string; valueMm: number; unit: string; memo: string };
type Constraint = { id: string; kind: string; status: string; value?: Record<string, number | string> };
type Measurement = {
  id: string;
  kind: string;
  targets: unknown[];
  labelOffsetMm: PointMm;
  overallOffsetMm: PointMm;
  visible: boolean;
};
type DimensionConstraintAnnotation = {
  constraintId: string;
  labelOffsetMm: PointMm;
  overallOffsetMm: PointMm;
  visible: boolean;
};
export type CanvasProjection = {
  stitchStartPoints: Array<{ id: string; positionMm: PointMm; visible: boolean }>;
  measurementAnnotations: Array<{
    id: string;
    visible: boolean;
    arc?: boolean;
    centerMm?: PointMm;
    startMm?: PointMm;
    endMm?: PointMm;
  }>;
  dimensionConstraints: Array<{
    id: string;
    visible: boolean;
    arc?: boolean;
    centerMm?: PointMm;
    startMm?: PointMm;
    endMm?: PointMm;
  }>;
  constraintMarkers: Array<{
    id: string;
    positionMm: PointMm;
    visible: boolean;
    label?: string;
    icon?: string;
    stackIndex?: number;
  }>;
};

export type State = {
  snapshot: { name: string; constraintStatus?: string; statistics: Record<string, number> };
  history: { canUndo: boolean; canRedo: boolean };
  persistence: { isDirty: boolean; hasPath?: boolean; path?: string };
  settings: { orientation: "portrait" | "landscape" };
  viewMode: CanvasViewMode;
  outputPreview?: { pages: OutputPreviewPage[]; warnings: Array<{ message: string }> } | null;
  entities: RawEntity[];
  drawingEntityMetadata: Array<{ entityId: string; derivedElementId?: string; resolvedIndex?: number }>;
  layers: Layer[];
  sharedStyles: SharedStyle[];
  parameters: Parameter[];
  parts: Part[];
  constraints: Constraint[];
  freeTexts: Array<{ id: string; content: string; positionMm: PointMm; fontSizeMm: number }>;
  derivedElements: DerivedElement[];
  roundHoles: Array<{ id: string; entityId: string; kind: string }>;
  stitchStartPoints: Array<{ id: string; targetEntityId: string }>;
  canvasProjection: CanvasProjection;
  measurementAnnotations: Measurement[];
  measurementEvaluations: Array<{ annotationId: string; value: Record<string, number> }>;
  dimensionConstraintAnnotations?: DimensionConstraintAnnotation[];
  coincidentPointGroups?: Array<{ id: string; representative: PointMm; targets: unknown[] }>;
  warnings: Array<{ code?: string; message?: string }>;
};

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
      const label = constraintMarkerLabel(constraints.get(item.id)?.kind ?? "");
      if (!label) return [];
      const key = `${item.positionMm.xMm}:${item.positionMm.yMm}`;
      const stackIndex = markerStacks.get(key) ?? 0;
      markerStacks.set(key, stackIndex + 1);
      return [{ ...item, label, icon: constraintMarkerIcon(constraints.get(item.id)?.kind ?? ""), stackIndex }];
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

export type EditControlTarget =
  import("@/features/canvas/domain/cad").ConstraintTarget | { controlPoint: { entityId: string; point: "radius" } };

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

export function partCanvasHighlights(
  part: Part | undefined,
  drawingEntityMetadata: State["drawingEntityMetadata"],
  stitchStartPoints: State["stitchStartPoints"],
) {
  if (!part)
    return {
      entityIds: new Set<string>(),
      freeTextIds: new Set<string>(),
      measurementAnnotationIds: new Set<string>(),
      stitchStartPointIds: new Set<string>(),
    };
  const derivedIds = new Set(part.derivedElementIds);
  const resolvedEntityIds = drawingEntityMetadata
    .filter((item) => derivedIds.has(item.derivedElementId ?? ""))
    .map((item) => item.entityId);
  const stitchTargetIds = new Set([...part.entityIds, ...part.derivedElementIds]);
  return {
    entityIds: new Set([...part.entityIds, ...resolvedEntityIds]),
    freeTextIds: new Set(part.freeTextIds),
    measurementAnnotationIds: new Set(part.measurementAnnotationIds),
    stitchStartPointIds: new Set(
      stitchStartPoints.filter((item) => stitchTargetIds.has(item.targetEntityId)).map((item) => item.id),
    ),
  };
}

export function documentWindowPresentation(name: string, path: string | undefined, isDirty: boolean) {
  const displayName = name === "Untitled" ? appStrings.app.untitled : name;
  if (!path)
    return {
      title: `${displayName} — ${appStrings.app.unsaved}`,
      accessibilityLabel: `${displayName}、${isDirty ? appStrings.app.unsavedChanges : appStrings.app.unsaved}`,
    };
  const fileName = path.split(/[\\/]/).pop() || path;
  const stem = fileName.replace(/\.[^.]*$/, "");
  const sameName = [fileName, stem].some(
    (candidate) => candidate.localeCompare(displayName, undefined, { sensitivity: "accent" }) === 0,
  );
  const title = sameName ? fileName : `${fileName} — ${displayName}`;
  return {
    title,
    accessibilityLabel: `${title}、${isDirty ? appStrings.app.unsavedChanges : appStrings.app.savedState}`,
  };
}
