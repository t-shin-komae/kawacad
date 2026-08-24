import { useCallback } from "react";
import type * as React from "react";
import { appStrings } from "@/localization";
import { type CanvasViewMode, type Tool } from "@/features/canvas/domain/canvasDomainModels";
import {
  hitConstraintMarker,
  hitEntity,
  hitFreeText,
  hitProjectedAnnotation,
  hitConstraintTarget,
  snapToEntityPoint,
  snapToGrid,
  type ConstraintTarget,
  type PointMm,
} from "@/features/canvas/domain/cad";
import { toolNames as names } from "@/features/canvas/domain/workspaceTools";
import { canvasMetrics } from "@/features/canvas/domain/canvasMetrics";
import { useCanvasPointerActionCallbacks } from "@/features/canvas/actions/useCanvasPointerActionCallbacks";
import { useCanvasPointActionCallbacks } from "@/features/canvas/actions/useCanvasPointActionCallbacks";
import { useConstraintActions } from "@/features/constraints/actions/useConstraintActions";
import type { CanvasProjection, State } from "@/shared/domain/coreWireTypes";
import type { CanvasPresentation } from "@/features/canvas/state/useCanvasPresentation";

type SetDocumentViewMode = (viewMode: CanvasViewMode, activeTool?: Tool) => void;

export type CanvasActionDependencies = {
  document: {
    state: State | undefined;
    command: (kind: string, payload: unknown, success: string) => Promise<State | undefined>;
    applyState: (next: State) => State;
    presentOperationFailure: (error: unknown, operation: string, commandKind?: string) => void;
    clearCanvasPreview: () => void;
    previewCommand: (command: unknown, success: string) => void;
    setMessage: (message: string) => void;
  };
  render: {
    snapEnabled: boolean;
    pointSnapEnabled: boolean;
    visibleEntities: import("@/features/canvas/domain/cad").RawEntity[];
    canvasProjection: CanvasProjection;
    measurementLabels: Record<string, string>;
    measurementLabelOffsets: Record<string, PointMm>;
    measurementArcCounterclockwise: Record<string, boolean>;
    dimensionLabels: Record<string, string>;
    dimensionLabelOffsets: Record<string, PointMm>;
    dimensionArcCounterclockwise: Record<string, boolean>;
  };
  externalSelection: {
    clearInspectorSelectedPart: () => void;
    clearPartOriginSelection: () => void;
    settingPartOriginId: string | undefined;
    inspectorSelectedPartId: string | undefined;
  };
  clearTransientCanvasState: () => void;
  setDocumentViewMode: SetDocumentViewMode;
};

