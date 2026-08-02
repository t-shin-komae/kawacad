import Foundation

/// Pure recovery identity and fingerprint calculations.
enum RecoveryFeature {
  static func fingerprint(_ state: LeatherDocumentState) -> Data {
    Data(state.persistence.revision.utf8)
  }

  static func recoveryID(
    override: String?,
    documentURL: URL?,
    sessionID: UUID
  ) -> String {
    override
      ?? makeDocumentRecoveryID(
        documentURL: documentURL,
        sessionID: sessionID
      )
  }
}
