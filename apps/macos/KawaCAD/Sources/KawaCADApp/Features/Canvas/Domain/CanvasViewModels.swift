import AppKit
import Foundation

struct CanvasPlacementModifiers: Hashable {
  var forceAxis: Bool = false
  var suppressesSnap: Bool = false
  var duplicatesOnDrag: Bool = false

  init(forceAxis: Bool = false, suppressesSnap: Bool = false, duplicatesOnDrag: Bool = false) {
    self.forceAxis = forceAxis
    self.suppressesSnap = suppressesSnap
    self.duplicatesOnDrag = duplicatesOnDrag
  }

  init(event: NSEvent) {
    self.forceAxis = event.modifierFlags.contains(.shift)
    self.suppressesSnap = event.modifierFlags.contains(.control)
    self.duplicatesOnDrag = event.modifierFlags.contains(.option)
  }
}

struct ArcPlacementResult: Hashable {
  let point: ModelPoint
  let sweepAngleRad: Double
}

enum LinePlacementOrientation: Hashable {
  case horizontal
  case vertical

  var constraintKind: String {
    switch self {
    case .horizontal: return "horizontal"
    case .vertical: return "vertical"
    }
  }

  var displayName: String {
    switch self {
    case .horizontal: return AppStrings.tr("line_orientation.horizontal")
    case .vertical: return AppStrings.tr("line_orientation.vertical")
    }
  }
}

struct LinePlacementEnd: Hashable {
  let point: ModelPoint
  let target: CanvasSelectionTarget?
  let orientation: LinePlacementOrientation?
}

enum CanvasControlPoint: Hashable {
  case start
  case end
  case center
  case radius
  case arcStart
  case arcEnd

  var displayName: String {
    switch self {
    case .start: return AppStrings.tr("control_point.start")
    case .end: return AppStrings.tr("control_point.end")
    case .center: return AppStrings.tr("control_point.center")
    case .radius: return AppStrings.tr("control_point.radius")
    case .arcStart: return AppStrings.tr("control_point.arc_start")
    case .arcEnd: return AppStrings.tr("control_point.arc_end")
    }
  }

  var jsonObject: Any {
    switch self {
    case .start: return "start"
    case .end: return "end"
    case .center: return "center"
    case .radius: return "radius"
    case .arcStart: return "start"
    case .arcEnd: return "end"
    }
  }

  var isConstraintCompatible: Bool {
    switch self {
    case .start, .end, .center, .arcStart, .arcEnd:
      return true
    case .radius:
      return false
    }
  }
}

struct CanvasSelectionTarget: Hashable {
  let entityID: String
  let entityLabel: String
  let entityKind: EntityKind
  let controlPoint: CanvasControlPoint?
  let point: ModelPoint?

  var displayName: String {
    guard let controlPoint else {
      return entityLabel
    }
    return "\(entityLabel) \(controlPoint.displayName)"
  }

  var isPointTarget: Bool {
    guard point != nil else {
      return false
    }
    if let controlPoint {
      return controlPoint.isConstraintCompatible
    }
    return entityKind == .point
  }

  var isLineTarget: Bool {
    controlPoint == nil && (entityKind == .lineSegment || entityKind == .centerLine)
  }

  var isLineEndpointTarget: Bool {
    (entityKind == .lineSegment || entityKind == .centerLine)
      && (controlPoint == .start || controlPoint == .end)
  }

  var isArcEndpointTarget: Bool {
    entityKind == .arc
      && (controlPoint == .arcStart || controlPoint == .arcEnd)
  }

  var constraintJSON: [String: Any] {
    wireTarget.jsonObject
  }

  var wireTarget: CoreConstraintTarget {
    guard let controlPoint else {
      return .entity(entityID)
    }
    return .controlPoint(entityID: entityID, point: controlPoint.wirePoint)
  }
}

enum CanvasGeometry: Hashable {
  case point(ModelPoint)
  case line(start: ModelPoint, end: ModelPoint, centerLine: Bool)
  case circle(center: ModelPoint, radiusMM: Double)
  case arc(center: ModelPoint, radiusMM: Double, startAngleRad: Double, sweepAngleRad: Double)
  case unsupported

  func translatedBy(dxMM: Double, dyMM: Double) -> CanvasGeometry {
    switch self {
    case .point(let point): return .point(point.translatedBy(dxMM: dxMM, dyMM: dyMM))
    case .line(let start, let end, let centerLine):
      return .line(
        start: start.translatedBy(dxMM: dxMM, dyMM: dyMM),
        end: end.translatedBy(dxMM: dxMM, dyMM: dyMM), centerLine: centerLine)
    case .circle(let center, let radiusMM):
      return .circle(center: center.translatedBy(dxMM: dxMM, dyMM: dyMM), radiusMM: radiusMM)
    case .arc(let center, let radiusMM, let startAngleRad, let sweepAngleRad):
      return .arc(
        center: center.translatedBy(dxMM: dxMM, dyMM: dyMM), radiusMM: radiusMM,
        startAngleRad: startAngleRad, sweepAngleRad: sweepAngleRad)
    case .unsupported: return self
    }
  }

