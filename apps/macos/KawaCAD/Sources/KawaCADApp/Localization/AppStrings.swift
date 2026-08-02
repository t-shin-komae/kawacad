import Foundation

enum AppStrings {
  static func tr(_ key: String) -> String {
    NSLocalizedString(key, bundle: .module, comment: "")
  }

  static func tr(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: tr(key), locale: Locale.current, arguments: arguments)
  }
}
