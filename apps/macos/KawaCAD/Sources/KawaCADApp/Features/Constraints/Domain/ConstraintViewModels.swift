import Foundation

enum ConstraintValueEntryMode: String, CaseIterable, Identifiable {
  case fixedValue
  case parameterReference

  var id: String { rawValue }

  var label: String {
    switch self {
    case .fixedValue:
      return AppStrings.tr("constraint_value_mode.fixed")
    case .parameterReference:
      return AppStrings.tr("constraint_value_mode.parameter")
    }
  }
}

enum OffsetSourceScope: String, CaseIterable, Identifiable {
  case closedContour
  case selectedRange
  case singleElement

  var id: String { rawValue }

  var label: String {
    switch self {
    case .closedContour:
      return AppStrings.tr("offset_source_scope.closed_contour")
    case .selectedRange:
      return AppStrings.tr("offset_source_scope.selected_range")
    case .singleElement:
      return AppStrings.tr("offset_source_scope.single_element")
    }
  }
}

struct OffsetSourceScopeOption: Hashable {
  let scope: OffsetSourceScope
  let sourceEntityIDs: [String]
  let sourceResolvedEntityIDs: [String]
  let direction: String
}

struct PendingConstraintValueDraft: Identifiable {
  let id = UUID()
  let kind: String
  let title: String
  let prompt: String
  let targets: [[String: Any]]
  var offsetSourceEntityIDs: [String] = []
  var offsetSourceResolvedEntityIDs: [String] = []
  var offsetDirection: String?
  var selectedOffsetSourceScope: OffsetSourceScope?
  var offsetSourceScopeOptions: [OffsetSourceScopeOption] = []
  var filletSourceEntityIDs: [String] = []
  var filletUpdateDerivedElementID: String?
  var filletClosed: Bool = true
  var filletLastAddedSourceID: String?
  var valueText: String
  let unit: String
  let allowsParameterReference: Bool
  var entryMode: ConstraintValueEntryMode
  var selectedParameterID: String?
  var anchorCanvasPoint: CGPoint?

  var filletCornerCount: Int {
    guard kind == "fillet" else { return 0 }
    return max(0, filletSourceEntityIDs.count - (filletClosed ? 0 : 1))
  }

  var filletIsReadyForValueEntry: Bool {
    kind == "fillet" && filletSourceEntityIDs.count >= 2
  }
}

struct ProjectParameter: Identifiable, Hashable {
  let id: String
  let name: String
  let valueMM: Double
  let unit: String
  let memo: String
  let usageCount: Int
  let usedConstraintIDs: [String]

  var unitLabel: String {
    switch unit {
    case "millimeter":
      return "mm"
    default:
      return unit
    }
  }

  var isUnused: Bool {
    usageCount == 0
  }

  var documentCommandPayload: [String: Any] {
    [
      "id": id,
      "name": name,
      "valueMm": valueMM,
      "unit": unit,
      "memo": memo,
    ]
  }
}

enum OffsetDirection: String, CaseIterable, Identifiable, Hashable {
  case left
  case right
  case inward
  case outward

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .left: return "左側"
    case .right: return "右側"
    case .inward: return "内側"
    case .outward: return "外側"
    }
  }

  var reversed: OffsetDirection {
    switch self {
    case .left: return .right
    case .right: return .left
    case .inward: return .outward
    case .outward: return .inward
    }
  }
}

enum ProjectDerivedElementKind: String, Hashable {
  case offsetCurve
  case fillet

  var displayName: String {
    switch self {
    case .offsetCurve: return "オフセット線"
    case .fillet: return "フィレット"
    }
  }
}

struct ProjectDerivedElement: Identifiable, Hashable {
  let id: String
  let layerID: String?
  let styleID: String?
  let kind: ProjectDerivedElementKind
  let sourceEntityIDs: [String]
  let sourceResolvedEntityIDs: [String]
  let distanceMM: Double?
  let distanceParameterID: String?
  let direction: OffsetDirection
  let radiusMM: Double?
  let radiusParameterID: String?
  let filletClosed: Bool

