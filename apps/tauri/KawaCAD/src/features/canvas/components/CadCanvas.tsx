import { useEffect, useRef, useState } from "react";
import { type CanvasRenderModel, entityIsVisible } from "@/features/canvas/selectors/canvasRendering";
import { useCanvasRenderer } from "@/features/canvas/components/useCanvasRenderer";
import { canvasInteractionDescription } from "@/features/canvas/selectors/canvasAccessibility";
import { canvasCursorClass } from "@/features/canvas/selectors/canvasCursor";
import { ToolIcon } from "@/features/canvas/components/ToolIcon";
import { accessibilityIdentifiers } from "@/shared/accessibility/accessibilityIdentifiers";
import { appStrings } from "@/localization";
import {
  displayScale,
  modelPointInA4Grid,
  selectionInRect,
  constraintTargetEntityId,
  screenPoint,
  type PointMm,
} from "@/features/canvas/domain/cad";

export {
  angleArcCounterclockwise,
  coincidentGroupIsVisible,
  displayStyleFor,
  entityIsVisible,
  lineDashPattern,
  outputPreviewPageRects,
} from "@/features/canvas/selectors/canvasRendering";
export type { OutputPreviewPage } from "@/features/canvas/selectors/canvasRendering";

export type CanvasInteractionModel = {
  editingFreeText?: { id: string; content: string; positionMm: PointMm; fontSizeMm: number };
  settingPartOrigin?: boolean;
  filletDraftEntityCount?: number;
  filletDraftClosed?: boolean;
  pendingTargetCount: number;
  draftPointCount: number;
  dragDuplicating?: boolean;
  movingContent?: boolean;
  hasHoveredCanvasTarget?: boolean;
  snapSuppressed?: boolean;
  toolName: string;
};

export type CanvasEventHandlers = {
  onPointerDown: (event: React.PointerEvent<HTMLCanvasElement>, point: PointMm) => void;
  onPointerMove: (event: React.PointerEvent<HTMLCanvasElement>, point: PointMm) => void;
  onPointerLeave?: () => void;
  onPointerUp: (event: React.PointerEvent<HTMLCanvasElement>, point: PointMm) => void;
  onDoubleClick: (event: React.MouseEvent<HTMLCanvasElement>, point: PointMm) => void;
  onCommitFreeText: (id: string, content: string) => void;
  onCancelFreeText: () => void;
  onWheel: (event: React.WheelEvent<HTMLCanvasElement>) => void;
  onContextMenu: (event: React.MouseEvent<HTMLCanvasElement>, point: PointMm) => void;
};

export type CADCanvasProps = {
  renderModel: CanvasRenderModel;
  interactionModel: CanvasInteractionModel;
  events: CanvasEventHandlers;
};

