import Foundation
import KawaCADOutput

/// The small read-only state surface shared by handlers that need to derive
/// selection and document presentation values. The full application context is
/// consumed only while constructing these feature dependency values.
struct ActionHandlerSelectionDependencies {
  let cadSession: CadSessionState
  let canvasPresentation: CanvasPresentationState
  let documentPresentation: DocumentPresentationState
  let outputPresentation: OutputPresentationState
  let partLibraryState: PartLibraryState
}

protocol ActionHandlerSelectionProviding: AnyObject {
  var selectionDependencies: ActionHandlerSelectionDependencies { get }
}

extension ActionHandlerSelectionProviding {
  var cadSession: CadSessionState { selectionDependencies.cadSession }
  var canvasPresentation: CanvasPresentationState { selectionDependencies.canvasPresentation }
  var documentPresentation: DocumentPresentationState { selectionDependencies.documentPresentation }
  var outputPresentation: OutputPresentationState { selectionDependencies.outputPresentation }
  var partLibraryState: PartLibraryState { selectionDependencies.partLibraryState }
}

/// Mutable state forwarding used by action implementations. It is separate
/// from the read-only selector extension so selector code cannot accidentally
/// become a state transfer API again.
protocol ActionHandlerStateAccessProviding: ActionHandlerSelectionProviding {}

extension ActionHandlerStateAccessProviding {
  var coreStatus: LeatherCoreStatus {
    get { cadSession.coreStatus }
    set { cadSession.setCoreStatus(newValue) }
  }

  var statusMessage: String {
    get { cadSession.message }
    set { cadSession.setMessage(newValue) }
  }

  var previewEntities: [CanvasEntity]? {
    get { cadSession.previewEntities }
    set { cadSession.setPreviewEntities(newValue) }
  }

  var previewCoincidentPointGroups: [CoincidentPointGroup]? {
    get { cadSession.previewCoincidentPointGroups }
    set { cadSession.setPreviewCoincidentPointGroups(newValue) }
  }

  var previewCanvasProjection: LeatherCanvasProjection? {
    get { cadSession.previewCanvasProjection }
    set { cadSession.setPreviewCanvasProjection(newValue) }
  }

  var selectedEntityID: String? {
    get { canvasPresentation.selectedEntityID }
    set { canvasPresentation.setPrimaryEntityID(newValue) }
  }

  var selectedEntityIDs: Set<String> {
    get { canvasPresentation.selectedEntityIDs }
    set { canvasPresentation.setEntityIDs(newValue) }
  }

  var selectedConstraintID: String? {
    get { canvasPresentation.selectedConstraintID }
    set { canvasPresentation.setConstraintID(newValue) }
  }

  var selectedMeasurementAnnotationID: String? {
    get { canvasPresentation.selectedMeasurementAnnotationID }
    set { canvasPresentation.setMeasurementAnnotationID(newValue) }
  }

  var selectedFreeTextID: String? {
    get { canvasPresentation.selectedFreeTextID }
    set { canvasPresentation.setFreeTextID(newValue) }
  }

  var selectedStitchStartPointID: String? {
    get { canvasPresentation.selectedStitchStartPointID }
    set { canvasPresentation.setStitchStartPointID(newValue) }
  }
}

struct CanvasActionHandlerDependencies {
  let selection: ActionHandlerSelectionDependencies
  let inspectorPresentation: InspectorPresentationState
  let workspacePreferences: WorkspacePreferencesState
  let workspaceLayout: WorkspaceLayoutState
  let commandFactory: DocumentCommandFactory
}

struct DocumentActionHandlerDependencies {
  let selection: ActionHandlerSelectionDependencies
  let inspectorPresentation: InspectorPresentationState
  let recoverySnapshotState: RecoverySnapshotState
  let commandFactory: DocumentCommandFactory
  let desktopEnvironment: any DesktopEnvironmentAdapting
}

struct ConstraintActionHandlerDependencies {
  let selection: ActionHandlerSelectionDependencies
  let commandFactory: DocumentCommandFactory
}

struct InspectorActionHandlerDependencies {
  let selection: ActionHandlerSelectionDependencies
  let inspectorPresentation: InspectorPresentationState
}

