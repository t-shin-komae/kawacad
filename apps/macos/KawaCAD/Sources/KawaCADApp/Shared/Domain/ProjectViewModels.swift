import AppKit
import Foundation

enum LayerKind: Hashable {
  case cutLine
  case dimension
  case printGuide
  case construction
  case unknown(String)

  var displayName: String {
    switch self {
    case .cutLine: return AppStrings.tr("layer_kind.cut_line")
    case .dimension: return AppStrings.tr("layer_kind.dimension")
    case .printGuide: return AppStrings.tr("layer_kind.print_guide")
    case .construction: return AppStrings.tr("layer_kind.construction")
    case .unknown(let value): return value
    }
  }
}

enum LinePattern: String, CaseIterable, Identifiable, Hashable {
  case solid
  case dashed
  case dotted
  case construction

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .solid: return AppStrings.tr("line_pattern.solid")
    case .dashed: return AppStrings.tr("line_pattern.dashed")
    case .dotted: return AppStrings.tr("line_pattern.dotted")
    case .construction: return AppStrings.tr("line_pattern.construction")
    }
  }
}

struct LayerColorPreset: Identifiable, Hashable {
  let id: String
  let displayName: String
  let colorHex: String

  static let all: [LayerColorPreset] = [
    LayerColorPreset(id: "black", displayName: "黒", colorHex: "#111827"),
    LayerColorPreset(id: "gray", displayName: "グレー", colorHex: "#6B7280"),
    LayerColorPreset(id: "red", displayName: "赤", colorHex: "#DC2626"),
    LayerColorPreset(id: "blue", displayName: "青", colorHex: "#2563EB"),
    LayerColorPreset(id: "green", displayName: "緑", colorHex: "#16A34A"),
    LayerColorPreset(id: "orange", displayName: "オレンジ", colorHex: "#EA580C"),
    LayerColorPreset(id: "purple", displayName: "紫", colorHex: "#9333EA"),
  ]

  static func matching(_ colorHex: String) -> LayerColorPreset? {
    let normalized = colorHex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    return all.first { $0.colorHex.uppercased() == normalized }
  }
}

struct LayerStrokeWidthPreset: Identifiable, Hashable {
  let widthMM: Double

  var id: Double { widthMM }

  var displayName: String {
    String(format: "%.2f mm", widthMM)
  }

  static let all: [LayerStrokeWidthPreset] = [0.13, 0.18, 0.25, 0.35, 0.50, 0.70]
    .map { LayerStrokeWidthPreset(widthMM: $0) }

  static func matching(_ widthMM: Double) -> LayerStrokeWidthPreset? {
    all.first { abs($0.widthMM - widthMM) < 0.000_001 }
  }
}

enum EntityKind: Hashable {
  case point
  case lineSegment
  case circle
  case arc
  case centerLine
  case unsupported(String)

  var displayName: String {
    switch self {
    case .point: return AppStrings.tr("entity_kind.point")
    case .lineSegment: return AppStrings.tr("entity_kind.line_segment")
    case .circle: return AppStrings.tr("entity_kind.circle")
    case .arc: return AppStrings.tr("entity_kind.arc")
    case .centerLine: return AppStrings.tr("entity_kind.center_line")
    case .unsupported(let value): return value
    }
  }
}

struct ModelPoint: Hashable, Codable {
  let xMM: Double
  let yMM: Double

  enum CodingKeys: String, CodingKey {
    case xMM = "xMm"
    case yMM = "yMm"
  }

  var jsonObject: [String: Double] {
    [
      "xMm": xMM,
      "yMm": yMM,
    ]
  }

  func translatedBy(dxMM: Double, dyMM: Double) -> ModelPoint {
    ModelPoint(xMM: xMM + dxMM, yMM: yMM + dyMM)
  }
}

struct ProjectFreeText: Identifiable, Hashable {
  let id: String
  let content: String
  let positionMM: ModelPoint
  let fontSizeMM: Double

  var jsonObject: [String: Any] {
    [
      "id": id,
      "content": content,
      "positionMm": positionMM.jsonObject,
      "fontSizeMm": fontSizeMM,
    ]
  }

  func withContent(_ content: String) -> ProjectFreeText {
    ProjectFreeText(id: id, content: content, positionMM: positionMM, fontSizeMM: fontSizeMM)
  }

  func withPosition(_ positionMM: ModelPoint) -> ProjectFreeText {
    ProjectFreeText(id: id, content: content, positionMM: positionMM, fontSizeMM: fontSizeMM)
  }

