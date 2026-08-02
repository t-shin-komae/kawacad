import Foundation

struct ConstraintMarker: Hashable {
  let constraintID: String
  let rawKind: String
  let label: String
  let displayName: String
  let tool: CanvasTool
  let position: ModelPoint
  let stackIndex: Int
}

enum ConstraintMarkerLayout {
  static func markers(
    constraints: [ProjectConstraint],
    anchors: [ResolvedCanvasPoint]
  ) -> [ConstraintMarker] {
    var markers: [ConstraintMarker] = []
    var stackCounts: [String: Int] = [:]
    let positions = Dictionary(
      uniqueKeysWithValues: anchors.filter(\.visible).map { ($0.id, $0.positionMM) }
    )

    for constraint in constraints {
      guard let markerDescriptor = markerDescriptor(for: constraint.rawKind),
        let position = positions[constraint.id]
      else {
        continue
      }

      let stackKey = "\(Int((position.xMM * 10).rounded())):\(Int((position.yMM * 10).rounded()))"
      let stackIndex = stackCounts[stackKey, default: 0]
      stackCounts[stackKey] = stackIndex + 1

      markers.append(
        ConstraintMarker(
          constraintID: constraint.id,
          rawKind: constraint.rawKind,
          label: markerDescriptor.label,
          displayName: markerDescriptor.displayName,
          tool: markerDescriptor.tool,
          position: position,
          stackIndex: stackIndex
        ))
    }

    return markers
  }

  private static func markerDescriptor(for rawKind: String) -> (
    label: String,
    displayName: String,
    tool: CanvasTool
  )? {
    switch rawKind {
    case "coincident":
      return ("=", AppStrings.tr("tool.coincident"), .coincident)
    case "horizontal":
      return ("H", AppStrings.tr("tool.horizontal"), .horizontal)
    case "vertical":
      return ("V", AppStrings.tr("tool.vertical"), .vertical)
    case "parallel":
      return ("//", AppStrings.tr("tool.parallel"), .parallel)
    case "perpendicular":
      return ("90", AppStrings.tr("tool.perpendicular"), .perpendicular)
    case "tangent":
      return ("TAN", AppStrings.tr("tool.tangent"), .tangent)
    case "fixed":
      return ("FIX", AppStrings.tr("tool.fixed"), .fixed)
    case "symmetric":
      return ("SYM", AppStrings.tr("tool.symmetric"), .symmetric)
    case "distance":
      return ("<->", AppStrings.tr("tool.distance"), .distance)
    case "horizontalDistance":
      return ("DX", AppStrings.tr("tool.horizontal_distance"), .horizontalDistance)
    case "verticalDistance":
      return ("DY", AppStrings.tr("tool.vertical_distance"), .verticalDistance)
    case "pointLineDistance":
      return ("P-L", AppStrings.tr("tool.point_line_distance"), .distance)
    case "lineLineDistance":
      return ("L-L", AppStrings.tr("tool.line_line_distance"), .lineLineDistance)
    case "pointOnLine":
      return ("PON", AppStrings.tr("tool.point_on_line"), .pointOnLine)
    case "segmentLength":
      return ("LEN", AppStrings.tr("tool.segment_length"), .segmentLength)
    case "angle":
      return ("DEG", AppStrings.tr("tool.angle"), .angle)
    case "diameter":
      return ("DIA", AppStrings.tr("tool.diameter"), .diameter)
    case "radius":
      return ("RAD", AppStrings.tr("tool.radius"), .radius)
    case "equalSegmentLength":
      return ("EQ", AppStrings.tr("tool.equal_length"), .equalLength)
    default: return nil
    }
  }

}
