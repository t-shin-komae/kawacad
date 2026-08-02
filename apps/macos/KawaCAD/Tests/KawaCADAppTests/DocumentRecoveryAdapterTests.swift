import Foundation
import Testing

@testable import KawaCADApp

@Test("DocumentRecoveryAdapter は snapshot を保存して復旧候補として列挙する")
func document_recovery_adapter_commits_and_lists_candidates() throws {
  let baseURL = uniqueTempURL("recovery-adapter")
  let configuration = DocumentRecoveryConfiguration(
    baseDirectoryURL: baseURL,
    saveDelay: 0,
    maxDirtyDelay: 0,
    retentionInterval: 30 * 24 * 60 * 60,
    maxDocuments: 10
  )
  let adapter = DocumentRecoveryAdapter(configuration: configuration)
  let fingerprint = Data("fingerprint".utf8)

  let result = adapter.commitSnapshot(
    recoveryID: "unsaved-session",
    documentID: "document-1",
    displayName: "Recovered Project",
    originalDocumentURL: nil,
    contentFingerprint: fingerprint,
    versionInfo: .init(fileFormatMajor: 1, schemaMajor: 2),
    appVersion: "0.1.0"
  ) { snapshotURL in
    let json = """
      {
        "fileFormatVersion": "0.1.0",
        "schemaVersion": "0.2.0",
        "document": { "name": "Recovered Project" }
      }
      """
    do {
      try Data(json.utf8).write(to: snapshotURL, options: .atomic)
      return .success(())
    } catch {
      return .failure(error.localizedDescription)
    }
  }

  switch result {
  case .success(let commit):
    let candidates = adapter.loadCandidates()
    #expect(commit.recoveryID == "unsaved-session")
    #expect(candidates.count == 1)
    #expect(candidates[0].displayName == "Recovered Project")
    #expect(candidates[0].isRecoverable)
  case .failure(let error):
    Issue.record("expected snapshot commit to succeed: \(error.localizedDescription)")
  }
}

@Test("DocumentRecoveryAdapter は recovery directory を削除できる")
func document_recovery_adapter_removes_recovery_directory() throws {
  let baseURL = uniqueTempURL("recovery-remove")
  let configuration = DocumentRecoveryConfiguration(
    baseDirectoryURL: baseURL,
    saveDelay: 0,
    maxDirtyDelay: 0,
    retentionInterval: 30 * 24 * 60 * 60,
    maxDocuments: 10
  )
  let adapter = DocumentRecoveryAdapter(configuration: configuration)

  _ = adapter.commitSnapshot(
    recoveryID: "saved-doc",
    documentID: "document-2",
    displayName: "Saved Project",
    originalDocumentURL: uniqueTempURL("saved-project.lcraft"),
    contentFingerprint: Data("fingerprint".utf8),
    versionInfo: nil,
    appVersion: "0.1.0"
  ) { snapshotURL in
    let json = """
      {
        "fileFormatVersion": "0.1.0",
        "schemaVersion": "0.2.0",
        "document": { "name": "Saved Project" }
      }
      """
    do {
      try Data(json.utf8).write(to: snapshotURL, options: .atomic)
      return .success(())
    } catch {
      return .failure(error.localizedDescription)
    }
  }

  #expect(adapter.loadCandidates().count == 1)
  adapter.removeRecovery(recoveryID: "saved-doc")
  #expect(adapter.loadCandidates().isEmpty)
}

@Test("DocumentRecoveryAdapter は壊れた recovery を件数上限だけでは自動削除しない")
func document_recovery_adapter_keeps_broken_entries_during_max_document_cleanup() throws {
  let baseURL = uniqueTempURL("recovery-broken-retention")
  let configuration = DocumentRecoveryConfiguration(
    baseDirectoryURL: baseURL,
    saveDelay: 0,
    maxDirtyDelay: 0,
    retentionInterval: 30 * 24 * 60 * 60,
    maxDocuments: 1
  )
  let now = Date(timeIntervalSince1970: 1_720_000_000)
  let adapter = DocumentRecoveryAdapter(configuration: configuration, now: { now })

  func commitRecoverable(recoveryID: String, displayName: String) {
    _ = adapter.commitSnapshot(
      recoveryID: recoveryID,
      documentID: recoveryID,
      displayName: displayName,
      originalDocumentURL: nil,
      contentFingerprint: Data(recoveryID.utf8),
      versionInfo: nil,
      appVersion: "0.1.0"
    ) { snapshotURL in
      do {
        try Data(
          """
          {
            "fileFormatVersion": "0.1.0",
            "schemaVersion": "0.2.0",
            "document": { "name": "\(displayName)" }
          }
          """.utf8
        ).write(to: snapshotURL, options: .atomic)
        return .success(())
      } catch {
        return .failure(error.localizedDescription)
      }
    }
  }

  commitRecoverable(recoveryID: "recoverable-old", displayName: "Old")
  commitRecoverable(recoveryID: "recoverable-new", displayName: "New")

  let brokenGenerationURL =
    baseURL
    .appendingPathComponent("broken-entry", isDirectory: true)
    .appendingPathComponent("generation-broken", isDirectory: true)
  try FileManager.default.createDirectory(
    at: brokenGenerationURL, withIntermediateDirectories: true)
  try Data("{\"invalid\":true}\n".utf8).write(
    to: brokenGenerationURL.appendingPathComponent("metadata.json"),
    options: .atomic
  )

  let candidates = adapter.loadCandidates()
  #expect(candidates.contains(where: { $0.recoveryID == "recoverable-new" && $0.isRecoverable }))
  #expect(candidates.contains(where: { $0.recoveryID == "broken-entry" && !$0.isRecoverable }))
  #expect(
    !FileManager.default.fileExists(
      atPath: baseURL.appendingPathComponent("recoverable-old", isDirectory: true).path
    ))
  #expect(
    FileManager.default.fileExists(
      atPath: baseURL.appendingPathComponent("broken-entry", isDirectory: true).path
    ))
}
