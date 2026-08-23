import CoreGraphics
import KawaCADOutput

struct WorkspaceViewPropsFactory {
  let actions: AppActionHandlers
  let inspectorPresentation: InspectorPresentationState
  let canvasPresentation: CanvasPresentationState
  private var handler: WorkspaceActionHandler { actions.workspace }

  init(
    actions: AppActionHandlers,
    inspectorPresentation: InspectorPresentationState,
    canvasPresentation: CanvasPresentationState
  ) {
    self.actions = actions
    self.inspectorPresentation = inspectorPresentation
    self.canvasPresentation = canvasPresentation
  }

  private var workspaceLayout: WorkspaceLayoutState { handler.workspaceLayout }
  private var workspacePreferences: WorkspacePreferencesState { handler.workspacePreferences }
  private var documentPresentation: DocumentPresentationState { handler.documentPresentation }
  private var outputPresentation: OutputPresentationState { handler.outputPresentation }
  private var recoverySnapshotState: RecoverySnapshotState { handler.recoverySnapshotState }
  private var errorPresentationState: AppErrorPresentationState { handler.errorPresentationState }
  private var layers: [ProjectLayer] { handler.layers }
  private var sharedStyles: [ProjectSharedStyle] { handler.sharedStyles }
  private var parameters: [ProjectParameter] { handler.parameters }
  private var constraints: [ProjectConstraint] { handler.constraints }
  private var entities: [CanvasEntity] { handler.entities }
  private var selectedEntityIDs: Set<String> { handler.selectedEntityIDs }
  private var selectedEntity: CanvasEntity? { handler.selectedEntity }
  private var selectedEntities: [CanvasEntity] { handler.selectedEntities }
  private var coreSnapshot: LeatherDocumentSnapshot? { handler.coreSnapshot }
  private var aggregatedConstraintStatus: ConstraintStatus { handler.aggregatedConstraintStatus }
  private var outputPreviewSummaryText: String? { handler.outputPreviewSummaryText }
  private var statusMessage: String { handler.statusMessage }
  private var documentName: String { handler.documentName }
  private var canRenameDocument: Bool { handler.canRenameDocument }
  private var unitLabel: String { handler.unitLabel }
  private var paperLabel: String {
    switch workspacePreferences.a4ReferenceOrientation {
    case .portrait:
      return AppStrings.tr("app.paper.a4_portrait")
    case .landscape:
      return AppStrings.tr("app.paper.a4_landscape")
    }
  }
  private func setToolPanelWidth(_ value: CGFloat) { handler.setToolPanelWidth(value) }
  private func setInspectorPanelWidth(_ value: CGFloat) { handler.setInspectorPanelWidth(value) }
  private func showCompactDrawer(_ drawer: CompactDrawer?) { handler.showCompactDrawer(drawer) }
  private func updateWindowLayoutMode(_ mode: WindowLayoutMode) {
    handler.updateWindowLayoutMode(mode)
  }
  private func setBottomWorkbenchVisible(_ visible: Bool) {
    handler.setBottomWorkbenchVisible(visible)
  }
  private func setDetailedToolsVisible(_ visible: Bool) { handler.setDetailedToolsVisible(visible) }
  private func setToolGroupCollapsed(_ collapsed: Bool, groupID: String) {
    handler.setToolGroupCollapsed(collapsed, groupID: groupID)
  }
  var workspaceViewState: WorkspaceViewState {
    WorkspaceViewState(
      toolPanelWidth: workspaceLayout.toolPanelWidth,
      inspectorPanelWidth: workspaceLayout.inspectorPanelWidth,
      inspectorPanelVisible: workspacePreferences.inspectorPanelVisible,
      compactDrawer: workspaceLayout.compactDrawer,
      windowLayoutMode: workspaceLayout.windowLayoutMode,
      toolbarState: toolbarState,
      documentHeaderState: documentHeaderState,
      toolPaletteState: toolPaletteState,
      canvasRenderInput: actions.canvas.canvasRenderInput,
      canvasInteractionInput: actions.canvas.canvasInteractionInput,
      constraintEntryHUDState: constraintEntryHUDState,
      canvasStatusBarState: canvasStatusBarState,
      bottomWorkbenchState: bottomWorkbenchState,
      inspectorPanelModel: InspectorFeatureModelFactory.make(
        actionHandlers: actions,
        inspectorPresentation: inspectorPresentation,
        canvasPresentation: canvasPresentation
      ),
      layerDeletionDialogState: layerDeletionDialogState,
      outputRequestSheetState: outputRequestSheetState,
      recoveryChooserState: recoveryChooserState,
      alertMessage: documentPresentation.alertMessage,
      outputRequestDraft: outputPresentation.requestDraft,
      documentSaveConfirmation: documentPresentation.saveConfirmation,
      recoveryChooser: recoverySnapshotState.chooser,
      recoveryBanner: recoverySnapshotState.banner,
      errorPresentation: errorPresentationState.presentation,
      pasteOptionsPresentation: documentPresentation.pasteOptions,
      bottomWorkbenchVisible: workspacePreferences.bottomWorkbenchVisible
    )
  }