  init(
    id: String,
    layerID: String?,
    styleID: String? = nil,
    kind: ProjectDerivedElementKind = .offsetCurve,
    sourceEntityIDs: [String],
    sourceResolvedEntityIDs: [String] = [],
    distanceMM: Double?,
    distanceParameterID: String?,
    direction: OffsetDirection = .left,
    radiusMM: Double? = nil,
    radiusParameterID: String? = nil,
    filletClosed: Bool = true
  ) {
    self.id = id
    self.layerID = layerID
    self.styleID = styleID
    self.kind = kind
    self.sourceEntityIDs = sourceEntityIDs
    self.sourceResolvedEntityIDs = sourceResolvedEntityIDs
    self.distanceMM = distanceMM
    self.distanceParameterID = distanceParameterID
    self.direction = direction
    self.radiusMM = radiusMM
    self.radiusParameterID = radiusParameterID
    self.filletClosed = filletClosed
  }

  var documentCommandPayload: [String: Any] {
    let kindPayload: [String: Any]
    switch kind {
    case .offsetCurve:
      var distance: [String: Any] = ["fixedMm": distanceMM ?? 1.0]
      if let distanceParameterID {
        distance = ["parameter": distanceParameterID]
      }
      var offset: [String: Any] = [
        "sourceEntityIds": sourceEntityIDs,
        "distance": distance,
        "direction": direction.rawValue,
      ]
      if !sourceResolvedEntityIDs.isEmpty {
        offset["sourceResolvedEntityIds"] = sourceResolvedEntityIDs
      }
      kindPayload = ["offsetCurve": offset]
    case .fillet:
      var radius: [String: Any] = ["fixedMm": radiusMM ?? distanceMM ?? 1.0]
      if let radiusParameterID = radiusParameterID ?? distanceParameterID {
        radius = ["parameter": radiusParameterID]
      }
      var fillet: [String: Any] = [
        "sourceEntityIds": sourceEntityIDs,
        "radius": radius,
      ]
      if !filletClosed {
        fillet["closed"] = false
      }
      kindPayload = [
        "fillet": fillet
      ]
    }
    var payload: [String: Any] = [
      "id": id,
      "styleId": styleID ?? NSNull(),
      "kind": kindPayload,
    ]
    if let layerID {
      payload["layerId"] = layerID
    }
    return payload
  }

  func withDirection(_ direction: OffsetDirection) -> ProjectDerivedElement {
    ProjectDerivedElement(
      id: id,
      layerID: layerID,
      styleID: styleID,
      kind: kind,
      sourceEntityIDs: sourceEntityIDs,
      sourceResolvedEntityIDs: sourceResolvedEntityIDs,
      distanceMM: distanceMM,
      distanceParameterID: distanceParameterID,
      direction: direction,
      radiusMM: radiusMM,
      radiusParameterID: radiusParameterID,
      filletClosed: filletClosed
    )
  }

  func withDistanceMM(_ distanceMM: Double) -> ProjectDerivedElement {
    ProjectDerivedElement(
      id: id,
      layerID: layerID,
      styleID: styleID,
      kind: kind,
      sourceEntityIDs: sourceEntityIDs,
      sourceResolvedEntityIDs: sourceResolvedEntityIDs,
      distanceMM: kind == .offsetCurve ? distanceMM : self.distanceMM,
      distanceParameterID: kind == .offsetCurve ? nil : distanceParameterID,
      direction: direction,
      radiusMM: kind == .fillet ? distanceMM : radiusMM,
      radiusParameterID: kind == .fillet ? nil : radiusParameterID,
      filletClosed: filletClosed
    )
  }

  func withParameter(_ parameter: ProjectParameter) -> ProjectDerivedElement {
    ProjectDerivedElement(
      id: id,
      layerID: layerID,
      styleID: styleID,
      kind: kind,
      sourceEntityIDs: sourceEntityIDs,
      sourceResolvedEntityIDs: sourceResolvedEntityIDs,
      distanceMM: kind == .offsetCurve ? nil : distanceMM,
      distanceParameterID: kind == .offsetCurve ? parameter.id : distanceParameterID,
      direction: direction,
      radiusMM: kind == .fillet ? nil : radiusMM,
      radiusParameterID: kind == .fillet ? parameter.id : radiusParameterID,
      filletClosed: filletClosed
    )
  }

