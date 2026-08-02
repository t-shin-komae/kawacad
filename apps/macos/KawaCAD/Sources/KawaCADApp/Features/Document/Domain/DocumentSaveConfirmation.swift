import Foundation

enum PendingDocumentIntent {
  case createNewProject
  case openProject(URL)
  case closeWindow
  case quitApplication

  var confirmationReasonKey: String {
    switch self {
    case .createNewProject:
      return "document.save_confirmation.reason.new_project"
    case .openProject:
      return "document.save_confirmation.reason.open_project"
    case .closeWindow:
      return "document.save_confirmation.reason.close_window"
    case .quitApplication:
      return "document.save_confirmation.reason.quit_application"
    }
  }
}

struct DocumentSaveConfirmation: Identifiable, Equatable {
  let id = UUID()
  let documentName: String
  let reason: String

  var title: String {
    AppStrings.tr("document.save_confirmation.title", documentName)
  }
}
