import Foundation

enum InspectorValueFormatting {
  static func format(_ value: Double?) -> String {
    guard let value, value.isFinite else { return "" }
    return String(format: "%.2f", value)
  }

  static func resolvedText(
    fixedValue: Double?,
    parameterID: String?,
    parameters: [ProjectParameter]
  ) -> String {
    if let fixedValue {
      return format(fixedValue)
    }
    guard let parameterID,
      let parameter = parameters.first(where: { $0.id == parameterID })
    else {
      return ""
    }
    return format(parameter.valueMM)
  }
}
