import Foundation

struct DocumentWindowPresentation: Equatable {
  let documentURL: URL?
  let isDocumentEdited: Bool

  var title: String {
    guard let documentURL else {
      return AppStrings.tr("window.title.unsaved", AppStrings.tr("app.document.untitled"))
    }
    return documentURL.lastPathComponent
  }

  var accessibilityLabel: String {
    let editedState = AppStrings.tr(
      isDocumentEdited ? "window.accessibility.edited" : "window.accessibility.saved"
    )
    if let documentURL {
      return AppStrings.tr(
        "window.accessibility.saved_document",
        documentURL.lastPathComponent,
        editedState
      )
    }
    return AppStrings.tr(
      "window.accessibility.unsaved_document", AppStrings.tr("app.document.untitled"),
      editedState)
  }
}
