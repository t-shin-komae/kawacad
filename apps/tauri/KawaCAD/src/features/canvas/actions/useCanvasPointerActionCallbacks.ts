import { useCallback } from "react";
import type * as React from "react";
import { appStrings } from "@/localization";
import {
  arcPlacementEndPoint,
  allowsDerivedTarget,
  constraintTargetEntityId,
  controlPointEntityId,
  coreConstraintTarget,
  hitConstraintMarker,
  preferredConstraintTarget,
  selectionInRect,
  type ConstraintTarget,
  type PointMm,
  type Viewport,
} from "@/features/canvas/domain/cad";
import type { CanvasActionContext } from "@/app/actions/useActionRuntime";
import { constraintTools, measurementKinds } from "@/features/canvas/domain/workspaceTools";

type CanvasPointerActionDependencies = CanvasActionContext & {
  snap: (point: PointMm) => PointMm;
};

export function useCanvasPointerActionCallbacks(dependencies: CanvasPointerActionDependencies) {
  const {
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
    setCursorPoint,
    previewCommand,
    clearCanvasPreview,
    setViewport,
    setMessage,
    visibleEntities,
    pendingTargets,
    setSelected,
    command,
    measurementMove,
    dimensionMove,
    freeTextMove,
    snap,
  } = dependencies;

  const canvasMove = useCallback(
    (event: React.PointerEvent<HTMLCanvasElement>, point: PointMm) => {
      setSnapSuppressed(event.ctrlKey);
      if (move.current) setDragDuplicating(event.altKey);
      const snappedPoint = event.ctrlKey ? point : snap(point);
      setSnapActive(
        !event.ctrlKey &&
          !marquee.current &&
          (Math.abs(snappedPoint.xMm - point.xMm) > 0.0001 || Math.abs(snappedPoint.yMm - point.yMm) > 0.0001),
      );
      if (marquee.current) setMarqueeCurrent(point);
      const canPickTarget =
        state?.viewMode !== "outputPreview" && (constraintTools.has(tool) || Boolean(measurementKinds[tool]));
      const hoveredTarget = canPickTarget
        ? preferredConstraintTarget(point, visibleEntities, viewport, tool, pendingTargets)
        : undefined;
      const hoveredTargetEntity = hoveredTarget
        ? visibleEntities.find((entity) => entity.id === constraintTargetEntityId(hoveredTarget))
        : undefined;
      setHoveredTargetEntityId(
        hoveredTarget && allowsDerivedTarget(tool, hoveredTargetEntity) ? hoveredTargetEntity?.id : undefined,
      );
      setHoveredConstraintId(
        state?.viewMode === "outputPreview" || tool !== "select"
          ? undefined
          : hitConstraintMarker(point, canvasProjection.constraintMarkers, viewport),
      );
      if (tool === "arc" && draft.length === 2) {
        const placement = arcPlacementEndPoint(draft[0], draft[1], snappedPoint, arcSweepAngle.current, event.shiftKey);
        if (placement) {
          arcSweepAngle.current = placement.sweepAngleRad;
          setCursorPoint(placement.point);
        } else setCursorPoint(snappedPoint);
      } else {
        if (tool === "arc") arcSweepAngle.current = undefined;
        setCursorPoint(snappedPoint);
      }
      if (move.current) {
        const delta = {
          xMm: snappedPoint.xMm - move.current.start.xMm,
          yMm: snappedPoint.yMm - move.current.start.yMm,
        };
        if (Math.hypot(delta.xMm, delta.yMm) > 0.0001) {
          const part = move.current.partId ? state?.parts.find((item) => item.id === move.current?.partId) : undefined;
          previewCommand(
            {
              kind: event.altKey ? (part ? "duplicatePart" : "duplicateSelection") : part ? "movePart" : "moveEntities",
              payload: event.altKey
                ? part
                  ? {
                      partId: part.id,
                      newPartId: `part:${crypto.randomUUID()}`,
                      newName: appStrings.inspector.copyOf(part.name),
                      idNamespace: crypto.randomUUID(),
                      delta,
                    }
                  : { selection: { entityIds: move.current.ids }, idNamespace: crypto.randomUUID(), delta }
                : part
                  ? { partId: part.id, delta }
                  : { entityIds: move.current.ids, delta, allowSingleLineStretch: true },
            },
            event.altKey ? appStrings.app.duplicatePreview : appStrings.app.movePreview,
          );
        } else clearCanvasPreview();
      }
      if (controlMove.current) {
        const target = controlMove.current.target;
        const radius = "controlPoint" in target && target.controlPoint.point === "radius";
        const metadata = radius
          ? state?.drawingEntityMetadata.find((item) => item.entityId === controlPointEntityId(target.controlPoint))
          : undefined;
        previewCommand(
          radius && metadata?.derivedElementId && typeof metadata.resolvedIndex === "number"
            ? {
                kind: "setDerivedRadiusFromPoint",
                payload: {
                  derivedElementId: metadata.derivedElementId,
                  resolvedIndex: metadata.resolvedIndex,
                  position: snap(snappedPoint),
                },
              }
            : {
                kind: "moveControlPoint",
                payload: {
                  target: coreConstraintTarget(target as ConstraintTarget),
                  position: snap(snappedPoint),
                  allowProjection: true,
                },
              },
          appStrings.app.preview,
        );
      }
      const current = pan.current;
      if (current)
        setViewport({
          ...current.viewport,
          panX: current.viewport.panX + event.clientX - current.screen.x,
          panY: current.viewport.panY + event.clientY - current.screen.y,
        });
      if (marquee.current && state)
        setMessage(
          appStrings.status.marqueeFeedback(
            point.xMm < marquee.current.xMm ? "crossing" : "contained",
            selectionInRect(visibleEntities, marquee.current, point, point.xMm < marquee.current.xMm).length,
          ),
        );
    },
    [
      canvasProjection.constraintMarkers,
      clearCanvasPreview,
      draft,
      previewCommand,
      snap,
      state?.drawingEntityMetadata,
      state?.viewMode,
      tool,
      viewport,
      setDragDuplicating,
      setSnapSuppressed,
      visibleEntities,
      pendingTargets,
      setHoveredTargetEntityId,
      setMarqueeCurrent,
      setSnapActive,
    ],
  );
  const canvasUp = useCallback(
    (event: React.PointerEvent<HTMLCanvasElement>, point: PointMm) => {
      const currentPan = pan.current;
      const moveStarted = Boolean(move.current);
      pan.current = undefined;
      setSnapSuppressed(false);
      setSnapActive(false);
      setDragDuplicating(false);
      setMarqueeCurrent(undefined);
      setHoveredTargetEntityId(undefined);
      if (state?.viewMode === "outputPreview") return;
      clearCanvasPreview();
      const marqueeStart = marquee.current;
      if (marquee.current && state) {
        const start = marquee.current;
        marquee.current = undefined;
        const ids = selectionInRect(visibleEntities, start, point, point.xMm < start.xMm);
        setSelected((current) => (event.shiftKey ? new Set([...current, ...ids]) : new Set(ids)));
        setMessage(appStrings.status.marqueeFeedback(point.xMm < start.xMm ? "crossing" : "contained", ids.length));
      }
      if (move.current) {
        const current = move.current;
        move.current = undefined;
        const dropPoint = event.ctrlKey ? point : snap(point);
        const delta = { xMm: dropPoint.xMm - current.start.xMm, yMm: dropPoint.yMm - current.start.yMm };
        if (Math.hypot(delta.xMm, delta.yMm) > 0.01) {
          const part = current.partId ? state?.parts.find((item) => item.id === current.partId) : undefined;
          if (event.altKey) {
            if (part)
              void command(
                "duplicatePart",
                {
                  partId: part.id,
                  newPartId: `part:${crypto.randomUUID()}`,
                  newName: appStrings.inspector.copyOf(part.name),
                  idNamespace: crypto.randomUUID(),
                  delta,
                },
                appStrings.app.geometryDuplicated,
              );
            else
              void command(
                "duplicateSelection",
                { selection: { entityIds: current.ids }, idNamespace: crypto.randomUUID(), delta },
                appStrings.app.geometryDuplicated,
              );
          } else {
            if (part) void command("movePart", { partId: part.id, delta }, appStrings.app.geometryMoved);
            else
              void command(
                "moveEntities",
                { entityIds: current.ids, delta, allowSingleLineStretch: true },
                appStrings.app.geometryMoved,
              );
          }
        }
      }
      if (controlMove.current) {
        const current = controlMove.current;
        controlMove.current = undefined;
        const targetControl = "controlPoint" in current.target ? current.target.controlPoint : undefined;
        const radius = targetControl?.point === "radius";
        const metadata = radius
          ? state?.drawingEntityMetadata.find((item) => item.entityId === targetControl.entityId)
          : undefined;
        if (radius && metadata?.derivedElementId && typeof metadata.resolvedIndex === "number")
          void command(
            "setDerivedRadiusFromPoint",
            {
              derivedElementId: metadata.derivedElementId,
              resolvedIndex: metadata.resolvedIndex,
              position: snap(point),
            },
            appStrings.app.filletRadiusUpdated,
          );
        else
          void command(
            "moveControlPoint",
            {
              target: coreConstraintTarget(current.target as ConstraintTarget),
              position: snap(point),
              allowProjection: true,
            },
            appStrings.app.controlPointMoved,
          );
      }
      if (measurementMove.current && state) {
        const current = measurementMove.current;
        measurementMove.current = undefined;
        const delta = { xMm: point.xMm - current.start.xMm, yMm: point.yMm - current.start.yMm };
        if (
          state.measurementAnnotations.some((item) => item.id === current.id) &&
          Math.hypot(delta.xMm, delta.yMm) > 0.0001
        )
          void command(
            "moveMeasurementAnnotation",
            { annotationId: current.id, delta, labelOnly: current.labelOnly },
            appStrings.app.measurementMoved,
          );
      }
      if (dimensionMove.current) {
        const current = dimensionMove.current;
        dimensionMove.current = undefined;
        const delta = { xMm: point.xMm - current.start.xMm, yMm: point.yMm - current.start.yMm };
        if (Math.hypot(delta.xMm, delta.yMm) > 0.0001)
          void command(
            "moveDimensionConstraintAnnotation",
            { constraintId: current.constraintId, delta, labelOnly: current.labelOnly },
            appStrings.app.dimensionMoved,
          );
      }
      if (freeTextMove.current && state) {
        const current = freeTextMove.current;
        freeTextMove.current = undefined;
        arcSweepAngle.current = undefined;
        const delta = { xMm: point.xMm - current.start.xMm, yMm: point.yMm - current.start.yMm };
        const freeText = state.freeTexts.find((item) => item.id === current.id);
        if (freeText && Math.hypot(delta.xMm, delta.yMm) > 0.0001)
          void command(
            "updateFreeText",
            {
              ...freeText,
              positionMm: {
                xMm: freeText.positionMm.xMm + delta.xMm,
                yMm: freeText.positionMm.yMm + delta.yMm,
              },
            },
            appStrings.app.textMoved,
          );
      }
      if (currentPan || marqueeStart || moveStarted) {
        if (!marqueeStart) setMessage(appStrings.status.operationCompleted);
      }
      if (event.currentTarget.hasPointerCapture(event.pointerId))
        event.currentTarget.releasePointerCapture(event.pointerId);
    },
    [
      clearCanvasPreview,
      command,
      setDragDuplicating,
      setHoveredTargetEntityId,
      setMarqueeCurrent,
      setMessage,
      setSnapActive,
      setSnapSuppressed,
      snap,
      state,
      visibleEntities,
    ],
  );

  const canvasLeave = useCallback(() => {
    setCursorPoint(undefined);
  }, [setCursorPoint]);

  return { canvasMove, canvasLeave, canvasUp };
}
