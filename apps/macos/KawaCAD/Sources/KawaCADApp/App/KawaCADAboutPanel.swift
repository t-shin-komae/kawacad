import AppKit

enum KawaCADAboutPanel {
  private static let defaultApplicationName = "KawaCAD"
  private static let defaultMarketingVersion = "0.1.0"
  private static let defaultCopyright = "© 2026 t-shin-komae"

  static func present(
    application: NSApplication = .shared,
    bundle: Bundle = .main
  ) {
    let info = bundle.infoDictionary ?? [:]
    let applicationName = info["CFBundleName"] as? String ?? defaultApplicationName
    let copyright = info["NSHumanReadableCopyright"] as? String ?? defaultCopyright
    let options: [NSApplication.AboutPanelOptionKey: Any] = [
      .applicationName: applicationName,
      .applicationVersion: displayVersion(from: info),
      NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): copyright,
      // The issue requires the marketing version only. Do not expose the
      // temporary, fixed CFBundleVersion as a build number in the panel.
      .version: "",
    ]
    application.orderFrontStandardAboutPanel(options: options)
  }

  static func displayVersion(from info: [String: Any]) -> String {
    let version = info["CFBundleShortVersionString"] as? String ?? defaultMarketingVersion
    let channel = info["KawaCADBuildChannel"] as? String
    if channel == "release" || version.hasSuffix("-dev") {
      return version
    }
    return "\(version)-dev"
  }
}