struct PartActionHandlerDependencies {
  let selection: ActionHandlerSelectionDependencies
  let inspectorPresentation: InspectorPresentationState
  let partLibraryState: PartLibraryState
  let commandFactory: DocumentCommandFactory
}

struct OutputActionHandlerDependencies {
  let selection: ActionHandlerSelectionDependencies
  let workspacePreferences: WorkspacePreferencesState
  let desktopEnvironment: any DesktopEnvironmentAdapting
}

struct RecoveryActionHandlerDependencies {
  let selection: ActionHandlerSelectionDependencies
  let recoverySnapshotState: RecoverySnapshotState
  let desktopEnvironment: any DesktopEnvironmentAdapting
}

struct WorkspaceActionHandlerDependencies {
  let selection: ActionHandlerSelectionDependencies
  let errorPresentationState: AppErrorPresentationState
  let recoverySnapshotState: RecoverySnapshotState
  let workspacePreferences: WorkspacePreferencesState
  let workspaceLayout: WorkspaceLayoutState
  let desktopEnvironment: any DesktopEnvironmentAdapting
}

protocol CanvasActionHandlerDependencyProviding: ActionHandlerStateAccessProviding {
  var handlerDependencies: CanvasActionHandlerDependencies { get }
}

extension CanvasActionHandlerDependencyProviding {
  var selectionDependencies: ActionHandlerSelectionDependencies { handlerDependencies.selection }
  var inspectorPresentation: InspectorPresentationState {
    handlerDependencies.inspectorPresentation
  }
  var workspacePreferences: WorkspacePreferencesState { handlerDependencies.workspacePreferences }
  var workspaceLayout: WorkspaceLayoutState { handlerDependencies.workspaceLayout }
  var commandFactory: DocumentCommandFactory { handlerDependencies.commandFactory }
}

protocol DocumentActionHandlerDependencyProviding: ActionHandlerStateAccessProviding {
  var handlerDependencies: DocumentActionHandlerDependencies { get }
}

extension DocumentActionHandlerDependencyProviding {
  var selectionDependencies: ActionHandlerSelectionDependencies { handlerDependencies.selection }
  var inspectorPresentation: InspectorPresentationState {
    handlerDependencies.inspectorPresentation
  }
  var recoverySnapshotState: RecoverySnapshotState { handlerDependencies.recoverySnapshotState }
  var commandFactory: DocumentCommandFactory { handlerDependencies.commandFactory }
  var desktopEnvironment: any DesktopEnvironmentAdapting { handlerDependencies.desktopEnvironment }
}

protocol ConstraintActionHandlerDependencyProviding: ActionHandlerStateAccessProviding {
  var handlerDependencies: ConstraintActionHandlerDependencies { get }
}

extension ConstraintActionHandlerDependencyProviding {
  var selectionDependencies: ActionHandlerSelectionDependencies { handlerDependencies.selection }
  var commandFactory: DocumentCommandFactory { handlerDependencies.commandFactory }
}

protocol InspectorActionHandlerDependencyProviding: ActionHandlerStateAccessProviding {
  var handlerDependencies: InspectorActionHandlerDependencies { get }
}

extension InspectorActionHandlerDependencyProviding {
  var selectionDependencies: ActionHandlerSelectionDependencies { handlerDependencies.selection }
  var inspectorPresentation: InspectorPresentationState {
    handlerDependencies.inspectorPresentation
  }
}

protocol PartActionHandlerDependencyProviding: ActionHandlerStateAccessProviding {
  var handlerDependencies: PartActionHandlerDependencies { get }
}

extension PartActionHandlerDependencyProviding {
  var selectionDependencies: ActionHandlerSelectionDependencies { handlerDependencies.selection }
  var inspectorPresentation: InspectorPresentationState {
    handlerDependencies.inspectorPresentation
  }
  var partLibraryState: PartLibraryState { handlerDependencies.partLibraryState }
  var commandFactory: DocumentCommandFactory { handlerDependencies.commandFactory }
}

protocol OutputActionHandlerDependencyProviding: ActionHandlerStateAccessProviding {
  var handlerDependencies: OutputActionHandlerDependencies { get }
}

extension OutputActionHandlerDependencyProviding {
  var selectionDependencies: ActionHandlerSelectionDependencies { handlerDependencies.selection }
  var workspacePreferences: WorkspacePreferencesState { handlerDependencies.workspacePreferences }
  var desktopEnvironment: any DesktopEnvironmentAdapting { handlerDependencies.desktopEnvironment }
}

