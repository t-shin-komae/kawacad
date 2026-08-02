import CoreGraphics
import Foundation

/// Cross-feature routing used by an individual handler when one user intent
/// spans more than one feature. These methods contain no feature behavior;
/// they only hand the request to the owning handler.
extension AppActionHandlerRouting {
  @discardableResult
  func executeDocumentCommand(_ request: DocumentCommandRequest) -> Bool {
    actions.document.executeDocumentCommand(request)
  }

  func presentCoreFailure(
    _ error: CoreFailure,
    operation: String,
    commandKind: String? = nil
  ) {
    actions.workspace.presentCoreFailure(error, operation: operation, commandKind: commandKind)
  }

  func presentInvalidDragError(_ message: String) {
    actions.workspace.presentInvalidDragError(message)
  }

  func reloadFromDocument() {
    actions.document.reloadFromDocument()
  }

  func dismissPasteOptions() {
    actions.document.dismissPasteOptions()
  }

  func clearPlacementDraft() {
    actions.canvas.clearPlacementDraft()
  }

  func cancelMovePreview() {
    actions.document.cancelMovePreview()
  }

  func setDetailedToolsVisible(_ visible: Bool) {
    actions.workspace.setDetailedToolsVisible(visible)
  }

  func handleConstraintTargetSelection(_ target: CanvasSelectionTarget?) {
    actions.constraints.handleConstraintTargetSelection(target)
  }

  func beginFilletValueEntry(
    sourceEntityIDs: [String],
    initialValueText: String = "",
    lastAddedSourceID: String? = nil
  ) {
    actions.constraints.beginFilletValueEntry(
      sourceEntityIDs: sourceEntityIDs,
      initialValueText: initialValueText,
      lastAddedSourceID: lastAddedSourceID
    )
  }

  func beginOffsetValueEntry(
    sourceEntityIDs: [String],
    sourceResolvedEntityIDs: [String],
    direction: String,
    scopeOptions: [OffsetSourceScopeOption]
  ) {
    actions.constraints.beginOffsetValueEntry(
      sourceEntityIDs: sourceEntityIDs,
      sourceResolvedEntityIDs: sourceResolvedEntityIDs,
      direction: direction,
      scopeOptions: scopeOptions
    )
  }

  func filletSourceEntityIDs(from targets: [CanvasSelectionTarget]) -> [String] {
    actions.constraints.filletSourceEntityIDs(from: targets)
  }

  func filletSourceEntityIDs(from selectedSourceIDs: Set<String>) -> [String] {
    actions.constraints.filletSourceEntityIDs(from: selectedSourceIDs)
  }

  func offsetSourceOptions(
    for entity: CanvasEntity,
    selectedSourceIDs: Set<String>,
    clickPoint: ModelPoint?
  ) -> [OffsetSourceScopeOption] {
    actions.constraints.offsetSourceOptions(
      for: entity,
      selectedSourceIDs: selectedSourceIDs,
      clickPoint: clickPoint
    )
  }

  func applyConstraint(kind: String, targets: [[String: Any]], value: Any = NSNull()) {
    actions.constraints.applyConstraint(kind: kind, targets: targets, value: value)
  }

  func applyConstraintUsingCoreInitialValue(kind: String, targets: [[String: Any]]) {
    actions.constraints.applyConstraintUsingCoreInitialValue(kind: kind, targets: targets)
  }

  func selectedLineTargetsForEqualLength() -> [CanvasSelectionTarget] {
    actions.constraints.selectedLineTargetsForEqualLength()
  }

  func duplicatePart(_ part: ProjectPart, delta: ModelPoint = ModelPoint(xMM: 10, yMM: -10)) {
    actions.parts.duplicatePart(part, delta: delta)
  }

  func selectPartContents(_ part: ProjectPart) {
    actions.parts.selectPartContents(part)
  }

  @discardableResult
  func movePart(_ part: ProjectPart, delta: ModelPoint) -> Bool {
    actions.parts.movePart(part, delta: delta)
  }

  func setSelectedPartOrigin(_ point: ModelPoint) {
    actions.parts.setSelectedPartOrigin(point)
  }

  func prepareForLoadedDocument() {
    actions.document.prepareForLoadedDocument()
  }

  func handleCadSessionStateChange(_ state: LeatherDocumentState?) {
    actions.document.handleCadSessionStateChange(state)
  }

  func refreshOutputPreviewBuildResult() {
    actions.output.refreshOutputPreviewBuildResult()
  }

  func drawingSharedStyleID(for tool: CanvasTool) -> String? {
    actions.canvas.drawingSharedStyleID(for: tool)
  }

  func selectCreatedItems() {
    actions.canvas.selectCreatedItems()
  }

  func syncDocumentRecoveryState() {
    actions.recovery.syncDocumentRecoveryState()
  }

  func presentUserCorrectableError(
    _ message: String,
    code: String = "userCorrectable",
    operation: String = "general",
    details: String? = nil,
    recoverySuggestion: String? = nil,
    commandKind: String? = nil,
    constraintKind: String? = nil,
    targetIDs: [String] = []
  ) {
    actions.workspace.presentUserCorrectableError(
      message,
      code: code,
      operation: operation,
      details: details,
      recoverySuggestion: recoverySuggestion,
      commandKind: commandKind,
      constraintKind: constraintKind,
      targetIDs: targetIDs
    )
  }

  func presentAlert(_ message: String) {
    actions.document.presentAlert(message)
  }

  func cancelPendingConstraintValueEntry() {
    actions.constraints.cancelPendingConstraintValueEntry()
  }

  func deleteDerivedElement(_ derivedElement: ProjectDerivedElement) {
    actions.document.deleteDerivedElement(derivedElement)
  }

  func resetInspectorPresentationForLoadedDocument() {
    actions.inspector.resetInspectorPresentationForLoadedDocument()
  }

  func reportUnavailable(_ feature: String) {
    actions.document.reportUnavailable(feature)
  }
}
