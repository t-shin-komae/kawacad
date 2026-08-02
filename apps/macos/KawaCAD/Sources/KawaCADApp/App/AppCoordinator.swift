import Combine
import KawaCADOutput

/// Composition root for the macOS application.
///
/// The root owns state, adapters, and an aggregate of independent feature
/// handlers. It does not inherit any action implementation.
final class AppCoordinator: ObservableObject {
  let actions: AppActionHandlers
  let cadSession: CadSessionState
  let annotationSelection: AnnotationSelectionState
  let canvasPresentation: CanvasPresentationState
  let documentPresentation: DocumentPresentationState
  let errorPresentationState: AppErrorPresentationState
  let inspectorPresentation: InspectorPresentationState
  let outputPresentation: OutputPresentationState
  let recoverySnapshotState: RecoverySnapshotState
  let workspacePreferences: WorkspacePreferencesState
  let workspaceLayout: WorkspaceLayoutState
  let partLibraryState: PartLibraryState

  var documentLifecycleController: (any DocumentLifecycleControlling)? {
    get { actions.document.documentLifecycleController }
    set {
      actions.document.documentLifecycleController = newValue
      actions.canvas.documentLifecycleController = newValue
      actions.constraints.documentLifecycleController = newValue
      actions.inspector.documentLifecycleController = newValue
      actions.parts.documentLifecycleController = newValue
      actions.output.documentLifecycleController = newValue
      actions.recovery.documentLifecycleController = newValue
      actions.workspace.documentLifecycleController = newValue
    }
  }

  init(
    documentAdapter: any DocumentSessionAdapting = DocumentSessionAdapter(),
    coreStatusProvider: @escaping () -> LeatherCoreStatus = LeatherCoreProcessAdapter
      .loadVersionInfo,
    commandFactory: DocumentCommandFactory = DocumentCommandFactory(),
    outputService: OutputService = OutputService(),
    desktopEnvironment: any DesktopEnvironmentAdapting = DesktopEnvironmentAdapter(),
    documentRecoveryConfiguration: DocumentRecoveryConfiguration = .disabled(),
    documentRecoveryAdapter: DocumentRecoveryAdapter? = nil,
    partLibraryAdapter: any PartLibraryAdapting = PartLibraryAdapter()
  ) {
    let annotationSelection = AnnotationSelectionState()
    let canvasPresentation = CanvasPresentationState(annotationSelection: annotationSelection)
    let cadSession = CadSessionState(
      documentAdapter: documentAdapter, coreStatusProvider: coreStatusProvider)
    let documentPresentation = DocumentPresentationState()
    let errorPresentationState = AppErrorPresentationState()
    let inspectorPresentation = InspectorPresentationState()
    let partLibraryState = PartLibraryState(adapter: partLibraryAdapter)
    let recoverySnapshotState = RecoverySnapshotState(
      configuration: documentRecoveryConfiguration,
      adapter: documentRecoveryAdapter
    )
    let outputPresentation = OutputPresentationState(service: outputService)
    let workspacePreferences = WorkspacePreferencesState()
    let workspaceLayout = WorkspaceLayoutState()

    self.cadSession = cadSession
    self.annotationSelection = annotationSelection
    self.canvasPresentation = canvasPresentation
    self.documentPresentation = documentPresentation
    self.errorPresentationState = errorPresentationState
    self.inspectorPresentation = inspectorPresentation
    self.outputPresentation = outputPresentation
    self.recoverySnapshotState = recoverySnapshotState
    self.workspacePreferences = workspacePreferences
    self.workspaceLayout = workspaceLayout
    self.partLibraryState = partLibraryState

    let context = AppActionHandlerContext(
      cadSession: cadSession,
      canvasPresentation: canvasPresentation,
      documentPresentation: documentPresentation,
      errorPresentationState: errorPresentationState,
      inspectorPresentation: inspectorPresentation,
      outputPresentation: outputPresentation,
      recoverySnapshotState: recoverySnapshotState,
      workspacePreferences: workspacePreferences,
      workspaceLayout: workspaceLayout,
      partLibraryState: partLibraryState,
      commandFactory: commandFactory,
      desktopEnvironment: desktopEnvironment
    )
    actions = AppActionHandlers(context: context)

    cadSession.onDocumentState = { [weak self] state in
      self?.actions.document.handleCadSessionStateChange(state)
    }
    actions.document.refreshCoreStatus()
    actions.document.performCreateNewProject()
  }
}
