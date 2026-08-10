import { useEffect, useRef, useState } from "react";
import {
  drawCanvasFrame,
  type DisplayStyle,
  type OutputPreviewPage,
  type ResolvedCanvasGeometry,
} from "@/features/canvas/selectors/canvasRendering";
import { canvasInteractionDescription } from "@/features/canvas/selectors/canvasAccessibility";
import { accessibilityIdentifiers } from "@/shared/accessibility/accessibilityIdentifiers";
import { appStrings } from "@/localization";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
import {
  displayScale,
  modelPointInA4Grid,
  selectionInRect,
  constraintTargetEntityId,
  screenPoint,
  type PointMm,
  type RawEntity,
  type Viewport,
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

type Props = {
  entities: RawEntity[];
  layers: Array<{ id: string; style: DisplayStyle; visible?: boolean }>;
  sharedStyles: Array<{ id: string; style: DisplayStyle }>;
  freeTexts: Array<{ id: string; content: string; positionMm: PointMm; fontSizeMm: number }>;
  editingFreeText?: { id: string; content: string; positionMm: PointMm; fontSizeMm: number };
  highlightedFreeTextIds?: Set<string>;
  highlightedMeasurementAnnotationIds?: Set<string>;
  highlightedStitchStartPointIds?: Set<string>;
  selectedIds: Set<string>;
  selectedMeasurementAnnotationId?: string;
  selectedStitchStartPointId?: string;
  viewport: Viewport;
  gridVisible: boolean;
  a4Visible: boolean;
  a4Landscape: boolean;
  outputPreview: boolean;
  outputPages: OutputPreviewPage[];
  pendingTargetCount: number;
  filletDraftEntityCount?: number;
  filletDraftClosed?: boolean;
  settingPartOrigin?: boolean;
  selectedPartOrigin?: PointMm;
  draftPoints: PointMm[];
  cursorPoint?: PointMm;
  arcSweepAngleRad?: number;
  hoveredConstraintId?: string;
  pendingTargetEntityIds?: Set<string>;
  marqueeStart?: PointMm;
  marqueeCurrent?: PointMm;
  dragDuplicating?: boolean;
  dragging?: boolean;
  snapEnabled?: boolean;
  pointSnapEnabled?: boolean;
  snapSuppressed?: boolean;
  coincidentPointGroups?: Array<{ id: string; representative: PointMm; targets: unknown[] }>;
  tool: Tool;
  toolName: string;
  projection: {
    stitchStartPoints: Array<{ id: string; positionMm: PointMm; visible: boolean }>;
    measurementAnnotations: ResolvedCanvasGeometry[];
    dimensionConstraints: ResolvedCanvasGeometry[];
    constraintMarkers: Array<{
      id: string;
      positionMm: PointMm;
      visible: boolean;
      label?: string;
      icon?: string;
      stackIndex?: number;
    }>;
  };
  measurementLabels: Record<string, string>;
  measurementLabelOffsets: Record<string, PointMm>;
  measurementArcCounterclockwise?: Record<string, boolean>;
  dimensionLabels: Record<string, string>;
  dimensionLabelOffsets: Record<string, PointMm>;
  dimensionArcCounterclockwise?: Record<string, boolean>;
  onPointerDown: (event: React.PointerEvent<HTMLCanvasElement>, point: PointMm) => void;
  onPointerMove: (event: React.PointerEvent<HTMLCanvasElement>, point: PointMm) => void;
  onPointerUp: (event: React.PointerEvent<HTMLCanvasElement>, point: PointMm) => void;
  onDoubleClick: (event: React.MouseEvent<HTMLCanvasElement>, point: PointMm) => void;
  onCommitFreeText: (id: string, content: string) => void;
  onCancelFreeText: () => void;
  onWheel: (event: React.WheelEvent<HTMLCanvasElement>) => void;
  onContextMenu: (event: React.MouseEvent<HTMLCanvasElement>, point: PointMm) => void;
};

export function CadCanvas({
  entities,
  layers,
  sharedStyles,
  freeTexts,
  editingFreeText,
  highlightedFreeTextIds = new Set(),
  highlightedMeasurementAnnotationIds = new Set(),
  highlightedStitchStartPointIds = new Set(),
  selectedIds,
  selectedMeasurementAnnotationId,
  selectedStitchStartPointId,
  viewport,
  gridVisible,
  a4Visible,
  a4Landscape,
  outputPreview,
  outputPages,
  pendingTargetCount,
  filletDraftEntityCount = 0,
  filletDraftClosed = false,
  settingPartOrigin = false,
  selectedPartOrigin,
  draftPoints,
  cursorPoint,
  arcSweepAngleRad,
  hoveredConstraintId,
  pendingTargetEntityIds = new Set(),
  marqueeStart,
  marqueeCurrent,
  dragDuplicating = false,
  dragging = false,
  snapEnabled = false,
  pointSnapEnabled = false,
  snapSuppressed = false,
  coincidentPointGroups = [],
  tool,
  toolName,
  projection,
  measurementLabels,
  measurementLabelOffsets,
  measurementArcCounterclockwise = {},
  dimensionLabels,
  dimensionLabelOffsets,
  dimensionArcCounterclockwise = {},
  onPointerDown,
  onPointerMove,
  onPointerUp,
  onDoubleClick,
  onCommitFreeText,
  onCancelFreeText,
  onWheel,
  onContextMenu,
}: Props) {
  const ref = useRef<HTMLCanvasElement>(null);
  const cancelledInlineEdit = useRef(false);
  const [editingContent, setEditingContent] = useState(editingFreeText?.content ?? "");
  useEffect(() => {
    cancelledInlineEdit.current = false;
    setEditingContent(editingFreeText?.content ?? "");
  }, [editingFreeText?.content, editingFreeText?.id]);
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const draw = () => {
      const rect = canvas.getBoundingClientRect(),
        pixelRatio = window.devicePixelRatio || 1;
      canvas.width = Math.max(1, Math.round(rect.width * pixelRatio));
      canvas.height = Math.max(1, Math.round(rect.height * pixelRatio));
      const context = canvas.getContext("2d");
      if (!context) return;
      context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
      context.clearRect(0, 0, rect.width, rect.height);
      drawCanvasFrame({
        context,
        width: rect.width,
        height: rect.height,
        viewport,
        outputPreview,
        gridVisible,
        a4Visible,
        a4Landscape,
        outputPages,
        entities,
        layers,
        sharedStyles,
        selectedIds,
        freeTexts,
        editingFreeTextId: editingFreeText?.id,
        highlightedFreeTextIds,
        highlightedMeasurementAnnotationIds,
        highlightedStitchStartPointIds,
        projection,
        selectedMeasurementAnnotationId,
        selectedStitchStartPointId,
        measurementLabels,
        measurementLabelOffsets,
        measurementArcCounterclockwise,
        dimensionLabels,
        dimensionLabelOffsets,
        dimensionArcCounterclockwise,
        selectedPartOrigin,
        coincidentPointGroups,
        tool,
        draftPoints,
        cursorPoint,
        arcSweepAngleRad,
        hoveredConstraintId,
        pendingTargetEntityIds,
        marqueeStart,
        marqueeCurrent,
        dragDuplicating,
        dragging,
        snapEnabled,
        pointSnapEnabled,
        snapSuppressed,
      });
    };
    draw();
    const observer = new ResizeObserver(draw);
    observer.observe(canvas);
    return () => observer.disconnect();
  }, [
    a4Landscape,
    arcSweepAngleRad,
    a4Visible,
    cursorPoint,
    coincidentPointGroups,
    dimensionLabels,
    dimensionArcCounterclockwise,
    editingFreeText?.id,
    draftPoints,
    entities,
    freeTexts,
    highlightedFreeTextIds,
    highlightedMeasurementAnnotationIds,
    highlightedStitchStartPointIds,
    hoveredConstraintId,
    marqueeCurrent,
    marqueeStart,
    dragDuplicating,
    dragging,
    pendingTargetEntityIds,
    snapEnabled,
    pointSnapEnabled,
    snapSuppressed,
    gridVisible,
    layers,
    measurementLabels,
    outputPreview,
    measurementArcCounterclockwise,
    outputPages,
    projection,
    selectedIds,
    selectedMeasurementAnnotationId,
    selectedPartOrigin,
    selectedStitchStartPointId,
    sharedStyles,
    tool,
    viewport,
  ]);
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
        ? selectionInRect(entities, marqueeStart, marqueeCurrent, marqueeCurrent.xMm < marqueeStart.xMm).length
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
  return (
    <>
      <canvas
        ref={ref}
        data-testid={accessibilityIdentifiers.workspaceCanvas}
        className="cad-canvas"
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
