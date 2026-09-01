import { useEffect, useMemo, useRef } from "react";
import { AlertTriangle } from "lucide-react";
import { ToolPalette } from "@/features/canvas/components/ToolPalette";
import { WorkspaceInspector } from "@/features/inspector/components/WorkspaceInspector";
import { CADToolbar } from "@/features/canvas/components/CadToolbar";
import { BottomWorkbench } from "@/features/workspace/components/BottomWorkbench";
import { DocumentSaveConfirmationDialog } from "@/features/document/components/DocumentSaveConfirmationDialog";
import { PanelResizeHandle } from "@/features/workspace/components/PanelResizeHandle";
import { WorkspaceCanvasSurface } from "@/features/workspace/components/WorkspaceCanvasSurface";
import { WorkspaceCanvasLayout } from "@/features/workspace/components/WorkspaceCanvasLayout";
import { CanvasStatusBar } from "@/features/canvas/components/CanvasStatusBar";
import type { PastePlacementMode } from "@/features/document/components/PasteOptionsOverlay";
import { WorkspaceBanners } from "@/features/workspace/components/WorkspaceBanners";
import { ConstraintValueDialog } from "@/features/constraints/components/ConstraintValueDialog";
import {
  DerivedValueDialog,
  type DerivedValue,
  type OffsetSourceOption,
} from "@/features/constraints/components/DerivedValueDialog";
import { LayerDeletionDialog } from "@/features/document/components/LayerDeletionDialog";
import { TextEntryDialog, type TextEntryField } from "@/shared/components/TextEntryDialog";
import type { MenuAction } from "@/app/domain/nativeMenuTypes";
import type { CSSProperties } from "react";
import { appStrings } from "@/localization";
import type { CanvasViewMode, Tool } from "@/features/canvas/domain/canvasDomainModels";
import { defaultViewport, constraintTargetEntityId, type ConstraintTarget } from "@/features/canvas/domain/cad";
import { canvasContextMenuModelFor } from "@/features/canvas/selectors/canvasContextMenuModel";
import { canvasDisplayStateFor, visibleEntitiesFor } from "@/features/canvas/selectors/canvasDisplayState";
import { partCanvasHighlights } from "@/features/parts/selectors/partCanvasHighlights";
import { compactInspectorViewModelFor, inspectorViewModelFor } from "@/features/inspector/selectors/inspectorViewModel";
import { inspectorActionModelsFor } from "@/features/inspector/selectors/inspectorActionModels";
import {
  documentDisplayName,
  documentWindowPresentation,
} from "@/features/workspace/selectors/documentWindowPresentation";
import {
  assistLine,
  constraintTools,
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
  type SelectionExport,
} from "@/features/canvas/state/useCanvasPresentation";
import { useCanvasInteractionController } from "@/features/canvas/actions/useCanvasInteractionController";
import { useDocumentPresentation } from "@/features/document/state/useDocumentPresentation";
import { useInspectorPresentation } from "@/features/inspector/state/useInspectorPresentation";
import { useOutputPresentation } from "@/features/output/state/useOutputPresentation";
import { useLicensesPresentation } from "@/features/licenses/state/useLicensesPresentation";
import { useAppActions } from "@/app/actions/useAppActions";
import { useDocumentLifecycleComposition } from "@/app/actions/useDocumentLifecycleComposition";
import { RecoveryChooserDialog } from "@/features/recovery/components/RecoveryChooserDialog";
import { useActiveDrawingOptions } from "@/features/canvas/selectors/useActiveDrawingOptions";
import { useWindowLifecycle } from "@/features/workspace/effects/useWindowLifecycle";
import { useNativeMenuSynchronization } from "@/features/workspace/effects/useNativeMenuSynchronization";
import { useGlobalCommands } from "@/features/workspace/effects/useGlobalCommands";
import { useGlobalInteractionCancellation } from "@/features/workspace/effects/useGlobalInteractionCancellation";
import { useCompactInspectorActions } from "@/features/workspace/effects/useCompactInspectorActions";
import { useRecoveryEffects } from "@/features/recovery/effects/useRecoveryEffects";
import { OpenSourceLicensesDialog } from "@/features/licenses/components/OpenSourceLicensesDialog";
import { OutputDialog } from "@/features/output/components/OutputDialog";

