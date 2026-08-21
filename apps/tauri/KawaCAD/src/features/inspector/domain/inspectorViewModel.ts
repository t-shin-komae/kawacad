import type { InspectorTab } from "@/features/inspector/selectors/inspectorFeature";
import type { PointMm, RawEntity } from "@/features/canvas/domain/cad";
import type { Constraint, DerivedElement, LineStyle, Part, PartLibraryEntry } from "@/shared/domain/coreWireTypes";

export type Measurement = { id: string; kind: string; visible: boolean };
export type InspectorParameter = {
  id: string;
  name: string;
  valueMm: number;
  unit: string;
  memo: string;
  usageCount?: number;
  usedConstraintIds?: string[];
};
export type InspectorLayer = {
  id: string;
  name: string;
  visible: boolean;
  printable: boolean;
  kind: string;
  style: LineStyle;
};
export type InspectorSharedStyle = { id: string; name: string; style: LineStyle };
export type InspectorFreeText = { id: string; content: string; positionMm: PointMm; fontSizeMm: number };

export type InspectorOperation<Input> = (input: Input, success: string) => void;
export type ConstraintValue = { fixedMm?: number; fixedDegrees?: number };
export type EntityMetric =
  | { kind: "segmentLength" | "circleRadius"; valueMm: number }
  | { kind: "arcUpdate"; radiusMm?: number; startAngleRad?: number; sweepAngleRad?: number };
export type SelectionInspectorActions = {
  setConstraintValue: InspectorOperation<{ constraintId: string; value: ConstraintValue }>;
  setConstraintParameter: InspectorOperation<{ constraintId: string; parameterId: string }>;
  deleteConstraint: InspectorOperation<string>;
  deleteMeasurement: InspectorOperation<string>;
  deleteEntity: InspectorOperation<string>;
  updateFreeText: InspectorOperation<{
    id: string;
    content: string;
    positionMm: PointMm;
    fontSizeMm: number;
  }>;
  deleteFreeText: InspectorOperation<string>;
  setDerivedDistance: InspectorOperation<{
    derivedElementId: string;
    value: { fixedMm?: number; parameter?: string };
  }>;
  setDerivedRadius: InspectorOperation<{
    derivedElementId: string;
    value: { fixedMm?: number; parameter?: string };
  }>;
  setDerivedDirection: InspectorOperation<{ derivedElementId: string; direction: string }>;
  setEntityLayer: InspectorOperation<{ entityId: string; layerId: string | null }>;
  setDerivedLayer: InspectorOperation<{ derivedElementId: string; layerId: string | null }>;
  setEntityStyle: InspectorOperation<{ entityId: string; styleId: string | null }>;
  setDerivedStyle: InspectorOperation<{ derivedElementId: string; styleId: string | null }>;
  setRoundHoleDiameter: InspectorOperation<{ roundHoleId: string; diameterMm: number }>;
  setRoundHoleKind: InspectorOperation<{ roundHoleId: string; kind: string }>;
  setEntityMetric: InspectorOperation<{ entityId: string; metric: EntityMetric }>;
  applyStyle: (styleId?: string) => void;
  deleteSelection: () => void;
  constrainSegmentLength: (entityId: string) => void;
  selectConstraint: (id: string) => void;
  selectFreeText: (id: string) => void;
  selectMeasurement: (id: string) => void;
  convertMeasurement: (id: string) => void;
};

export type ConstraintInspectorActions = Pick<
  SelectionInspectorActions,
  "setConstraintValue" | "setConstraintParameter" | "deleteConstraint"
>;
export type MeasurementInspectorActions = Pick<SelectionInspectorActions, "convertMeasurement" | "deleteMeasurement">;
export type FreeTextInspectorActions = Pick<SelectionInspectorActions, "updateFreeText" | "deleteFreeText">;
export type DerivedElementInspectorActions = Pick<
  SelectionInspectorActions,
  "setDerivedDistance" | "setDerivedRadius" | "setDerivedDirection"
>;
export type EntityInspectorActions = Pick<
  SelectionInspectorActions,
  | "setEntityLayer"
  | "setDerivedLayer"
  | "setEntityStyle"
  | "setDerivedStyle"
  | "deleteEntity"
  | "setEntityMetric"
  | "constrainSegmentLength"