  var controlPointLabels: [String] {
    switch self {
    case .point:
      return [AppStrings.tr("geometry.control_point.point")]
    case .line:
      return [
        AppStrings.tr("geometry.control_point.start"), AppStrings.tr("geometry.control_point.end"),
      ]
    case .circle, .arc:
      return [AppStrings.tr("geometry.control_point.center")]
    case .unsupported:
      return []
    }
  }

}
struct CoincidentPointGroup: Identifiable, Hashable {
  let id: String
  let representative: ModelPoint
  let targetsJSON: String
}

struct CanvasEntity: Identifiable, Hashable {
  let id: String
  let label: String
  let kind: EntityKind
  let layerID: String?
  let styleID: String?
  let geometry: CanvasGeometry
  let constraintStatus: ConstraintStatus
  let remainingDof: Int?
  let isSuppressedByFillet: Bool
  let derivedElementID: String?
  let derivedResolvedIndex: Int?
  let sourceEntityID: String?

  func translatedBy(dxMM: Double, dyMM: Double) -> CanvasEntity {
    CanvasEntity(
      id: id, label: label, kind: kind, layerID: layerID, styleID: styleID,
      geometry: geometry.translatedBy(dxMM: dxMM, dyMM: dyMM), constraintStatus: constraintStatus,
      remainingDof: remainingDof, isSuppressedByFillet: isSuppressedByFillet,
      derivedElementID: derivedElementID, derivedResolvedIndex: derivedResolvedIndex,
      sourceEntityID: sourceEntityID)
  }

  init(
    id: String,
    label: String,
    kind: EntityKind,
    layerID: String?,
    styleID: String? = nil,
    geometry: CanvasGeometry,
    constraintStatus: ConstraintStatus = .unknown,
    remainingDof: Int? = nil,
    isSuppressedByFillet: Bool = false,
    derivedElementID: String? = nil,
    derivedResolvedIndex: Int? = nil,
    sourceEntityID: String? = nil
  ) {
    self.id = id
    self.label = label
    self.kind = kind
    self.layerID = layerID
    self.styleID = styleID
    self.geometry = geometry
    self.constraintStatus = constraintStatus
    self.remainingDof = remainingDof
    self.isSuppressedByFillet = isSuppressedByFillet
    self.derivedElementID = derivedElementID
    self.derivedResolvedIndex = derivedResolvedIndex
    self.sourceEntityID = sourceEntityID
  }

  func withConstraintStatus(_ status: ConstraintStatus, remainingDof: Int) -> CanvasEntity {
    CanvasEntity(
      id: id,
      label: label,
      kind: kind,
      layerID: layerID,
      styleID: styleID,
      geometry: geometry,
      constraintStatus: status,
      remainingDof: remainingDof,
      isSuppressedByFillet: isSuppressedByFillet,
      derivedElementID: derivedElementID,
      derivedResolvedIndex: derivedResolvedIndex,
      sourceEntityID: sourceEntityID
    )
  }

  func withFilletSuppressedStyle() -> CanvasEntity {
    CanvasEntity(
      id: id,
      label: label,
      kind: kind,
      layerID: layerID,
      styleID: styleID,
      geometry: geometry,
      constraintStatus: constraintStatus,
      remainingDof: remainingDof,
      isSuppressedByFillet: true,
      derivedElementID: derivedElementID,
      derivedResolvedIndex: derivedResolvedIndex,
      sourceEntityID: sourceEntityID
    )
  }

  func withCoreMetadata(
    derivedElementID: String?,
    derivedResolvedIndex: Int?,
    sourceEntityID: String?,
    isSuppressedByFillet: Bool
  ) -> CanvasEntity {
    CanvasEntity(
      id: id,
      label: label,
      kind: kind,
      layerID: layerID,
      styleID: styleID,
      geometry: geometry,
      constraintStatus: constraintStatus,
      remainingDof: remainingDof,
      isSuppressedByFillet: isSuppressedByFillet,
      derivedElementID: derivedElementID,
      derivedResolvedIndex: derivedResolvedIndex,
      sourceEntityID: sourceEntityID
    )
  }

  var controlPoints: [String] {
    geometry.controlPointLabels
  }

