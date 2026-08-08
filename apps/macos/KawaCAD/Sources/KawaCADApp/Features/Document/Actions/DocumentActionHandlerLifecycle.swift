import AppKit
import KawaCADOutput
import SwiftUI

/// Document create, open, save, close, and reload actions.
extension DocumentActionHandler {
  func createNewProject() {
    guard hasValidPendingDocumentNameDraft() else {
      return
    }
    guard requestDocumentIntent(.createNewProject) else {
      return
    }
    performCreateNewProject()
  }

  func openProjectPanel() {
    guard let url = desktopEnvironment.promptForOpenProjectURL() else { return }
    openProject(at: url)
  }

  func openProject(at url: URL) {
    guard commitPendingDocumentNameDraftBeforeDocumentTransition() else {
      return
    }
    guard requestDocumentIntent(.openProject(url)) else {
      return
    }
    performOpenProject(at: url)
  }

  func saveProject() {
    guard commitPendingDocumentNameDraftBeforeDocumentTransition() else {
      return
    }
    if let documentURL {
      _ = writeProject(to: documentURL)
    } else {
      _ = saveProjectAsPanel()
    }
  }

  @discardableResult
  func saveProjectAsPanel() -> Bool {
    guard commitPendingDocumentNameDraftBeforeDocumentTransition() else {
      return false
    }
    return saveProjectAsPanelResult() == .saved
  }

  func requestWindowClose() -> Bool {
    syncDocumentRecoveryState()
    recoverySnapshotState.flush()
    if !isDocumentDirty {
      recoverySnapshotState.discardCurrent(documentURL: documentURL)
    }
    return requestDocumentIntent(.closeWindow)
  }

  func requestApplicationQuit() -> Bool {
    if documentPresentation.consumeDiscardedWindowClosePendingApplicationTermination() {
      recoverySnapshotState.discardCurrent(documentURL: documentURL)
      return true
    }
    syncDocumentRecoveryState()
    recoverySnapshotState.flush()
    if !isDocumentDirty {
      recoverySnapshotState.discardCurrent(documentURL: documentURL)
    }
    return requestDocumentIntent(.quitApplication)
  }

  func confirmDocumentSaveAndContinue() {
    guard let intent = documentPresentation.pendingIntent else {
      return
    }
    switch saveForPendingDocumentIntent() {
    case .saved:
      dismissDocumentSaveConfirmation()
      executePendingDocumentIntent(intent)
    case .cancelled:
      dismissDocumentSaveConfirmation()
      cancelPendingDocumentIntent(intent)
    case .failed:
      break
    }
  }

  func discardDocumentChangesAndContinue() {
    guard let intent = documentPresentation.pendingIntent else {
      return
    }
    if case .closeWindow = intent {
      documentPresentation.markDiscardedWindowClosePendingApplicationTermination()
    }
    dismissDocumentSaveConfirmation()
    executePendingDocumentIntent(intent)
  }

  func cancelDocumentSaveConfirmation() {
    guard let intent = documentPresentation.pendingIntent else {
      return
    }
    dismissDocumentSaveConfirmation()
    cancelPendingDocumentIntent(intent)
  }

  func performCreateNewProject(discardingRecoveryID: String? = nil) {
    switch cadSession.createDocument(
      named: AppStrings.tr("app.document.untitled"), viewMode: canvasPresentation.viewMode)
    {
    case .success(let state):
      prepareForLoadedDocument()
      recoverySnapshotState.beginDocumentSession()
      statusMessage = AppStrings.tr("app.status.created_new_document")
      handleCadSessionStateChange(state)
      if canvasPresentation.viewMode == .outputPreview {
        refreshOutputPreviewBuildResult()
      } else {
        outputPresentation.setPreviewBuildResult(nil)
      }
      recoverySnapshotState.discard(recoveryID: discardingRecoveryID)
    case .failure(let message):
      coreStatus = .unavailable(message.localizedDescription)
      presentCoreFailure(message, operation: "recoverDocument")
    }
  }

  private func performOpenProject(at url: URL, discardingRecoveryID: String? = nil) {
    switch cadSession.openDocument(at: url, viewMode: canvasPresentation.viewMode) {
    case .success(let state):
      prepareForLoadedDocument()
      recoverySnapshotState.beginDocumentSession()
      statusMessage = AppStrings.tr("status.opened_project", url.lastPathComponent)
      handleCadSessionStateChange(state)
      if canvasPresentation.viewMode == .outputPreview {
        refreshOutputPreviewBuildResult()
      } else {
        outputPresentation.setPreviewBuildResult(nil)
      }
      recoverySnapshotState.discard(recoveryID: discardingRecoveryID)
    case .failure(let message):
      coreStatus = .unavailable(message.localizedDescription)
      presentCoreFailure(message, operation: "openDocument")
    }
  }

