import CryptoKit
import Foundation

struct DocumentRecoveryConfiguration {
  let baseDirectoryURL: URL
  let saveDelay: TimeInterval
  let maxDirtyDelay: TimeInterval
  let retentionInterval: TimeInterval
  let maxDocuments: Int

  static func live(fileManager: FileManager = .default) -> DocumentRecoveryConfiguration {
    let appSupport =
      fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())
    let baseDirectoryURL =
      appSupport
      .appendingPathComponent("KawaCAD", isDirectory: true)
      .appendingPathComponent("Recovery", isDirectory: true)
    return DocumentRecoveryConfiguration(
      baseDirectoryURL: baseDirectoryURL,
      saveDelay: 2.0,
      maxDirtyDelay: 30.0,
      retentionInterval: 30 * 24 * 60 * 60,
      maxDocuments: 10
    )
  }

  static func disabled() -> DocumentRecoveryConfiguration {
    DocumentRecoveryConfiguration(
      baseDirectoryURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
        "KawaCAD-Recovery-Disabled",
        isDirectory: true
      ),
      saveDelay: 2.0,
      maxDirtyDelay: 30.0,
      retentionInterval: 30 * 24 * 60 * 60,
      maxDocuments: 10
    )
  }
}

struct DocumentRecoveryMetadata: Codable, Equatable {
  let recoveryID: String
  let generationID: String
  let documentID: String
  let displayName: String
  let originalDocumentURL: String?
  let updatedAt: Date
  let appVersion: String
  let fileFormatMajor: UInt32?
  let schemaMajor: UInt32?
  let contentFingerprintBase64: String
}

struct DocumentRecoveryCandidate: Identifiable, Equatable {
  enum Status: Equatable {
    case recoverable(snapshotURL: URL)
    case broken(details: String)
  }

  let recoveryID: String
  let generationID: String?
  let displayName: String
  let originalDocumentURL: URL?
  let updatedAt: Date
  let containerURL: URL
  let metadataURL: URL?
  let status: Status

  var id: String { recoveryID }
  var isRecoverable: Bool {
    if case .recoverable = status {
      return true
    }
    return false
  }
}

enum DocumentRecoveryAdapterError: LocalizedError {
  case disabled
  case snapshotWriteFailed(String)
  case invalidSnapshotJSON
  case metadataWriteFailed

  var errorDescription: String? {
    switch self {
    case .disabled:
      return "document recovery is disabled"
    case .snapshotWriteFailed(let message):
      return message
    case .invalidSnapshotJSON:
      return "snapshot.lcraft is not valid JSON"
    case .metadataWriteFailed:
      return "metadata.json could not be written"
    }
  }
}

struct DocumentRecoveryCommitResult: Equatable {
  let recoveryID: String
  let generationID: String
  let snapshotURL: URL
  let metadata: DocumentRecoveryMetadata
}

final class DocumentRecoveryAdapter {
  private let configuration: DocumentRecoveryConfiguration
  private let fileManager: FileManager
  private let now: () -> Date
  private let enabled: Bool

  init(
    configuration: DocumentRecoveryConfiguration,
    fileManager: FileManager = .default,
    now: @escaping () -> Date = Date.init,
    enabled: Bool = true
  ) {
    self.configuration = configuration
    self.fileManager = fileManager
    self.now = now
    self.enabled = enabled
  }

  var isEnabled: Bool { enabled }

  func loadCandidates() -> [DocumentRecoveryCandidate] {
    guard enabled else {
      return []
    }
    ensureBaseDirectory()
    cleanupRetainedEntries()

    let directoryURLs =
      (try? fileManager.contentsOfDirectory(
        at: configuration.baseDirectoryURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )) ?? []

    let candidates = directoryURLs.compactMap(loadCandidate(at:))
    return candidates.sorted { lhs, rhs in
      if lhs.updatedAt == rhs.updatedAt {
        return lhs.recoveryID < rhs.recoveryID
      }
      return lhs.updatedAt > rhs.updatedAt
    }
  }

  @discardableResult
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
    guard enabled else {
      return .failure(.disabled)
    }
    ensureBaseDirectory()

    let recoveryDirectoryURL = configuration.baseDirectoryURL.appendingPathComponent(
      recoveryID,
      isDirectory: true
    )
    try? fileManager.createDirectory(at: recoveryDirectoryURL, withIntermediateDirectories: true)