  var supportsLinearConstraint: Bool {
    switch geometry {
    case .line(_, _, let centerLine):
      return centerLine || kind == .lineSegment
    default:
      return false
    }
  }

  var isCenterLine: Bool {
    if case .line(_, _, let centerLine) = geometry {
      return centerLine || kind == .centerLine
    }
    return false
  }

  var supportsDiameterConstraint: Bool {
    if case .circle = geometry {
      return true
    }
    return false
  }

  var supportsDiameterMeasurement: Bool {
    switch geometry {
    case .circle, .arc:
      return true
    default:
      return false
    }
  }

  var diameterConstraintValue: Double? {
    if case .circle(_, let radiusMM) = geometry {
      return radiusMM * 2.0
    }
    return nil
  }

  var supportsRadiusConstraint: Bool {
    switch geometry {
    case .circle, .arc:
      return true
    default:
      return false
    }
  }

  var radiusConstraintValue: Double? {
    switch geometry {
    case .circle(_, let radiusMM), .arc(_, let radiusMM, _, _):
      return radiusMM
    default:
      return nil
    }
  }

  var arcSweepAngleDegrees: Double? {
    if case .arc(_, _, _, let sweepAngleRad) = geometry {
      return radiansToDegrees(sweepAngleRad)
    }
    return nil
  }

  var entitySelectionTarget: CanvasSelectionTarget {
    CanvasSelectionTarget(
      entityID: id,
      entityLabel: label,
      entityKind: kind,
      controlPoint: nil,
      point: entityPointTarget
    )
  }

  var entityPoint: ModelPoint? {
    entityPointTarget
  }

  var pointSelectionTargets: [(target: CanvasSelectionTarget, point: ModelPoint)] {
    switch geometry {
    case .point(let point):
      return [(entitySelectionTarget, point)]
    case .line(let start, let end, _):
      return [
        (controlPointSelectionTarget(.start, point: start), start),
        (controlPointSelectionTarget(.end, point: end), end),
      ]
    case .circle(let center, _):
      return [(controlPointSelectionTarget(.center, point: center), center)]
    case .arc(let center, let radiusMM, let startAngleRad, let sweepAngleRad):
      let start = ModelPoint(
        xMM: center.xMM + radiusMM * cos(startAngleRad),
        yMM: center.yMM + radiusMM * sin(startAngleRad)
      )
      let endAngle = startAngleRad + sweepAngleRad
      let end = ModelPoint(
        xMM: center.xMM + radiusMM * cos(endAngle),
        yMM: center.yMM + radiusMM * sin(endAngle)
      )
      return [
        (controlPointSelectionTarget(.center, point: center), center),
        (controlPointSelectionTarget(.arcStart, point: start), start),
        (controlPointSelectionTarget(.arcEnd, point: end), end),
      ]
    case .unsupported:
      return []
    }
  }

  var editPointTargets: [(target: CanvasSelectionTarget, point: ModelPoint)] {
    switch geometry {
    case .circle(let center, let radiusMM):
      let radiusHandle = ModelPoint(xMM: center.xMM + radiusMM, yMM: center.yMM)
      return pointSelectionTargets + [
        (controlPointSelectionTarget(.radius, point: radiusHandle), radiusHandle)
      ]
    case .arc(let center, let radiusMM, let startAngleRad, let sweepAngleRad):
      let radiusAngle = startAngleRad + sweepAngleRad / 2.0
      let radiusHandle = ModelPoint(
        xMM: center.xMM + radiusMM * cos(radiusAngle),
        yMM: center.yMM + radiusMM * sin(radiusAngle)
      )
      return pointSelectionTargets + [
        (controlPointSelectionTarget(.radius, point: radiusHandle), radiusHandle)
      ]
    default:
      return pointSelectionTargets
    }
  }

  var snapPointTargets: [(target: CanvasSelectionTarget?, point: ModelPoint)] {
    let selectablePoints = pointSelectionTargets.map { item in
      (target: Optional(item.target), point: item.point)
    }

    switch geometry {
    case .line(let start, let end, _):
      return selectablePoints + [(target: nil, point: midpoint(start, end))]
    default:
      return selectablePoints
    }
  }

  var lineSelectionTargets: [(target: CanvasSelectionTarget, start: ModelPoint, end: ModelPoint)] {
    switch geometry {
    case .line(let start, let end, _):
      return [(entitySelectionTarget, start, end)]
    default:
      return []
    }
  }

  var defaultPointSelectionTarget: CanvasSelectionTarget? {
    switch geometry {
    case .point:
      return entitySelectionTarget
    case .circle(let center, _):
      return controlPointSelectionTarget(.center, point: center)
    case .arc(let center, _, _, _):
      return controlPointSelectionTarget(.center, point: center)
    default:
      return nil
    }
  }