/** Canvas actions compose selection, snapping, pointer input, and drawing. */
export function useCanvasActions(canvas: CanvasPresentation, dependencies: CanvasActionDependencies) {
  const {
    beginFreeTextEdit,
    tool,
    setTool,
    selected,
    setSelected,
    selectedFreeTextId,
    setSelectedFreeTextId,
    selectedConstraintId,
    setSelectedConstraintId,
    selectedMeasurementId,
    setSelectedMeasurementId,
    selectedStitchStartPointId,
    setSelectedStitchStartPointId,
    viewport,
    setViewport,
    cursorPoint,
    setCursorPoint,
    activeLayer,
    activeStyle,
    roundDiameter,
    roundKind,
    setContextMenu,
    setHoveredConstraintId,
    setSnapSuppressed,
    setSnapActive,
    setDragDuplicating,
    setMarqueeCurrent,
    setHoveredTargetEntityId,
    setHasHoveredCanvasTarget,
    pan,
    marquee,
    move,
    controlMove,
    measurementMove,
    dimensionMove,
    freeTextMove,
    pendingTargets,
    setPendingTargets,
    pendingConstraintValue,
    setPendingConstraintValue,
    pendingDerivedValue,
    setPendingDerivedValue,
    draft,
    setDraft,
    arcSweepAngle,
    lineStartSnap,
  } = canvas;
  const { document: documentInput, render: renderInput, externalSelection } = dependencies;
  const { command, applyState, presentOperationFailure, clearCanvasPreview, previewCommand, setMessage } =
    documentInput;
  const {
    snapEnabled,
    pointSnapEnabled,
    visibleEntities,
    canvasProjection,
    measurementLabels,
    measurementLabelOffsets,
    measurementArcCounterclockwise,
    dimensionLabels,
    dimensionLabelOffsets,
    dimensionArcCounterclockwise,
  } = renderInput;
  const { clearInspectorSelectedPart, clearPartOriginSelection, settingPartOriginId } = externalSelection;
  const state = documentInput.state;
  const { clearTransientCanvasState, setDocumentViewMode } = dependencies;

  const selectTool = useCallback(
    (next: Tool) => {
      clearCanvasPreview();
      setTool(next);
      setHasHoveredCanvasTarget(false);
      setHoveredTargetEntityId(undefined);
      setHoveredConstraintId(undefined);
      setDraft([]);
      setPendingTargets([]);
      setPendingConstraintValue(undefined);
      setPendingDerivedValue(undefined);
      lineStartSnap.current = undefined;
      arcSweepAngle.current = undefined;
      const message = next === "select" ? appStrings.app.selectGeometry : appStrings.app.clickTarget(names[next]);
      if (state?.viewMode === "outputPreview") setDocumentViewMode("editDisplay", next);
      else setMessage(message);
    },
    [
      arcSweepAngle,
      clearCanvasPreview,
      lineStartSnap,
      setDocumentViewMode,
      setDraft,
      setHasHoveredCanvasTarget,
      setHoveredConstraintId,
      setHoveredTargetEntityId,
      setMessage,
      setPendingConstraintValue,
      setPendingDerivedValue,
      setPendingTargets,
      setTool,
      state?.viewMode,
    ],
  );
  const snap = useCallback(
    (point: PointMm) => {
      const gridPoint = snapToGrid(point, snapEnabled);
      return pointSnapEnabled ? snapToEntityPoint(gridPoint, visibleEntities, viewport) : gridPoint;
    },
    [pointSnapEnabled, snapEnabled, viewport, visibleEntities],
  );
  const snapWithTarget = useCallback(
    (point: PointMm, enabled: boolean) => {
      if (!enabled) return { point, target: undefined };
      const snapped = snap(point);
      const target = pointSnapEnabled ? hitConstraintTarget(snapped, visibleEntities, viewport) : undefined;
      return { point: snapped, target: target && "controlPoint" in target ? target : undefined };
    },
    [pointSnapEnabled, snap, viewport, visibleEntities],
  );
  const addGesture = useCallback(
    (gesture: Record<string, unknown>, gestureConstraints: Record<string, unknown> = {}) =>
      command(
        "createEntityFromGesture",
        {
          id: `entity:${crypto.randomUUID()}`,
          layerId: activeLayer || null,
          styleId: activeStyle || null,
          gesture,
          ...gestureConstraints,
        },
        appStrings.app.entityCreated(names[tool]),
      ),
    [activeLayer, activeStyle, command, tool],
  );

  const constraintActions = useConstraintActions(
    {
      state,
      command,
      applyState,
      presentOperationFailure,
      setPendingConstraintValue,
      setPendingDerivedValue,
      setMessage,
      setSelected,
      activeLayer,
      activeStyle,
      selected,
      tool,
      pendingDerivedValue,
    },
    selectTool,
  );
  const pointerActions = useCanvasPointerActionCallbacks({
    state,
    tool,
    draft,
    canvasProjection,
    viewport,
    arcSweepAngle,
    move,
    controlMove,
    pan,
    marquee,
    setHoveredConstraintId,
    setSnapSuppressed,
    setSnapActive,
    setDragDuplicating,
    setMarqueeCurrent,
    setHoveredTargetEntityId,
    setHasHoveredCanvasTarget,
    setCursorPoint,
    previewCommand,
    clearCanvasPreview,
    setViewport,
    setMessage,
    visibleEntities,
    pendingTargets,
    measurementLabels,
    measurementLabelOffsets,
    measurementArcCounterclockwise,
    dimensionLabels,
    dimensionLabelOffsets,
    dimensionArcCounterclockwise,
    setSelected,
    command,
    measurementMove,
    dimensionMove,
    freeTextMove,
    snap,
  });
  const pointActions = useCanvasPointActionCallbacks({
    state,
    command,
    tool,
    selected,
    pendingTargets,
    pendingDerivedValue,
    visibleEntities,
    viewport,
    canvasProjection,
    measurementLabels,
    measurementLabelOffsets,
    measurementArcCounterclockwise,
    dimensionLabels,
    dimensionLabelOffsets,
    dimensionArcCounterclockwise,
    draft,
    cursorPoint,
    roundDiameter,
    roundKind,
    activeLayer,
    settingPartOriginId,
    clearPartOriginSelection,
    setSelected,
    setSelectedFreeTextId,
    setSelectedConstraintId,
    setSelectedMeasurementId,
    setSelectedStitchStartPointId,
    beginFreeTextEdit,
    clearInspectorSelectedPart,
    setMessage,
    setSnapSuppressed,
    setDragDuplicating,
    setPendingTargets,
    setPendingDerivedValue,
    setDraft,
    setCursorPoint,
    lineStartSnap,
    arcSweepAngle,
    pan,
    measurementMove,
    dimensionMove,
    freeTextMove,
    controlMove,
    move,
    marquee,
    clearCanvasPreview,
    activeStyleId: activeStyle || null,
    snapWithTarget,
    addGesture,
    ...constraintActions,
  });
  const handleCanvasDoubleClick = useCallback(
    (_event: React.MouseEvent<HTMLCanvasElement>, point: PointMm) => {
      const freeTextId = hitFreeText(point, state?.freeTexts ?? []);
      if (!freeTextId) return;
      setSelected(new Set());
      setSelectedFreeTextId(freeTextId);
      setSelectedConstraintId(undefined);
      setSelectedMeasurementId(undefined);
      setSelectedStitchStartPointId(undefined);
      clearInspectorSelectedPart();
      beginFreeTextEdit(freeTextId);
    },
    [
      beginFreeTextEdit,
      clearInspectorSelectedPart,
      setSelected,
      setSelectedConstraintId,
      setSelectedFreeTextId,
      setSelectedMeasurementId,
      setSelectedStitchStartPointId,
      state?.freeTexts,
    ],
  );
  const handleCanvasWheel = useCallback(
    (event: React.WheelEvent<HTMLCanvasElement>) => {
      event.preventDefault();
      const factor = event.deltaY < 0 ? canvasMetrics.zoomWheelFactor : 1 / canvasMetrics.zoomWheelFactor;
      setViewport((value) => ({
        ...value,
        zoom: Math.max(canvasMetrics.zoomMinimum, Math.min(canvasMetrics.zoomMaximum, value.zoom * factor)),
      }));
    },
    [setViewport],
  );
  const handleCanvasContextMenu = useCallback(
    (event: React.MouseEvent<HTMLCanvasElement>, point: PointMm) => {
      if (state?.viewMode === "outputPreview") return;
      const clearSelection = () => {
        setSelected(new Set());
        setSelectedFreeTextId(undefined);
        setSelectedConstraintId(undefined);
        setSelectedMeasurementId(undefined);
        setSelectedStitchStartPointId(undefined);
        clearInspectorSelectedPart();
      };
      const position = (selectionKind: "measurement" | "constraint" | "freeText" | "entity" | "none") => ({
        x: event.nativeEvent.offsetX,
        y: event.nativeEvent.offsetY,
        point,
        selectionKind,
      });
      const measurementId = hitProjectedAnnotation(
        point,
        canvasProjection.measurementAnnotations.map((item) => ({
          ...item,
          arcCounterclockwise: measurementArcCounterclockwise[item.id],
        })),
        viewport,
      );
      if (measurementId) {
        clearSelection();
        setSelectedMeasurementId(measurementId);
        setContextMenu(position("measurement"));
        return;
      }
      const dimensionConstraintId = hitProjectedAnnotation(
        point,
        canvasProjection.dimensionConstraints.map((item) => ({
          ...item,
          arcCounterclockwise: dimensionArcCounterclockwise[item.id],
        })),
        viewport,
      );
      const constraintId =
        dimensionConstraintId ?? hitConstraintMarker(point, canvasProjection.constraintMarkers, viewport);
      if (constraintId) {
        clearSelection();
        setSelectedConstraintId(constraintId);
        setContextMenu(position("constraint"));
        return;
      }
      const freeTextId = hitFreeText(point, state?.freeTexts ?? []);
      if (freeTextId) {
        clearSelection();
        setSelectedFreeTextId(freeTextId);
        setContextMenu(position("freeText"));
        return;
      }
      const hit = hitEntity(point, visibleEntities, viewport);
      if (hit) {
        clearSelection();
        setSelected(new Set([hit]));
        setSelectedFreeTextId(undefined);
        setContextMenu(position("entity"));
        return;
      }
      setContextMenu(position("none"));
    },
    [
      canvasProjection.constraintMarkers,
      canvasProjection.dimensionConstraints,
      canvasProjection.measurementAnnotations,
      viewport,
      dimensionArcCounterclockwise,
      measurementArcCounterclockwise,
      setContextMenu,
      clearInspectorSelectedPart,
      setSelected,
      setSelectedConstraintId,
      setSelectedFreeTextId,
      setSelectedMeasurementId,
      setSelectedStitchStartPointId,
      state?.freeTexts,
      state?.viewMode,
      visibleEntities,
    ],
  );

  return {
    clearTransientCanvasState,
    selectTool,
    snap,
    snapWithTarget,
    addGesture,
    ...constraintActions,
    ...pointActions,
    ...pointerActions,
    handleCanvasDoubleClick,
    handleCanvasWheel,
    handleCanvasContextMenu,
  };
}
