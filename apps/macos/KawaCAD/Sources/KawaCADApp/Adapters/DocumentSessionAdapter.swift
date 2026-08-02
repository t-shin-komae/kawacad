import Foundation
import KawaCADOutput

protocol LeatherDocumentSessionManaging: OutputSession {
  func loadState(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState>
  func previewCommand(_ payload: CoreDocumentCommand, viewMode: CanvasViewMode)
    -> LeatherCoreResult<LeatherDocumentState>
  func preflightConstraint(kind: String, targets: [CoreConstraintTarget]) -> LeatherCoreResult<
    ConstraintPreflightResult
  >
  func layerDeletionImpact(layerID: String) -> LeatherCoreResult<LayerDeletionImpact>
  func preflightDerivedElement(
    kind: DerivedElementPreflightKind, hitEntityID: String?, selectedEntityIDs: [String],
    clickPoint: ModelPoint?
  ) -> LeatherCoreResult<DerivedElementPreflightResult>
  func evaluateMeasurement(annotationID: String) -> LeatherCoreResult<MeasurementEvaluation>
  func exportSelection(_ selection: CoreSelectionReference) -> LeatherCoreResult<
    SelectionClipboardExport
  >
  func exportPartLibraryItem(partID: String) -> LeatherCoreResult<PartLibraryExport>
  func applyCommand(_ payload: CoreDocumentCommand, viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  >
  func undo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState>
  func redo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState>
  func writeJSONFile(to url: URL) -> LeatherCoreResult<Void>
  func writeSnapshotFile(to url: URL) -> LeatherCoreResult<Void>
}

extension LeatherDocumentSessionManaging {
  func layerDeletionImpact(layerID: String) -> LeatherCoreResult<LayerDeletionImpact> {
    .failure("layer deletion impact is unavailable")
  }
  func exportPartLibraryItem(partID: String) -> LeatherCoreResult<PartLibraryExport> {
    .failure("part library export is unavailable")
  }

  func writeSnapshotFile(to url: URL) -> LeatherCoreResult<Void> {
    writeJSONFile(to: url)
  }
}

protocol DocumentSessionAdapting: OutputSession {
  var hasDocument: Bool { get }
  var canUndo: Bool { get }
  var canRedo: Bool { get }
  var isDocumentDirty: Bool { get }
  var documentURL: URL? { get }
  /// Records a state returned by Core so this adapter can derive history and
  /// dirty metadata for subsequent transport operations. UI rendering state
  /// belongs to `CadSessionState`.
  func recordAppliedState(_ state: LeatherDocumentState?)
  func createNewDocument(named name: String, viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  >
  func openDocument(at url: URL, viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  >
  func recoverDocument(
    from recoverySnapshotURL: URL,
    suggestedDocumentURL: URL?,
    viewMode: CanvasViewMode
  ) -> LeatherCoreResult<LeatherDocumentState>
  func loadState(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState>
  func saveDocument(to url: URL) -> LeatherCoreResult<Void>
  func writeSnapshot(to url: URL) -> LeatherCoreResult<Void>
  func previewCommand(_ payload: CoreDocumentCommand, viewMode: CanvasViewMode)
    -> LeatherCoreResult<LeatherDocumentState>
  func preflightConstraint(kind: String, targets: [CoreConstraintTarget]) -> LeatherCoreResult<
    ConstraintPreflightResult
  >
  func layerDeletionImpact(layerID: String) -> LeatherCoreResult<LayerDeletionImpact>
  func preflightDerivedElement(
    kind: DerivedElementPreflightKind, hitEntityID: String?, selectedEntityIDs: [String],
    clickPoint: ModelPoint?
  ) -> LeatherCoreResult<DerivedElementPreflightResult>
  func evaluateMeasurement(annotationID: String) -> LeatherCoreResult<MeasurementEvaluation>
  func exportSelection(_ selection: CoreSelectionReference) -> LeatherCoreResult<
    SelectionClipboardExport
  >
  func exportPartLibraryItem(partID: String) -> LeatherCoreResult<PartLibraryExport>
  func applyCommand(_ payload: CoreDocumentCommand, viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  >
  func undo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState>
  func redo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState>
}

extension DocumentSessionAdapting {
  func layerDeletionImpact(layerID: String) -> LeatherCoreResult<LayerDeletionImpact> {
    .failure("layer deletion impact is unavailable")
  }
  func exportPartLibraryItem(partID: String) -> LeatherCoreResult<PartLibraryExport> {
    .failure("part library export is unavailable")
  }
}

protocol DocumentSessionAdapterBackend {
  func createDocument(named name: String) -> LeatherCoreResult<any LeatherDocumentSessionManaging>
  func readDocument(from url: URL) -> LeatherCoreResult<any LeatherDocumentSessionManaging>
}

struct LiveDocumentSessionAdapterBackend: DocumentSessionAdapterBackend {
  func createDocument(named name: String) -> LeatherCoreResult<any LeatherDocumentSessionManaging> {
    switch LeatherCoreProcessAdapter.createDocument(named: name) {
    case .success(let session):
      return .success(session)
    case .failure(let message):
      return .failure(message)
    }
  }

  func readDocument(from url: URL) -> LeatherCoreResult<any LeatherDocumentSessionManaging> {
    switch LeatherCoreProcessAdapter.readDocument(from: url) {
    case .success(let session):
      return .success(session)
    case .failure(let message):
      return .failure(message)
    }
  }
}

final class DocumentSessionAdapter: DocumentSessionAdapting {
  private var session: (any LeatherDocumentSessionManaging)?
  private var undoAvailable = false
  private var redoAvailable = false
  private var forcedDirtyUntilSave = false
  private let backend: any DocumentSessionAdapterBackend

  private(set) var documentURL: URL?
  /// Adapter-local cache used only for Core lifecycle, history, and save
  /// bookkeeping. It is deliberately not part of `DocumentSessionAdapting`.
  private(set) var lastAppliedState: LeatherDocumentState?

  var hasDocument: Bool { session != nil }
  var canUndo: Bool { undoAvailable }
  var canRedo: Bool { redoAvailable }
  private(set) var isDocumentDirty = false

  init(backend: any DocumentSessionAdapterBackend = LiveDocumentSessionAdapterBackend()) {
    self.backend = backend
  }

  func recordAppliedState(_ state: LeatherDocumentState?) {
    lastAppliedState = state
    updateHistoryAvailability(state)
    updateDirtyState(for: state)
  }

  func createNewDocument(named name: String, viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  > {
    switch backend.createDocument(named: name) {
    case .success(let newSession):
      switch newSession.loadState(viewMode: viewMode) {
      case .success(let state):
        installSession(newSession, documentURL: nil, state: state)
        return .success(state)
      case .failure(let message):
        return .failure(message)
      }
    case .failure(let message):
      return .failure(message)
    }
  }

  func openDocument(at url: URL, viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  > {
    switch backend.readDocument(from: url) {
    case .success(let openedSession):
      switch openedSession.loadState(viewMode: viewMode) {
      case .success(let state):
        installSession(openedSession, documentURL: url, state: state)
        return .success(state)
      case .failure(let message):
        return .failure(message)
      }
    case .failure(let message):
      return .failure(message)
    }
  }

  func recoverDocument(
    from recoverySnapshotURL: URL,
    suggestedDocumentURL: URL?,
    viewMode: CanvasViewMode
  ) -> LeatherCoreResult<LeatherDocumentState> {
    switch backend.readDocument(from: recoverySnapshotURL) {
    case .success(let openedSession):
      switch openedSession.loadState(viewMode: viewMode) {
      case .success(let state):
        installSession(
          openedSession,
          documentURL: suggestedDocumentURL,
          state: state,
          forcedDirtyUntilSave: true
        )
        return .success(state)
      case .failure(let message):
        return .failure(message)
      }
    case .failure(let message):
      return .failure(message)
    }
  }

  func loadState(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    guard let session else {
      return .failure(AppStrings.tr("document.error.unavailable"))
    }
    return updateStateResult(session.loadState(viewMode: viewMode))
  }

  func saveDocument(to url: URL) -> LeatherCoreResult<Void> {
    guard let session else {
      return .failure(AppStrings.tr("document.error.unavailable"))
    }
    switch session.writeJSONFile(to: url) {
    case .success:
      documentURL = url
      forcedDirtyUntilSave = false
      if var state = lastAppliedState {
        state.persistence = LeatherPersistenceState(
          isDirty: false,
          revision: state.persistence.revision
        )
        lastAppliedState = state
      }
      isDocumentDirty = false
      return .success(())
    case .failure(let message):
      return .failure(message)
    }
  }

  func writeSnapshot(to url: URL) -> LeatherCoreResult<Void> {
    guard let session else {
      return .failure(AppStrings.tr("document.error.unavailable"))
    }
    return session.writeSnapshotFile(to: url)
  }

  func previewCommand(_ payload: CoreDocumentCommand, viewMode: CanvasViewMode)
    -> LeatherCoreResult<LeatherDocumentState>
  {
    guard let session else {
      return .failure(AppStrings.tr("document.error.unavailable"))
    }

    return session.previewCommand(payload, viewMode: viewMode)
  }

  func preflightConstraint(kind: String, targets: [CoreConstraintTarget]) -> LeatherCoreResult<
    ConstraintPreflightResult
  > {
    guard let session else {
      return .failure(AppStrings.tr("document.error.unavailable"))
    }

    return session.preflightConstraint(kind: kind, targets: targets)
  }

  func layerDeletionImpact(layerID: String) -> LeatherCoreResult<LayerDeletionImpact> {
    guard let session else { return .failure("document is not open") }
    return session.layerDeletionImpact(layerID: layerID)
  }

  func preflightDerivedElement(
    kind: DerivedElementPreflightKind,
    hitEntityID: String?,
    selectedEntityIDs: [String],
    clickPoint: ModelPoint?
  ) -> LeatherCoreResult<DerivedElementPreflightResult> {
    guard let session else { return .failure(AppStrings.tr("document.error.unavailable")) }
    return session.preflightDerivedElement(
      kind: kind,
      hitEntityID: hitEntityID,
      selectedEntityIDs: selectedEntityIDs,
      clickPoint: clickPoint
    )
  }

  func evaluateMeasurement(annotationID: String) -> LeatherCoreResult<MeasurementEvaluation> {
    guard let session else { return .failure(AppStrings.tr("document.error.unavailable")) }
    return session.evaluateMeasurement(annotationID: annotationID)
  }

  func exportSelection(_ selection: CoreSelectionReference) -> LeatherCoreResult<
    SelectionClipboardExport
  > {
    guard let session else { return .failure(AppStrings.tr("document.error.unavailable")) }
    return session.exportSelection(selection)
  }

  func exportPartLibraryItem(partID: String) -> LeatherCoreResult<PartLibraryExport> {
    guard let session else { return .failure(AppStrings.tr("document.error.unavailable")) }
    return session.exportPartLibraryItem(partID: partID)
  }

  func applyCommand(_ payload: CoreDocumentCommand, viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  > {
    guard let session else {
      return .failure(AppStrings.tr("document.error.unavailable"))
    }

    return updateStateResult(session.applyCommand(payload, viewMode: viewMode))
  }

  func undo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    guard let session, canUndo else {
      return .failure(AppStrings.tr("document.error.no_undo"))
    }
    return updateStateResult(session.undo(viewMode: viewMode))
  }

  func redo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    guard let session, canRedo else {
      return .failure(AppStrings.tr("document.error.no_redo"))
    }
    return updateStateResult(session.redo(viewMode: viewMode))
  }

  func buildOutputDocumentModel(options: OutputBuildOptions) -> OutputResult<OutputBuildResult> {
    guard let session else {
      return .failure(OutputError(AppStrings.tr("document.error.unavailable")))
    }
    return session.buildOutputDocumentModel(options: options)
  }

  func renderPDF(outputDocumentModel: OutputDocumentModel) -> OutputResult<Data> {
    guard let session else {
      return .failure(OutputError(AppStrings.tr("document.error.unavailable")))
    }
    return session.renderPDF(outputDocumentModel: outputDocumentModel)
  }

  func renderPrint(outputDocumentModel: OutputDocumentModel) -> OutputResult<OutputPrintRenderData>
  {
    guard let session else {
      return .failure(OutputError(AppStrings.tr("document.error.unavailable")))
    }
    return session.renderPrint(outputDocumentModel: outputDocumentModel)
  }

  private func updateStateResult(_ result: LeatherCoreResult<LeatherDocumentState>)
    -> LeatherCoreResult<LeatherDocumentState>
  {
    switch result {
    case .success(let state):
      recordAppliedState(state)
      return .success(state)
    case .failure(let message):
      return .failure(message)
    }
  }

  private func updateHistoryAvailability(_ state: LeatherDocumentState?) {
    undoAvailable = state?.history.canUndo ?? false
    redoAvailable = state?.history.canRedo ?? false
  }

  private func installSession(
    _ session: any LeatherDocumentSessionManaging,
    documentURL: URL?,
    state: LeatherDocumentState,
    forcedDirtyUntilSave: Bool = false
  ) {
    self.session = session
    self.documentURL = documentURL
    self.forcedDirtyUntilSave = forcedDirtyUntilSave
    lastAppliedState = state
    updateHistoryAvailability(state)
    isDocumentDirty = forcedDirtyUntilSave || state.persistence.isDirty
  }

  private func updateDirtyState(for state: LeatherDocumentState?) {
    isDocumentDirty = forcedDirtyUntilSave || (state?.persistence.isDirty ?? false)
  }
}

extension LeatherDocumentSession: LeatherDocumentSessionManaging {}
