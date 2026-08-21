import { useCanvasActions } from "@/features/canvas/actions/useCanvasActions";
import { useDocumentActions } from "@/features/document/actions/useDocumentActions";
import { useInspectorActions } from "@/features/inspector/actions/useInspectorActions";
import { useOutputActions } from "@/features/output/actions/useOutputActions";
import { usePartActions } from "@/features/parts/actions/usePartActions";
import { useWorkspaceActions } from "@/features/workspace/actions/useWorkspaceActions";
export type AppActionSurface = ReturnType<typeof useAppActions>;
type CanvasCompositionInput = Omit<
  Parameters<typeof useCanvasActions>[1],
  "clearTransientCanvasState" | "setDocumentViewMode"
>;

/** Composition root for explicitly named feature action surfaces. */
export function useAppActions(
  documentContext: Parameters<typeof useDocumentActions>[0],
  canvasPresentation: Parameters<typeof useCanvasActions>[0],
  canvasContext: CanvasCompositionInput,
  inspectorContext: Parameters<typeof useInspectorActions>[0],
  outputContext: Parameters<typeof useOutputActions>[0],
  partContext: Parameters<typeof usePartActions>[0],
  workspaceContext: Parameters<typeof useWorkspaceActions>[0],
) {
  const inspectorActions = useInspectorActions(inspectorContext);
  const documentActions = useDocumentActions(documentContext, inspectorActions.resetInspectorPresentation);
  const outputActions = useOutputActions(outputContext, documentActions.clearTransientCanvasState);
  const canvasActions = useCanvasActions(canvasPresentation, {
    ...canvasContext,
    clearTransientCanvasState: documentActions.clearTransientCanvasState,
    setDocumentViewMode: outputActions.setDocumentViewMode,
  });
  const partActions = usePartActions(partContext, documentActions.openTextEntry);
  const workspaceActions = useWorkspaceActions(workspaceContext);

  return {
    document: documentActions,
    canvas: canvasActions,
    parts: partActions,
    output: outputActions,
    inspector: inspectorActions,
    workspace: workspaceActions,
  };
}
