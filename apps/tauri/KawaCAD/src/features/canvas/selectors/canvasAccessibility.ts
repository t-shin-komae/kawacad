import { appStrings } from "@/localization";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";

type CanvasInteractionDescriptionInput = {
  outputPreview: boolean;
  settingPartOrigin: boolean;
  filletDraftEntityCount: number;
  filletDraftClosed: boolean;
  draftPointCount: number;
  tool: Tool;
  pendingTargetCount: number;
  marqueeCandidateCount?: number;
  marqueeCrossing?: boolean;
  dragDuplicating: boolean;
  dragging: boolean;
  selectionCount: number;
  snapSuppressed: boolean;
};

export function canvasInteractionDescription(input: CanvasInteractionDescriptionInput): string {
  if (input.outputPreview) return appStrings.canvas.outputPreview;
  if (input.marqueeCandidateCount !== undefined)
    return appStrings.status.marqueeFeedback(
      input.marqueeCrossing ? "crossing" : "contained",
      input.marqueeCandidateCount,
    );
  if (input.dragging)
    return input.dragDuplicating
      ? appStrings.canvas.dragCopy(input.selectionCount)
      : appStrings.canvas.dragMove(input.selectionCount);
  if (input.snapSuppressed) return appStrings.canvas.snapOff;
  if (input.settingPartOrigin) return appStrings.canvas.partOriginSelection;
  if (input.filletDraftEntityCount > 0)
    return appStrings.canvas.filletDraft(input.filletDraftEntityCount, input.filletDraftClosed);
  if (input.draftPointCount > 0 && input.tool === "arc") {
    return input.draftPointCount === 1 ? appStrings.canvas.arcStartSelection : appStrings.canvas.arcEndSelection;
  }
  if (input.pendingTargetCount > 0) return appStrings.canvas.constraintTargetSelection(input.pendingTargetCount);
  return input.draftPointCount > 0 ? appStrings.canvas.drawingNextPoint : appStrings.canvas.drawingWaiting;
}