export function MainWindowView() {
  const { licensesOpen, setLicensesOpen } = useLicensesPresentation();
  const { outputDestination, setOutputDestination } = useOutputPresentation();
  const {
    inspectorTab,
    setInspectorTab,
    arrangementPartIds,
    setArrangementPartIds,
    inspectorSelectedPartId,
    setInspectorSelectedPartId,
    settingPartOriginId,
    setSettingPartOriginId,
    clearInspectorSelectedPart,
    clearPartOriginSelection,
    inspectorRevision,
    setInspectorRevision,
  } = useInspectorPresentation();
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
    hasHoveredCanvasTarget,
    pan,
    marquee,
    move,
    controlMove,
    measurementMove,
    dimensionMove,
    freeTextMove,
    arcSweepAngle,
    lineStartSnap,
    selectedFreeTextId,
    setSelectedFreeTextId,
    clearSelectedFreeText,
    selectedConstraintId,
    setSelectedConstraintId,
    clearSelectedConstraint,
    selectedMeasurementId,
    setSelectedMeasurementId,
    clearSelectedMeasurement,
    selectedStitchStartPointId,
    setSelectedStitchStartPointId,
    clearSelectedStitchStartPoint,
    clearAnnotationSelection,
  } = canvasPresentation;
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
    documentSaveConfirmation,
    requestDocumentSaveConfirmation,
    resolveDocumentSaveConfirmation,
    clearLayerDeletionConfirmation,
  } = useDocumentPresentation();
  const {
    layout,
    toolPaletteWidth,
    setToolPaletteWidth,
    setToolPaletteVisible,
    compactDrawer,
    setCompactDrawer,
    closeCompactDrawer,
    resetWorkspaceLayout,
  } = useWorkspaceLayout();
  const canvasState = previewState ?? state;
  const selectToolRef = useRef<(nextTool: Tool) => void>(() => undefined);
  const rewindFilletDraftRef = useRef<() => void>(() => undefined);
  const {
    projection: canvasProjection,
    measurementLabels,
    measurementLabelOffsets,
    measurementArcCounterclockwise,
    dimensionLabels,
    dimensionLabelOffsets,
    dimensionArcCounterclockwise,
  } = canvasDisplayStateFor(canvasState);
  const visibleEntities = useMemo(() => visibleEntitiesFor(state), [state]);
  const canvasInteraction = useCanvasInteractionController({
    canvas: canvasPresentation.interaction,
    previewActive,
    clearCanvasPreview,
    setMessage,
    selectTool: (nextTool) => selectToolRef.current(nextTool),
    rewindFilletDraft: () => rewindFilletDraftRef.current(),
  });
  const { clearTransientCanvasState, resetCanvasPresentation } = canvasInteraction;
  const documentLifecycle = useDocumentLifecycleComposition({
    resetCanvasPresentation,
    clearTransientCanvasState,
    clearInspectorSelection: clearInspectorSelectedPart,
    clearPartOriginSelection,
    closeWorkspacePanels: closeCompactDrawer,
  });

  const actions = useAppActions(
    {
      state,
      run,
      command,
      onDocumentLoaded: documentLifecycle.onDocumentLoaded,
      onHistoryRestored: documentLifecycle.onHistoryRestored,
      canvas: {
        cursorPoint,
        activeStyle,
        startPastePlacement: canvasPresentation.setPastePlacement,
        clearPastePlacement: () => canvasPresentation.setPastePlacement(undefined),
        clearFreeTextEdit: canvasPresentation.clearFreeTextEdit,
      },
      layerDeletionConfirmation,
      showLayerDeletionConfirmation: setLayerDeletionConfirmation,
      clearLayerDeletionConfirmation,
      presentOperationFailure,
      selection: canvasPresentation.documentSelection,
      presentTextEntry: canvasPresentation.setPendingTextEntry,
      clearPendingTextEntry: canvasPresentation.clearPendingTextEntry,
      setMessage,
      requestDocumentSaveConfirmation,
      clipboard,
      storeSelectionExport: canvasPresentation.storeSelectionExport,
      pasteOptions,
      pasteSequence,
      advancePasteSequence: canvasPresentation.advancePasteSequence,
    },
    canvasPresentation,
    {
      document: {
        state,
        command,
        applyState,
        clearCanvasPreview,
        previewCommand,
        presentOperationFailure,
        setMessage,
      },
      render: {
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
      },
      externalSelection: {
        clearInspectorSelectedPart,
        clearPartOriginSelection,
        settingPartOriginId,
        inspectorSelectedPartId,
      },
    },
    {
      invalidate: () => setInspectorRevision((revision) => revision + 1),
      selection: {
        clearEntities: () => setSelected(new Set()),
        selectConstraint: setSelectedConstraintId,
        selectFreeText: setSelectedFreeTextId,
        selectStitchStartPoint: setSelectedStitchStartPointId,
        selectMeasurement: setSelectedMeasurementId,
      },
      clearInspectorSelectedPart,
    },
    { state, a4Landscape, run, setTool },
    {
      state,
      canvas: { cursorPoint },
      command,
      selection: {
        selected,
        replace: setSelected,
        clearFreeText: clearSelectedFreeText,
        clearConstraint: clearSelectedConstraint,
      },
      inspector: {
        selectPart: setInspectorSelectedPartId,
        beginPartOrigin: setSettingPartOriginId,
      },
      setMessage,
      partLibrary,
      updatePartLibrary,
      presentOperationFailure,
      arrangementPartIds,
      toggleArrangementPart: (partId) =>
        setArrangementPartIds((current) =>
          current.has(partId) ? new Set([...current].filter((id) => id !== partId)) : new Set([...current, partId]),
        ),
    },
    { setViewport, resetWorkspacePreferences, resetWorkspaceLayout, setMessage },
  );
  const documentActions = actions.document;
  const canvasActions = actions.canvas;
  const inspectorActions = actions.inspector;
  const outputActions = actions.output;
  const partActions = actions.parts;
  const workspaceActions = actions.workspace;
  const {
    openTextEntry,
    saveBeforeDestructiveAction,
    resolveDirtyReplacement,
    newDocument,
    openDocument,
    saveDocument,
    saveCurrentDocument,
    reloadDocument,
    restoreHistory,
    addLayer,
    deleteLayer,
    addParameter,
    renameLayer,
    applyActiveStyle,
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
  } = documentActions;
  const { setDocumentViewMode, setOutputOrientation } = outputActions;
  const {
    selectTool,
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
    smoothSelectedArcTangencies,
    handleCanvasPoint,
    canvasMove,
    canvasLeave,
    canvasUp,
    handleCanvasDoubleClick,
    handleCanvasWheel,
    handleCanvasContextMenu,
    convertMeasurement,
  } = canvasActions;
  selectToolRef.current = selectTool;
  rewindFilletDraftRef.current = rewindFilletDraft;
  const { resetInspectorPresentation, selectConstraint, selectFreeText, selectMeasurement } = inspectorActions;
  const {
    createPart,
    selectPartContents,
    addPartToLibrary,
    insertPartFromLibrary,
    toggleArrangementPart,
    alignParts,
    distributeParts,
    removePartFromLibrary,
    beginSetPartOrigin,
  } = partActions;
  const { resetWorkspace } = workspaceActions;
  const cancelCurrentInteraction = useGlobalInteractionCancellation({
    cancelCanvasInteraction: canvasInteraction.cancelCurrentInteraction,
    layerDeletionConfirmationOpen: Boolean(layerDeletionConfirmation),
    dismissLayerDeletionConfirmation: clearLayerDeletionConfirmation,
    compactDrawerOpen: Boolean(compactDrawer),
    closeCompactDrawer,
    partOriginSelectionActive: Boolean(settingPartOriginId),
    clearPartOriginSelection,
    inspectorPartSelectionActive: Boolean(inspectorSelectedPartId),
    clearInspectorPartSelection: clearInspectorSelectedPart,
    announceInspectorPartSelectionCleared: () => setMessage(appStrings.status.partSelectionCleared),
  });
  useGlobalCommands({
    document: {
      documentActions,
      selectAllEntities: () => setSelected(new Set(state?.entities.map((entity) => entity.id) ?? [])),
    },
    canvas: {
      canvasActions,
      cancelCurrentInteraction,
      zoomToFit: () => setViewport(defaultViewport),
    },
    presentation: {
      outputActions,
      compactDrawer,
      layoutMode: layout.mode,
      a4Landscape,
      setOutputDestination,
      setOutputOrientation,
      setLicensesOpen,
      setInspectorOpen,
      setToolPaletteVisible,
      setBottomWorkbenchVisible,
      setCompactDrawer,
      setMessage,
      resetWorkspace,
    },
  });
  const recoverySnapshot = useRecoverySnapshot({
    execute: run,
    report: setMessage,
    onRestored: resetInspectorPresentation,
  });
  const { recoveryCandidates } = recoverySnapshot;
  useWindowLifecycle({
    state,
    allowWindowClose,
    saveBeforeDestructiveAction,
    presentOperationFailure,
    requestDocumentSaveConfirmation,
  });
  const recoveryEffects = useRecoveryEffects({ state });
  useEffect(() => {
    void refresh().then(() => setMessage(appStrings.status.readyToDraw));
  }, [refresh]);
  useEffect(() => {
    const warning = state?.warnings.find((item) => item.message)?.message;
    if (warning) setDocumentWarning(warning);
  }, [state?.warnings]);
  useEffect(() => {
    if (layout.mode === "compact" && inspectorOpen && selected.size) setCompactDrawer("inspector");
  }, [inspectorOpen, layout.mode, selected]);
  useNativeMenuSynchronization({
    state,
    selected,
    selectedFreeTextId,
    selectedConstraintId,
    selectedMeasurementId,
    selectedStitchStartPointId,
    clipboardAvailable: Boolean(clipboard),
    inspectorOpen,
    compactDrawer,
    layoutMode: layout.mode,
    toolPaletteVisible: layout.toolDockVisible,
    inspectorTab,
    bottomWorkbenchVisible,
  });

  const selectedPartId = settingPartOriginId ?? inspectorSelectedPartId;
  const selectedInspectorPart = state?.parts.find((part) => part.id === inspectorSelectedPartId);
  const selectedPart = state?.parts.find((part) => part.id === selectedPartId);
  const selectedPartHighlights = partCanvasHighlights(
    selectedInspectorPart,
    state?.drawingEntityMetadata ?? [],
    state?.stitchStartPoints ?? [],
  );
  const {
    selectionActions,
    layerActions,
    styleActions,
    parameterActions,
    partActions: inspectorPartActions,
  } = inspectorActionModelsFor({
    executeCommand,
    selection: {
      applyStyle: applyActiveStyle,
      deleteSelection,
      constrainSegmentLength: (entityId) => void constrainSegmentLengthFromInspector(entityId),
      selectConstraint,
      selectFreeText,
      selectMeasurement,
      convertMeasurement: (id) => void convertMeasurement(id),
    },
    layers: { addLayer, changeActiveLayer: setActiveLayer, renameLayer, deleteLayer },
    parameters: { add: addParameter },
    parts: {
      create: createPart,
      select: selectPartContents,
      align: alignParts,
      distribute: distributeParts,
      insertFromLibrary: insertPartFromLibrary,
      removeFromLibrary: removePartFromLibrary,
      addToLibrary: addPartToLibrary,
      toggleArrangement: toggleArrangementPart,
      beginSetOrigin: beginSetPartOrigin,
    },
  });
  const inspectorProps = inspectorViewModelFor({
    state,
    selected,
    activeLayer,
    visibleEntityCount: visibleEntities.length,
    arrangementPartIds,
    partLibrary,
    inspectorSelectedPartId,
    settingPartOriginId,
    selectedFreeTextId,
    selectedConstraintId,
    selectedMeasurementId,
    selectedStitchStartPointId,
    shellActions: { onTabChange: setInspectorTab },
    selectionActions,
    layerActions,
    styleActions,
    parameterActions,
    partActions: inspectorPartActions,
  });
  const selectedEntity = inspectorProps.selection.selectedEntity;
  const compactInspectorActions = useCompactInspectorActions(setSettingPartOriginId, closeCompactDrawer);
  const compactInspectorProps = compactInspectorViewModelFor(
    inspectorProps,
    compactInspectorActions.beginSetPartOrigin,
  );
  const pasteOverlayProps = pasteOptions
    ? {
        activeMode: pasteOptions.activeMode,
        canPlaceAtCursor: Boolean(pasteOptions.cursorPoint),
        positionMm:
          pasteOptions.activeMode === "cursor" && pasteOptions.cursorPoint
            ? pasteOptions.cursorPoint
            : pasteOptions.nearSourcePoint,
        viewport,
        onSelectMode: (mode: PastePlacementMode) => void selectPastePlacement(mode),
        onDismiss: () => setPasteOptions(undefined),
      }
    : undefined;
  const contextMenuProps = canvasContextMenuModelFor({
    contextMenu,
    clipboardAvailable: Boolean(clipboard),
    state,
    selectedEntityIDs: selected,
    selectedMeasurementID: selectedMeasurementId,
    selectedFreeTextID: selectedFreeTextId,
    copySelection: () => void copySelection(),
    pasteSelection,
    duplicateSelection,
    deleteSelection,
    convertMeasurement: (id) => convertMeasurement(id, appStrings.app.measurementConvertedShort),
    beginFreeTextEdit: setEditingFreeTextId,
    smoothSelectedArcTangencies,
    selectAllEntities: setSelected,
    dismiss: () => setContextMenu(undefined),
  });
  const canvasContentMoving = Boolean(
    move.current || controlMove.current || measurementMove.current || dimensionMove.current || freeTextMove.current,
  );

  return (
    <main
      className={`app-shell layout-${layout.mode}${layout.toolDockVisible ? "" : " tool-palette-hidden"}`}
      style={{ "--tool-palette-width": `${toolPaletteWidth}px` } as CSSProperties}
      aria-label={
        state
          ? documentWindowPresentation(state.persistence.path, state.persistence.isDirty).accessibilityLabel
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
          <PanelResizeHandle
            value={toolPaletteWidth}
            min={toolPaletteWidthRange.min}
            max={toolPaletteWidthRange.max}
            ariaLabel={appStrings.resize.paletteWidth}
            onChange={setToolPaletteWidth}
          />
        </>
      )}
      <section className="workspace-column">
        <WorkspaceBanners
          errorPresentation={errorPresentation}
          recoverySaveFailure={recoveryEffects.saveFailure}
          onDismissError={dismissPresentedError}
          onRetryRecovery={() => void recoveryEffects.retry()}
          onDismissRecovery={recoveryEffects.dismiss}
        />
        {documentWarning && (
          <aside className="document-warning-banner" role="alert">
            <AlertTriangle className="app-error-icon" size={16} strokeWidth={2} aria-hidden="true" />
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
            floatingPosition={pendingDerivedValue.hudPosition}
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
            documentName={documentSaveConfirmation.displayName}
            onChoose={resolveDocumentSaveConfirmation}
          />
        )}
        {licensesOpen && <OpenSourceLicensesDialog onClose={() => setLicensesOpen(false)} />}
        {outputDestination && (
          <OutputDialog
            documentName={documentDisplayName(state?.persistence.path).replace(/\.kawa$/i, "")}
            initialOrientation={a4Landscape ? "landscape" : "portrait"}
            initialDestination={outputDestination}
            onClose={() => setOutputDestination(undefined)}
            onSaved={(path) => setMessage(appStrings.output.exported(path))}
            onPrinted={() => setMessage(appStrings.output.directPrintStarted)}
          />
        )}
        <CADToolbar
          tool={tool}
          layers={state?.layers ?? []}
          activeLayer={activeLayer}
          viewMode={state?.viewMode ?? "editDisplay"}
          zoomPercent={Math.round(viewport.zoom * 100)}
          gridVisible={gridVisible}
          a4Visible={a4Visible}
          a4Landscape={a4Landscape}
          snapEnabled={snapEnabled}
          pointSnapEnabled={pointSnapEnabled}
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
          toolPaletteVisible={layout.mode !== "compact" && layout.toolDockVisible}
          onToggleInspector={() =>
            layout.mode === "compact"
              ? setCompactDrawer((value) => (value === "inspector" ? undefined : "inspector"))
              : setInspectorOpen((value) => !value)
          }
          onToggleTools={() => {
            if (layout.mode === "compact") setCompactDrawer((value) => (value === "tools" ? undefined : "tools"));
            else setToolPaletteVisible((value) => !value);
          }}
        />
        <WorkspaceCanvasLayout
          mode={layout.mode}
          inspectorOpen={inspectorOpen}
          compactDrawer={compactDrawer}
          canvas={
            <WorkspaceCanvasSurface
              canvas={{
                renderModel: {
                  entities: canvasState?.entities ?? [],
                  suppressedByFilletEntityIds: new Set(
                    (canvasState?.drawingEntityMetadata ?? [])
                      .filter((item) => item.suppressedByFillet)
                      .map((item) => item.entityId),
                  ),
                  layers: canvasState?.layers ?? [],
                  sharedStyles: canvasState?.sharedStyles ?? [],
                  freeTexts: canvasState?.freeTexts ?? [],
                  editingFreeTextId,
                  highlightedFreeTextIds: selectedPartHighlights.freeTextIds,
                  highlightedEntityIds: selectedPartHighlights.entityIds,
                  highlightedMeasurementAnnotationIds: selectedPartHighlights.measurementAnnotationIds,
                  highlightedStitchStartPointIds: selectedPartHighlights.stitchStartPointIds,
                  selectedIds: selected,
                  selectedMeasurementAnnotationId: selectedMeasurementId,
                  selectedConstraintId,
                  selectedStitchStartPointId,
                  viewport,
                  gridVisible,
                  a4Visible,
                  a4Landscape,
                  outputPreview: state?.viewMode === "outputPreview",
                  outputPages: state?.outputPreview?.pages ?? [],
                  selectedPartOrigin: selectedPart?.visible ? selectedPart.originMm : undefined,
                  draftPoints: draft,
                  cursorPoint,
                  arcSweepAngleRad: arcSweepAngle.current,
                  hoveredConstraintId,
                  pendingTargetEntityIds: new Set(pendingTargets.map(constraintTargetEntityId)),
                  marqueeStart: marquee.current,
                  marqueeCurrent: marquee.current ? marqueeCurrent : undefined,
                  dragDuplicating,
                  dragging: Boolean(move.current),
                  snapActive,
                  snapSuppressed,
                  hoveredTargetEntityId,
                  coincidentPointGroups: canvasState?.coincidentPointGroups ?? [],
                  tool,
                  projection: canvasProjection,
                  measurementLabels,
                  measurementLabelOffsets,
                  measurementArcCounterclockwise,
                  dimensionLabels,
                  dimensionLabelOffsets,
                  dimensionArcCounterclockwise,
                },
                interactionModel: {
                  editingFreeText: state?.freeTexts.find((item) => item.id === editingFreeTextId),
                  settingPartOrigin: Boolean(settingPartOriginId),
                  filletDraftEntityCount:
                    pendingDerivedValue?.candidate === "fillet"
                      ? pendingDerivedValue.preflight.sourceEntityIds.length
                      : 0,
                  filletDraftClosed:
                    pendingDerivedValue?.candidate === "fillet" ? pendingDerivedValue.preflight.closed : false,
                  pendingTargetCount: pendingTargets.length,
                  draftPointCount: draft.length,
                  dragDuplicating,
                  movingContent: canvasContentMoving,
                  hasHoveredCanvasTarget,
                  snapSuppressed,
                  topBannerVisible: Boolean(errorPresentation || recoveryEffects.saveFailure || documentWarning),
                  toolName: names[tool],
                },
                events: {
                  onPointerDown: handleCanvasPoint,
                  onPointerMove: canvasMove,
                  onPointerLeave: canvasLeave,
                  onPointerUp: canvasUp,
                  onDoubleClick: handleCanvasDoubleClick,
                  onCommitFreeText: commitFreeTextEdit,
                  onCancelFreeText: cancelFreeTextEdit,
                  onWheel: handleCanvasWheel,
                  onContextMenu: handleCanvasContextMenu,
                },
              }}
              hudText={appStrings.app.hud(Math.round(viewport.zoom * 100), selected.size)}
              pasteOptions={pasteOverlayProps}
              contextMenu={contextMenuProps}
            />
          }
          dockedInspector={<WorkspaceInspector mode="docked" revision={inspectorRevision} inspector={inspectorProps} />}
          compactToolDrawer={
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
          }
          compactInspectorDrawer={
            <WorkspaceInspector mode="compact" revision={inspectorRevision} inspector={compactInspectorProps} />
          }
          onDismissCompactDrawer={() => setCompactDrawer(undefined)}
        />
        {bottomWorkbenchVisible && (
          <BottomWorkbench
            selectedEntity={selectedEntity}
            layers={state?.layers ?? []}
            constraints={state?.constraints ?? []}
            parameters={state?.parameters ?? []}
          />
        )}
        <CanvasStatusBar
          visibleEntityCount={visibleEntities.length}
          selectedCount={selected.size}
          cursorPoint={cursorPoint}
          viewMode={state?.viewMode ?? "editDisplay"}
          outputWarningCount={state?.outputPreview?.warnings.length ?? 0}
          outputPageCount={state?.outputPreview?.pages.length ?? 0}
          message={message}
          summaryVisible={bottomWorkbenchVisible}
          onToggleSummary={() =>
            setBottomWorkbenchVisible((visible) => {
              setMessage(visible ? appStrings.status.summaryHidden : appStrings.status.summaryShown);
              return !visible;
            })
          }
        />
      </section>
    </main>
  );
}
