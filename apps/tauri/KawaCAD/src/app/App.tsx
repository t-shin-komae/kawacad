import { useEffect, useMemo, useState, type ComponentProps } from "react";
import { angleArcCounterclockwise, CadCanvas } from "@/features/canvas/components/CadCanvas";
import { ToolPalette } from "@/features/canvas/components/ToolPalette";
import { InspectorPanel, type Part, type PartLibraryEntry } from "@/features/inspector/components/InspectorPanel";
import type { InspectorTab } from "@/features/inspector/selectors/inspectorFeature";
import { WorkspaceInspector } from "@/features/inspector/components/WorkspaceInspector";
import { CadToolbar } from "@/features/canvas/components/CadToolbar";
import { CanvasContextMenu } from "@/features/canvas/components/CanvasContextMenu";
import { BottomWorkbench } from "@/features/workspace/components/BottomWorkbench";
import { DocumentHeader } from "@/features/document/components/DocumentHeader";
import { DocumentSaveConfirmationDialog } from "@/features/document/components/DocumentSaveConfirmationDialog";
import { PaletteResizeHandle } from "@/features/workspace/components/PaletteResizeHandle";
import { PasteOptionsOverlay, type PastePlacementMode } from "@/features/document/components/PasteOptionsOverlay";
import { AppErrorBanner } from "@/features/workspace/components/AppErrorBanner";
import { ConstraintValueDialog } from "@/features/constraints/components/ConstraintValueDialog";
import {
  DerivedValueDialog,
  type DerivedValue,
  type OffsetSourceOption,
} from "@/features/constraints/components/DerivedValueDialog";
import { LayerDeletionDialog } from "@/features/document/components/LayerDeletionDialog";
import { TextEntryDialog, type TextEntryField } from "@/shared/components/TextEntryDialog";
import type { MenuAction } from "@/app/domain/nativeMenuTypes";
import { updateNativeMenuState } from "@/adapters/nativeMenuAdapter";
import type { CSSProperties } from "react";
import { accessibilityIdentifiers } from "@/shared/accessibility/accessibilityIdentifiers";
import { appStrings } from "@/localization";
import type { CanvasViewMode, Tool } from "@/features/canvas/domain/canvasDomainModels";
import {
  defaultViewport,
  constraintTargetEntityId,
  type PointMm,
  type ConstraintTarget,
} from "@/features/canvas/domain/cad";
import {
  canvasProjectionFor,
  documentWindowPresentation,
  hitDerivedRadiusControl,
  partCanvasHighlights,
  selectedSourceArcId,
  type State,
} from "@/shared/domain/workspaceState";
import {
  assistLine,
  constraintKinds,
  constraintTools,
  displayValue,
  drawingTools,
  fixedValue,
  id,
  measurementKinds,
  targetCount,
  toolPaletteWidthRange,
  toolNames as names,
} from "@/features/canvas/domain/workspaceTools";
import { useWorkspacePreferences } from "@/features/workspace/state/useWorkspacePreferences";
import { useAppErrorPresentation } from "@/features/workspace/state/useAppErrorPresentation";
import { useAnnotationSelection } from "@/features/canvas/state/useAnnotationSelection";
import { useCadSession } from "@/features/document/state/useCadSession";
import { usePartLibrary } from "@/features/parts/state/usePartLibrary";
import { useRecoverySnapshot } from "@/features/recovery/state/useRecoverySnapshot";
import { useWorkspaceLayout } from "@/features/workspace/state/useWorkspaceLayout";
import {
  useCanvasPresentation,
  type ContextMenu,
  type ConstraintPreflight,
  type DerivedPreflight,
  type PasteOptions,
  type PendingConstraintValue,
  type PendingDerivedValue,
  type PendingTextEntry,
  type SelectionExport,
} from "@/features/canvas/state/useCanvasPresentation";
import { useDocumentPresentation } from "@/features/document/state/useDocumentPresentation";
import { useInspectorPresentation } from "@/features/inspector/state/useInspectorPresentation";
import { useAppActions } from "@/app/actions/useAppActions";
import { RecoveryChooserDialog } from "@/features/recovery/components/RecoveryChooserDialog";
import { RecoverySaveFailureBanner } from "@/features/recovery/components/RecoverySaveFailureBanner";
import { useActiveDrawingOptions } from "@/features/canvas/selectors/useActiveDrawingOptions";
import { useWindowLifecycle } from "@/features/workspace/effects/useWindowLifecycle";
import { useRecoveryEffects } from "@/features/recovery/effects/useRecoveryEffects";
import { OpenSourceLicensesDialog } from "@/features/licenses/components/OpenSourceLicensesDialog";
import { OutputDialog } from "@/features/output/components/OutputDialog";
import { CircleDot, FileOutput, Info, MapPin, MousePointer2 } from "lucide-react";

function isTextEditingElement(element: EventTarget | null) {
  return (
    element instanceof HTMLElement &&
    (element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement || element.isContentEditable)
  );
}

function performTextEditingCommand(action: "cut" | "copy" | "paste") {
  return (
    isTextEditingElement(document.activeElement) &&
    typeof document.execCommand === "function" &&
    document.execCommand(action)
  );
}

