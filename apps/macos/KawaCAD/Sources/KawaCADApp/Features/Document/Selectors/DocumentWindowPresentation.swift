import Foundation

struct DocumentWindowPresentation: Equatable {
  let documentName: String
  let documentURL: URL?
  let isDocumentEdited: Bool

  var title: String {
    guard let documentURL else {
      return AppStrings.tr("window.title.unsaved", documentName)
    }
    let fileName = documentURL.lastPathComponent
    guard !isSameNameAsFile(documentName, fileName: fileName) else {
      return fileName
    }
    return "\(fileName) — \(documentName)"
  }

  var accessibilityLabel: String {
    let editedState = AppStrings.tr(
      isDocumentEdited ? "window.accessibility.edited" : "window.accessibility.saved"
    )
    if let documentURL {
      return AppStrings.tr(
        "window.accessibility.saved_document",
        documentURL.lastPathComponent,
        documentName,
        editedState
      )
    }
    return AppStrings.tr("window.accessibility.unsaved_document", documentName, editedState)
  }

  private func isSameNameAsFile(_ documentName: String, fileName: String) -> Bool {
    let stem = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
    return [fileName, stem].contains {
      $0.compare(documentName, options: [.caseInsensitive, .widthInsensitive]) == .orderedSame
    }
  }
}
