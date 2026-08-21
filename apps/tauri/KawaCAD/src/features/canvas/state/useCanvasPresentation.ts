import { useCallback, useRef, useState } from "react";
import { useAnnotationSelection } from "@/features/canvas/state/useAnnotationSelection";
import { cancelCanvasInteraction as cancelCanvasState } from "@/features/canvas/actions/canvasCancellation";
import type { PastePlacementMode } from "@/features/document/components/PasteOptionsOverlay";
import type { TextEntryField } from "@/shared/components/TextEntryDialog";
import type { OffsetSourceOption } from "@/features/constraints/components/DerivedValueDialog";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
import { defaultViewport, type ConstraintTarget, type PointMm, type Viewport } from "@/features/canvas/domain/cad";
import type { EditControlTarget } from "@/shared/domain/coreWireTypes";
import type {
  CanvasCancellationExternal,
  CanvasInteractionPresentation,
} from "@/features/canvas/actions/useCanvasInteractionController";

export type SelectionExport = { clipboardJson: string; anchorPoint?: PointMm };
export type PasteOptions = {
  activeMode: PastePlacementMode;
  anchorPoint: PointMm;
  cursorPoint?: PointMm;
  nearSourcePoint: PointMm;
  namespace: string;
};
export type ConstraintPreflight = {
  kind: string;
  normalizedTargets: unknown[];
  value?: Record<string, number | string | undefined>;
};
export type HudPosition = { x: number; y: number };
export type PendingConstraintValue = {
  candidate: Tool;
  preflight: ConstraintPreflight;
  hudPosition?: HudPosition;
};
export type DerivedPreflight = {
  offsetOptions: OffsetSourceOption[];
  sourceEntityIds: string[];
  updateDerivedElementId?: string;
  closed: boolean;
};
export type PendingDerivedValue = {
  candidate: "offset" | "fillet";
  preflight: DerivedPreflight;
  clickPoint?: PointMm;
  hudPosition?: HudPosition;
  valueText: string;
  entryMode: "fixed" | "parameter";
  parameterId: string;
};
export type PendingTextEntry = {
  title: string;
  fields: TextEntryField[];
  onConfirm: (values: Record<string, string>) => void;
};
export type ContextSelectionKind = "none" | "entity" | "constraint" | "measurement" | "freeText";
export type ContextMenu = { x: number; y: number; point: PointMm; selectionKind: ContextSelectionKind };

