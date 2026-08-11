enum SharedStyleDefaults {
  static let colorHex = "#111827"
  static let strokeWidthMM = 0.2
  static let linePattern: LinePattern = .solid

  static func name(number: Int) -> String {
    AppStrings.tr("command.default_shared_style_name", number)
  }
}
