import Combine
import Foundation

struct DocumentRecoveryBannerState: Equatable {
  let recoveryID: String
  let message: String
  let details: String
}

struct DocumentRecoveryChooserState: Identifiable, Equatable {
  let id = UUID()
  var candidates: [DocumentRecoveryCandidate]
}

struct RecoverySnapshotContext {
  let state: LeatherDocumentState
  let isDirty: Bool
  let documentURL: URL?
  let documentName: String
  let versionInfo: LeatherCoreVersionInfo?
  let appVersion: String
  let snapshotWriter: (URL) -> LeatherCoreResult<Void>
}

/// UI recovery candidates and banner presentation. Snapshot I/O and scheduling
/// remain in `DocumentRecoveryAdapter`, matching the split in `useRecoverySnapshot`.
final class RecoverySnapshotState: ObservableObject {
  @Published private(set) var banner: DocumentRecoveryBannerState?
  @Published private(set) var chooser: DocumentRecoveryChooserState?

  private let adapter: DocumentRecoveryAdapter
  let configuration: DocumentRecoveryConfiguration
  private var documentSessionID = UUID()
  private var recoveryIDOverride: String?
  private var writeTask: Task<Void, Never>?
  private var dirtySince: Date?
  private var lastWrittenFingerprint: Data?
  private var didLoadStartupRecoveries = false
  private var latestContext: RecoverySnapshotContext?

  init(
    configuration: DocumentRecoveryConfiguration,
    adapter: DocumentRecoveryAdapter? = nil
  ) {
    self.configuration = configuration
    self.adapter =
      adapter
      ?? DocumentRecoveryAdapter(
        configuration: configuration,
        enabled: configuration.baseDirectoryURL.lastPathComponent
          != "KawaCAD-Recovery-Disabled"
      )
  }

  var isEnabled: Bool { adapter.isEnabled }

  func setBanner(_ banner: DocumentRecoveryBannerState?) {
    self.banner = banner
  }

  func setChooser(_ chooser: DocumentRecoveryChooserState?) {
    self.chooser = chooser
  }

  func loadCandidates() -> [DocumentRecoveryCandidate] {
    adapter.loadCandidates()
  }

  func loadStartupChooserIfNeeded() -> DocumentRecoveryChooserState? {
    guard isEnabled, !didLoadStartupRecoveries else { return nil }
    didLoadStartupRecoveries = true
    let candidates = loadCandidates()
    return candidates.isEmpty
      ? nil
      : DocumentRecoveryChooserState(candidates: candidates)
  }

  func removeRecovery(recoveryID: String) {
    adapter.removeRecovery(recoveryID: recoveryID)
  }

  func commitSnapshot(
    recoveryID: String,
    documentID: String,
    displayName: String,
    originalDocumentURL: URL?,
    contentFingerprint: Data,
    versionInfo: LeatherCoreVersionInfo?,
    appVersion: String,
    snapshotWriter: (URL) -> LeatherCoreResult<Void>
  ) -> Result<DocumentRecoveryCommitResult, DocumentRecoveryAdapterError> {
    adapter.commitSnapshot(
      recoveryID: recoveryID,
      documentID: documentID,
      displayName: displayName,
      originalDocumentURL: originalDocumentURL,
      contentFingerprint: contentFingerprint,
      versionInfo: versionInfo,
      appVersion: appVersion,
      snapshotWriter: snapshotWriter
    )
  }

  func beginDocumentSession(recoveryIDOverride: String? = nil) {
    documentSessionID = UUID()
    self.recoveryIDOverride = recoveryIDOverride
    dirtySince = nil
    lastWrittenFingerprint = nil
    writeTask?.cancel()
    banner = nil
    latestContext = nil
  }

  func sync(_ context: RecoverySnapshotContext?) {
    guard isEnabled else { return }
    latestContext = context
    guard let context else {
      clearPendingSnapshotState()
      return
    }
    if context.isDirty {
      scheduleSnapshot(for: context)
    } else {
      writeTask?.cancel()
      dirtySince = nil
      // This fingerprint tracks a recovery generation that was actually
      // written. A clean document has no recovery generation, so keeping
      // its fingerprint would suppress a later dirty transition whose
      // Core snapshot happens to be byte-for-byte identical.
      lastWrittenFingerprint = nil
      banner = nil
      removeRecovery(recoveryID: currentRecoveryID(documentURL: context.documentURL))
    }
  }

  func flush(force: Bool = false) {
    writeTask?.cancel()
    writeSnapshot(force: force)
  }

  func markSaved(recoveryID: String) {
    recoveryIDOverride = nil
    dirtySince = nil
    lastWrittenFingerprint = nil
    writeTask?.cancel()
    banner = nil
    latestContext = nil
    removeRecovery(recoveryID: recoveryID)
  }

  func discardCurrent(documentURL: URL?) {
    guard isEnabled else { return }
    writeTask?.cancel()
    removeRecovery(recoveryID: currentRecoveryID(documentURL: documentURL))
    dirtySince = nil
    lastWrittenFingerprint = nil
    banner = nil
    latestContext = nil
  }

  func discard(recoveryID: String?) {
    guard let recoveryID, isEnabled else { return }
    removeRecovery(recoveryID: recoveryID)
  }

  func currentRecoveryID(documentURL: URL?) -> String {
    RecoveryFeature.recoveryID(
      override: recoveryIDOverride,
      documentURL: documentURL,
      sessionID: documentSessionID
    )
  }

  private func scheduleSnapshot(for context: RecoverySnapshotContext) {
    let fingerprint = RecoveryFeature.fingerprint(context.state)
    let now = Date()
    if dirtySince == nil {
      dirtySince = now
    }
    let delay: TimeInterval
    if let dirtySince,
      now.timeIntervalSince(dirtySince) >= configuration.maxDirtyDelay
    {
      delay = 0
    } else {
      delay = configuration.saveDelay
    }
    if lastWrittenFingerprint == fingerprint, banner == nil {
      return
    }

    writeTask?.cancel()
    writeTask = Task { @MainActor [weak self] in
      if delay > 0 {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      }
      guard !Task.isCancelled else { return }
      self?.writeSnapshot(force: false)
    }
  }

  private func writeSnapshot(force: Bool) {
    guard isEnabled,
      let context = latestContext,
      context.isDirty
    else {
      return
    }
    let fingerprint = RecoveryFeature.fingerprint(context.state)
    if !force, lastWrittenFingerprint == fingerprint {
      return
    }

    let result = commitSnapshot(
      recoveryID: currentRecoveryID(documentURL: context.documentURL),
      documentID: documentSessionID.uuidString.lowercased(),
      displayName: context.documentName,
      originalDocumentURL: context.documentURL,
      contentFingerprint: fingerprint,
      versionInfo: context.versionInfo,
      appVersion: context.appVersion,
      snapshotWriter: context.snapshotWriter
    )

    switch result {
    case .success:
      lastWrittenFingerprint = fingerprint
      dirtySince = Date()
      banner = nil
    case .failure(let error):
      banner = DocumentRecoveryBannerState(
        recoveryID: currentRecoveryID(documentURL: context.documentURL),
        message: AppStrings.tr("document.recovery.banner_message"),
        details: error.localizedDescription
      )
    }
  }

  private func clearPendingSnapshotState() {
    writeTask?.cancel()
    dirtySince = nil
    lastWrittenFingerprint = nil
    banner = nil
  }
}