protocol RecoveryActionHandlerDependencyProviding: ActionHandlerStateAccessProviding {
  var handlerDependencies: RecoveryActionHandlerDependencies { get }
}

extension RecoveryActionHandlerDependencyProviding {
  var selectionDependencies: ActionHandlerSelectionDependencies { handlerDependencies.selection }
  var recoverySnapshotState: RecoverySnapshotState { handlerDependencies.recoverySnapshotState }
  var desktopEnvironment: any DesktopEnvironmentAdapting { handlerDependencies.desktopEnvironment }
}

protocol WorkspaceActionHandlerDependencyProviding: ActionHandlerStateAccessProviding {
  var handlerDependencies: WorkspaceActionHandlerDependencies { get }
}

extension WorkspaceActionHandlerDependencyProviding {
  var selectionDependencies: ActionHandlerSelectionDependencies { handlerDependencies.selection }
  var errorPresentationState: AppErrorPresentationState {
    handlerDependencies.errorPresentationState
  }
  var recoverySnapshotState: RecoverySnapshotState { handlerDependencies.recoverySnapshotState }
  var workspacePreferences: WorkspacePreferencesState { handlerDependencies.workspacePreferences }
  var workspaceLayout: WorkspaceLayoutState { handlerDependencies.workspaceLayout }
  var desktopEnvironment: any DesktopEnvironmentAdapting { handlerDependencies.desktopEnvironment }
}

extension AppActionHandlerContext {
  var selectionDependencies: ActionHandlerSelectionDependencies {
    ActionHandlerSelectionDependencies(
      cadSession: cadSession,
      canvasPresentation: canvasPresentation,
      documentPresentation: documentPresentation,
      outputPresentation: outputPresentation,
      partLibraryState: partLibraryState
    )
  }

  var canvasActionHandlerDependencies: CanvasActionHandlerDependencies {
    CanvasActionHandlerDependencies(
      selection: selectionDependencies,
      inspectorPresentation: inspectorPresentation,
      workspacePreferences: workspacePreferences,
      workspaceLayout: workspaceLayout,
      commandFactory: commandFactory
    )
  }

  var documentActionHandlerDependencies: DocumentActionHandlerDependencies {
    DocumentActionHandlerDependencies(
      selection: selectionDependencies,
      inspectorPresentation: inspectorPresentation,
      recoverySnapshotState: recoverySnapshotState,
      commandFactory: commandFactory,
      desktopEnvironment: desktopEnvironment
    )
  }

  var constraintActionHandlerDependencies: ConstraintActionHandlerDependencies {
    ConstraintActionHandlerDependencies(
      selection: selectionDependencies, commandFactory: commandFactory)
  }

  var inspectorActionHandlerDependencies: InspectorActionHandlerDependencies {
    InspectorActionHandlerDependencies(
      selection: selectionDependencies, inspectorPresentation: inspectorPresentation)
  }

  var partActionHandlerDependencies: PartActionHandlerDependencies {
    PartActionHandlerDependencies(
      selection: selectionDependencies,
      inspectorPresentation: inspectorPresentation,
      partLibraryState: partLibraryState,
      commandFactory: commandFactory
    )
  }

  var outputActionHandlerDependencies: OutputActionHandlerDependencies {
    OutputActionHandlerDependencies(
      selection: selectionDependencies,
      workspacePreferences: workspacePreferences,
      desktopEnvironment: desktopEnvironment
    )
  }

  var recoveryActionHandlerDependencies: RecoveryActionHandlerDependencies {
    RecoveryActionHandlerDependencies(
      selection: selectionDependencies,
      recoverySnapshotState: recoverySnapshotState,
      desktopEnvironment: desktopEnvironment
    )
  }

  var workspaceActionHandlerDependencies: WorkspaceActionHandlerDependencies {
    WorkspaceActionHandlerDependencies(
      selection: selectionDependencies,
      errorPresentationState: errorPresentationState,
      recoverySnapshotState: recoverySnapshotState,
      workspacePreferences: workspacePreferences,
      workspaceLayout: workspaceLayout,
      desktopEnvironment: desktopEnvironment
    )
  }
}