export function CADCanvas({ renderModel, interactionModel, events }: CADCanvasProps) {
  const ref = useRef<HTMLCanvasElement>(null);
  const cancelledInlineEdit = useRef(false);
  const [editingContent, setEditingContent] = useState(interactionModel.editingFreeText?.content ?? "");
  const {
    viewport,
    a4Landscape,
    outputPreview,
    entities,
    layers,
    tool,
    selectedIds,
    draftPoints,
    marqueeStart,
    marqueeCurrent,
    dragging,
  } = renderModel;
  const {
    editingFreeText,
    settingPartOrigin = false,
    filletDraftEntityCount = 0,
    filletDraftClosed = false,
    pendingTargetCount,
    draftPointCount,
    dragDuplicating = false,
    movingContent = false,
    hasHoveredCanvasTarget = false,
    snapSuppressed = false,
    toolName,
  } = interactionModel;
  const {
    onContextMenu,
    onPointerDown,
    onPointerMove,
    onPointerLeave,
    onPointerUp,
    onDoubleClick,
    onCommitFreeText,
    onCancelFreeText,
    onWheel,
  } = events;
  useEffect(() => {
    cancelledInlineEdit.current = false;
    setEditingContent(editingFreeText?.content ?? "");
  }, [editingFreeText?.content, editingFreeText?.id]);
  useCanvasRenderer(ref, renderModel);
  const pointAt = (event: React.MouseEvent<HTMLCanvasElement>) => {
    const rect = event.currentTarget.getBoundingClientRect();
    return modelPointInA4Grid(
      { x: event.clientX - rect.left, y: event.clientY - rect.top },
      rect.width,
      rect.height,
      viewport,
      a4Landscape ? "landscape" : "portrait",
    );
  };
  const interactionDescription = canvasInteractionDescription({
    outputPreview,
    settingPartOrigin,
    filletDraftEntityCount,
    filletDraftClosed,
    draftPointCount: draftPoints.length,
    tool,
    pendingTargetCount,
    marqueeCandidateCount:
      marqueeStart && marqueeCurrent
        ? selectionInRect(
            entities.filter((entity) => entityIsVisible(entity, layers)),
            marqueeStart,
            marqueeCurrent,
            marqueeCurrent.xMm < marqueeStart.xMm,
          ).length
        : undefined,
    marqueeCrossing: marqueeStart && marqueeCurrent ? marqueeCurrent.xMm < marqueeStart.xMm : undefined,
    dragDuplicating,
    dragging,
    selectionCount: selectedIds.size,
    snapSuppressed,
  });
  const canvasRect = ref.current?.getBoundingClientRect();
  const inlineEditorPoint =
    editingFreeText && canvasRect
      ? screenPoint(editingFreeText.positionMm, canvasRect.width, canvasRect.height, viewport)
      : undefined;
  const cursorClass = canvasCursorClass({
    tool,
    outputPreview,
    hasTarget: hasHoveredCanvasTarget,
    editingFreeText: Boolean(editingFreeText),
    settingPartOrigin,
    movingContent,
  });
  const interactionInProgress =
    Boolean(marqueeStart && marqueeCurrent) ||
    dragging ||
    settingPartOrigin ||
    filletDraftEntityCount > 0 ||
    draftPointCount > 0 ||
    pendingTargetCount > 0 ||
    snapSuppressed;
  const showOperationGuide = !outputPreview && (tool !== "select" || interactionInProgress);
  const operationGuideMessage = interactionInProgress ? interactionDescription : appStrings.toolHints[tool];
  return (
    <>
      <canvas
        ref={ref}
        data-testid={accessibilityIdentifiers.workspaceCanvas}
        className={`cad-canvas ${cursorClass}`}
        tabIndex={0}
        role="application"
        aria-label={appStrings.canvas.ariaLabel}
        aria-describedby="cad-canvas-interaction-state"
        onContextMenu={(event) => {
          event.preventDefault();
          onContextMenu(event, pointAt(event));
        }}
        onPointerDown={(event) => onPointerDown(event, pointAt(event))}
        onPointerMove={(event) => onPointerMove(event, pointAt(event))}
        onPointerLeave={onPointerLeave}
        onPointerUp={(event) => onPointerUp(event, pointAt(event))}
        onDoubleClick={(event) => onDoubleClick(event, pointAt(event))}
        onWheel={onWheel}
      />
      {editingFreeText && inlineEditorPoint && (
        <input
          autoFocus
          className="canvas-inline-text-editor"
          aria-label={appStrings.canvas.editText}
          style={{
            left: inlineEditorPoint.x,
            top: inlineEditorPoint.y,
            fontSize: Math.max(9, editingFreeText.fontSizeMm * displayScale(viewport)),
          }}
          value={editingContent}
          onChange={(event) => setEditingContent(event.target.value)}
          onBlur={() => {
            if (!cancelledInlineEdit.current) onCommitFreeText(editingFreeText.id, editingContent);
          }}
          onKeyDown={(event) => {
            if (event.key === "Escape") {
              event.preventDefault();
              cancelledInlineEdit.current = true;
              onCancelFreeText();
            }
            if (event.key === "Enter") {
              event.preventDefault();
              event.currentTarget.blur();
            }
          }}
        />
      )}
      {showOperationGuide && (
        <div
          className="canvas-operation-guide"
          data-testid="canvas-operation-guide"
          aria-live="polite"
          aria-atomic="true"
        >
          <ToolIcon tool={tool} size={16} className="canvas-operation-guide-icon" />
          <strong>{toolName}</strong>
          <span>{operationGuideMessage}</span>
        </div>
      )}
      <span id="cad-canvas-interaction-state" className="visually-hidden">
        {appStrings.canvas.interactionSummary(
          toolName,
          outputPreview ? appStrings.canvas.outputPreview : appStrings.canvas.editDisplay,
          selectedIds.size,
          pendingTargetCount,
          interactionDescription,
        )}
      </span>
    </>
  );
}
