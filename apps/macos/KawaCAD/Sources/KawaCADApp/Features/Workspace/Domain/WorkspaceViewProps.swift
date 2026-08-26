import CoreGraphics
import KawaCADOutput

struct CADToolbarState {
  let selectedTool: CanvasTool
  let viewMode: CanvasViewMode
  let layers: [ProjectLayer]
  let activeLayerID: String
  let zoomScale: Double
  let gridVisible: Bool
  let a4ReferenceVisible: Bool
  let a4ReferenceOrientation: OutputPrintOrientation
  let gridSnapEnabled: Bool
  let pointSnapEnabled: Bool
  let inspectorPanelVisible: Bool
  let toolPaletteVisible: Bool
}

struct CADToolbarActions {
  let showToolPalette: () -> Void
  let toggleInspector: (WindowLayoutMode) -> Void
  let setActiveLayer: (String) -> Void
  let setViewMode: (CanvasViewMode) -> Void
  let zoomIn: () -> Void
  let zoomOut: () -> Void
  let zoomToFit: () -> Void
  let setGridVisible: (Bool) -> Void
  let setA4ReferenceVisible: (Bool) -> Void
  let setA4ReferenceOrientation: (OutputPrintOrientation) -> Void
  let setGridSnapEnabled: (Bool) -> Void
  let setPointSnapEnabled: (Bool) -> Void
}

struct CanvasStatusBarState {
  let visibleEntityCount: Int
  let selectionText: String
  let cursorCoordinateText: String
  let outputPreviewSummaryText: String?
  let outputPreviewHasWarnings: Bool
  let statusMessage: String
  let bottomWorkbenchVisible: Bool
}

struct CanvasStatusBarActions {
  let setBottomWorkbenchVisible: (Bool) -> Void
}

struct ToolPaletteState {
  let selectedTool: CanvasTool
  let sharedStyles: [ProjectSharedStyle]
  let activePatternLineStyleID: String
  let selectedEntityCount: Int
  let activeRoundHoleKind: ProjectRoundHoleKind
  let activeRoundHoleDiameterMM: Double
  let showsDetailedTools: Bool
  let collapsedGroupIDs: Set<String>
}

struct ToolPaletteActions {
  let activateTool: (CanvasTool) -> Void
  let setActivePatternLineStyle: (String) -> Void
  let applyActivePatternLineStyleToSelection: () -> Void
  let setActiveRoundHoleKind: (ProjectRoundHoleKind) -> Void
  let setActiveRoundHoleDiameter: (Double) -> Bool
  let setActiveRoundHoleDiameterInputValid: (Bool) -> Void
  let setShowsDetailedTools: (Bool) -> Void
  let setGroupCollapsed: (Bool, String) -> Void
}

struct ConstraintEntryHUDState {
  let draft: PendingConstraintValueDraft?
  let parameters: [ProjectParameter]
}

struct ConstraintEntryHUDActions {
  let updateOffsetSourceScope: (OffsetSourceScope) -> Void
  let updateEntryMode: (ConstraintValueEntryMode) -> Void
  let updateParameterID: (String) -> Void
  let updateValueText: (String) -> Void
  let commit: () -> Void
  let cancel: () -> Void
}

struct LayerDeletionDialogState {
  let confirmation: LayerDeletionConfirmation?
}

struct LayerDeletionDialogActions {
  let dismiss: () -> Void
  let confirm: () -> Void
  let cancel: () -> Void
}

struct RecoveryChooserState {
  let candidates: [DocumentRecoveryCandidate]
}

struct RecoveryChooserActions {
  let postpone: () -> Void
  let recover: (DocumentRecoveryCandidate) -> Void
  let discard: (DocumentRecoveryCandidate) -> Void
  let revealInFinder: (DocumentRecoveryCandidate) -> Void
}

struct DocumentSaveConfirmationActions {
  let cancel: () -> Void
  let discard: () -> Void
  let save: () -> Void
}

struct OutputRequestSheetState {
  let draft: OutputRequestDraft?
  let disabledReason: String?
}
struct OutputRequestSheetActions {
  let setDestination: (OutputDestination) -> Void
  let setIncludeDimensionLabels: (Bool) -> Void
  let setIncludeScaleGuide: (Bool) -> Void
  let selectDirectPrintPrinter: (String) -> Void
  let cancel: () -> Void
  let confirm: () -> Void
}