export function App() {
  const [licensesOpen, setLicensesOpen] = useState(false);
  const [outputDestination, setOutputDestination] = useState<"pdf" | "directPrint">();
  const [inspectorTab, setInspectorTab] = useState<InspectorTab>("selection");
  const canvasPresentation = useCanvasPresentation();
  const {
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
  } = canvasPresentation;
  const {
    selectedFreeTextId,
    setSelectedFreeTextId,
    selectedConstraintId,
    setSelectedConstraintId,
    selectedMeasurementId,
    setSelectedMeasurementId,
    selectedStitchStartPointId,
    setSelectedStitchStartPointId,
    clearAnnotationSelection,
  } = useAnnotationSelection();
  const {
    gridVisible,
    setGridVisible,
    a4Visible,
    setA4Visible,
    snapEnabled,
    setSnapEnabled,
    pointSnapEnabled,
    setPointSnapEnabled,
    inspectorOpen,
    setInspectorOpen,
    bottomWorkbenchVisible,
    setBottomWorkbenchVisible,
    basicToolsOnly,
    setBasicToolsOnly,
    collapsedToolGroups,
    setCollapsedToolGroups,
    resetWorkspacePreferences,
  } = useWorkspacePreferences();
  const normalizeActiveDrawingOptions = useActiveDrawingOptions(setActiveLayer, setActiveStyle);
  const { errorPresentation, dismissPresentedError, presentOperationFailure } = useAppErrorPresentation();
  const {
    state,
    previewState,
    message,
    setMessage,
    previewActive,
    applyState,
    clearCanvasPreview,
    previewCommand,
    refresh,
    run,
    command,
  } = useCadSession({
    onDocumentState: normalizeActiveDrawingOptions,
    reportError: presentOperationFailure,
  });
  const a4Landscape = state?.settings.orientation === "landscape";
  const { partLibrary, updatePartLibrary } = usePartLibrary({ report: setMessage });
  const {
    layerDeletionConfirmation,
    setLayerDeletionConfirmation,
    documentWarning,
    setDocumentWarning,
    allowWindowClose,
    documentHeader,
    documentNameForFileDialog,
    documentSaveConfirmation,
    requestDocumentSaveConfirmation,
    resolveDocumentSaveConfirmation,
  } = useDocumentPresentation();
  const {
    arrangementPartIds,
    setArrangementPartIds,
    inspectorSelectedPartId,
    setInspectorSelectedPartId,
    settingPartOriginId,
    setSettingPartOriginId,
    inspectorRevision,
    setInspectorRevision,
  } = useInspectorPresentation();
  const { layout, toolPaletteWidth, setToolPaletteWidth, compactDrawer, setCompactDrawer, resetWorkspaceLayout } =
    useWorkspaceLayout();
  const canvasState = previewState ?? state;
  const canvasProjection = canvasProjectionFor(canvasState);
  const measurementLabels = Object.fromEntries(
    (canvasState?.measurementEvaluations ?? []).map((item) => [item.annotationId, displayValue(item.value)]),
  );
  const measurementLabelOffsets = Object.fromEntries(
    (canvasState?.measurementAnnotations ?? []).map((item) => [item.id, item.labelOffsetMm]),
  );
  const dimensionLabels = Object.fromEntries(
    (canvasState?.constraints ?? []).map((item) => [item.id, displayValue(item.value)]),
  );
  const measurementArcCounterclockwise = Object.fromEntries(
    (canvasState?.measurementEvaluations ?? [])
      .filter((item) => typeof item.value.fixedDegrees === "number")
      .map((item) => [item.annotationId, Number(item.value.fixedDegrees) > 0]),
  ) as Record<string, boolean>;
  const dimensionArcCounterclockwise = Object.fromEntries(
    (canvasState?.constraints ?? [])
      .filter((item) => item.kind === "angle")
      .flatMap((item) => {
        const fixedDegrees = item.value?.fixedDegrees;
        return typeof fixedDegrees === "number" ? [[item.id, angleArcCounterclockwise(fixedDegrees)]] : [];
      }),
  ) as Record<string, boolean>;
  const dimensionLabelOffsets = Object.fromEntries(
    (canvasState?.dimensionConstraintAnnotations ?? []).map((item) => [item.constraintId, item.labelOffsetMm]),
  );
  const visibleEntities = useMemo(() => {
    const visibleLayerIds = new Set((state?.layers ?? []).filter((layer) => layer.visible).map((layer) => layer.id));
    return (state?.entities ?? []).filter((entity) => !entity.layerId || visibleLayerIds.has(entity.layerId));
  }, [state?.entities, state?.layers]);

  const {
    clearTransientCanvasState,
    setDocumentViewMode,
    setOutputOrientation,
    renameDocument,
    commitPendingDocumentName,
    validatePendingDocumentName,
    openTextEntry,
    selectTool,
    resetInspectorPresentation,
    resetLoadedDocumentPresentation,
    saveBeforeDestructiveAction,
    resolveDirtyReplacement,
    newDocument,
    openDocument,
    saveDocument,
    saveCurrentDocument,
    reloadDocument,
    restoreHistory,
    smoothSelectedArcTangencies,
    addLayer,
    deleteLayer,
    createPart,
    addParameter,
    renameLayer,
    applyActiveStyle,
    snap,
    snapWithTarget,
    addGesture,
    commitConstraint,
    applyConstraint,
    constrainSegmentLengthFromInspector,
    applyMeasurement,
    applyDerived,
    commitDerived,
    useSelectedTargets,
    rewindFilletDraft,
    handleCanvasPoint,
    canvasMove,
    canvasUp,
    handleCanvasDoubleClick,
    handleCanvasWheel,
    handleCanvasContextMenu,
    deleteSelection,
    copySelection,
    cutSelection,
    pasteSelection,
    selectPastePlacement,
    duplicateSelection,
    confirmDeleteLayer,
    cancelDeleteLayer,
    commitFreeTextEdit,
    cancelFreeTextEdit,
    executeCommand,
    resetWorkspace,
    selectPartContents,
    addPartToLibrary,
    insertPartFromLibrary,
    toggleArrangementPart,
    alignParts,
    distributeParts,
    removePartFromLibrary,
    beginSetPartOrigin,
    selectConstraint,
    selectFreeText,
    selectMeasurement,
    convertMeasurement,
  } = useAppActions({
    state,
    a4Landscape,
    run,
    command,
    applyState,
    clearCanvasPreview,
    previewCommand,
    previewActive,
    tool,
    setViewport,
    cursorPoint,
    editingFreeTextId,
    layerDeletionConfirmation,
    setLayerDeletionConfirmation,
    presentOperationFailure,
    arcSweepAngle,
    lineStartSnap,
    setSelected,
    clearAnnotationSelection,
    setEditingFreeTextId,
    setHoveredConstraintId,
    setSnapSuppressed,
    setSnapActive,
    setDragDuplicating,
    setMarqueeCurrent,
    setHoveredTargetEntityId,
    setPendingTargets,
    setPendingConstraintValue,
    setPendingDerivedValue,
    setPendingTextEntry,
    setDraft,
    setCursorPoint,
    setPasteOptions,
    setContextMenu,
    setArrangementPartIds,
    setInspectorSelectedPartId,
    setSettingPartOriginId,
    setCompactDrawer,
    setActiveLayer,
    setActiveStyle,
    setTool,
    setMessage,
    setInspectorRevision,
    documentHeader,
    documentNameForFileDialog,
    requestDocumentSaveConfirmation,
    resetWorkspacePreferences,
    resetWorkspaceLayout,
    activeLayer,
    activeStyle,
    selected,
    viewport,
    snapEnabled,
    pointSnapEnabled,
    visibleEntities,
    clipboard,
    setClipboard,
    pasteOptions,
    pasteSequence,
    setPasteSequence,
    pendingTargets,
    pendingDerivedValue,
    roundDiameter,
    roundKind,
    selectedFreeTextId,
    selectedConstraintId,
    selectedMeasurementId,
    selectedStitchStartPointId,
    setSelectedFreeTextId,
    setSelectedConstraintId,
    setSelectedMeasurementId,
    setSelectedStitchStartPointId,
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
    draft,
    partLibrary,
    updatePartLibrary,
    arrangementPartIds,
    inspectorSelectedPartId,
  });
  const recoverySnapshot = useRecoverySnapshot({
    execute: run,
    report: setMessage,
    onRestored: resetInspectorPresentation,
  });
  const { recoveryCandidates } = recoverySnapshot;
  useWindowLifecycle({ state, allowWindowClose, saveBeforeDestructiveAction, requestDocumentSaveConfirmation });
  const recoveryEffects = useRecoveryEffects({ state });
  useEffect(() => {
    void refresh().then(() => setMessage(appStrings.status.readyToDraw));
  }, [refresh]);
  useEffect(() => {
    documentNameForFileDialog.current = state?.snapshot.name;
  }, [state?.snapshot.name]);
  useEffect(() => {
    const warning = state?.warnings.find((item) => item.message)?.message;
    if (warning) setDocumentWarning(warning);
  }, [state?.warnings]);
  useEffect(() => {
    if (layout.mode === "compact" && inspectorOpen && selected.size) setCompactDrawer("inspector");
  }, [inspectorOpen, layout.mode, selected]);
  useEffect(() => {
    updateNativeMenuState({
      hasDocument: Boolean(state),
      viewMode: state?.viewMode ?? "editDisplay",
      canUndo: Boolean(state?.history.canUndo),
      canRedo: Boolean(state?.history.canRedo),
      hasSelection:
        selected.size > 0 ||
        Boolean(selectedFreeTextId || selectedConstraintId || selectedMeasurementId || selectedStitchStartPointId),
      canPaste: Boolean(clipboard),
      canEditLayers: Boolean(state?.layers.length),
      canExportPDF: Boolean(state),
      canDirectPrint: Boolean(state),
      canSmoothArcTangencies: Boolean(
        state && selectedSourceArcId(selected, state.entities, state.drawingEntityMetadata ?? []),
      ),
      inspectorOpen: layout.mode === "compact" ? compactDrawer === "inspector" : inspectorOpen,
      inspectorTab,
      bottomWorkbenchVisible,
    });
  }, [
    bottomWorkbenchVisible,
    clipboard,
    inspectorOpen,
    inspectorTab,
    compactDrawer,
    layout.mode,
    selected,
    selectedConstraintId,
    selectedFreeTextId,
    selectedMeasurementId,
    selectedStitchStartPointId,
    state,
  ]);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.defaultPrevented) return;
      const primary = event.metaKey || event.ctrlKey;
      const key = event.key.toLowerCase();
      if (primary && ["x", "c", "v"].includes(key) && isTextEditingElement(event.target)) return;
      if (primary && key === "s") {
        event.preventDefault();
        if (event.shiftKey) void saveDocument();
        else saveCurrentDocument();
      } else if (primary && key === "o") {
        event.preventDefault();
        void openDocument();
      } else if (primary && key === "n") {
        event.preventDefault();
        newDocument();
      } else if (primary && key === "z") {
        event.preventDefault();
        restoreHistory(event.shiftKey ? "redo" : "undo");
      } else if (primary && key === "x") {
        event.preventDefault();
        void cutSelection();
      } else if (primary && key === "c") {
        event.preventDefault();
        void copySelection();
      } else if (primary && key === "v") {
        event.preventDefault();
        pasteSelection();
      } else if (primary && key === "d") {
        event.preventDefault();
        duplicateSelection();
      } else if (primary && key === "a") {
        event.preventDefault();
        setSelected(new Set(state?.entities.map((entity) => entity.id) ?? []));
      } else if (primary && key === "f") {
        event.preventDefault();
        window.dispatchEvent(new Event("kawa-cad-find-inspector"));
      } else if (primary && key === "r") {
        event.preventDefault();
        reloadDocument();
      } else if (primary && event.altKey && (key === "1" || key === "2")) {
        event.preventDefault();
        setDocumentViewMode(key === "1" ? "editDisplay" : "outputPreview");
      } else if (primary && key >= "1" && key <= "5") {
        event.preventDefault();
        selectTool((["select", "point", "line", "circle", "centerLine"] as Tool[])[Number(key) - 1]);
      } else if (!primary && !event.altKey && key === "v") {
        event.preventDefault();
        selectTool("select");
      } else if (primary && event.shiftKey && key === "h") {
        event.preventDefault();
        selectTool("horizontal");
      } else if (primary && event.shiftKey && key === "v") {
        event.preventDefault();
        selectTool("vertical");
      } else if (primary && event.shiftKey && key === "l") {
        event.preventDefault();
        addLayer();
      } else if (event.key === "Delete" || event.key === "Backspace") {
        event.preventDefault();
        deleteSelection();
      } else if (event.key === "Escape") {
        event.preventDefault();
        if (pasteOptions) {
          setPasteOptions(undefined);
          setMessage(appStrings.status.pastePositionDismissed);
          return;
        }
        pan.current = undefined;
        marquee.current = undefined;
        move.current = undefined;
        setSnapSuppressed(false);
        setSnapActive(false);
        setDragDuplicating(false);
        setMarqueeCurrent(undefined);
        setHoveredTargetEntityId(undefined);
        controlMove.current = undefined;
        measurementMove.current = undefined;
        dimensionMove.current = undefined;
        freeTextMove.current = undefined;
        if (editingFreeTextId) setEditingFreeTextId(undefined);
        else if (pendingConstraintValue) setPendingConstraintValue(undefined);
        else if (pendingDerivedValue?.candidate === "fillet") rewindFilletDraft();
        else if (pendingDerivedValue) setPendingDerivedValue(undefined);
        else if (pendingTextEntry) setPendingTextEntry(undefined);
        else if (layerDeletionConfirmation) setLayerDeletionConfirmation(undefined);
        else if (compactDrawer) setCompactDrawer(undefined);
        else if (previewActive.current) {
          clearCanvasPreview();
          setMessage(appStrings.status.movePreviewCancelled);
        } else if (pendingTargets.length) setPendingTargets([]);
        else if (draft.length) setDraft([]);
        else if (settingPartOriginId) setSettingPartOriginId(undefined);
        else if (selectedMeasurementId) setSelectedMeasurementId(undefined);
        else if (selectedConstraintId) setSelectedConstraintId(undefined);
        else if (selectedFreeTextId) setSelectedFreeTextId(undefined);
        else if (selectedStitchStartPointId) setSelectedStitchStartPointId(undefined);
        else if (selected.size) setSelected(new Set());
        else if (inspectorSelectedPartId) {
          setInspectorSelectedPartId(undefined);
          setMessage(appStrings.status.partSelectionCleared);
        } else selectTool("select");
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [
    addLayer,
    clearCanvasPreview,
    copySelection,
    cutSelection,
    deleteSelection,
    duplicateSelection,
    compactDrawer,
    draft.length,
    editingFreeTextId,
    newDocument,
    openDocument,
    pendingConstraintValue,
    pendingDerivedValue,
    pendingTextEntry,
    pasteOptions,
    rewindFilletDraft,
    layerDeletionConfirmation,
    pasteSelection,
    pendingTargets.length,
    reloadDocument,
    restoreHistory,
    saveCurrentDocument,
    saveDocument,
    selectTool,
    setDocumentViewMode,
    selectedConstraintId,
    selectedFreeTextId,
    selectedMeasurementId,
    selected.size,
    selectedStitchStartPointId,
    inspectorSelectedPartId,
    settingPartOriginId,
    state?.entities,
  ]);

  useEffect(() => {
    const onMenu = (event: Event) => {
      const action = (event as CustomEvent<MenuAction>).detail;
      if (action === "new") newDocument();
      else if (action === "open") void openDocument();
      else if (action === "save") saveCurrentDocument();
      else if (action === "saveAs") void saveDocument();
      else if (action === "exportPDF") setOutputDestination("pdf");
      else if (action === "directPrint") setOutputDestination("directPrint");
      else if (action === "undo" || action === "redo") restoreHistory(action);
      else if (action === "cut") {
        if (!performTextEditingCommand("cut")) void cutSelection();
      } else if (action === "copy") {
        if (!performTextEditingCommand("copy")) void copySelection();
      } else if (action === "paste") {
        if (!performTextEditingCommand("paste")) pasteSelection();
      } else if (action === "duplicate") duplicateSelection();
      else if (action === "delete") deleteSelection();
      else if (action === "selectAll") setSelected(new Set(state?.entities.map((entity) => entity.id) ?? []));
      else if (action === "cancelCurrentInteraction")
        window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
      else if (action === "findInspector") window.dispatchEvent(new Event("kawa-cad-find-inspector"));
      else if (action === "toggleInspector") {
        if (layout.mode === "compact") setCompactDrawer((value) => (value === "inspector" ? undefined : "inspector"));
        else setInspectorOpen((value) => !value);
      } else if (action === "toggleBottomWorkbench")
        setBottomWorkbenchVisible((visible) => {
          setMessage(visible ? appStrings.status.summaryHidden : appStrings.status.summaryShown);
          return !visible;
        });
      else if (action === "zoomToFit") setViewport(defaultViewport);
      else if (action === "resetLayout") resetWorkspace();
      else if (action === "reload") reloadDocument();
      else if (action === "smoothArcTangencies") smoothSelectedArcTangencies();
      else if (action === "editDisplay" || action === "outputPreview") setDocumentViewMode(action);
      else if (action === "toggleA4Orientation") {
        const next = !a4Landscape;
        setOutputOrientation(next);
      } else if (action === "addLayer") addLayer();
      else if (action === "openLicenses") setLicensesOpen(true);
      else selectTool(action);
    };
    window.addEventListener("kawa-cad-menu", onMenu);
    return () => window.removeEventListener("kawa-cad-menu", onMenu);
  }, [
    addLayer,
    a4Landscape,
    compactDrawer,
    copySelection,
    cutSelection,
    deleteSelection,
    duplicateSelection,
    newDocument,
    openDocument,
    pasteSelection,
    reloadDocument,
    resetWorkspace,
    restoreHistory,
    run,
    saveCurrentDocument,
    saveDocument,
    selectTool,
    smoothSelectedArcTangencies,
    state?.entities,
    setDocumentViewMode,
    setCompactDrawer,
    setInspectorOpen,
    layout.mode,
    setOutputOrientation,
  ]);

  const selectedEntity = selected.size === 1 ? state?.entities.find((entity) => selected.has(entity.id)) : undefined;
  const selectedDerivedElement = selectedEntity
    ? state?.derivedElements.find(
        (element) =>
          element.id ===
          state?.drawingEntityMetadata.find((item) => item.entityId === selectedEntity.id)?.derivedElementId,
      )
    : undefined;
  const selectedPartId = settingPartOriginId ?? inspectorSelectedPartId;
  const selectedInspectorPart = state?.parts.find((part) => part.id === inspectorSelectedPartId);
  const selectedPart = state?.parts.find((part) => part.id === selectedPartId);
  const selectedPartHighlights = partCanvasHighlights(
    selectedInspectorPart,
    state?.drawingEntityMetadata ?? [],
    state?.stitchStartPoints ?? [],
  );
  const selectedStitchStartPoint = state?.stitchStartPoints.find((item) => item.id === selectedStitchStartPointId);
  const inspectorProps = {
    selectedCount: selected.size,
    documentSummary: {
      viewMode: state?.viewMode === "outputPreview" ? appStrings.canvas.outputPreview : appStrings.canvas.editDisplay,
      activeLayerName: state?.layers.find((layer) => layer.id === activeLayer)?.name ?? "—",
      visibleEntityCount: visibleEntities.length,
      constraintCount: state?.constraints.length ?? 0,
      parameterCount: state?.parameters.length ?? 0,
    },
    selectedEntityIds: [...selected],
    selectedEntity,
    selectedEntities: (state?.entities ?? []).filter((entity) => selected.has(entity.id)),
    selectedDerivedElement,
    selectedFreeText: state?.freeTexts.find((item) => item.id === selectedFreeTextId),
    selectedConstraint: state?.constraints.find((item) => item.id === selectedConstraintId),
    selectedMeasurement: state?.measurementAnnotations.find((item) => item.id === selectedMeasurementId),
    selectedStitchStartPoint,
    selectedStitchTargetEntity: state?.entities.find(
      (entity) => entity.id === selectedStitchStartPoint?.targetEntityId,
    ),
    constraints: state?.constraints ?? [],
    measurements: state?.measurementAnnotations ?? [],
    freeTexts: state?.freeTexts ?? [],
    parameters: state?.parameters ?? [],
    layers: state?.layers ?? [],
    activeLayerId: activeLayer,
    sharedStyles: state?.sharedStyles ?? [],
    parts: state?.parts ?? [],
    arrangementPartIds,
    partLibrary,
    roundHoles: state?.roundHoles ?? [],
    onCommand: executeCommand,
    onApplyStyle: applyActiveStyle,
    onDeleteSelection: deleteSelection,
    onCreatePart: createPart,
    onAddParameter: addParameter,
    onAddLayer: addLayer,
    onActiveLayerChange: setActiveLayer,
    onDeleteLayer: deleteLayer,
    onRenameLayer: renameLayer,
    onSelectPart: selectPartContents,
    onToggleArrangementPart: toggleArrangementPart,
    onAlignParts: alignParts,
    onDistributeParts: distributeParts,
    onAddPartToLibrary: (part: Part) => void addPartToLibrary(part),
    onInsertPartFromLibrary: insertPartFromLibrary,
    onRemovePartFromLibrary: removePartFromLibrary,
    onConstrainSegmentLength: (entityId: string) => void constrainSegmentLengthFromInspector(entityId),
    onSelectConstraint: selectConstraint,
    onSelectFreeText: selectFreeText,
    onSelectMeasurement: selectMeasurement,
    onConvertMeasurement: convertMeasurement,
    onBeginSetPartOrigin: beginSetPartOrigin,
    onTabChange: setInspectorTab,
  } satisfies ComponentProps<typeof InspectorPanel>;

  return (
    <main
      className={`app-shell layout-${layout.mode}${layout.toolDockVisible ? "" : " tool-palette-hidden"}`}
      style={{ "--tool-palette-width": `${toolPaletteWidth}px` } as CSSProperties}
      aria-label={
        state
          ? documentWindowPresentation(state.snapshot.name, state.persistence.path, state.persistence.isDirty)
              .accessibilityLabel
          : undefined
      }
    >
      {layout.toolDockVisible && (
        <>
          <ToolPalette
            activeStyle={activeStyle}
            sharedStyles={state?.sharedStyles ?? []}
            activeTool={tool}
            roundDiameter={roundDiameter}
            roundKind={roundKind}
            selectedCount={selected.size}
            basicOnly={basicToolsOnly}
            collapsedGroups={collapsedToolGroups}
            onActiveStyleChange={setActiveStyle}
            onToolChange={selectTool}
            onRoundDiameterChange={setRoundDiameter}
            onRoundKindChange={setRoundKind}
            onBasicOnlyChange={setBasicToolsOnly}
            onCollapsedGroupsChange={setCollapsedToolGroups}
            onApplyStyle={applyActiveStyle}
          />
          <PaletteResizeHandle
            value={toolPaletteWidth}
            min={toolPaletteWidthRange.min}
            max={toolPaletteWidthRange.max}
            onChange={setToolPaletteWidth}
          />
        </>
      )}
      <section className="workspace-column">
        <DocumentHeader
          ref={documentHeader}
          documentName={
            state?.snapshot.name === "Untitled"
              ? appStrings.document.untitled
              : (state?.snapshot.name ?? appStrings.document.untitled)
          }
          paperLabel={a4Landscape ? appStrings.app.paperLandscape : appStrings.app.paperPortrait}
          onRename={renameDocument}
        />
        {errorPresentation && <AppErrorBanner presentation={errorPresentation} onDismiss={dismissPresentedError} />}
        {recoveryEffects.saveFailure && (
          <RecoverySaveFailureBanner
            details={recoveryEffects.saveFailure}
            onRetry={() => void recoveryEffects.retry()}
            onDismiss={recoveryEffects.dismiss}
          />
        )}
        {documentWarning && (
          <aside className="document-warning-banner" role="alert">
            <span>{documentWarning}</span>
            <button type="button" onClick={() => setDocumentWarning(undefined)}>
              {appStrings.common.close}
            </button>
          </aside>
        )}
        {recoveryCandidates.length > 0 && (
          <RecoveryChooserDialog
            candidates={recoveryCandidates}
            onRestore={recoverySnapshot.restoreRecoverySnapshot}
            onDiscard={recoverySnapshot.discardRecoverySnapshot}
            onReveal={recoverySnapshot.revealRecoverySnapshot}
            onPostpone={recoverySnapshot.postponeRecoverySnapshot}
          />
        )}
        {pendingConstraintValue && (
          <ConstraintValueDialog
            label={names[pendingConstraintValue.candidate]}
            initialValue={pendingConstraintValue.preflight.value}
            parameters={state?.parameters ?? []}
            degrees={pendingConstraintValue.candidate === "angle"}
            floating
            floatingPosition={pendingConstraintValue.hudPosition}
            onConfirm={(value) =>
              void commitConstraint(pendingConstraintValue.candidate, pendingConstraintValue.preflight, value)
            }
            onCancel={() => setPendingConstraintValue(undefined)}
          />
        )}
        {pendingDerivedValue && (
          <DerivedValueDialog
            kind={pendingDerivedValue.candidate}
            offsetOptions={pendingDerivedValue.preflight.offsetOptions}
            sourceCount={pendingDerivedValue.preflight.sourceEntityIds.length}
            parameters={state?.parameters ?? []}
            floating={pendingDerivedValue.candidate === "fillet"}
            valueText={pendingDerivedValue.valueText}
            entryMode={pendingDerivedValue.entryMode}
            parameterId={pendingDerivedValue.parameterId}
            onValueTextChange={(valueText) => setPendingDerivedValue((current) => current && { ...current, valueText })}
            onEntryModeChange={(entryMode) => setPendingDerivedValue((current) => current && { ...current, entryMode })}
            onParameterIdChange={(parameterId) =>
              setPendingDerivedValue((current) => current && { ...current, parameterId })
            }
            onConfirm={(value, option) => void commitDerived(pendingDerivedValue, value, option)}
            onCancel={() => {
              setPendingDerivedValue(undefined);
              if (pendingDerivedValue.candidate === "fillet") setSelected(new Set());
            }}
          />
        )}
        {pendingTextEntry && (
          <TextEntryDialog
            title={pendingTextEntry.title}
            fields={pendingTextEntry.fields}
            onConfirm={(values) => {
              pendingTextEntry.onConfirm(values);
              setPendingTextEntry(undefined);
            }}
            onCancel={() => setPendingTextEntry(undefined)}
          />
        )}
        {layerDeletionConfirmation && (
          <LayerDeletionDialog
            layerName={layerDeletionConfirmation.name}
            affectedCount={layerDeletionConfirmation.affectedCount}
            onConfirm={confirmDeleteLayer}
            onCancel={cancelDeleteLayer}
          />
        )}
        {documentSaveConfirmation && (
          <DocumentSaveConfirmationDialog
            reason={documentSaveConfirmation.reason}
            onChoose={resolveDocumentSaveConfirmation}
          />
        )}
        {licensesOpen && <OpenSourceLicensesDialog onClose={() => setLicensesOpen(false)} />}
        {outputDestination && (
          <OutputDialog
            documentName={state?.snapshot.name ?? appStrings.document.untitled}
            initialOrientation={a4Landscape ? "landscape" : "portrait"}
            initialDestination={outputDestination}
            onClose={() => setOutputDestination(undefined)}
            onSaved={(path) => setMessage(`PDFを保存しました: ${path}`)}
            onPrinted={() => setMessage("印刷ジョブを開始しました。")}
          />
        )}
        <CadToolbar
          tool={tool}
          layers={state?.layers ?? []}
          activeLayer={activeLayer}
          viewMode={state?.viewMode ?? "editDisplay"}
          clipboardAvailable={Boolean(clipboard)}
          selectedCount={selected.size}
          constraintStatuses={
            state?.snapshot.constraintStatus
              ? [state.snapshot.constraintStatus]
              : (state?.constraints ?? []).map((constraint) => constraint.status)
          }
          zoomPercent={Math.round(viewport.zoom * 100)}
          gridVisible={gridVisible}
          a4Visible={a4Visible}
          a4Landscape={a4Landscape}
          snapEnabled={snapEnabled}
          pointSnapEnabled={pointSnapEnabled}
          onCopy={() => void copySelection()}
          onPaste={() => pasteSelection()}
          onDuplicate={duplicateSelection}
          onLayerChange={setActiveLayer}
          onViewModeChange={setDocumentViewMode}
          onViewportChange={setViewport}
          onGridChange={setGridVisible}
          onA4Change={setA4Visible}
          onA4LandscapeChange={(value) => {
            setOutputOrientation(value);
          }}
          onSnapChange={setSnapEnabled}
          onPointSnapChange={setPointSnapEnabled}
          showToolPaletteButton={layout.mode === "compact"}
          onToggleInspector={() =>
            layout.mode === "compact"
              ? setCompactDrawer((value) => (value === "inspector" ? undefined : "inspector"))
              : setInspectorOpen((value) => !value)
          }
          onToggleTools={() => setCompactDrawer((value) => (value === "tools" ? undefined : "tools"))}
        />
        <section className="workspace">
          <section className="canvas-area">
            <CadCanvas
              entities={canvasState?.entities ?? []}
              layers={canvasState?.layers ?? []}
              sharedStyles={canvasState?.sharedStyles ?? []}
              freeTexts={canvasState?.freeTexts ?? []}
              editingFreeText={state?.freeTexts.find((item) => item.id === editingFreeTextId)}
              highlightedFreeTextIds={selectedPartHighlights.freeTextIds}
              highlightedMeasurementAnnotationIds={selectedPartHighlights.measurementAnnotationIds}
              highlightedStitchStartPointIds={selectedPartHighlights.stitchStartPointIds}
              selectedIds={selected}
              selectedMeasurementAnnotationId={selectedMeasurementId}
              selectedStitchStartPointId={selectedStitchStartPointId}
              viewport={viewport}
              gridVisible={gridVisible}
              a4Visible={a4Visible}
              a4Landscape={a4Landscape}
              outputPreview={state?.viewMode === "outputPreview"}
              outputPages={state?.outputPreview?.pages ?? []}
              pendingTargetCount={pendingTargets.length}
              filletDraftEntityCount={
                pendingDerivedValue?.candidate === "fillet" ? pendingDerivedValue.preflight.sourceEntityIds.length : 0
              }
              filletDraftClosed={
                pendingDerivedValue?.candidate === "fillet" ? pendingDerivedValue.preflight.closed : false
              }
              settingPartOrigin={Boolean(settingPartOriginId)}
              selectedPartOrigin={selectedPart?.visible ? selectedPart.originMm : undefined}
              draftPoints={draft}
              cursorPoint={cursorPoint}
              arcSweepAngleRad={arcSweepAngle.current}
              hoveredConstraintId={hoveredConstraintId}
              pendingTargetEntityIds={new Set(pendingTargets.map(constraintTargetEntityId))}
              marqueeStart={marquee.current}
              marqueeCurrent={marquee.current ? marqueeCurrent : undefined}
              dragDuplicating={dragDuplicating}
              dragging={Boolean(move.current)}
              snapActive={snapActive}
              snapSuppressed={snapSuppressed}
              hoveredTargetEntityId={hoveredTargetEntityId}
              coincidentPointGroups={canvasState?.coincidentPointGroups}
              tool={tool}
              toolName={names[tool]}
              projection={canvasProjection}
              measurementLabels={measurementLabels}
              measurementLabelOffsets={measurementLabelOffsets}
              dimensionLabels={dimensionLabels}
              dimensionLabelOffsets={dimensionLabelOffsets}
              measurementArcCounterclockwise={measurementArcCounterclockwise}
              dimensionArcCounterclockwise={dimensionArcCounterclockwise}
              onPointerDown={handleCanvasPoint}
              onPointerMove={canvasMove}
              onPointerUp={canvasUp}
              onDoubleClick={handleCanvasDoubleClick}
              onCommitFreeText={commitFreeTextEdit}
              onCancelFreeText={cancelFreeTextEdit}
              onWheel={handleCanvasWheel}
              onContextMenu={handleCanvasContextMenu}
            />
            <div className="canvas-hud" aria-hidden="true">
              {appStrings.app.hud(Math.round(viewport.zoom * 100), selected.size)}
            </div>
            {pasteOptions && (
              <PasteOptionsOverlay
                activeMode={pasteOptions.activeMode}
                canPlaceAtCursor={Boolean(pasteOptions.cursorPoint)}
                onSelectMode={(mode) => void selectPastePlacement(mode)}
                onDismiss={() => setPasteOptions(undefined)}
              />
            )}
            {contextMenu && (
              <CanvasContextMenu
                position={contextMenu}
                selectionKind={contextMenu.selectionKind}
                hasSelection={contextMenu.selectionKind !== "none"}
                canPaste={Boolean(clipboard)}
                onCopy={() => void copySelection()}
                onPaste={pasteSelection}
                onDuplicate={duplicateSelection}
                onDelete={deleteSelection}
                onConvertMeasurement={() => {
                  if (selectedMeasurementId)
                    convertMeasurement(selectedMeasurementId, appStrings.app.measurementConvertedShort);
                }}
                onEditFreeText={() => {
                  if (selectedFreeTextId) setEditingFreeTextId(selectedFreeTextId);
                }}
                canSmoothArcTangencies={Boolean(
                  selectedSourceArcId(selected, state?.entities ?? [], state?.drawingEntityMetadata ?? []),
                )}
                onSmoothArcTangencies={smoothSelectedArcTangencies}
                onSelectAll={() => setSelected(new Set(state?.entities.map((entity) => entity.id) ?? []))}
                onDismiss={() => {
                  setContextMenu(undefined);
                }}
              />
            )}
          </section>
          {inspectorOpen && layout.mode !== "compact" && (
            <WorkspaceInspector mode="docked" revision={inspectorRevision} inspector={inspectorProps} />
          )}
          {layout.mode === "compact" && compactDrawer === "tools" && (
            <aside className="compact-drawer compact-tools-drawer" aria-label={appStrings.app.toolDrawer}>
              <ToolPalette
                activeStyle={activeStyle}
                sharedStyles={state?.sharedStyles ?? []}
                activeTool={tool}
                roundDiameter={roundDiameter}
                roundKind={roundKind}
                selectedCount={selected.size}
                basicOnly={basicToolsOnly}
                collapsedGroups={collapsedToolGroups}
                onActiveStyleChange={setActiveStyle}
                onToolChange={(next) => {
                  selectTool(next);
                  setCompactDrawer(undefined);
                }}
                onRoundDiameterChange={setRoundDiameter}
                onRoundKindChange={setRoundKind}
                onBasicOnlyChange={setBasicToolsOnly}
                onCollapsedGroupsChange={setCollapsedToolGroups}
                onApplyStyle={applyActiveStyle}
              />
            </aside>
          )}
          {layout.mode === "compact" &&
            (compactDrawer === "tools" || (compactDrawer === "inspector" && inspectorOpen)) && (
              <button
                type="button"
                className="compact-drawer-backdrop"
                aria-label={appStrings.accessibility.dismissDrawer}
                onClick={() => setCompactDrawer(undefined)}
              />
            )}
          {layout.mode === "compact" && compactDrawer === "inspector" && inspectorOpen && (
            <WorkspaceInspector
              mode="compact"
              revision={inspectorRevision}
              inspector={{
                ...inspectorProps,
                onBeginSetPartOrigin: (part) => {
                  setSettingPartOriginId(part.id);
                  setCompactDrawer(undefined);
                },
              }}
            />
          )}
        </section>
        {bottomWorkbenchVisible && (
          <BottomWorkbench
            selectedEntity={selectedEntity}
            layers={state?.layers ?? []}
            constraints={state?.constraints ?? []}
            parameters={state?.parameters ?? []}
          />
        )}
        <footer className="statusbar" data-testid={accessibilityIdentifiers.workspaceStatusBar}>
          <span>
            <span className="statusbar-item">
              <CircleDot size={12} strokeWidth={1.8} aria-hidden="true" />
              {appStrings.app.statusGeometry(visibleEntities.length)}
            </span>{" "}
            ·{" "}
            <span className="statusbar-item">
              <MousePointer2 size={12} strokeWidth={1.8} aria-hidden="true" />
              {selected.size ? appStrings.app.statusSelection(selected.size) : appStrings.app.statusNoSelection}
            </span>{" "}
            ·{" "}
            {cursorPoint ? (
              <span className="statusbar-item">
                <MapPin size={12} strokeWidth={1.8} aria-hidden="true" />
                {appStrings.app.statusCoordinates(cursorPoint.xMm, cursorPoint.yMm)}
              </span>
            ) : (
              <span className="statusbar-item">
                <MapPin size={12} strokeWidth={1.8} aria-hidden="true" />
                {appStrings.app.statusNoCoordinates}
              </span>
            )}
          </span>
          {state?.viewMode === "outputPreview" && (
            <span>
              <FileOutput size={12} strokeWidth={1.8} aria-hidden="true" />{" "}
              {state.outputPreview?.warnings.length
                ? appStrings.app.outputWarnings(state.outputPreview.warnings.length)
                : appStrings.app.outputPages(state.outputPreview?.pages.length ?? 0)}
            </span>
          )}
          <span className="statusbar-item" role="status" aria-live="polite">
            <Info size={12} strokeWidth={1.8} aria-hidden="true" />
            {message}
          </span>
          <button
            type="button"
            className="statusbar-summary-toggle"
            aria-label={bottomWorkbenchVisible ? appStrings.app.statusSummaryHide : appStrings.app.statusSummaryShow}
            onClick={() =>
              setBottomWorkbenchVisible((visible) => {
                setMessage(visible ? appStrings.status.summaryHidden : appStrings.status.summaryShown);
                return !visible;
              })
            }
          >
            {bottomWorkbenchVisible ? appStrings.app.statusSummaryHide : appStrings.app.statusSummaryShow}
          </button>
        </footer>
      </section>
    </main>
  );
}
