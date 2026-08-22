/**
 * Types exchanged with the Core or derived directly from a Core response.
 *
 * These types intentionally do not depend on a feature component.  Canvas,
 * Inspector, Parts, and adapters can all consume the same wire vocabulary
 * without making one feature own another feature's data model.
 */

export type PointMm = { xMm: number; yMm: number };
export type Viewport = { zoom: number; panX: number; panY: number };
export type CanvasViewMode = "editDisplay" | "outputPreview";
export type RawEntity = { id: string; layerId?: string | null; styleId?: string | null; kind: Record<string, unknown> };
export type ConstraintTarget =
  | { entity: string }
  | {
      controlPoint:
        | { entityId: string; point: "start" | "end" | "center" }
        | { entity_id: string; point: "start" | "end" | "center" };
    };

export type LineStyle = {
  stroke: { red: number; green: number; blue: number; alpha: number };
  strokeWidthMm: number;
  pattern: string;
};
export type Layer = { id: string; name: string; visible: boolean; printable: boolean; kind: string; style: LineStyle };
export type SharedStyle = { id: string; name: string; style: LineStyle };
export type Parameter = {
  id: string;
  name: string;
  valueMm: number;
  unit: string;
  memo: string;
  usageCount?: number;
  usedConstraintIds?: string[];
};
export type Constraint = { id: string; kind: string; status: string; value?: Record<string, number | string> };
export type Measurement = {
  id: string;
  kind: string;
  targets: unknown[];
  labelOffsetMm: PointMm;
  overallOffsetMm: PointMm;
  visible: boolean;
};
export type DimensionConstraintAnnotation = {
  constraintId: string;
  labelOffsetMm: PointMm;
  overallOffsetMm: PointMm;
  visible: boolean;
};
export type Part = {
  id: string;
  name: string;
  quantity: number;
  visible: boolean;
  printable: boolean;
  originMm: PointMm;
  entityIds: string[];
  outlineEntityIds: string[];
  holeEntityIdGroups: string[][];
  derivedElementIds: string[];
  freeTextIds: string[];
  measurementAnnotationIds: string[];
};
export type PartLibraryEntry = { id: string; name: string; libraryJson: string; sourcePart: Part };
type ConstraintValue = { fixedMm?: number; parameter?: string };
type OffsetCurve = { sourceEntityIds: string[]; distance: ConstraintValue; direction: string };
type Fillet = { sourceEntityIds: string[]; radius: ConstraintValue; closed?: boolean };
export type DerivedElement = {
  id: string;
  layerId?: string | null;
  styleId?: string | null;
  kind: { offsetCurve?: OffsetCurve; fillet?: Fillet };
};

export type OutputPreviewPage = {
  widthMm: number;
  heightMm: number;
  gridColumn: number;
  gridRow: number;
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

export type EditControlTarget = ConstraintTarget | { controlPoint: { entityId: string; point: "radius" } };

export type State = {
  snapshot: { name: string; constraintStatus?: string; statistics: Record<string, number> };
  history: { canUndo: boolean; canRedo: boolean };
  persistence: { isDirty: boolean; hasPath?: boolean; path?: string };
  settings: { orientation: "portrait" | "landscape" };
  viewMode: CanvasViewMode;
  outputPreview?: { pages: OutputPreviewPage[]; warnings: Array<{ message: string }> } | null;
  entities: RawEntity[];
  drawingEntityMetadata: Array<{
    entityId: string;
    derivedElementId?: string;
    resolvedIndex?: number;
    sourceEntityId?: string;
    suppressedByFillet?: boolean;
  }>;
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
