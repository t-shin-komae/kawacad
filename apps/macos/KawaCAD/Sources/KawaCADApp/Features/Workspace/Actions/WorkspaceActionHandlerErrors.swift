import Foundation

extension WorkspaceActionHandler {
  func presentCoreFailure(
    _ failure: CoreFailure,
    operation: String,
    commandKind: String? = nil
  ) {
    statusMessage = failure.localizedDescription
    presentError(
      .coreFailure(
        failure,
        operation: operation,
        commandKind: commandKind
      ))
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
    statusMessage = message
    presentError(
      .make(
        category: .userCorrectable,
        code: code,
        operation: operation,
        message: message,
        details: details,
        recoverySuggestion: recoverySuggestion,
        commandKind: commandKind,
        constraintKind: constraintKind,
        targetIDs: targetIDs
      )
    )
  }

  func presentOperationFailure(
    _ message: String,
    code: String = "operationFailure",
    operation: String = "general",
    details: String? = nil,
    recoverySuggestion: String? = nil,
    commandKind: String? = nil,
    constraintKind: String? = nil,
    targetIDs: [String] = []
  ) {
    statusMessage = message
    presentError(
      .make(
        category: .operationFailure,
        code: code,
        operation: operation,
        message: message,
        details: details,
        recoverySuggestion: recoverySuggestion,
        commandKind: commandKind,
        constraintKind: constraintKind,
        targetIDs: targetIDs
      )
    )
  }

  func presentSystemInternalError(
    _ message: String,
    code: String = "systemInternal",
    operation: String = "general",
    details: String? = nil,
    recoverySuggestion: String? = nil,
    commandKind: String? = nil,
    constraintKind: String? = nil,
    targetIDs: [String] = []
  ) {
    statusMessage = message
    presentError(
      .make(
        category: .systemInternal,
        code: code,
        operation: operation,
        message: message,
        details: details,
        recoverySuggestion: recoverySuggestion,
        commandKind: commandKind,
        constraintKind: constraintKind,
        targetIDs: targetIDs
      )
    )
  }

  func dismissPresentedError() {
    errorPresentationState.dismiss()
  }

  func presentInvalidDragError(_ message: String) {
    presentUserCorrectableError(
      message,
      code: "invalidDrag",
      operation: "canvasDrag",
      recoverySuggestion: AppStrings.tr("error.recovery.adjust_selection_or_target")
    )
  }

  private func presentError(_ presentation: AppErrorPresentation) {
    errorPresentationState.present(presentation)
  }
}
