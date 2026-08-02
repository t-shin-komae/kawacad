import Foundation

func formatAngleDegrees(_ degrees: Double) -> String {
  if abs(degrees.rounded() - degrees) < 0.005 {
    return "\(Int(degrees.rounded()))°"
  }
  return String(format: "%.2f°", degrees)
}

struct AngleConstraintOverlay: Hashable {
  enum Kind: Hashable {
    case linePair
    case arc
  }

  let constraintID: String
  let kind: Kind
  let center: ModelPoint
  let start: ModelPoint
  let end: ModelPoint
  let signedDegrees: Double

  var label: String {
    formatAngleDegrees(signedDegrees)
  }
}