  var workspaceViewActions: WorkspaceViewActions {
    WorkspaceViewActions(
      toolbarActions: toolbarActions,
      documentHeaderActions: documentHeaderActions,
      toolPaletteActions: toolPaletteActions,
      canvasActionGroups: actions.canvas.canvasActionGroups,
      constraintEntryHUDActions: constraintEntryHUDActions,
      canvasStatusBarActions: canvasStatusBarActions,
      layerDeletionDialogActions: layerDeletionDialogActions,
      outputRequestSheetActions: outputRequestSheetActions,
      documentSaveConfirmationActions: documentSaveConfirmationActions,
      recoveryChooserActions: recoveryChooserActions,
      setToolPanelWidth: { [self] in setToolPanelWidth($0) },
      setInspectorPanelWidth: { [self] in setInspectorPanelWidth($0) },
      showCompactDrawer: { [self] in showCompactDrawer($0) },
      updateWindowLayoutMode: { [self] in updateWindowLayoutMode($0) },
      dismissAlert: { [self] in documentPresentation.setAlertMessage(nil) },
      dismissOutputRequest: { [self] in outputPresentation.setRequestDraft(nil) },
      dismissDocumentSaveConfirmation: { [self] in
        documentPresentation.setSaveConfirmation(nil)
      },
      dismissRecoveryChooser: { [self] in recoverySnapshotState.setChooser(nil) },
      retryRecoveryBanner: { [self] in actions.recovery.retryRecoveryBanner() },
      dismissRecoveryBanner: { [self] in actions.recovery.dismissRecoveryBanner() },
      dismissPresentedError: { [self] in actions.workspace.dismissPresentedError() },
      selectPastePlacement: { [self] in actions.document.selectPastePlacement($0) },
      dismissPasteOptions: { [self] in actions.document.dismissPasteOptions() },
    )
  }

  var toolbarState: CADToolbarState {
    CADToolbarState(
      selectedTool: canvasPresentation.selectedTool,
      viewMode: canvasPresentation.viewMode,
      layers: layers,
      activeLayerID: canvasPresentation.activeLayerID,
      zoomScale: canvasPresentation.zoomScale,
      gridVisible: workspacePreferences.gridVisible,
      a4ReferenceVisible: workspacePreferences.a4ReferenceVisible,
      a4ReferenceOrientation: workspacePreferences.a4ReferenceOrientation,
      gridSnapEnabled: workspacePreferences.gridSnapEnabled,
      pointSnapEnabled: workspacePreferences.pointSnapEnabled,
      inspectorPanelVisible: workspacePreferences.inspectorPanelVisible
    )
  }

