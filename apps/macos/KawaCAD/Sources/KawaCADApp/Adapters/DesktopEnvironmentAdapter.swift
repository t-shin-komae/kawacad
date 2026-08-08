import AppKit
import UniformTypeIdentifiers

protocol DesktopEnvironmentAdapting {
  var appVersion: String { get }
  func promptForOpenProjectURL() -> URL?
  func promptForSaveProjectURL(documentName: String) -> URL?
  func promptForSavePDFURL(documentName: String) -> URL?
  func revealInFinder(_ url: URL)
}

struct DesktopEnvironmentAdapter: DesktopEnvironmentAdapting {
  var appVersion: String {
    Bundle.main.object(
      forInfoDictionaryKey: "CFBundleShortVersionString"
    ) as? String ?? "dev"
  }

  func promptForOpenProjectURL() -> URL? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = ProjectFileDialogConfiguration.contentTypes
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.title = AppStrings.tr("core.panel.open_title")
    panel.message = AppStrings.tr("core.panel.open_message")
    guard panel.runModal() == .OK else { return nil }
    return panel.url
  }

  func promptForSaveProjectURL(documentName: String) -> URL? {
    let panel = NSSavePanel()
    panel.allowedContentTypes = ProjectFileDialogConfiguration.contentTypes
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = ProjectFileDialogConfiguration.suggestedFilename(
      documentName: documentName
    )
    panel.title = AppStrings.tr("core.panel.save_project_title")
    guard panel.runModal() == .OK else { return nil }
    return panel.url.map(ProjectFileDialogConfiguration.normalizedSaveURL)
  }

  func promptForSavePDFURL(documentName: String) -> URL? {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.pdf]
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = "\(documentName).pdf"
    panel.title = AppStrings.tr("core.panel.save_pdf_title")
    guard panel.runModal() == .OK else { return nil }
    return panel.url
  }

  func revealInFinder(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
}

enum ProjectFileDialogConfiguration {
  static let fileExtension = "kawa"

  static var contentTypes: [UTType] {
    UTType(filenameExtension: fileExtension).map { [$0] } ?? []
  }

  static func suggestedFilename(documentName: String) -> String {
    "\(documentName).\(fileExtension)"
  }

  static func normalizedSaveURL(_ url: URL) -> URL {
    guard url.pathExtension.isEmpty else { return url }
    return url.appendingPathExtension(fileExtension)
  }
}