struct BottomWorkbenchState {
  let selectedEntity: CanvasEntity?
  let layers: [ProjectLayer]
  let constraintStatus: ConstraintStatus
  let constraints: [ProjectConstraint]
  let parameters: [ProjectParameter]
}

/// Immutable render input for the workspace shell.
///
/// Child components keep their own focused state values; this aggregate only
/// prevents the view hierarchy from reaching back into `AppCoordinator`.
struct WorkspaceViewState {
  let toolPanelWidth: CGFloat
  let inspectorPanelWidth: CGFloat
  let inspectorPanelVisible: Bool
  let compactDrawer: CompactDrawer?
  let windowLayoutMode: WindowLayoutMode
  let toolbarState: CADToolbarState
  let toolPaletteState: ToolPaletteState
  let canvasRenderInput: LeatherCanvasRenderInput
  let canvasInteractionInput: LeatherCanvasInteractionInput
  let constraintEntryHUDState: ConstraintEntryHUDState
  let canvasStatusBarState: CanvasStatusBarState
  let bottomWorkbenchState: BottomWorkbenchState
  let inspectorPanelModel: InspectorPanelModel
  let layerDeletionDialogState: LayerDeletionDialogState
  let outputRequestSheetState: OutputRequestSheetState
  let recoveryChooserState: RecoveryChooserState
  let alertMessage: UserAlertMessage?
  let outputRequestDraft: OutputRequestDraft?
  let documentSaveConfirmation: DocumentSaveConfirmation?
  let recoveryChooser: DocumentRecoveryChooserState?
  let recoveryBanner: DocumentRecoveryBannerState?
  let errorPresentation: AppErrorPresentation?
  let pasteOptionsPresentation: PasteOptionsPresentation?
  let bottomWorkbenchVisible: Bool
}

/// Effect boundary for the workspace shell.
///
/// The render tree can emit user intents through these closures without
/// knowing which intents mutate UI state, persist preferences, or call an OS
/// adapter.
struct WorkspaceViewActions {
  let toolbarActions: CADToolbarActions
  let toolPaletteActions: ToolPaletteActions
  let canvasActionGroups: LeatherCanvasActionGroups
  let constraintEntryHUDActions: ConstraintEntryHUDActions
  let canvasStatusBarActions: CanvasStatusBarActions
  let layerDeletionDialogActions: LayerDeletionDialogActions
  let outputRequestSheetActions: OutputRequestSheetActions
  let documentSaveConfirmationActions: DocumentSaveConfirmationActions
  let recoveryChooserActions: RecoveryChooserActions
  let setToolPanelWidth: (CGFloat) -> Void
  let setInspectorPanelWidth: (CGFloat) -> Void
  let showCompactDrawer: (CompactDrawer?) -> Void
  let updateWindowLayoutMode: (WindowLayoutMode) -> Void
  let dismissAlert: () -> Void
  let dismissOutputRequest: () -> Void
  let dismissDocumentSaveConfirmation: () -> Void
  let dismissRecoveryChooser: () -> Void
  let retryRecoveryBanner: () -> Void
  let dismissRecoveryBanner: () -> Void
  let dismissPresentedError: () -> Void
  let selectPastePlacement: (PastePlacementMode) -> Void
  let dismissPasteOptions: () -> Void
}

struct WorkspaceCanvasSurfaceState {
  let canvasRenderInput: LeatherCanvasRenderInput
  let canvasInteractionInput: LeatherCanvasInteractionInput
  let constraintEntryHUDState: ConstraintEntryHUDState
  let pasteOptionsPresentation: PasteOptionsPresentation?
}

struct WorkspaceCanvasSurfaceActions {
  let canvasActionGroups: LeatherCanvasActionGroups
  let constraintEntryHUDActions: ConstraintEntryHUDActions
  let selectPastePlacement: (PastePlacementMode) -> Void
  let dismissPasteOptions: () -> Void
}

struct WorkspaceCanvasLayoutState {
  let inspectorPanelWidth: CGFloat
  let inspectorPanelVisible: Bool
  let compactDrawer: CompactDrawer?
  let toolPaletteState: ToolPaletteState
}

struct WorkspaceCanvasLayoutActions {
  let setInspectorPanelWidth: (CGFloat) -> Void
  let showCompactDrawer: (CompactDrawer?) -> Void
  let toolPaletteActions: ToolPaletteActions
}
