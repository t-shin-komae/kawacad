import KawaCADOutput

extension OutputPrintOrientation {
  var displayName: String {
    switch self {
    case .portrait:
      return AppStrings.tr("sheet.orientation.portrait")
    case .landscape:
      return AppStrings.tr("sheet.orientation.landscape")
    }
  }
}
