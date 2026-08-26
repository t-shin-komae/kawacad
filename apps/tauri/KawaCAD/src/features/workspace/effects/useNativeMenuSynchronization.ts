import { useEffect } from "react";
import { updateNativeMenuState } from "@/adapters/nativeMenuAdapter";
import { selectedSourceArcId } from "@/features/canvas/selectors/canvasProjection";
import type { InspectorTab } from "@/features/inspector/selectors/inspectorFeature";
import type { State } from "@/shared/domain/coreWireTypes";

type Props = {
  state: State | undefined;
  selected: Set<string>;
  selectedFreeTextId?: string;
  selectedConstraintId?: string;
  selectedMeasurementId?: string;
  selectedStitchStartPointId?: string;
  clipboardAvailable: boolean;
  inspectorOpen: boolean;
  compactDrawer: "tools" | "inspector" | undefined;
  layoutMode: "compact" | "regular" | "wide";
  toolPaletteVisible: boolean;
  inspectorTab: InspectorTab;
  bottomWorkbenchVisible: boolean;
};

/** Keeps native menu enablement derived from feature state in one place. */
export function useNativeMenuSynchronization({
  state,
  selected,
  selectedFreeTextId,
  selectedConstraintId,
  selectedMeasurementId,
  selectedStitchStartPointId,
  clipboardAvailable,
  inspectorOpen,
  compactDrawer,
  layoutMode,
  toolPaletteVisible,
  inspectorTab,
  bottomWorkbenchVisible,
}: Props) {
  useEffect(() => {
    updateNativeMenuState({
      hasDocument: Boolean(state),
      viewMode: state?.viewMode ?? "editDisplay",
      canUndo: Boolean(state?.history.canUndo),
      canRedo: Boolean(state?.history.canRedo),
      hasSelection:
        selected.size > 0 ||
        Boolean(selectedFreeTextId || selectedConstraintId || selectedMeasurementId || selectedStitchStartPointId),
      canPaste: clipboardAvailable,
      canEditLayers: Boolean(state?.layers.length),
      canExportPDF: Boolean(state),
      canDirectPrint: Boolean(state),
      canSmoothArcTangencies: Boolean(
        state && selectedSourceArcId(selected, state.entities, state.drawingEntityMetadata ?? []),
      ),
      inspectorOpen: layoutMode === "compact" ? compactDrawer === "inspector" : inspectorOpen,
      toolPaletteVisible: layoutMode === "compact" ? compactDrawer === "tools" : toolPaletteVisible,
      inspectorTab,
      bottomWorkbenchVisible,
    });
  }, [
    bottomWorkbenchVisible,
    clipboardAvailable,
    compactDrawer,
    inspectorOpen,
    inspectorTab,
    layoutMode,
    toolPaletteVisible,
    selected,
    selectedConstraintId,
    selectedFreeTextId,
    selectedMeasurementId,
    selectedStitchStartPointId,
    state,
  ]);
}