  var toolbarActions: CADToolbarActions {
    let bindings = KawaCADUIBindings(handler: actions)
    return CADToolbarActions(
      showToolPalette: { [self] in showCompactDrawer(.tools) },
      toggleInspector: { [self] mode in
        if mode == .compact {
          showCompactDrawer(.inspector)
        } else {
          bindings.toolbar.setInspectorPanelVisible(
            !workspacePreferences.inspectorPanelVisible
          )
        }
      },
      setActiveLayer: bindings.toolbar.setActiveLayer,
      setViewMode: bindings.menu.setViewMode,
      zoomIn: bindings.toolbar.zoomIn,
      zoomOut: bindings.toolbar.zoomOut,
      zoomToFit: bindings.toolbar.zoomToFit,
      setGridVisible: bindings.toolbar.setGridVisible,
      setA4ReferenceVisible: bindings.toolbar.setA4ReferenceVisible,
      setA4ReferenceOrientation: bindings.toolbar.setA4ReferenceOrientation,
      setGridSnapEnabled: bindings.toolbar.setGridSnapEnabled,
      setPointSnapEnabled: bindings.toolbar.setPointSnapEnabled
    )
  }

  var canvasStatusBarState: CanvasStatusBarState {
    let visibleEntityCount: Int
    switch canvasPresentation.viewMode {
    case .editDisplay:
      visibleEntityCount = coreSnapshot?.editDisplaySummary.visibleEntityCount ?? entities.count
    case .outputPreview:
      visibleEntityCount = coreSnapshot?.outputPreviewSummary.visibleEntityCount ?? entities.count
    }
    let selectionText =
      selectedEntityIDs.count > 1
      ? AppStrings.tr("status_item.selection_count", selectedEntityIDs.count)
      : selectedEntity?.label ?? AppStrings.tr("workbench.none_selected")
    let cursorCoordinateText =
      canvasPresentation.cursorModelPoint.map {
        AppStrings.tr("status_item.coordinate_value", $0.xMM, $0.yMM)
      } ?? AppStrings.tr("status_item.coordinate_none")
    return CanvasStatusBarState(
      visibleEntityCount: visibleEntityCount,
      selectionText: selectionText,
      cursorCoordinateText: cursorCoordinateText,
      outputPreviewSummaryText: outputPreviewSummaryText,
      outputPreviewHasWarnings: !(outputPresentation.previewBuildResult?.warnings.isEmpty ?? true),
      statusMessage: statusMessage,
      bottomWorkbenchVisible: workspacePreferences.bottomWorkbenchVisible
    )
  }

  var canvasStatusBarActions: CanvasStatusBarActions {
    CanvasStatusBarActions(setBottomWorkbenchVisible: { [self] in setBottomWorkbenchVisible($0) })
  }

  var documentHeaderState: DocumentHeaderState {
    DocumentHeaderState(
      documentName: documentName,
      canRenameDocument: canRenameDocument,
      unitLabel: unitLabel,
      paperLabel: paperLabel
    )
  }

  var documentHeaderActions: DocumentHeaderActions {
    DocumentHeaderActions(
      updateDocumentNameDraft: { [self] in actions.document.updatePendingDocumentNameDraft($0) },
      commitDocumentName: { [self] in actions.document.commitPendingDocumentNameDraft($0) }
    )
  }

  var toolPaletteState: ToolPaletteState {
    ToolPaletteState(
      selectedTool: canvasPresentation.selectedTool,
      sharedStyles: sharedStyles,
      activePatternLineStyleID: canvasPresentation.activePatternLineStyleID,
      selectedEntityCount: selectedEntities.count,
      activeRoundHoleKind: canvasPresentation.activeRoundHoleKind,
      activeRoundHoleDiameterMM: canvasPresentation.activeRoundHoleDiameterMM,
      showsDetailedTools: workspacePreferences.detailedToolsVisible,
      collapsedGroupIDs: workspacePreferences.collapsedToolGroupIDs
    )
  }

  var toolPaletteActions: ToolPaletteActions {
    let bindings = KawaCADUIBindings(handler: actions)
    return ToolPaletteActions(
      activateTool: bindings.menu.activateTool,
      setActivePatternLineStyle: { [self] in actions.document.setActivePatternLineStyle($0) },
      applyActivePatternLineStyleToSelection: { [self] in
        _ = actions.document.applyActivePatternLineStyleToSelection()
      },
      setActiveRoundHoleKind: { [self] in actions.document.setActiveRoundHoleKind($0) },
      setActiveRoundHoleDiameter: { [self] in actions.document.setActiveRoundHoleDiameter($0) },
      setActiveRoundHoleDiameterInputValid: { [self] in
        actions.canvas.setActiveRoundHoleDiameterInputValid($0)
      },
      setShowsDetailedTools: { [self] in setDetailedToolsVisible($0) },
      setGroupCollapsed: { [self] in setToolGroupCollapsed($0, groupID: $1) }
    )
  }

