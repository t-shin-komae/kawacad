import { useCallback } from "react";
import type { State } from "@/shared/domain/coreWireTypes";

type DocumentLifecycleCompositionInput = {
  resetCanvasPresentation: (next: { layers: State["layers"]; sharedStyles: State["sharedStyles"] }) => void;
  clearTransientCanvasState: () => void;
  clearInspectorSelection: () => void;
  clearPartOriginSelection: () => void;
  closeWorkspacePanels: () => void;
};

/** Composes the feature resets required after document lifecycle transitions. */
export function useDocumentLifecycleComposition(input: DocumentLifecycleCompositionInput) {
  const {
    resetCanvasPresentation,
    clearTransientCanvasState,
    clearInspectorSelection,
    clearPartOriginSelection,
    closeWorkspacePanels,
  } = input;
  const onDocumentLoaded = useCallback(
    (next: State) => {
      resetCanvasPresentation({ layers: next.layers, sharedStyles: next.sharedStyles });
      clearInspectorSelection();
      clearPartOriginSelection();
      closeWorkspacePanels();
    },
    [clearInspectorSelection, clearPartOriginSelection, closeWorkspacePanels, resetCanvasPresentation],
  );

  return { onDocumentLoaded, onHistoryRestored: clearTransientCanvasState };
}