  func withFontSize(_ fontSizeMM: Double) -> ProjectFreeText {
    ProjectFreeText(id: id, content: content, positionMM: positionMM, fontSizeMM: fontSizeMM)
  }

}

struct ProjectPart: Identifiable, Hashable, Codable {
  let id: String
  let name: String
  let originMM: ModelPoint
  let outlineEntityIDs: [String]
  let holeEntityIDGroups: [[String]]
  let entityIDs: [String]
  let derivedElementIDs: [String]
  let freeTextIDs: [String]
  let measurementAnnotationIDs: [String]
  let visible: Bool
  let printable: Bool
  let locked: Bool
  let quantity: Int

  enum CodingKeys: String, CodingKey {
    case id, name
    case originMM = "originMm"
    case outlineEntityIDs = "outlineEntityIds"
    case holeEntityIDGroups = "holeEntityIdGroups"
    case entityIDs = "entityIds"
    case derivedElementIDs = "derivedElementIds"
    case freeTextIDs = "freeTextIds"
    case measurementAnnotationIDs = "measurementAnnotationIds"
    case visible, printable, locked, quantity
  }

  init(
    id: String,
    name: String,
    originMM: ModelPoint,
    outlineEntityIDs: [String],
    holeEntityIDGroups: [[String]],
    entityIDs: [String],
    derivedElementIDs: [String],
    freeTextIDs: [String],
    measurementAnnotationIDs: [String],
    visible: Bool = true,
    printable: Bool = true,
    locked: Bool = true,
    quantity: Int = 1
  ) {
    self.id = id
    self.name = name
    self.originMM = originMM
    self.outlineEntityIDs = outlineEntityIDs
    self.holeEntityIDGroups = holeEntityIDGroups
    self.entityIDs = entityIDs
    self.derivedElementIDs = derivedElementIDs
    self.freeTextIDs = freeTextIDs
    self.measurementAnnotationIDs = measurementAnnotationIDs
    self.visible = visible
    self.printable = printable
    self.locked = locked
    self.quantity = quantity
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      id: try container.decode(String.self, forKey: .id),
      name: try container.decode(String.self, forKey: .name),
      originMM: try container.decode(ModelPoint.self, forKey: .originMM),
      outlineEntityIDs: try container.decode([String].self, forKey: .outlineEntityIDs),
      holeEntityIDGroups: try container.decodeIfPresent(
        [[String]].self, forKey: .holeEntityIDGroups) ?? [],
      entityIDs: try container.decode([String].self, forKey: .entityIDs),
      derivedElementIDs: try container.decodeIfPresent([String].self, forKey: .derivedElementIDs)
        ?? [],
      freeTextIDs: try container.decodeIfPresent([String].self, forKey: .freeTextIDs) ?? [],
      measurementAnnotationIDs: try container.decodeIfPresent(
        [String].self, forKey: .measurementAnnotationIDs) ?? [],
      visible: try container.decodeIfPresent(Bool.self, forKey: .visible) ?? true,
      printable: try container.decodeIfPresent(Bool.self, forKey: .printable) ?? true,
      locked: try container.decodeIfPresent(Bool.self, forKey: .locked) ?? true,
      quantity: try container.decodeIfPresent(Int.self, forKey: .quantity) ?? 1
    )
  }

  func withMetadata(name: String, originMM: ModelPoint) -> ProjectPart {
    ProjectPart(
      id: id,
      name: name,
      originMM: originMM,
      outlineEntityIDs: outlineEntityIDs,
      holeEntityIDGroups: holeEntityIDGroups,
      entityIDs: entityIDs,
      derivedElementIDs: derivedElementIDs,
      freeTextIDs: freeTextIDs,
      measurementAnnotationIDs: measurementAnnotationIDs,
      visible: visible,
      printable: printable,
      locked: locked,
      quantity: quantity
    )
  }

  func withSettings(
    visible: Bool? = nil,
    printable: Bool? = nil,
    locked: Bool? = nil,
    quantity: Int? = nil
  ) -> ProjectPart {
    ProjectPart(
      id: id,
      name: name,
      originMM: originMM,
      outlineEntityIDs: outlineEntityIDs,
      holeEntityIDGroups: holeEntityIDGroups,
      entityIDs: entityIDs,
      derivedElementIDs: derivedElementIDs,
      freeTextIDs: freeTextIDs,
      measurementAnnotationIDs: measurementAnnotationIDs,
      visible: visible ?? self.visible,
      printable: printable ?? self.printable,
      locked: locked ?? self.locked,
      quantity: quantity ?? self.quantity
    )
  }
}

