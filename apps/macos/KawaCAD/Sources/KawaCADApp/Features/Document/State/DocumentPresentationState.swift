import Combine

/// Document-workflow UI state that is not part of the Core document.
final class DocumentPresentationState: ObservableObject {
  @Published private(set) var alertMessage: UserAlertMessage?
  @Published private(set) var layerDeletionConfirmation: LayerDeletionConfirmation?
  @Published private(set) var saveConfirmation: DocumentSaveConfirmation?
  @Published private(set) var clipboardBundle: ClipboardBundle?
  @Published private(set) var pasteOptions: PasteOptionsPresentation?
  @Published private(set) var pendingNameDraft: String?
  private(set) var pendingIntent: PendingDocumentIntent?
  private(set) var discardedWindowClosePendingApplicationTermination = false
  private(set) var clipboardPasteSequence = 0
  private(set) var lastPasteCursorPoint: ModelPoint?
  private(set) var lastPastePlacementPoint: ModelPoint?

  func setAlertMessage(_ message: UserAlertMessage?) {
    alertMessage = message
  }

  func setLayerDeletionConfirmation(_ confirmation: LayerDeletionConfirmation?) {
    layerDeletionConfirmation = confirmation
  }

  func setSaveConfirmation(_ confirmation: DocumentSaveConfirmation?) {
    saveConfirmation = confirmation
  }

  func setClipboardBundle(_ bundle: ClipboardBundle?) {
    clipboardBundle = bundle
  }

  func setPasteOptions(_ options: PasteOptionsPresentation?) {
    pasteOptions = options
  }

  func setPendingNameDraft(_ draft: String?) {
    pendingNameDraft = draft
  }

  func beginPendingIntent(_ intent: PendingDocumentIntent) {
    pendingIntent = intent
  }

  func clearPendingIntent() {
    pendingIntent = nil
  }

  func markDiscardedWindowClosePendingApplicationTermination() {
    discardedWindowClosePendingApplicationTermination = true
  }

  func consumeDiscardedWindowClosePendingApplicationTermination() -> Bool {
    guard discardedWindowClosePendingApplicationTermination else { return false }
    discardedWindowClosePendingApplicationTermination = false
    return true
  }

  func resetPasteTracking() {
    clipboardPasteSequence = 0
    lastPasteCursorPoint = nil
    lastPastePlacementPoint = nil
  }

  func advancePasteSequence(to sequence: Int) {
    clipboardPasteSequence = sequence
  }

  func recordPastePlacement(
    cursorPoint: ModelPoint?,
    placementPoint: ModelPoint
  ) {
    lastPasteCursorPoint = cursorPoint
    lastPastePlacementPoint = placementPoint
  }
}
