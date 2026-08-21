import { useCallback } from "react";

type GlobalInteractionCancellationInput = {
  cancelCanvasInteraction: () => boolean;
  layerDeletionConfirmationOpen: boolean;
  dismissLayerDeletionConfirmation: () => void;
  compactDrawerOpen: boolean;
  closeCompactDrawer: () => void;
  partOriginSelectionActive: boolean;
  clearPartOriginSelection: () => void;
  inspectorPartSelectionActive: boolean;
  clearInspectorPartSelection: () => void;
  announceInspectorPartSelectionCleared: () => void;
};

/** Owns the Escape priority shared by Canvas, document dialogs, and workspace panels. */
export function useGlobalInteractionCancellation(input: GlobalInteractionCancellationInput) {
  const {
    cancelCanvasInteraction,
    layerDeletionConfirmationOpen,
    dismissLayerDeletionConfirmation,
    compactDrawerOpen,
    closeCompactDrawer,
    partOriginSelectionActive,
    clearPartOriginSelection,
    inspectorPartSelectionActive,
    clearInspectorPartSelection,
    announceInspectorPartSelectionCleared,
  } = input;
  return useCallback(() => {
    if (cancelCanvasInteraction()) return;
    if (layerDeletionConfirmationOpen) {
      dismissLayerDeletionConfirmation();
      return;
    }
    if (compactDrawerOpen) {
      closeCompactDrawer();
      return;
    }
    if (partOriginSelectionActive) {
      clearPartOriginSelection();
      return;
    }
    if (inspectorPartSelectionActive) {
      clearInspectorPartSelection();
      announceInspectorPartSelectionCleared();
    }
  }, [
    announceInspectorPartSelectionCleared,
    cancelCanvasInteraction,
    clearInspectorPartSelection,
    clearPartOriginSelection,
    closeCompactDrawer,
    compactDrawerOpen,
    dismissLayerDeletionConfirmation,
    inspectorPartSelectionActive,
    layerDeletionConfirmationOpen,
    partOriginSelectionActive,
  ]);
}
