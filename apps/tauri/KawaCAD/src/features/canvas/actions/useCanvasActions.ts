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
import type { PendingTextEntry } from "@/features/canvas/state/useCanvasPresentation";
import type { TextEntryField } from "@/shared/components/TextEntryDialog";
import { toolNames as names } from "@/features/canvas/domain/workspaceTools";
import { useCanvasPointerActionCallbacks } from "@/features/canvas/actions/useCanvasPointerActionCallbacks";
import { useCanvasPointActionCallbacks } from "@/features/canvas/actions/useCanvasPointActionCallbacks";
import { useConstraintActions } from "@/features/constraints/actions/useConstraintActions";
import type { CanvasActionContext } from "@/app/actions/useActionRuntime";

type OpenTextEntry = (title: string, fields: TextEntryField[], onConfirm: PendingTextEntry["onConfirm"]) => void;
type SetDocumentViewMode = (viewMode: CanvasViewMode, activeTool?: Tool) => void;

type CanvasActionDependencies = {
  clearTransientCanvasState: () => void;
  openTextEntry: OpenTextEntry;
  setDocumentViewMode: SetDocumentViewMode;
};

/** Canvas actions compose selection, snapping, pointer input, and drawing. */
export function useCanvasActions(context: CanvasActionContext, dependencies: CanvasActionDependencies) {
  const {
    state,
    clearCanvasPreview,
    tool,
    setViewport,
    cursorPoint,
    setSelected,
    setHoveredConstraintId,
    setPendingTargets,
    setPendingConstraintValue,
    setPendingDerivedValue,
    setDraft,
    setCursorPoint,
    setContextMenu,
    setSelectedFreeTextId,
    setSelectedConstraintId,
    setSelectedMeasurementId,
    setSelectedStitchStartPointId,
    setEditingFreeTextId,
    setInspectorSelectedPartId,
    setTool,
    setMessage,
    activeLayer,
    activeStyle,
    snapEnabled,
    pointSnapEnabled,
    visibleEntities,
    selected,
    pendingTargets,
    pendingDerivedValue,
    roundDiameter,
    roundKind,
    canvasProjection,
    measurementLabels,
    measurementLabelOffsets,
    dimensionLabels,
    dimensionLabelOffsets,
    settingPartOriginId,
    pan,
    marquee,
    move,
    controlMove,
    measurementMove,
    dimensionMove,
    freeTextMove,
    arcSweepAngle,
    lineStartSnap,
    draft,
  } = context;
  const { clearTransientCanvasState, openTextEntry, setDocumentViewMode } = dependencies;

  const selectTool = useCallback(
    (next: Tool) => {
      clearCanvasPreview();
      setTool(next);
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
      return pointSnapEnabled ? snapToEntityPoint(gridPoint, visibleEntities, context.viewport) : gridPoint;
    },
    [context.viewport, pointSnapEnabled, snapEnabled, visibleEntities],
  );
  const snapWithTarget = useCallback(
    (point: PointMm, enabled: boolean) => {
      if (!enabled) return { point, target: undefined };
      const snapped = snap(point);
      const target = pointSnapEnabled ? hitConstraintTarget(snapped, visibleEntities, context.viewport) : undefined;
      return { point: snapped, target: target && "controlPoint" in target ? target : undefined };
    },
    [context.viewport, pointSnapEnabled, snap, visibleEntities],
  );
  const addGesture = useCallback(
    (gesture: Record<string, unknown>, gestureConstraints: Record<string, unknown> = {}) =>
      context.command(
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
    [activeLayer, activeStyle, context.command, tool],
  );

  const constraintActions = useConstraintActions(context, selectTool);
  const pointerActions = useCanvasPointerActionCallbacks({ ...context, snap });
  const pointActions = useCanvasPointActionCallbacks({
    ...context,
    activeStyleId: activeStyle || null,
    snapWithTarget,
    addGesture,
    ...constraintActions,
    openTextEntry,
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
      setInspectorSelectedPartId(undefined);
      setEditingFreeTextId(freeTextId);
    },
    [
      setEditingFreeTextId,
      setInspectorSelectedPartId,
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
      const factor = event.deltaY < 0 ? 1.12 : 1 / 1.12;
      setViewport((value) => ({ ...value, zoom: Math.max(0.5, Math.min(3, value.zoom * factor)) }));
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
        setInspectorSelectedPartId(undefined);
      };
      const position = (selectionKind: "measurement" | "constraint" | "freeText" | "entity" | "none") => ({
        x: event.nativeEvent.offsetX,
        y: event.nativeEvent.offsetY,
        point,
        selectionKind,
      });
      const measurementId = hitProjectedAnnotation(point, canvasProjection.measurementAnnotations, context.viewport);
      if (measurementId) {
        clearSelection();
        setSelectedMeasurementId(measurementId);
        setContextMenu(position("measurement"));
        return;
      }
      const dimensionConstraintId = hitProjectedAnnotation(
        point,
        canvasProjection.dimensionConstraints,
        context.viewport,
      );
      const constraintId =
        dimensionConstraintId ?? hitConstraintMarker(point, canvasProjection.constraintMarkers, context.viewport);
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
      const hit = hitEntity(point, visibleEntities, context.viewport);
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
      context.viewport,
      setContextMenu,
      setInspectorSelectedPartId,
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