  @discardableResult
  private func writeProject(to url: URL) -> Bool {
    guard commitPendingDocumentNameDraftBeforeDocumentTransition() else {
      return false
    }
    let previousRecoveryID = recoverySnapshotState.currentRecoveryID(documentURL: documentURL)
    switch cadSession.saveDocument(to: url) {
    case .success:
      recoverySnapshotState.markSaved(recoveryID: previousRecoveryID)
      statusMessage = AppStrings.tr("status.saved_project", url.lastPathComponent)
      return true
    case .failure(let message):
      coreStatus = .unavailable(message.localizedDescription)
      presentCoreFailure(message, operation: "loadDocument")
      return false
    }
  }

  private func requestDocumentIntent(_ intent: PendingDocumentIntent) -> Bool {
    if documentPresentation.saveConfirmation != nil {
      if case .quitApplication = intent {
        documentLifecycleController?.replyToApplicationTermination(false)
      }
      return false
    }
    guard cadSession.hasDocument, isDocumentDirty else {
      return true
    }
    documentPresentation.beginPendingIntent(intent)
    documentPresentation.setSaveConfirmation(
      DocumentSaveConfirmation(
        documentName: documentName,
        reason: AppStrings.tr(intent.confirmationReasonKey)
      ))
    return false
  }

  private func dismissDocumentSaveConfirmation() {
    documentPresentation.setSaveConfirmation(nil)
    documentPresentation.clearPendingIntent()
  }

  private func executePendingDocumentIntent(_ intent: PendingDocumentIntent) {
    switch intent {
    case .createNewProject:
      performCreateNewProject(
        discardingRecoveryID: recoverySnapshotState.currentRecoveryID(documentURL: documentURL))
    case .openProject(let url):
      performOpenProject(
        at: url,
        discardingRecoveryID: recoverySnapshotState.currentRecoveryID(documentURL: documentURL))
    case .closeWindow:
      recoverySnapshotState.discardCurrent(documentURL: documentURL)
      documentLifecycleController?.continueClosingWindow()
    case .quitApplication:
      recoverySnapshotState.discardCurrent(documentURL: documentURL)
      documentLifecycleController?.replyToApplicationTermination(true)
    }
  }

  private func cancelPendingDocumentIntent(_ intent: PendingDocumentIntent) {
    if case .quitApplication = intent {
      documentLifecycleController?.replyToApplicationTermination(false)
    }
  }

  private func saveForPendingDocumentIntent() -> PendingDocumentSaveResult {
    if let documentURL {
      return writeProject(to: documentURL) ? .saved : .failed
    }
    return saveProjectAsPanelResult()
  }

  private func saveProjectAsPanelResult() -> PendingDocumentSaveResult {
    guard
      let url = desktopEnvironment.promptForSaveProjectURL(
        documentName: documentName
      )
    else {
      return .cancelled
    }
    return writeProject(to: url) ? .saved : .failed
  }

  func refreshCoreStatus() {
    cadSession.refreshCoreStatus()
  }

  func reloadFromDocument() {
    refreshCoreStatus()
    canvasPresentation.setPendingConstraintValueDraft(nil)

    guard cadSession.hasDocument else {
      clearDocumentState()
      return
    }

    switch cadSession.refresh(viewMode: canvasPresentation.viewMode) {
    case .success:
      if canvasPresentation.viewMode == .outputPreview {
        refreshOutputPreviewBuildResult()
      } else {
        outputPresentation.setPreviewBuildResult(nil)
      }
    case .failure(let message):
      outputPresentation.setPreviewBuildResult(nil)
      coreStatus = .unavailable(message.localizedDescription)
      presentCoreFailure(message, operation: "buildOutputPreview")
    }
  }

  func prepareForLoadedDocument() {
    documentPresentation.setPendingNameDraft(nil)
    canvasPresentation.resetForLoadedDocument()
    resetInspectorPresentationForLoadedDocument()
  }

}

private enum PendingDocumentSaveResult {
  case saved
  case cancelled
  case failed
}
