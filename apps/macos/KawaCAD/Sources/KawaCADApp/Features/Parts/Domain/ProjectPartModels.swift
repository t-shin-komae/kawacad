import Foundation

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
      id: id, name: name, originMM: originMM, outlineEntityIDs: outlineEntityIDs,
      holeEntityIDGroups: holeEntityIDGroups, entityIDs: entityIDs,
      derivedElementIDs: derivedElementIDs,
      freeTextIDs: freeTextIDs, measurementAnnotationIDs: measurementAnnotationIDs,
      visible: visible,
      printable: printable, locked: locked, quantity: quantity)
  }

  func withSettings(
    visible: Bool? = nil, printable: Bool? = nil, locked: Bool? = nil, quantity: Int? = nil
  ) -> ProjectPart {
    ProjectPart(
      id: id, name: name, originMM: originMM, outlineEntityIDs: outlineEntityIDs,
      holeEntityIDGroups: holeEntityIDGroups, entityIDs: entityIDs,
      derivedElementIDs: derivedElementIDs,
      freeTextIDs: freeTextIDs, measurementAnnotationIDs: measurementAnnotationIDs,
      visible: visible ?? self.visible,
      printable: printable ?? self.printable, locked: locked ?? self.locked,
      quantity: quantity ?? self.quantity)
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
    ["id": id, "entityId": entityID, "kind": kind.rawValue]
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
    var payload: [String: Any] = ["id": id, "targetId": targetID, "positionRatio": positionRatio]
    if let resolvedIndex { payload["resolvedIndex"] = resolvedIndex }
    return payload
  }
}
