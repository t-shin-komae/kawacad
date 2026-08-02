import AppKit
import KawaCADOutput
import SwiftUI

/// Recovery lifecycle and snapshot presentation actions.
extension RecoveryActionHandler {
  func handleApplicationLaunch() {
    recoverySnapshotState.setChooser(recoverySnapshotState.loadStartupChooserIfNeeded())
  }

  func handleApplicationWillResignActive() {
    syncDocumentRecoveryState()
    recoverySnapshotState.flush()
  }

  func retryRecoveryBanner() {
    recoverySnapshotState.setBanner(nil)
    syncDocumentRecoveryState()
    recoverySnapshotState.flush(force: true)
  }

  func dismissRecoveryBanner() {
    recoverySnapshotState.setBanner(nil)
  }

  func postponeRecoveryChooser() {
    recoverySnapshotState.setChooser(nil)
  }

  func discardRecoveryCandidate(_ candidate: DocumentRecoveryCandidate) {
    recoverySnapshotState.removeRecovery(recoveryID: candidate.recoveryID)
    guard var chooser = recoverySnapshotState.chooser else {
      return
    }
    chooser.candidates.removeAll { $0.recoveryID == candidate.recoveryID }
    recoverySnapshotState.setChooser(chooser.candidates.isEmpty ? nil : chooser)
  }

  func recoverRecoveryCandidate(_ candidate: DocumentRecoveryCandidate) {
    guard case .recoverable(let snapshotURL) = candidate.status else {
      return
    }
    switch cadSession.recoverDocument(
      from: snapshotURL,
      suggestedDocumentURL: candidate.originalDocumentURL,
      viewMode: canvasPresentation.viewMode
    ) {
    case .success(let state):
      prepareForLoadedDocument()
      recoverySnapshotState.beginDocumentSession(recoveryIDOverride: candidate.recoveryID)
      statusMessage = AppStrings.tr("document.recovery.recovered_document")
      handleCadSessionStateChange(state)
      recoverySnapshotState.setChooser(nil)
      if canvasPresentation.viewMode == .outputPreview {
        refreshOutputPreviewBuildResult()
      } else {
        outputPresentation.setPreviewBuildResult(nil)
      }
    case .failure(let message):
      coreStatus = .unavailable(message.localizedDescription)
      presentCoreFailure(message, operation: "connectCore")
    }
  }

  func syncDocumentRecoveryState() {
    guard let currentDocumentState else {
      recoverySnapshotState.sync(nil)
      return
    }
    let versionInfo: LeatherCoreVersionInfo?
    switch coreStatus {
    case .connected(let info):
      versionInfo = info
    case .unavailable:
      versionInfo = nil
    }
    recoverySnapshotState.sync(
      RecoverySnapshotContext(
        state: currentDocumentState,
        isDirty: isDocumentDirty,
        documentURL: documentURL,
        documentName: documentName,
        versionInfo: versionInfo,
        appVersion: desktopEnvironment.appVersion,
        snapshotWriter: { [cadSession] snapshotURL in
          cadSession.writeSnapshot(to: snapshotURL)
        }
      ))
  }

}
