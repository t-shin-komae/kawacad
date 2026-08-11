import { useCallback } from "react";
import type * as React from "react";
import { appStrings } from "@/localization";
import {
  arcPlacementEndPoint,
  allowsDerivedTarget,
  coreConstraintTarget,
  controlPointEntityId,
  constraintTargetEntityId,
  geometryOf,
  hitConstraintMarker,
  hitConstraintTarget,
  hitEntity,
  hitFreeText,
  hitProjectedAnnotation,
  hitProjectedAnnotationDetail,
  hitProjectedPoint,
  preferredConstraintTarget,
  preferredEntitySelectionHit,
  supportsOffsetTarget,
  type ConstraintTarget,
  type PointMm,
} from "@/features/canvas/domain/cad";
import { hitDerivedRadiusControl } from "@/features/canvas/selectors/canvasProjection";
import type { State } from "@/shared/domain/coreWireTypes";
import {
  assistLine,
  constraintTools,
  displayValue,
  drawingTools,
  fixedValue,
  id,
  measurementKinds,
  targetCount,
  toolNames as names,
} from "@/features/canvas/domain/workspaceTools";
import type { DerivedValue } from "@/features/constraints/components/DerivedValueDialog";
import type { Part } from "@/shared/domain/coreWireTypes";
import type { PendingTextEntry } from "@/features/canvas/state/useCanvasPresentation";
import type { TextEntryField } from "@/shared/components/TextEntryDialog";
import type { CanvasActionContext } from "@/app/actions/useActionRuntime";

function partIDForDraggedEntities(state: State, entityIDs: string[]): string | undefined {
  const candidates = state.parts.filter((part) =>
    entityIDs.every((entityID) => {
      if (part.entityIds.includes(entityID)) return true;
      const metadata = state.drawingEntityMetadata.find((item) => item.entityId === entityID);
      return metadata?.derivedElementId ? part.derivedElementIds.includes(metadata.derivedElementId) : false;
    }),
  );
  return candidates.length === 1 ? candidates[0].id : undefined;
}

type CanvasPointActionDependencies = CanvasActionContext & {
  activeStyleId: string | null;
  snapWithTarget: (point: PointMm, enabled: boolean) => { point: PointMm; target?: ConstraintTarget };
  addGesture: (gesture: Record<string, unknown>, constraints?: Record<string, unknown>) => Promise<State | undefined>;
  applyConstraint: (
    candidate: import("@/features/canvas/domain/canvasDomainModels").Tool,
    targets: ConstraintTarget[],
    hudPosition?: { x: number; y: number },
  ) => Promise<void>;
  applyMeasurement: (
    candidate: import("@/features/canvas/domain/canvasDomainModels").Tool,
    targets: ConstraintTarget[],
  ) => Promise<void>;
  applyDerived: (
    candidate: import("@/features/canvas/domain/canvasDomainModels").Tool,
    ids: string[],
    previous?: import("@/features/canvas/state/useCanvasPresentation").PendingDerivedValue,
    clickPoint?: PointMm,
    hudPosition?: { x: number; y: number },
  ) => Promise<void>;
  useSelectedTargets: (
    candidate: import("@/features/canvas/domain/canvasDomainModels").Tool,
    ids: Set<string>,
    clickPoint?: PointMm,
    hudPosition?: { x: number; y: number },
  ) => void;
  openTextEntry: (title: string, fields: TextEntryField[], onConfirm: PendingTextEntry["onConfirm"]) => void;
};

