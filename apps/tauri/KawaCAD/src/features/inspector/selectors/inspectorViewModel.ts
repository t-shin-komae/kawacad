import { appStrings } from "@/localization";
import type { State } from "@/shared/domain/coreWireTypes";
import type { PartLibraryEntry } from "@/shared/domain/coreWireTypes";
import type { InspectorViewModel } from "@/features/inspector/domain/inspectorViewModel";

type CallbackKey =
  | "onCommand"
  | "onApplyStyle"
  | "onDeleteSelection"
  | "onCreatePart"
  | "onAddParameter"
  | "onAddLayer"
  | "onActiveLayerChange"
  | "onRenameLayer"
  | "onDeleteLayer"
  | "onSelectPart"
  | "onToggleArrangementPart"
  | "onAlignParts"
  | "onDistributeParts"
  | "onAddPartToLibrary"
  | "onInsertPartFromLibrary"
  | "onRemovePartFromLibrary"
  | "onConstrainSegmentLength"
  | "onSelectConstraint"
  | "onSelectFreeText"
  | "onSelectMeasurement"
  | "onConvertMeasurement"
  | "onBeginSetPartOrigin"
  | "onTabChange";

export type InspectorViewModelInput = {
  state: State | undefined;
  selected: Set<string>;
  activeLayer: string;
  visibleEntityCount: number;
  arrangementPartIds: Set<string>;
  partLibrary: PartLibraryEntry[];
  inspectorSelectedPartId?: string;
  settingPartOriginId?: string;
  selectedFreeTextId?: string;
  selectedConstraintId?: string;
  selectedMeasurementId?: string;
  selectedStitchStartPointId?: string;
  callbacks: Pick<InspectorViewModel, CallbackKey>;
};

export function inspectorViewModelFor(input: InspectorViewModelInput): InspectorViewModel {
  const { state, selected } = input;
  const selectedEntity = selected.size === 1 ? state?.entities.find((entity) => selected.has(entity.id)) : undefined;
  const selectedDerivedElement = selectedEntity
    ? state?.derivedElements.find(
        (element) =>
          element.id ===
          state?.drawingEntityMetadata.find((item) => item.entityId === selectedEntity.id)?.derivedElementId,
      )
    : undefined;
  const selectedStitchStartPoint = state?.stitchStartPoints.find(
    (item) => item.id === input.selectedStitchStartPointId,
  );
  return {
    selectedCount: selected.size,
    documentSummary: {
      viewMode: state?.viewMode === "outputPreview" ? appStrings.canvas.outputPreview : appStrings.canvas.editDisplay,
      activeLayerName: state?.layers.find((layer) => layer.id === input.activeLayer)?.name ?? "—",
      visibleEntityCount: input.visibleEntityCount,
      constraintCount: state?.constraints.length ?? 0,
      parameterCount: state?.parameters.length ?? 0,
    },
    selectedEntityIds: [...selected],
    selectedEntity,
    selectedEntities: (state?.entities ?? []).filter((entity) => selected.has(entity.id)),
    selectedDerivedElement,
    selectedFreeText: state?.freeTexts.find((item) => item.id === input.selectedFreeTextId),
    selectedConstraint: state?.constraints.find((item) => item.id === input.selectedConstraintId),
    selectedMeasurement: state?.measurementAnnotations.find((item) => item.id === input.selectedMeasurementId),
    selectedStitchStartPoint,
    selectedStitchTargetEntity: state?.entities.find(
      (entity) => entity.id === selectedStitchStartPoint?.targetEntityId,
    ),
    constraints: state?.constraints ?? [],
    measurements: state?.measurementAnnotations ?? [],
    freeTexts: state?.freeTexts ?? [],
    parameters: state?.parameters ?? [],
    layers: state?.layers ?? [],
    activeLayerId: input.activeLayer,
    sharedStyles: state?.sharedStyles ?? [],
    parts: state?.parts ?? [],
    arrangementPartIds: input.arrangementPartIds,
    partLibrary: input.partLibrary,
    roundHoles: state?.roundHoles ?? [],
    ...input.callbacks,
  };
}
