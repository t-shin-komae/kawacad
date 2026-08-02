import Combine
import Foundation
import KawaCADOutput

/// UI-facing document session, corresponding to React's `useCadSession`.
///
/// `DocumentSessionAdapter` remains the Core/file adapter. This type is the
/// single owner of the state a workspace renders from: the latest Core state,
/// an optional non-destructive preview, connection status, and user message.
final class CadSessionState: ObservableObject {
  private let documentAdapter: any DocumentSessionAdapting
  private let coreStatusProvider: () -> LeatherCoreStatus

  @Published private(set) var state: LeatherDocumentState?
  @Published private(set) var previewState: LeatherDocumentState?
  @Published private var previewEntitiesOverride: [CanvasEntity]?
  @Published private var previewCoincidentPointGroupsOverride: [CoincidentPointGroup]?
  @Published private var previewCanvasProjectionOverride: LeatherCanvasProjection?
  @Published private(set) var message: String
  @Published private(set) var coreStatus: LeatherCoreStatus

  /// The workspace may normalize local drawing choices after a Core state
  /// changes, but it never becomes another owner of the document state.
  var onDocumentState: ((LeatherDocumentState?) -> Void)?

  init(
    documentAdapter: any DocumentSessionAdapting,
    coreStatusProvider: @escaping () -> LeatherCoreStatus,
    initialMessage: String = AppStrings.tr("app.status.created_new_document")
  ) {
    self.documentAdapter = documentAdapter
    self.coreStatusProvider = coreStatusProvider
    state = nil
    message = initialMessage
    coreStatus = .unavailable(AppStrings.tr("app.core.unavailable"))
  }

  var documentURL: URL? { documentAdapter.documentURL }
  var hasDocument: Bool { documentAdapter.hasDocument }
  var canUndo: Bool { documentAdapter.canUndo }
  var canRedo: Bool { documentAdapter.canRedo }
  var isDocumentDirty: Bool { documentAdapter.isDocumentDirty }
  var previewActive: Bool { previewState != nil }
  var previewEntities: [CanvasEntity]? { previewEntitiesOverride ?? previewState?.entities }
  var previewCoincidentPointGroups: [CoincidentPointGroup]? {
    previewCoincidentPointGroupsOverride ?? previewState?.coincidentPointGroups
  }
  var previewCanvasProjection: LeatherCanvasProjection? {
    previewCanvasProjectionOverride ?? previewState?.canvasProjection
  }

  func setMessage(_ message: String) {
    self.message = message
  }

  func setCoreStatus(_ status: LeatherCoreStatus) {
    coreStatus = status
  }

  func applyState(_ next: LeatherDocumentState) {
    documentAdapter.recordAppliedState(next)
    state = next
    clearCanvasPreview()
    onDocumentState?(next)
  }

  func clearState() {
    documentAdapter.recordAppliedState(nil)
    state = nil
    clearCanvasPreview()
    onDocumentState?(nil)
  }

  @discardableResult
  func saveDocument(to url: URL) -> LeatherCoreResult<Void> {
    let result = documentAdapter.saveDocument(to: url)
    guard case .success = result else { return result }

    if var state {
      state.persistence = LeatherPersistenceState(
        isDirty: false,
        revision: state.persistence.revision
      )
      self.state = state
      onDocumentState?(state)
    }
    return result
  }

  func clearCanvasPreview() {
    previewState = nil
    previewEntitiesOverride = nil
    previewCoincidentPointGroupsOverride = nil
    previewCanvasProjectionOverride = nil
  }

  func setPreviewEntities(_ entities: [CanvasEntity]?) {
    previewEntitiesOverride = entities
  }

  func setPreviewCoincidentPointGroups(_ groups: [CoincidentPointGroup]?) {
    previewCoincidentPointGroupsOverride = groups
  }

  func setPreviewCanvasProjection(_ projection: LeatherCanvasProjection?) {
    previewCanvasProjectionOverride = projection
  }

  @discardableResult
  func previewCommand(
    _ command: CoreDocumentCommand,
    viewMode: CanvasViewMode
  ) -> LeatherCoreResult<LeatherDocumentState> {
    let result = documentAdapter.previewCommand(command, viewMode: viewMode)
    if case .success(let next) = result {
      previewEntitiesOverride = nil
      previewCoincidentPointGroupsOverride = nil
      previewCanvasProjectionOverride = nil
      previewState = next
    }
    return result
  }