export function useCanvasPointActionCallbacks(dependencies: CanvasPointActionDependencies) {
  const {
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
    dimensionLabels,
    dimensionLabelOffsets,
    draft,
    cursorPoint,
    roundDiameter,
    roundKind,
    activeLayer,
    activeStyleId,
    settingPartOriginId,
    setSettingPartOriginId,
    setSelected,
    setSelectedFreeTextId,
    setSelectedConstraintId,
    setSelectedMeasurementId,
    setSelectedStitchStartPointId,
    setInspectorSelectedPartId,
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
    snapWithTarget,
    addGesture,
    applyConstraint,
    applyMeasurement,
    applyDerived,
    useSelectedTargets,
    openTextEntry,
  } = dependencies;

  const handleCanvasPoint = useCallback(
    (event: React.PointerEvent<HTMLCanvasElement>, original: PointMm) => {
      if (!state || state.viewMode === "outputPreview") return;
      setSnapSuppressed(event.ctrlKey);
      setDragDuplicating(Boolean(event.altKey && move.current));
      const placement = snapWithTarget(original, !event.ctrlKey);
      const point = placement.point;
      if (settingPartOriginId) {
        void command("setPartPosition", { partId: settingPartOriginId, position: point }, appStrings.app.partOriginSet);
        setSettingPartOriginId(undefined);
        return;
      }
      if (event.button === 1 || event.button === 2) {
        pan.current = { screen: { x: event.clientX, y: event.clientY }, viewport };
        event.currentTarget.setPointerCapture(event.pointerId);
        return;
      }
      if (event.button !== 0) return;
      const hit = hitEntity(point, visibleEntities, viewport);
      if (tool === "select") {
        const measurementHit = hitProjectedAnnotationDetail(
          point,
          canvasProjection.measurementAnnotations,
          viewport,
          measurementLabels,
          measurementLabelOffsets,
        );
        if (measurementHit) {
          measurementMove.current = { id: measurementHit.id, start: point, labelOnly: measurementHit.labelOnly };
          setSelected(new Set());
          setSelectedFreeTextId(undefined);
          setSelectedConstraintId(undefined);
          setSelectedMeasurementId(measurementHit.id);
          setSelectedStitchStartPointId(undefined);
          setInspectorSelectedPartId(undefined);
          setMessage(appStrings.status.measurementSelected);
          event.currentTarget.setPointerCapture(event.pointerId);
          return;
        }
        const dimensionHit = hitProjectedAnnotationDetail(
          point,
          canvasProjection.dimensionConstraints,
          viewport,
          dimensionLabels,
          dimensionLabelOffsets,
        );
        if (dimensionHit) {
          dimensionMove.current = { constraintId: dimensionHit.id, start: point, labelOnly: dimensionHit.labelOnly };
          setSelected(new Set());
          setSelectedFreeTextId(undefined);
          setSelectedConstraintId(dimensionHit.id);
          setSelectedMeasurementId(undefined);
          setSelectedStitchStartPointId(undefined);
          setInspectorSelectedPartId(undefined);
          setMessage(appStrings.status.dimensionConstraintSelected);
          event.currentTarget.setPointerCapture(event.pointerId);
          return;
        }
        // A draggable control point must win over a nearby constraint marker.
        // Otherwise coincident vertices cannot be dragged once the marker is visible.
        const controlTarget = hitConstraintTarget(point, visibleEntities, viewport);
        const markerControlEntity =
          controlTarget && "controlPoint" in controlTarget
            ? visibleEntities.find((entity) => entity.id === controlPointEntityId(controlTarget.controlPoint))
            : undefined;
        const markerIsPointControl = geometryOf(markerControlEntity ?? { id: "", kind: {} })?.tag === "point";
        const constraintId =
          controlTarget && "controlPoint" in controlTarget && !markerIsPointControl
            ? undefined
            : hitConstraintMarker(point, canvasProjection.constraintMarkers, viewport);
        if (constraintId) {
          setSelected(new Set());
          setSelectedFreeTextId(undefined);
          setSelectedConstraintId(constraintId);
          setSelectedMeasurementId(undefined);
          setSelectedStitchStartPointId(undefined);
          setInspectorSelectedPartId(undefined);
          setMessage(appStrings.status.constraintSelected);
          return;
        }
        const stitchStartPointId = hitProjectedPoint(point, canvasProjection.stitchStartPoints, viewport);
        if (stitchStartPointId) {
          setSelected(new Set());
          setSelectedFreeTextId(undefined);
          setSelectedConstraintId(undefined);
          setSelectedMeasurementId(undefined);
          setSelectedStitchStartPointId(stitchStartPointId);
          setInspectorSelectedPartId(undefined);
          setMessage(appStrings.status.stitchStartPointSelected);
          return;
        }
        const freeTextId = hitFreeText(point, state.freeTexts);
        if (freeTextId) {
          freeTextMove.current = { id: freeTextId, start: point };
          setSelected(new Set());
          setSelectedFreeTextId(freeTextId);
          setSelectedConstraintId(undefined);
          setSelectedMeasurementId(undefined);
          setSelectedStitchStartPointId(undefined);
          setInspectorSelectedPartId(undefined);
          setMessage(appStrings.status.textSelected);
          event.currentTarget.setPointerCapture(event.pointerId);
          return;
        }
        setSelectedFreeTextId(undefined);
        setSelectedConstraintId(undefined);
        setSelectedMeasurementId(undefined);
        setSelectedStitchStartPointId(undefined);
        setInspectorSelectedPartId(undefined);
        const selectionHit = preferredEntitySelectionHit(point, visibleEntities, viewport, selected);
        const radiusControl = hitDerivedRadiusControl(
          point,
          visibleEntities,
          state.drawingEntityMetadata,
          viewport,
          state.derivedElements,
        );
        if (radiusControl) {
          controlMove.current = { target: radiusControl };
          if ("controlPoint" in radiusControl)
            setSelected(new Set([controlPointEntityId(radiusControl.controlPoint)!]));
          event.currentTarget.setPointerCapture(event.pointerId);
          setMessage(appStrings.status.dragFilletRadius);
          return;
        }
        const control = hitConstraintTarget(point, visibleEntities, viewport);
        const controlEntity =
          control && "controlPoint" in control
            ? visibleEntities.find((item) => item.id === controlPointEntityId(control.controlPoint))
            : undefined;
        const isPointControl = geometryOf(controlEntity ?? { id: "", kind: {} })?.tag === "point";
        if (control && "controlPoint" in control && !isPointControl) {
          controlMove.current = { target: control };
          setSelected(new Set([controlPointEntityId(control.controlPoint)!]));
          event.currentTarget.setPointerCapture(event.pointerId);
          setMessage(appStrings.status.dragControlPoint);
          return;
        }
        if (selectionHit && selected.has(selectionHit) && !event.shiftKey) {
          const ids = [...selected];
          move.current = { start: point, ids, partId: partIDForDraggedEntities(state, ids) };
          event.currentTarget.setPointerCapture(event.pointerId);
          return;
        }
        if (selectionHit)
          setSelected((current) =>
            event.shiftKey
              ? new Set(
                  current.has(selectionHit)
                    ? [...current].filter((item) => item !== selectionHit)
                    : [...current, selectionHit],
                )
              : new Set([selectionHit]),
          );
        else {
          marquee.current = point;
          setDragDuplicating(false);
          setSelected(event.shiftKey ? selected : new Set());
          event.currentTarget.setPointerCapture(event.pointerId);
        }
        return;
      }
      if (!drawingTools.has(tool)) {
        if (constraintTools.has(tool) || measurementKinds[tool]) {
          const target = preferredConstraintTarget(point, visibleEntities, viewport, tool, pendingTargets);
          if (!target) {
            setMessage(appStrings.status.clickToolTarget(names[tool]));
            return;
          }
          const entityId = constraintTargetEntityId(target);
          const entity = visibleEntities.find((item) => item.id === entityId);
          if (!allowsDerivedTarget(tool, entity) || (tool === "offset" && !supportsOffsetTarget(entity))) {
            setMessage(appStrings.status.derivedTargetUnsupported(names[tool]));
            return;
          }
          const next = [...pendingTargets, target];
          const required = targetCount[tool] ?? 1;
          setSelected((current) => new Set([...current, entityId]));
          setPendingTargets(next);
          if (next.length < required) {
            setMessage(appStrings.status.remainingTargets(names[tool], required - next.length));
            return;
          }
          if (constraintTools.has(tool)) void applyConstraint(tool, next, { x: event.clientX, y: event.clientY });
          else void applyMeasurement(tool, next);
          return;
        }
        if (!hit) {
          setMessage(appStrings.status.clickToolTarget(names[tool]));
          return;
        }
        const entity = visibleEntities.find((item) => item.id === hit);
        if (!allowsDerivedTarget(tool, entity) || (tool === "offset" && !supportsOffsetTarget(entity))) {
          setMessage(appStrings.status.derivedTargetUnsupported(names[tool]));
          return;
        }
        const next = new Set(
          tool === "fillet" && pendingDerivedValue?.candidate === "fillet"
            ? pendingDerivedValue.preflight.sourceEntityIds
            : selected,
        );
        next.add(hit);
        setSelected(next);
        if (tool === "fillet" && pendingDerivedValue?.candidate === "fillet")
          void applyDerived("fillet", [...next], pendingDerivedValue, undefined, {
            x: event.clientX,
            y: event.clientY,
          });
        else
          useSelectedTargets(tool, next, tool === "offset" ? point : undefined, {
            x: event.clientX,
            y: event.clientY,
          });
        return;
      }
      if (tool === "point") {
        void addGesture({ kind: "point", position: point });
        return;
      }
      if (tool === "roundHole") {
        if (!Number.isFinite(roundDiameter) || roundDiameter <= 0) {
          setMessage(appStrings.app.invalidRoundHoleDiameter);
          return;
        }
        void command(
          "createRoundHole",
          {
            id: id("round-hole"),
            entityId: id("entity"),
            center: point,
            diameterMm: roundDiameter,
            roundHoleKind: roundKind,
            layerId: activeLayer || null,
            styleId: activeStyleId,
          },
          appStrings.app.roundHoleCreated,
        );
        return;
      }
      if (tool === "stitchStartPoint") {
        void command(
          "placeStitchStartPoint",
          { id: id("stitch-start"), position: point, candidateTargetIds: hit ? [hit] : [], maxDistanceMm: 3 },
          appStrings.app.stitchStartPointPlaced,
        );
        return;
      }
      if (tool === "freeText") {
          openTextEntry(
          appStrings.app.addAnnotationTitle,
          [{ id: "content", label: appStrings.app.annotation, initialValue: appStrings.app.annotation }],
          (values) => {
            const content = values.content.trim();
            if (!content) return;
            void command(
              "addFreeText",
              { id: id("free-text"), content, positionMm: point, fontSizeMm: 4.0 },
              appStrings.app.textAdded,
            );
          },
        );
        return;
      }
      const points = [...draft, point];
      const required = tool === "arc" ? 3 : 2;
      if (points.length < required) {
        if (tool === "line") lineStartSnap.current = placement.target;
        setDraft(points);
        if (tool === "arc") {
          arcSweepAngle.current = undefined;
          setMessage(points.length === 1 ? appStrings.status.arcStartPoint : appStrings.status.arcEndPoint);
        } else setMessage(appStrings.status.specifyNextPoint(names[tool]));
        return;
      }
      if (tool === "circle") {
        setDraft([]);
        void addGesture({ kind: "circle", center: points[0], radiusPoint: points[1] });
      } else if (tool === "arc") {
        const placement = arcPlacementEndPoint(points[0], points[1], point, arcSweepAngle.current, event.shiftKey);
        if (!placement) {
          setMessage(appStrings.status.arcEndAngleInvalid);
          return;
        }
        setDraft([]);
        arcSweepAngle.current = undefined;
        void addGesture({
          kind: "arc",
          center: points[0],
          start: points[1],
          end: placement.point,
          sweepReferenceRad: placement.sweepAngleRad,
        });
      } else {
        setDraft([]);
        const axis =
          tool === "horizontalCenterLine" ? "horizontal" : tool === "verticalCenterLine" ? "vertical" : undefined;
        const assisted =
          tool === "line"
            ? assistLine(points[0], points[1], Boolean(event.shiftKey), placement.target)
            : { point: points[1], axis };
        const lineAxis = axis ?? assisted.axis;
        const makeSnap = (target: ConstraintTarget | undefined) =>
          target ? { constraintId: id("constraint:coincident"), target: coreConstraintTarget(target) } : undefined;
        void addGesture(
          {
            kind: "line",
            start: points[0],
            end: assisted.point,
            centerLine: tool !== "line",
            ...(lineAxis ? { axis: lineAxis } : {}),
          },
          tool === "line"
            ? {
                startSnap: makeSnap(lineStartSnap.current),
                endSnap: makeSnap(placement.target),
                ...(lineAxis ? { axisConstraintId: id(`constraint:${lineAxis}`) } : {}),
              }
            : {},
        );
        lineStartSnap.current = undefined;
      }
    },
    [
      activeLayer,
      activeStyleId,
      addGesture,
      applyConstraint,
      applyDerived,
      applyMeasurement,
      canvasProjection,
      command,
      draft,
      dimensionLabelOffsets,
      dimensionLabels,
      measurementLabelOffsets,
      measurementLabels,
      openTextEntry,
      pendingDerivedValue,
      pendingTargets,
      roundDiameter,
      roundKind,
      selected,
      settingPartOriginId,
      snapWithTarget,
      state,
      tool,
      useSelectedTargets,
      viewport,
      visibleEntities,
      setDragDuplicating,
      setSnapSuppressed,
    ],
  );

  return { handleCanvasPoint };
}