>;
export type RoundHoleInspectorActions = Pick<SelectionInspectorActions, "setRoundHoleDiameter" | "setRoundHoleKind">;
export type EntityEditorActions = EntityInspectorActions & DerivedElementInspectorActions & RoundHoleInspectorActions;

export type LayerInspectorActions = {
  setVisibility: InspectorOperation<{ layerId: string; visible: boolean }>;
  setPrintable: InspectorOperation<{ layerId: string; printable: boolean }>;
  setStyle: InspectorOperation<{ layerId: string; style: LineStyle }>;
  addLayer: () => void;
  changeActiveLayer: (id: string) => void;
  renameLayer: (id: string, name: string) => void;
  deleteLayer: (layer: { id: string; name: string }) => void;
};

export type StyleInspectorActions = {
  update: InspectorOperation<{ styleId: string; name: string; style: LineStyle }>;
  delete: InspectorOperation<string>;
  add: (name: string) => void;
};

export type ParameterInspectorActions = {
  update: InspectorOperation<{
    id: string;
    name: string;
    valueMm: number;
    unit: string;
    memo: string;
  }>;
  delete: InspectorOperation<{ parameterId: string; replacementValueMm: number }>;
  add: () => void;
};

export type PartInspectorActions = {
  create: () => void;
  select: (part: Part) => void;
  align: (alignment: string) => void;
  distribute: (axis: string) => void;
  insertFromLibrary: (entry: PartLibraryEntry) => void;
  removeFromLibrary: (entry: PartLibraryEntry) => void;
  addToLibrary: (part: Part) => void;
  toggleArrangement: (id: string) => void;
  beginSetOrigin: (part: Part) => void;
  rename: InspectorOperation<{ partId: string; name: string }>;
  setPosition: InspectorOperation<{ partId: string; position: PointMm }>;
  setVisibility: InspectorOperation<{ partId: string; visible: boolean }>;
  setPrintable: InspectorOperation<{ partId: string; printable: boolean }>;
  setQuantity: InspectorOperation<{ partId: string; quantity: number }>;
  move: InspectorOperation<{ partId: string; delta: PointMm }>;
  duplicate: InspectorOperation<{
    partId: string;
    newPartId: string;
    newName: string;
    idNamespace: string;
    delta: PointMm;
  }>;
  delete: InspectorOperation<string>;
};

export type InspectorShellModel = { onTabChange: (tab: InspectorTab) => void };
export type SelectionInspectorModel = {
  selectedCount: number;
  documentSummary: {
    viewMode: string;
    activeLayerName: string;
    visibleEntityCount: number;
    constraintCount: number;
    parameterCount: number;
  };
  selectedEntityIds?: string[];
  selectedEntities?: RawEntity[];
  selectedEntity?: RawEntity;
  selectedDerivedElement?: DerivedElement;
  selectedFreeText?: InspectorFreeText;
  selectedConstraint?: Constraint;
  selectedMeasurement?: Measurement;
  selectedStitchStartPoint?: { id: string; targetEntityId: string };
  selectedStitchTargetEntity?: RawEntity;
  constraints: Constraint[];
  measurements: Measurement[];
  freeTexts: InspectorFreeText[];
  parameters: InspectorParameter[];
  layers: InspectorLayer[];
  sharedStyles: InspectorSharedStyle[];
  roundHoles: Array<{ id: string; entityId: string; kind: string }>;
  actions: SelectionInspectorActions;
};
export type LayerInspectorModel = {
  layers: InspectorLayer[];
  activeLayerId: string;
  actions: LayerInspectorActions;
};
export type StyleInspectorModel = {
  sharedStyles: InspectorSharedStyle[];
  actions: StyleInspectorActions;
};
export type ParameterInspectorModel = {
  parameters: InspectorParameter[];
  constraints: Constraint[];
  actions: ParameterInspectorActions;
};
export type PartInspectorModel = {
  selectedCount: number;
  parts: Part[];
  arrangementPartIds: Set<string>;
  partLibrary: PartLibraryEntry[];
  actions: PartInspectorActions;
};
export type InspectorViewModel = {
  shell: InspectorShellModel;
  selection: SelectionInspectorModel;
  layers: LayerInspectorModel;
  styles: StyleInspectorModel;
  parameters: ParameterInspectorModel;
  parts: PartInspectorModel;
};