/** Owns transient Canvas interaction state; it does not execute commands. */
export function useCanvasPresentation() {
  const annotationSelection = useAnnotationSelection();
  const [tool, setTool] = useState<Tool>("select");
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [editingFreeTextId, setEditingFreeTextId] = useState<string>();
  const [pendingTargets, setPendingTargets] = useState<ConstraintTarget[]>([]);
  const [draft, setDraft] = useState<PointMm[]>([]);
  const [cursorPoint, setCursorPoint] = useState<PointMm>();
  const [viewport, setViewport] = useState<Viewport>(defaultViewport);
  const [activeLayer, setActiveLayer] = useState("layer:cut-line");
  const [activeStyle, setActiveStyle] = useState("style:outer-cut-line");
  const [roundDiameter, setRoundDiameter] = useState(5);
  const [roundKind, setRoundKind] = useState("keyRing");
  const [clipboard, setClipboard] = useState<SelectionExport>();
  const [pasteOptions, setPasteOptions] = useState<PasteOptions>();
  const [pasteSequence, setPasteSequence] = useState(0);
  const [pendingConstraintValue, setPendingConstraintValue] = useState<PendingConstraintValue>();
  const [pendingDerivedValue, setPendingDerivedValue] = useState<PendingDerivedValue>();
  const [pendingTextEntry, setPendingTextEntry] = useState<PendingTextEntry>();
  const [contextMenu, setContextMenu] = useState<ContextMenu>();
  const [hoveredConstraintId, setHoveredConstraintId] = useState<string>();
  const [snapSuppressed, setSnapSuppressed] = useState(false);
  const [snapActive, setSnapActive] = useState(false);
  const [dragDuplicating, setDragDuplicating] = useState(false);
  const [marqueeCurrent, setMarqueeCurrent] = useState<PointMm>();
  const [hoveredTargetEntityId, setHoveredTargetEntityId] = useState<string>();
  const pan = useRef<{ screen: { x: number; y: number }; viewport: Viewport }>();
  const marquee = useRef<PointMm>();
  const move = useRef<{ start: PointMm; ids: string[]; partId?: string }>();
  const controlMove = useRef<{ target: EditControlTarget }>();
  const measurementMove = useRef<{ id: string; start: PointMm; labelOnly: boolean }>();
  const dimensionMove = useRef<{ constraintId: string; start: PointMm; labelOnly: boolean }>();
  const freeTextMove = useRef<{ id: string; start: PointMm }>();
  const arcSweepAngle = useRef<number>();
  const lineStartSnap = useRef<ConstraintTarget>();
  const clearPendingTextEntry = useCallback(() => setPendingTextEntry(undefined), []);
  const beginFreeTextEdit = useCallback((id: string) => setEditingFreeTextId(id), []);
  const selectEntities = useCallback((ids: Set<string>) => setSelected(ids), []);
  const clearEntitySelection = useCallback(() => setSelected(new Set()), []);
  const clearFreeTextEdit = useCallback(() => setEditingFreeTextId(undefined), []);
  const setPastePlacement = useCallback((options: PasteOptions | undefined) => setPasteOptions(options), []);
  const storeSelectionExport = useCallback((exported: SelectionExport) => {
    setClipboard(exported);
    setPasteSequence(0);
  }, []);
  const advancePasteSequence = useCallback(() => setPasteSequence((sequence) => sequence + 1), []);
  const resetPasteSequence = useCallback(() => setPasteSequence(0), []);
  const clearTransientCanvasState = useCallback(() => {
    clearEntitySelection();
    annotationSelection.clearAnnotationSelection();
    clearFreeTextEdit();
    setHoveredConstraintId(undefined);
    setSnapSuppressed(false);
    setSnapActive(false);
    setDragDuplicating(false);
    setMarqueeCurrent(undefined);
    setHoveredTargetEntityId(undefined);
    setPendingTargets([]);
    setPendingConstraintValue(undefined);
    setPendingDerivedValue(undefined);
    setDraft([]);
    lineStartSnap.current = undefined;
    arcSweepAngle.current = undefined;
  }, [annotationSelection, clearEntitySelection, clearFreeTextEdit]);
  const resetCanvasPresentation = useCallback(
    (next: { layers: Array<{ id: string }>; sharedStyles: Array<{ id: string }> }) => {
      setTool("select");
      clearTransientCanvasState();
      clearPendingTextEntry();
      setCursorPoint(undefined);
      setPastePlacement(undefined);
      setActiveLayer(
        next.layers.some((layer) => layer.id === "layer:cut-line") ? "layer:cut-line" : (next.layers[0]?.id ?? ""),
      );
      setActiveStyle(
        next.sharedStyles.some((style) => style.id === "style:outer-cut-line")
          ? "style:outer-cut-line"
          : (next.sharedStyles[0]?.id ?? ""),
      );
    },
    [clearPendingTextEntry, clearTransientCanvasState, setPastePlacement],
  );
  const cancelCanvasInteraction = useCallback(
    (external: CanvasCancellationExternal) =>
      cancelCanvasState({
        pasteOptions,
        clearPastePlacement: () => setPastePlacement(undefined),
        setMessage: external.setMessage,
        pan,
        marquee,
        move,
        controlMove,
        measurementMove,
        dimensionMove,
        freeTextMove,
        setSnapSuppressed,
        setSnapActive,
        setDragDuplicating,
        setMarqueeCurrent,
        setHoveredTargetEntityId,
        setPendingConstraintValue,
        setPendingDerivedValue,
        clearPendingTextEntry,
        clearCanvasPreview: external.clearCanvasPreview,
        previewActive: external.previewActive,
        pendingTargets,
        setPendingTargets,
        draft,
        setDraft,
        selectedMeasurementId: annotationSelection.selectedMeasurementId,
        clearSelectedMeasurement: annotationSelection.clearSelectedMeasurement,
        selectedConstraintId: annotationSelection.selectedConstraintId,
        clearSelectedConstraint: annotationSelection.clearSelectedConstraint,
        selectedFreeTextId: annotationSelection.selectedFreeTextId,
        clearSelectedFreeText: annotationSelection.clearSelectedFreeText,
        selectedStitchStartPointId: annotationSelection.selectedStitchStartPointId,
        clearSelectedStitchStartPoint: annotationSelection.clearSelectedStitchStartPoint,
        selected,
        clearEntitySelection,
        pendingConstraintValue,
        pendingDerivedValue,
        pendingTextEntry,
        editingFreeTextId,
        clearFreeTextEdit,
        rewindFilletDraft: external.rewindFilletDraft,
        selectedTool: tool,
        selectTool: external.selectTool,
      }),
    [
      annotationSelection,
      clearEntitySelection,
      clearFreeTextEdit,
      clearPendingTextEntry,
      draft,
      editingFreeTextId,
      pendingConstraintValue,
      pendingDerivedValue,
      pendingTargets,
      pasteOptions,
      selected,
      setPastePlacement,
      pendingTextEntry,
      tool,
    ],
  );
  const interaction: CanvasInteractionPresentation = {
    clearTransientCanvasState,
    resetCanvasPresentation,
    cancelCanvasInteraction,
  };
  const documentSelection = {
    entityIDs: selected,
    replaceEntitySelection: selectEntities,
    annotation: annotationSelection.selectedMeasurementId
      ? ({ kind: "measurement", id: annotationSelection.selectedMeasurementId } as const)
      : annotationSelection.selectedStitchStartPointId
        ? ({ kind: "stitchStartPoint", id: annotationSelection.selectedStitchStartPointId } as const)
        : annotationSelection.selectedConstraintId
          ? ({ kind: "constraint", id: annotationSelection.selectedConstraintId } as const)
          : annotationSelection.selectedFreeTextId
            ? ({ kind: "freeText", id: annotationSelection.selectedFreeTextId } as const)
            : undefined,
    clearAnnotationSelection: annotationSelection.clearAnnotationSelection,
  };

  return {
    tool,
    setTool,
    selected,
    setSelected,
    editingFreeTextId,
    setEditingFreeTextId,
    pendingTargets,
    setPendingTargets,
    draft,
    setDraft,
    cursorPoint,
    setCursorPoint,
    viewport,
    setViewport,
    activeLayer,
    setActiveLayer,
    activeStyle,
    setActiveStyle,
    roundDiameter,
    setRoundDiameter,
    roundKind,
    setRoundKind,
    clipboard,
    setClipboard,
    pasteOptions,
    setPasteOptions,
    pasteSequence,
    setPasteSequence,
    pendingConstraintValue,
    setPendingConstraintValue,
    pendingDerivedValue,
    setPendingDerivedValue,
    pendingTextEntry,
    setPendingTextEntry,
    clearPendingTextEntry,
    beginFreeTextEdit,
    selectEntities,
    clearEntitySelection,
    clearFreeTextEdit,
    setPastePlacement,
    storeSelectionExport,
    advancePasteSequence,
    resetPasteSequence,
    interaction,
    documentSelection,
    clearTransientCanvasState,
    resetCanvasPresentation,
    cancelCanvasInteraction,
    contextMenu,
    setContextMenu,
    hoveredConstraintId,
    setHoveredConstraintId,
    snapSuppressed,
    setSnapSuppressed,
    snapActive,
    setSnapActive,
    dragDuplicating,
    setDragDuplicating,
    marqueeCurrent,
    setMarqueeCurrent,
    hoveredTargetEntityId,
    setHoveredTargetEntityId,
    pan,
    marquee,
    move,
    controlMove,
    measurementMove,
    dimensionMove,
    freeTextMove,
    arcSweepAngle,
    lineStartSnap,
    ...annotationSelection,
  };
}

export type CanvasPresentation = ReturnType<typeof useCanvasPresentation>;