enum ProjectRoundHoleKind: String, CaseIterable, Identifiable, Hashable {
  case keyRing
  case rivet
  case snapFastener
  case decorative

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .keyRing: return AppStrings.tr("round_hole.kind.key_ring")
    case .rivet: return AppStrings.tr("round_hole.kind.rivet")
    case .snapFastener: return AppStrings.tr("round_hole.kind.snap_fastener")
    case .decorative: return AppStrings.tr("round_hole.kind.decorative")
    }
  }
}

struct ProjectRoundHole: Identifiable, Hashable {
  let id: String
  let entityID: String
  let kind: ProjectRoundHoleKind

  var documentCommandPayload: [String: Any] {
    [
      "id": id,
      "entityId": entityID,
      "kind": kind.rawValue,
    ]
  }

  func withKind(_ kind: ProjectRoundHoleKind) -> ProjectRoundHole {
    ProjectRoundHole(id: id, entityID: entityID, kind: kind)
  }

}

struct ProjectStitchStartPoint: Identifiable, Hashable {
  let id: String
  let targetID: String
  let resolvedIndex: Int?
  let positionRatio: Double

  var documentCommandPayload: [String: Any] {
    var payload: [String: Any] = [
      "id": id,
      "targetId": targetID,
      "positionRatio": positionRatio,
    ]
    if let resolvedIndex {
      payload["resolvedIndex"] = resolvedIndex
    }
    return payload
  }

}

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

struct ProjectLayer: Identifiable, Hashable {
  let id: String
  let name: String
  let kind: LayerKind
  let visible: Bool
  let printable: Bool
  let colorHex: String
  let strokeWidthMM: Double
  let linePattern: LinePattern

  init(
    id: String,
    name: String,
    kind: LayerKind,
    visible: Bool,
    printable: Bool,
    colorHex: String,
    strokeWidthMM: Double = 0.2,
    linePattern: LinePattern = .solid
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.visible = visible
    self.printable = printable
    self.colorHex = colorHex
    self.strokeWidthMM = strokeWidthMM
    self.linePattern = linePattern
  }
}

struct ProjectSharedStyle: Identifiable, Hashable {
  let id: String
  let name: String
  let colorHex: String
  let strokeWidthMM: Double
  let linePattern: LinePattern

  var stylePayload: [String: Any] {
    [
      "stroke": rgbaPayload(fromHex: colorHex),
      "strokeWidthMm": strokeWidthMM,
      "pattern": linePattern.rawValue,
    ]
  }

  var documentCommandPayload: [String: Any] {
    [
      "id": id,
      "name": name,
      "style": stylePayload,
    ]
  }

  func withName(_ name: String) -> ProjectSharedStyle {
    ProjectSharedStyle(
      id: id, name: name, colorHex: colorHex, strokeWidthMM: strokeWidthMM, linePattern: linePattern
    )
  }

  func withStyle(colorHex: String, strokeWidthMM: Double, linePattern: LinePattern)
    -> ProjectSharedStyle
  {
    ProjectSharedStyle(
      id: id, name: name, colorHex: colorHex, strokeWidthMM: strokeWidthMM, linePattern: linePattern
    )
  }
}

private func rgbaPayload(fromHex hex: String) -> [String: Double] {
  let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
  var rgb: UInt64 = 0
  Scanner(string: value).scanHexInt64(&rgb)

  return [
    "red": Double((rgb >> 16) & 0xFF) / 255.0,
    "green": Double((rgb >> 8) & 0xFF) / 255.0,
    "blue": Double(rgb & 0xFF) / 255.0,
    "alpha": 1.0,
  ]
}

struct UserAlertMessage: Identifiable, Hashable {
  let id = UUID()
  let message: String
}

struct LayerDeletionConfirmation: Identifiable, Hashable {
  let id = UUID()
  let layer: ProjectLayer
  let entityCount: Int

  var message: String {
    let entityText =
      entityCount > 0 ? AppStrings.tr("layer_deletion.entity_count", entityCount) : nil
    let references = [entityText].compactMap { $0 }.joined(separator: "、")
    return AppStrings.tr("layer_deletion.message", layer.name, references)
  }
}

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

extension Array where Element == ConstraintStatus {
  func aggregated() -> ConstraintStatus {
    if isEmpty {
      return .unknown
    }
    if contains(.conflicting) {
      return .conflicting
    }
    if contains(.overConstrained) {
      return .overConstrained
    }
    if allSatisfy({ $0 == .fullyConstrained }) {
      return .fullyConstrained
    }
    if contains(.underConstrained) {
      return .underConstrained
    }
    return .unknown
  }
}