  @discardableResult
  func refresh(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    let result = documentAdapter.loadState(viewMode: viewMode)
    switch result {
    case .success(let next):
      applyState(next)
    case .failure:
      // Preserve the UI state that was last rendered. The adapter's
      // lifecycle cache is intentionally not a second UI state source.
      break
    }
    return result
  }

  func refreshCoreStatus() {
    coreStatus = coreStatusProvider()
  }

  @discardableResult
  func createDocument(
    named name: String,
    viewMode: CanvasViewMode
  ) -> LeatherCoreResult<LeatherDocumentState> {
    applyDocumentResult(documentAdapter.createNewDocument(named: name, viewMode: viewMode))
  }

  @discardableResult
  func openDocument(
    at url: URL,
    viewMode: CanvasViewMode
  ) -> LeatherCoreResult<LeatherDocumentState> {
    applyDocumentResult(documentAdapter.openDocument(at: url, viewMode: viewMode))
  }

  @discardableResult
  func recoverDocument(
    from recoverySnapshotURL: URL,
    suggestedDocumentURL: URL?,
    viewMode: CanvasViewMode
  ) -> LeatherCoreResult<LeatherDocumentState> {
    applyDocumentResult(
      documentAdapter.recoverDocument(
        from: recoverySnapshotURL,
        suggestedDocumentURL: suggestedDocumentURL,
        viewMode: viewMode
      ))
  }

  @discardableResult
  func undo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    applyDocumentResult(documentAdapter.undo(viewMode: viewMode))
  }

  @discardableResult
  func redo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    applyDocumentResult(documentAdapter.redo(viewMode: viewMode))
  }

  func preflightConstraint(
    kind: String,
    targets: [CoreConstraintTarget]
  ) -> LeatherCoreResult<ConstraintPreflightResult> {
    documentAdapter.preflightConstraint(kind: kind, targets: targets)
  }

  func preflightDerivedElement(
    kind: DerivedElementPreflightKind,
    hitEntityID: String?,
    selectedEntityIDs: [String],
    clickPoint: ModelPoint?
  ) -> LeatherCoreResult<DerivedElementPreflightResult> {
    documentAdapter.preflightDerivedElement(
      kind: kind,
      hitEntityID: hitEntityID,
      selectedEntityIDs: selectedEntityIDs,
      clickPoint: clickPoint
    )
  }

  func layerDeletionImpact(layerID: String) -> LeatherCoreResult<LayerDeletionImpact> {
    documentAdapter.layerDeletionImpact(layerID: layerID)
  }

  func exportSelection(
    _ selection: CoreSelectionReference
  ) -> LeatherCoreResult<SelectionClipboardExport> {
    documentAdapter.exportSelection(selection)
  }

  func exportPartLibraryItem(partID: String) -> LeatherCoreResult<PartLibraryExport> {
    documentAdapter.exportPartLibraryItem(partID: partID)
  }

  func writeSnapshot(to url: URL) -> LeatherCoreResult<Void> {
    documentAdapter.writeSnapshot(to: url)
  }

  /// Applies a semantic document command through the internal adapter and
  /// owns the resulting Core state, matching `useCadSession.execute`.
  func execute(
    _ request: DocumentCommandRequest,
    viewMode: CanvasViewMode
  ) -> DocumentCommandExecutionResult {
    switch documentAdapter.applyCommand(request.payload, viewMode: viewMode) {
    case .success(let next):
      applyState(next)
      return .success(next, successMessage: request.successMessage)
    case .failure(let failure):
      return .failure(failure)
    }
  }

  private func applyDocumentResult(
    _ result: LeatherCoreResult<LeatherDocumentState>
  ) -> LeatherCoreResult<LeatherDocumentState> {
    if case .success(let next) = result {
      applyState(next)
    }
    return result
  }
}

extension CadSessionState: OutputSession {
  func buildOutputDocumentModel(options: OutputBuildOptions) -> OutputResult<OutputBuildResult> {
    documentAdapter.buildOutputDocumentModel(options: options)
  }

  func renderPDF(outputDocumentModel: OutputDocumentModel) -> OutputResult<Data> {
    documentAdapter.renderPDF(outputDocumentModel: outputDocumentModel)
  }

  func renderPrint(outputDocumentModel: OutputDocumentModel) -> OutputResult<OutputPrintRenderData>
  {
    documentAdapter.renderPrint(outputDocumentModel: outputDocumentModel)
  }
}
