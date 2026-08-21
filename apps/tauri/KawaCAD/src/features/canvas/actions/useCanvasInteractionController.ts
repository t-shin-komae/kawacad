import type { Tool } from "@/features/canvas/domain/canvasDomainModels";

/** Named Canvas transitions exposed to the app shell. State remains in the Canvas feature. */
export type CanvasInteractionPresentation = {
  clearTransientCanvasState: () => void;
  resetCanvasPresentation: (next: { layers: Array<{ id: string }>; sharedStyles: Array<{ id: string }> }) => void;
  cancelCanvasInteraction: (external: CanvasCancellationExternal) => boolean;
};

export type CanvasCancellationExternal = {
  previewActive: { current: boolean };
  clearCanvasPreview: () => void;
  setMessage: (message: string) => void;
  selectTool: (tool: Tool) => void;
  rewindFilletDraft: () => void;
};

type CanvasInteractionControllerInput = {
  canvas: CanvasInteractionPresentation;
  previewActive: { current: boolean };
  clearCanvasPreview: () => void;
  setMessage: (message: string) => void;
  selectTool: (tool: Tool) => void;
  rewindFilletDraft: () => void;
};

/** Owns Canvas transition rules; cross-feature cancellation is composed by the app shell. */
export function useCanvasInteractionController(input: CanvasInteractionControllerInput) {
  const { canvas, clearCanvasPreview, setMessage, selectTool, rewindFilletDraft } = input;

  return {
    clearTransientCanvasState: () => {
      clearCanvasPreview();
      canvas.clearTransientCanvasState();
    },
    resetCanvasPresentation: (next: { layers: Array<{ id: string }>; sharedStyles: Array<{ id: string }> }) => {
      clearCanvasPreview();
      canvas.resetCanvasPresentation(next);
    },
    cancelCurrentInteraction: () =>
      canvas.cancelCanvasInteraction({
        previewActive: input.previewActive,
        clearCanvasPreview,
        setMessage,
        selectTool,
        rewindFilletDraft,
      }),
  };
}
