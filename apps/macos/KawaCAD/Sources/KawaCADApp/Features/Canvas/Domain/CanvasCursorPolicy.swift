import AppKit

enum CanvasCursorKind: Equatable {
  case arrow
  case crosshair
  case iBeam
  case openHand
  case closedHand
  case pointingHand
  case operationNotAllowed

  var nsCursor: NSCursor {
    switch self {
    case .arrow: return .arrow
    case .crosshair: return .crosshair
    case .iBeam: return .iBeam
    case .openHand: return .openHand
    case .closedHand: return .closedHand
    case .pointingHand: return .pointingHand
    case .operationNotAllowed: return .operationNotAllowed
    }
  }
}

struct CanvasCursorState {
  let tool: CanvasTool
  let outputPreview: Bool
  let pointerInsideCanvas: Bool
  let hasTarget: Bool
  let inlineTextEditing: Bool
  let settingPartOrigin: Bool
  let movingContent: Bool
}

enum CanvasCursorPolicy {
  static func cursor(for state: CanvasCursorState) -> CanvasCursorKind {
    guard state.pointerInsideCanvas, !state.outputPreview else { return .arrow }
    if state.movingContent { return .closedHand }
    if state.inlineTextEditing { return .iBeam }
    if state.settingPartOrigin { return .crosshair }
    if case .select = state.tool { return state.hasTarget ? .openHand : .arrow }
    if case .freeText = state.tool { return .crosshair }
    if isPlacementTool(state.tool) { return .crosshair }
    if state.tool.isConstraintTool || state.tool.isMeasurementTool {
      return state.hasTarget ? .pointingHand : .operationNotAllowed
    }
    return .arrow
  }

  private static func isPlacementTool(_ tool: CanvasTool) -> Bool {
    switch tool {
    case .point, .line, .circle, .arc, .centerLine, .horizontalCenterLine, .verticalCenterLine,
      .roundHole, .stitchStartPoint:
      return true
    default:
      return false
    }
  }
}
