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
    panel.allowedContentTypes = projectContentTypes
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
    panel.allowedContentTypes = projectContentTypes
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = "\(documentName).lcraft"
    panel.title = AppStrings.tr("core.panel.save_project_title")
    guard panel.runModal() == .OK else { return nil }
    return panel.url
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

  private var projectContentTypes: [UTType] {
    if let lcraft = UTType(filenameExtension: "lcraft") {
      return [lcraft, .json]
    }
    return [.json]
  }
}
