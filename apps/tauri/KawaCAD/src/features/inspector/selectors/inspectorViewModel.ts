import { appStrings } from "@/localization";
import type { InspectorTab } from "@/features/inspector/selectors/inspectorFeature";
import type { State } from "@/shared/domain/coreWireTypes";
import type { PartLibraryEntry } from "@/shared/domain/coreWireTypes";
import type {
  InspectorViewModel,
  LayerInspectorActions,
  ParameterInspectorActions,
  PartInspectorActions,
  SelectionInspectorActions,
  StyleInspectorActions,
} from "@/features/inspector/domain/inspectorViewModel";

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
  shellActions: { onTabChange: (tab: InspectorTab) => void };
  selectionActions: SelectionInspectorActions;
  layerActions: LayerInspectorActions;
  styleActions: StyleInspectorActions;
  parameterActions: ParameterInspectorActions;
  partActions: PartInspectorActions;
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
  const layers = state?.layers ?? [];
  const sharedStyles = state?.sharedStyles ?? [];
  const parameters = state?.parameters ?? [];
  const constraints = state?.constraints ?? [];
  const selection = {
    selectedCount: selected.size,
    documentSummary: {
      viewMode: state?.viewMode === "outputPreview" ? appStrings.canvas.outputPreview : appStrings.canvas.editDisplay,
      activeLayerName: layers.find((layer) => layer.id === input.activeLayer)?.name ?? "—",
      visibleEntityCount: input.visibleEntityCount,
      constraintCount: constraints.length,
      parameterCount: parameters.length,
    },
    selectedEntityIds: [...selected],
    selectedEntity,
    selectedEntities: (state?.entities ?? []).filter((entity) => selected.has(entity.id)),
    selectedDerivedElement,
    selectedFreeText: state?.freeTexts.find((item) => item.id === input.selectedFreeTextId),
    selectedConstraint: constraints.find((item) => item.id === input.selectedConstraintId),
    selectedMeasurement: state?.measurementAnnotations.find((item) => item.id === input.selectedMeasurementId),
    selectedStitchStartPoint,
    selectedStitchTargetEntity: state?.entities.find(
      (entity) => entity.id === selectedStitchStartPoint?.targetEntityId,
    ),
    constraints,
    measurements: state?.measurementAnnotations ?? [],
    freeTexts: state?.freeTexts ?? [],
    parameters,
    layers,
    sharedStyles,
    roundHoles: state?.roundHoles ?? [],
    actions: input.selectionActions,
  };
  return {
    shell: input.shellActions,
    selection,
    layers: {
      layers,
      activeLayerId: input.activeLayer,
      actions: input.layerActions,
    },
    styles: { sharedStyles, actions: input.styleActions },
    parameters: {
      parameters,
      constraints,
      actions: input.parameterActions,
    },
    parts: {
      selectedCount: selected.size,
      parts: state?.parts ?? [],
      arrangementPartIds: input.arrangementPartIds,
      partLibrary: input.partLibrary,
      actions: input.partActions,
    },
  };
}

/** Applies the compact-workspace origin workflow without rebuilding unrelated Inspector tabs. */
export function compactInspectorViewModelFor(
  model: InspectorViewModel,
  beginSetOrigin: (part: InspectorViewModel["parts"]["parts"][number]) => void,
): InspectorViewModel {
  return {
    ...model,
    parts: {
      ...model.parts,
      actions: { ...model.parts.actions, beginSetOrigin },
    },
  };
}