  var constraintEntryHUDState: ConstraintEntryHUDState {
    ConstraintEntryHUDState(
      draft: canvasPresentation.pendingConstraintValueDraft, parameters: parameters)
  }

  var constraintEntryHUDActions: ConstraintEntryHUDActions {
    ConstraintEntryHUDActions(
      updateOffsetSourceScope: { [self] in actions.constraints.updatePendingOffsetSourceScope($0) },
      updateEntryMode: { [self] in actions.constraints.updatePendingConstraintEntryMode($0) },
      updateParameterID: { [self] in actions.constraints.updatePendingConstraintParameterID($0) },
      updateValueText: { [self] in actions.constraints.updatePendingConstraintValueText($0) },
      commit: { [self] in actions.constraints.commitPendingConstraintValueEntry() },
      cancel: { [self] in actions.constraints.cancelPendingConstraintValueEntry() }
    )
  }

  var layerDeletionDialogState: LayerDeletionDialogState {
    LayerDeletionDialogState(
      confirmation: documentPresentation.layerDeletionConfirmation
    )
  }

  var layerDeletionDialogActions: LayerDeletionDialogActions {
    LayerDeletionDialogActions(
      dismiss: { [self] in
        documentPresentation.setLayerDeletionConfirmation(nil)
      },
      confirm: { [self] in actions.document.confirmLayerDeletion() },
      cancel: { [self] in actions.document.cancelLayerDeletion() }
    )
  }

  var recoveryChooserState: RecoveryChooserState {
    RecoveryChooserState(candidates: recoverySnapshotState.chooser?.candidates ?? [])
  }

  var recoveryChooserActions: RecoveryChooserActions {
    RecoveryChooserActions(
      postpone: { [self] in actions.recovery.postponeRecoveryChooser() },
      recover: { [self] in actions.recovery.recoverRecoveryCandidate($0) },
      discard: { [self] in actions.recovery.discardRecoveryCandidate($0) },
      revealInFinder: { candidate in
        actions.workspace.desktopEnvironment.revealInFinder(candidate.containerURL)
      }
    )
  }

  var documentSaveConfirmationActions: DocumentSaveConfirmationActions {
    DocumentSaveConfirmationActions(
      cancel: { [self] in actions.document.cancelDocumentSaveConfirmation() },
      discard: { [self] in actions.document.discardDocumentChangesAndContinue() },
      save: { [self] in actions.document.confirmDocumentSaveAndContinue() }
    )
  }

  var outputRequestSheetState: OutputRequestSheetState {
    OutputRequestSheetState(
      draft: outputPresentation.requestDraft,
      disabledReason: outputPresentation.requestDraft.flatMap {
        self.actions.output.outputExecutionDisabledReason(for: $0)
      }
    )
  }
  var outputRequestSheetActions: OutputRequestSheetActions {
    OutputRequestSheetActions(
      setDestination: { [self] in actions.output.setOutputRequestDestination($0) },
      setIncludeDimensionLabels: { [self] in
        actions.output.setOutputRequestIncludeDimensionLabels($0)
      },
      setIncludeScaleGuide: { [self] in actions.output.setOutputRequestIncludeScaleGuide($0) },
      setWarningsAcknowledged: { [self] in actions.output.setOutputWarningsAcknowledged($0) },
      selectDirectPrintPrinter: { [self] in actions.output.selectDirectPrintPrinter($0) },
      cancel: { [self] in actions.output.cancelOutputRequest() },
      confirm: { [self] in actions.output.confirmOutputRequest() }
    )
  }

  var bottomWorkbenchState: BottomWorkbenchState {
    BottomWorkbenchState(
      selectedEntity: selectedEntity,
      layers: layers,
      constraintStatus: aggregatedConstraintStatus,
      constraints: constraints,
      parameters: parameters
    )
  }
}
