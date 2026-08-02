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
};

export function canvasInteractionDescription(input: CanvasInteractionDescriptionInput): string {
  if (input.outputPreview) return appStrings.canvas.outputPreview;
  if (input.settingPartOrigin) return appStrings.canvas.partOriginSelection;
  if (input.filletDraftEntityCount > 0)
    return appStrings.canvas.filletDraft(input.filletDraftEntityCount, input.filletDraftClosed);
  if (input.draftPointCount > 0 && input.tool === "arc") {
    return input.draftPointCount === 1 ? appStrings.canvas.arcStartSelection : appStrings.canvas.arcEndSelection;
  }
  if (input.pendingTargetCount > 0) return appStrings.canvas.constraintTargetSelection(input.pendingTargetCount);
  return input.draftPointCount > 0 ? appStrings.canvas.drawingNextPoint : appStrings.canvas.drawingWaiting;
}
