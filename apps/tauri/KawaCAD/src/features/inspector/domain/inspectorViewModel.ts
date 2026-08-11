import type { InspectorTab } from "@/features/inspector/selectors/inspectorFeature";
import type { PointMm, RawEntity } from "@/features/canvas/domain/cad";
import type { Constraint, DerivedElement, LineStyle, Part, PartLibraryEntry } from "@/shared/domain/coreWireTypes";

export type Measurement = { id: string; kind: string; visible: boolean };

/** Props exchanged between workspace composition and the inspector view. */
export type InspectorViewModel = {
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
  selectedFreeText?: { id: string; content: string; positionMm: PointMm; fontSizeMm: number };
  selectedConstraint?: Constraint;
  selectedMeasurement?: Measurement;
  selectedStitchStartPoint?: { id: string; targetEntityId: string };
  selectedStitchTargetEntity?: RawEntity;
  constraints: Constraint[];
  measurements: Measurement[];
  freeTexts: Array<{ id: string; content: string; positionMm: PointMm; fontSizeMm: number }>;
  parameters: Array<{
    id: string;
    name: string;
    valueMm: number;
    unit: string;
    memo: string;
    usageCount?: number;
    usedConstraintIds?: string[];
  }>;
  layers: Array<{ id: string; name: string; visible: boolean; printable: boolean; kind: string; style: LineStyle }>;
  activeLayerId: string;
  sharedStyles: Array<{ id: string; name: string; style: LineStyle }>;
  parts: Part[];
  arrangementPartIds: Set<string>;
  partLibrary: PartLibraryEntry[];
  roundHoles: Array<{ id: string; entityId: string; kind: string }>;
  onCommand: (kind: string, payload: unknown, success: string) => void;
  onApplyStyle: (styleId?: string) => void;
  onDeleteSelection: () => void;
  onCreatePart: () => void;
  onAddParameter: () => void;
  onAddLayer: () => void;
  onActiveLayerChange: (id: string) => void;
  onRenameLayer: (id: string, name: string) => void;
  onDeleteLayer: (layer: { id: string; name: string }) => void;
  onSelectPart: (part: Part) => void;
  onToggleArrangementPart: (id: string) => void;
  onAlignParts: (alignment: string) => void;
  onDistributeParts: (axis: string) => void;
  onAddPartToLibrary: (part: Part) => void;
  onInsertPartFromLibrary: (entry: PartLibraryEntry) => void;
  onRemovePartFromLibrary: (entry: PartLibraryEntry) => void;
  onBeginSetPartOrigin?: (part: Part) => void;
  onConstrainSegmentLength?: (entityId: string) => void;
  onSelectConstraint?: (id: string) => void;
  onSelectFreeText?: (id: string) => void;
  onSelectMeasurement?: (id: string) => void;
  onConvertMeasurement?: (id: string) => void;
  onTabChange?: (tab: InspectorTab) => void;
};
