import Foundation

enum PartDefaults {
  static func name(number: Int) -> String {
    AppStrings.tr("part.default_name", number)
  }

  static func libraryPlacement(
    cursorPoint: ModelPoint?,
    existingOrigins: [ModelPoint]
  ) -> ModelPoint {
    if let cursorPoint {
      return cursorPoint
    }
    return ModelPoint(
      xMM: existingOrigins.reduce(-30) { max($0, $1.xMM) } + 30,
      yMM: existingOrigins.reduce(0) { max($0, $1.yMM) }
    )
  }
}