  var defaultPointConstraintTarget: [String: Any]? {
    defaultPointSelectionTarget?.constraintJSON
  }

  var documentCommandPayload: [String: Any]? {
    guard derivedElementID == nil else {
      return nil
    }
    let kindPayload: [String: Any]
    switch geometry {
    case .point(let point):
      kindPayload = ["point": point.jsonObject]
    case .line(let start, let end, let centerLine):
      kindPayload = [
        centerLine ? "centerLine" : "lineSegment": [
          "start": start.jsonObject,
          "end": end.jsonObject,
        ]
      ]
    case .circle(let center, let radiusMM):
      kindPayload = [
        "circle": [
          "center": center.jsonObject,
          "radiusMm": radiusMM,
        ]
      ]
    case .arc(let center, let radiusMM, let startAngleRad, let sweepAngleRad):
      kindPayload = [
        "arc": [
          "center": center.jsonObject,
          "radiusMm": radiusMM,
          "startAngleRad": startAngleRad,
          "sweepAngleRad": sweepAngleRad,
        ]
      ]
    case .unsupported:
      return nil
    }

    return [
      "id": id,
      "layerId": layerID ?? NSNull(),
      "styleId": styleID ?? NSNull(),
      "kind": kindPayload,
    ]
  }

  func withLayer(_ layerID: String) -> CanvasEntity {
    CanvasEntity(
      id: id,
      label: label,
      kind: kind,
      layerID: layerID,
      styleID: styleID,
      geometry: geometry,
      constraintStatus: constraintStatus,
      remainingDof: remainingDof,
      isSuppressedByFillet: isSuppressedByFillet,
      derivedElementID: derivedElementID,
      derivedResolvedIndex: derivedResolvedIndex,
      sourceEntityID: sourceEntityID
    )
  }

  func withSharedStyle(_ styleID: String?) -> CanvasEntity {
    CanvasEntity(
      id: id,
      label: label,
      kind: kind,
      layerID: layerID,
      styleID: styleID,
      geometry: geometry,
      constraintStatus: constraintStatus,
      remainingDof: remainingDof,
      isSuppressedByFillet: isSuppressedByFillet,
      derivedElementID: derivedElementID,
      derivedResolvedIndex: derivedResolvedIndex,
      sourceEntityID: sourceEntityID
    )
  }

  func withGeometry(_ geometry: CanvasGeometry) -> CanvasEntity {
    CanvasEntity(
      id: id,
      label: label,
      kind: kind,
      layerID: layerID,
      styleID: styleID,
      geometry: geometry,
      constraintStatus: constraintStatus,
      remainingDof: remainingDof,
      isSuppressedByFillet: isSuppressedByFillet,
      derivedElementID: derivedElementID,
      derivedResolvedIndex: derivedResolvedIndex,
      sourceEntityID: sourceEntityID
    )
  }

  private var entityPointTarget: ModelPoint? {
    if case .point(let point) = geometry {
      return point
    }
    return nil
  }

  private func controlPointSelectionTarget(_ controlPoint: CanvasControlPoint, point: ModelPoint)
    -> CanvasSelectionTarget
  {
    CanvasSelectionTarget(
      entityID: id,
      entityLabel: label,
      entityKind: kind,
      controlPoint: controlPoint,
      point: point
    )
  }

  func point(for jsonValue: Any) -> ModelPoint? {
    if let value = jsonValue as? String {
      switch value {
      case "start":
        if case .line(let start, _, _) = geometry {
          return start
        }
        if case .arc(let center, let radiusMM, let startAngleRad, _) = geometry {
          return ModelPoint(
            xMM: center.xMM + radiusMM * cos(startAngleRad),
            yMM: center.yMM + radiusMM * sin(startAngleRad)
          )
        }
      case "end":
        if case .line(_, let end, _) = geometry {
          return end
        }
        if case .arc(let center, let radiusMM, let startAngleRad, let sweepAngleRad) = geometry {
          let endAngleRad = startAngleRad + sweepAngleRad
          return ModelPoint(
            xMM: center.xMM + radiusMM * cos(endAngleRad),
            yMM: center.yMM + radiusMM * sin(endAngleRad)
          )
        }
      case "center":
        switch geometry {
        case .circle(let center, _),
          .arc(let center, _, _, _):
          return center
        default:
          return nil
        }
      default:
        return nil
      }
    }
    return nil
  }

  private func midpoint(_ first: ModelPoint, _ second: ModelPoint) -> ModelPoint {
    ModelPoint(
      xMM: (first.xMM + second.xMM) / 2.0,
      yMM: (first.yMM + second.yMM) / 2.0
    )
  }
}
