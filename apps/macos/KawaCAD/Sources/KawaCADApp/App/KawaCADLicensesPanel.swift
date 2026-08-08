import AppKit
import SwiftUI

private struct LicenseNoticeSection: Identifiable {
  let id: Int
  let title: String
  let body: String
}

private func licenseNoticeSections(_ notices: String) -> [LicenseNoticeSection] {
  notices
    .components(separatedBy: "\n## ")
    .enumerated()
    .map { index, chunk in
      let lines = chunk.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
      let title = String(lines.first ?? "Third-party notices").trimmingCharacters(
        in: .whitespacesAndNewlines)
      let body =
        lines.count > 1 ? String(lines[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
      return LicenseNoticeSection(id: index, title: title, body: body)
    }
    .filter { !$0.title.isEmpty || !$0.body.isEmpty }
}

struct KawaCADLicensesView: View {
  let notices: String

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 20) {
        ForEach(licenseNoticeSections(notices)) { section in
          VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
              .font(.headline)
            Text(section.body)
              .font(.system(.body, design: .monospaced))
              .textSelection(.enabled)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(20)
    }
    .frame(minWidth: 620, minHeight: 460)
  }
}

enum KawaCADLicensesPanel {
  private static var window: NSWindow?

  static func noticeText(bundle: Bundle = .module) -> String {
    let url =
      bundle.url(forResource: "ThirdPartyNotices.generated", withExtension: "md")
      ?? bundle.url(forResource: "ThirdPartyNotices", withExtension: "md")
    guard let url,
      let text = try? String(contentsOf: url, encoding: .utf8)
    else {
      return AppStrings.tr("licenses.unavailable")
    }
    return text
  }

  static func present(application: NSApplication = .shared, bundle: Bundle = .module) {
    if let window {
      window.makeKeyAndOrderFront(nil)
      application.activate(ignoringOtherApps: true)
      return
    }

    let controller = NSHostingController(
      rootView: KawaCADLicensesView(notices: noticeText(bundle: bundle)))
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false
    )
    panel.contentViewController = controller
    panel.title = AppStrings.tr("menu.open_source_licenses")
    panel.isReleasedWhenClosed = false
    panel.center()
    window = panel
    panel.makeKeyAndOrderFront(nil)
    application.activate(ignoringOtherApps: true)
  }
}