  func withLayer(_ layerID: String) -> ProjectDerivedElement {
    ProjectDerivedElement(
      id: id,
      layerID: layerID,
      styleID: styleID,
      kind: kind,
      sourceEntityIDs: sourceEntityIDs,
      sourceResolvedEntityIDs: sourceResolvedEntityIDs,
      distanceMM: distanceMM,
      distanceParameterID: distanceParameterID,
      direction: direction,
      radiusMM: radiusMM,
      radiusParameterID: radiusParameterID,
      filletClosed: filletClosed
    )
  }

  func withSharedStyle(_ styleID: String?) -> ProjectDerivedElement {
    ProjectDerivedElement(
      id: id,
      layerID: layerID,
      styleID: styleID,
      kind: kind,
      sourceEntityIDs: sourceEntityIDs,
      sourceResolvedEntityIDs: sourceResolvedEntityIDs,
      distanceMM: distanceMM,
      distanceParameterID: distanceParameterID,
      direction: direction,
      radiusMM: radiusMM,
      radiusParameterID: radiusParameterID,
      filletClosed: filletClosed
    )
  }

  func withSourceEntityIDs(
    _ sourceEntityIDs: [String],
    radiusMM: Double?,
    radiusParameterID: String?,
    filletClosed: Bool
  ) -> ProjectDerivedElement {
    ProjectDerivedElement(
      id: id,
      layerID: layerID,
      styleID: styleID,
      kind: kind,
      sourceEntityIDs: sourceEntityIDs,
      sourceResolvedEntityIDs: kind == .offsetCurve ? sourceResolvedEntityIDs : [],
      distanceMM: distanceMM,
      distanceParameterID: distanceParameterID,
      direction: direction,
      radiusMM: kind == .fillet ? radiusMM : self.radiusMM,
      radiusParameterID: kind == .fillet ? radiusParameterID : self.radiusParameterID,
      filletClosed: kind == .fillet ? filletClosed : self.filletClosed
    )
  }
}
struct ProjectConstraint: Identifiable, Hashable {
  let id: String
  let rawKind: String
  let kind: String
  let targets: [String]
  let targetsJSON: String
  let valueMM: Double?
  let valueDegrees: Double?
  let valueParameterID: String?
  let status: ConstraintStatus

  var isDimensionConstraint: Bool {
    valueMM != nil || valueDegrees != nil || valueParameterID != nil
  }

}

struct ProjectMeasurementAnnotation: Identifiable, Hashable {
  let id: String
  let rawKind: String
  let kind: String
  let targets: [String]
  let targetsJSON: String
  let labelOffsetMM: ModelPoint
  let overallOffsetMM: ModelPoint
  let visible: Bool

  var documentCommandPayload: [String: Any]? {
    guard let targetObjects = CoreConstraintTarget.decodeList(from: targetsJSON) else {
      return nil
    }
    return [
      "id": id,
      "kind": rawKind,
      "targets": targetObjects.map(\.jsonObject),
      "labelOffsetMm": labelOffsetMM.jsonObject,
      "overallOffsetMm": overallOffsetMM.jsonObject,
      "visible": visible,
    ]
  }

  func withOffsets(labelOffsetMM: ModelPoint, overallOffsetMM: ModelPoint)
    -> ProjectMeasurementAnnotation
  {
    ProjectMeasurementAnnotation(
      id: id,
      rawKind: rawKind,
      kind: kind,
      targets: targets,
      targetsJSON: targetsJSON,
      labelOffsetMM: labelOffsetMM,
      overallOffsetMM: overallOffsetMM,
      visible: visible
    )
  }

}

struct ProjectDimensionConstraintAnnotation: Identifiable, Hashable {
  let constraintID: String
  let labelOffsetMM: ModelPoint
  let overallOffsetMM: ModelPoint
  let visible: Bool

  var id: String { constraintID }

  var documentCommandPayload: [String: Any] {
    [
      "constraintId": constraintID,
      "labelOffsetMm": labelOffsetMM.jsonObject,
      "overallOffsetMm": overallOffsetMM.jsonObject,
      "visible": visible,
    ]
  }

  func withOffsets(labelOffsetMM: ModelPoint, overallOffsetMM: ModelPoint)
    -> ProjectDimensionConstraintAnnotation
  {
    ProjectDimensionConstraintAnnotation(
      constraintID: constraintID,
      labelOffsetMM: labelOffsetMM,
      overallOffsetMM: overallOffsetMM,
      visible: visible
    )
  }

}