    let generationID = UUID().uuidString.lowercased()
    let tempDirectoryURL = recoveryDirectoryURL.appendingPathComponent(
      ".tmp-\(generationID)", isDirectory: true)
    let finalDirectoryURL = recoveryDirectoryURL.appendingPathComponent(
      generationID, isDirectory: true)
    let snapshotURL = tempDirectoryURL.appendingPathComponent("snapshot.lcraft")
    let metadataURL = tempDirectoryURL.appendingPathComponent("metadata.json")
    let committedURL = tempDirectoryURL.appendingPathComponent("COMMITTED")

    try? fileManager.removeItem(at: tempDirectoryURL)
    try? fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)

    switch snapshotWriter(snapshotURL) {
    case .success:
      break
    case .failure(let message):
      try? fileManager.removeItem(at: tempDirectoryURL)
      return .failure(.snapshotWriteFailed(message.localizedDescription))
    }

    guard snapshotLooksValid(at: snapshotURL) else {
      try? fileManager.removeItem(at: tempDirectoryURL)
      return .failure(.invalidSnapshotJSON)
    }

    let metadata = DocumentRecoveryMetadata(
      recoveryID: recoveryID,
      generationID: generationID,
      documentID: documentID,
      displayName: displayName,
      originalDocumentURL: originalDocumentURL?.path,
      updatedAt: now(),
      appVersion: appVersion,
      fileFormatMajor: versionInfo?.fileFormatMajor,
      schemaMajor: versionInfo?.schemaMajor,
      contentFingerprintBase64: contentFingerprint.base64EncodedString()
    )

    guard writeMetadata(metadata, to: metadataURL) else {
      try? fileManager.removeItem(at: tempDirectoryURL)
      return .failure(.metadataWriteFailed)
    }

    fileManager.createFile(atPath: committedURL.path, contents: Data(), attributes: nil)

    do {
      try fileManager.moveItem(at: tempDirectoryURL, to: finalDirectoryURL)
    } catch {
      try? fileManager.removeItem(at: tempDirectoryURL)
      return .failure(.metadataWriteFailed)
    }

    trimGenerations(in: recoveryDirectoryURL, keeping: generationID)
    cleanupRetainedEntries()

    return .success(
      DocumentRecoveryCommitResult(
        recoveryID: recoveryID,
        generationID: generationID,
        snapshotURL: finalDirectoryURL.appendingPathComponent("snapshot.lcraft"),
        metadata: metadata
      ))
  }

  func removeRecovery(recoveryID: String) {
    guard enabled else {
      return
    }
    let recoveryDirectoryURL = configuration.baseDirectoryURL.appendingPathComponent(
      recoveryID,
      isDirectory: true
    )
    try? fileManager.removeItem(at: recoveryDirectoryURL)
  }

  private func loadCandidate(at recoveryDirectoryURL: URL) -> DocumentRecoveryCandidate? {
    let generationURLs =
      ((try? fileManager.contentsOfDirectory(
        at: recoveryDirectoryURL,
        includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles]
      )) ?? []).sorted { lhs, rhs in
        lhs.lastPathComponent > rhs.lastPathComponent
      }

    var brokenCandidate: DocumentRecoveryCandidate?
    for generationURL in generationURLs {
      let candidate = loadGenerationCandidate(
        recoveryID: recoveryDirectoryURL.lastPathComponent,
        generationURL: generationURL
      )
      switch candidate.status {
      case .recoverable:
        return candidate
      case .broken:
        if brokenCandidate == nil {
          brokenCandidate = candidate
        }
      }
    }
    return brokenCandidate
  }

  private func loadGenerationCandidate(
    recoveryID: String,
    generationURL: URL
  ) -> DocumentRecoveryCandidate {
    let metadataURL = generationURL.appendingPathComponent("metadata.json")
    let snapshotURL = generationURL.appendingPathComponent("snapshot.lcraft")
    let committedURL = generationURL.appendingPathComponent("COMMITTED")
    let modificationDate =
      (try? generationURL.resourceValues(forKeys: [.contentModificationDateKey])
        .contentModificationDate)
      ?? now()

    guard fileManager.fileExists(atPath: committedURL.path) else {
      return DocumentRecoveryCandidate(
        recoveryID: recoveryID,
        generationID: generationURL.lastPathComponent,
        displayName: recoveryID,
        originalDocumentURL: nil,
        updatedAt: modificationDate,
        containerURL: generationURL,
        metadataURL: metadataURL,
        status: .broken(details: "COMMITTED marker がありません")
      )
    }

    guard let metadata = readMetadata(at: metadataURL) else {
      return DocumentRecoveryCandidate(
        recoveryID: recoveryID,
        generationID: generationURL.lastPathComponent,
        displayName: recoveryID,
        originalDocumentURL: nil,
        updatedAt: modificationDate,
        containerURL: generationURL,
        metadataURL: metadataURL,
        status: .broken(details: "metadata.json を読めません")
      )
    }

    guard fileManager.fileExists(atPath: snapshotURL.path),
      snapshotLooksValid(at: snapshotURL)
    else {
      return DocumentRecoveryCandidate(
        recoveryID: recoveryID,
        generationID: metadata.generationID,
        displayName: metadata.displayName,
        originalDocumentURL: metadata.originalDocumentURL.map(URL.init(fileURLWithPath:)),
        updatedAt: metadata.updatedAt,
        containerURL: generationURL,
        metadataURL: metadataURL,
        status: .broken(details: "snapshot.lcraft を検証できません")
      )
    }

    return DocumentRecoveryCandidate(
      recoveryID: recoveryID,
      generationID: metadata.generationID,
      displayName: metadata.displayName,
      originalDocumentURL: metadata.originalDocumentURL.map(URL.init(fileURLWithPath:)),
      updatedAt: metadata.updatedAt,
      containerURL: generationURL,
      metadataURL: metadataURL,
      status: .recoverable(snapshotURL: snapshotURL)
    )
  }

  private func cleanupRetainedEntries() {
    guard enabled else {
      return
    }
    let candidates = loadCandidatesWithoutCleanup().sorted { lhs, rhs in
      lhs.updatedAt < rhs.updatedAt
    }

    let expirationDate = now().addingTimeInterval(-configuration.retentionInterval)
    for candidate in candidates where candidate.updatedAt < expirationDate {
      try? fileManager.removeItem(at: rootDirectoryURL(for: candidate.recoveryID))
    }

    let remaining = loadCandidatesWithoutCleanup().sorted { lhs, rhs in
      lhs.updatedAt < rhs.updatedAt
    }
    let recoverable = remaining.filter(\.isRecoverable)
    guard recoverable.count > configuration.maxDocuments else {
      return
    }

    for candidate in recoverable.prefix(recoverable.count - configuration.maxDocuments) {
      try? fileManager.removeItem(at: rootDirectoryURL(for: candidate.recoveryID))
    }
  }

  private func loadCandidatesWithoutCleanup() -> [DocumentRecoveryCandidate] {
    let directoryURLs =
      (try? fileManager.contentsOfDirectory(
        at: configuration.baseDirectoryURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )) ?? []
    return directoryURLs.compactMap(loadCandidate(at:))
  }

  private func trimGenerations(in recoveryDirectoryURL: URL, keeping generationID: String) {
    let generationURLs =
      (try? fileManager.contentsOfDirectory(
        at: recoveryDirectoryURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )) ?? []
    for generationURL in generationURLs where generationURL.lastPathComponent != generationID {
      try? fileManager.removeItem(at: generationURL)
    }
  }

  private func readMetadata(at url: URL) -> DocumentRecoveryMetadata? {
    guard let data = try? Data(contentsOf: url) else {
      return nil
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(DocumentRecoveryMetadata.self, from: data)
  }

  private func writeMetadata(_ metadata: DocumentRecoveryMetadata, to url: URL) -> Bool {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(metadata) else {
      return false
    }
    do {
      try data.write(to: url, options: .atomic)
      return true
    } catch {
      return false
    }
  }

  private func snapshotLooksValid(at url: URL) -> Bool {
    guard let data = try? Data(contentsOf: url),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return false
    }
    if let fileFormatVersion = object["fileFormatVersion"] as? String,
      !fileFormatVersion.isEmpty,
      let schemaVersion = object["schemaVersion"] as? String,
      !schemaVersion.isEmpty
    {
      return true
    }
    return object["document"] != nil
  }

  private func ensureBaseDirectory() {
    try? fileManager.createDirectory(
      at: configuration.baseDirectoryURL,
      withIntermediateDirectories: true
    )
  }

  private func rootDirectoryURL(for recoveryID: String) -> URL {
    configuration.baseDirectoryURL.appendingPathComponent(recoveryID, isDirectory: true)
  }
}

func makeDocumentRecoveryID(documentURL: URL?, sessionID: UUID) -> String {
  if let documentURL {
    let normalized = documentURL.standardizedFileURL.path.lowercased()
    let digest = SHA256.hash(data: Data(normalized.utf8))
    let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
    return "saved-\(hex)"
  }
  return "unsaved-\(sessionID.uuidString.lowercased())"
}
