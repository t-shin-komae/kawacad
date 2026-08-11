import CoreFoundation
import Foundation

enum CoreWireError: LocalizedError {
  case unsupportedJSONValue(String)

  var errorDescription: String? {
    switch self {
    case .unsupportedJSONValue(let typeName):
      return "unsupported JSON value: \(typeName)"
    }
  }
}

enum CoreJSONValue: Codable, Hashable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case null
  case array([CoreJSONValue])
  case object([String: CoreJSONValue])

  init(any value: Any) throws {
    switch value {
    case let string as String:
      self = .string(string)
    case let number as NSNumber:
      if CFGetTypeID(number) == CFBooleanGetTypeID() {
        self = .bool(number.boolValue)
        return
      }
      let value = number.doubleValue
      guard value.isFinite else {
        throw CoreWireError.unsupportedJSONValue(String(describing: type(of: value)))
      }
      self = .number(value)
    case _ as NSNull:
      self = .null
    case let array as [Any]:
      self = .array(try array.map(CoreJSONValue.init(any:)))
    case let object as [String: Any]:
      self = .object(try object.mapValues(CoreJSONValue.init(any:)))
    default:
      throw CoreWireError.unsupportedJSONValue(String(describing: type(of: value)))
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([CoreJSONValue].self) {
      self = .array(value)
    } else if let value = try? container.decode([String: CoreJSONValue].self) {
      self = .object(value)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "unsupported JSON value"
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    switch self {
    case .string(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)
    case .number(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)
    case .bool(let value):
      var container = encoder.singleValueContainer()
      try container.encode(value)
    case .null:
      var container = encoder.singleValueContainer()
      try container.encodeNil()
    case .array(let values):
      var container = encoder.unkeyedContainer()
      for value in values {
        try container.encode(value)
      }
    case .object(let values):
      var container = encoder.container(keyedBy: DynamicCodingKey.self)
      for key in values.keys.sorted() {
        guard let value = values[key] else { continue }
        try container.encode(value, forKey: DynamicCodingKey(stringValue: key))
      }
    }
  }
}

extension CoreJSONValue {
  var objectValue: [String: CoreJSONValue]? {
    guard case .object(let value) = self else { return nil }
    return value
  }

  var stringValue: String? {
    guard case .string(let value) = self else { return nil }
    return value
  }

  var intValue: Int? {
    guard case .number(let value) = self, value.rounded() == value else { return nil }
    return Int(value)
  }

  var stringArrayValue: [String]? {
    guard case .array(let values) = self else { return nil }
    let strings = values.compactMap(\.stringValue)
    return strings.count == values.count ? strings : nil
  }

  var anyValue: Any {
    switch self {
    case .string(let value): value
    case .number(let value): value
    case .bool(let value): value
    case .null: NSNull()
    case .array(let values): values.map(\.anyValue)
    case .object(let values): values.mapValues(\.anyValue)
    }
  }
}

enum CoreDocumentCommandKind: String, Codable, Hashable {
  case renameDocument, setPrintOrientation, addEntity, createEntityFromGesture, updateEntity,
    moveEntities,
    moveControlPoint
  case setEntityMetric, setEntityLayer, smoothArcTangencies, deleteEntity
  case addDerivedElement, updateDerivedElement, setDerivedDistance, setDerivedRadius
  case setDerivedRadiusFromPoint, setDerivedDirection, setDerivedLayer, setDerivedSharedStyle,
    setFilletSources, deleteDerivedElement
  case addFreeText, updateFreeText, deleteFreeText
  case addRoundHole, updateRoundHole, createRoundHole, setRoundHoleDiameter, setRoundHoleKind,
    deleteRoundHole
  case addStitchStartPoint, placeStitchStartPoint, updateStitchStartPoint, deleteStitchStartPoint
  case addLayer, renameLayer, deleteLayer, setLayerVisibility, setLayerPrintable, setLayerStyle
  case addSharedStyle, updateSharedStyle, deleteSharedStyle, setEntitySharedStyle
  case addConstraint, updateConstraint, setConstraintValue, setConstraintParameter, deleteConstraint
  case addMeasurementAnnotation, updateMeasurementAnnotation, moveMeasurementAnnotation,
    deleteMeasurementAnnotation
  case convertMeasurementToConstraint
  case addDimensionConstraintAnnotation, updateDimensionConstraintAnnotation,
    moveDimensionConstraintAnnotation, deleteDimensionConstraintAnnotation
  case addParameter, updateParameter, deleteParameter, setParameterValue
  case createPart, updatePart, renamePart, updatePartSettings, setPartVisibility, setPartPrintable,
    setPartQuantity, deletePart, movePart, setPartPosition, duplicatePart
  case insertPartLibraryItem
  case addEntitiesToPart, removeEntitiesFromPart, setPartBoundary
  case alignParts, distributeParts
  case duplicateSelection, pasteSelection, compound
}

struct CoreDocumentCommand: Encodable, Hashable {
  let kind: CoreDocumentCommandKind
  let payload: CoreJSONValue

  init(kind: CoreDocumentCommandKind, payload: CoreJSONValue) {
    self.kind = kind
    self.payload = payload
  }

  init(legacyObject: [String: Any]) throws {
    guard let rawKind = legacyObject["kind"] as? String,
      let kind = CoreDocumentCommandKind(rawValue: rawKind),
      let payload = legacyObject["payload"]
    else {
      throw CoreWireError.unsupportedJSONValue("DocumentCommand")
    }
    self.init(kind: kind, payload: try CoreJSONValue(any: payload))
  }

  private enum CodingKeys: String, CodingKey { case kind, payload }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(kind, forKey: .kind)
    try container.encode(payload, forKey: .payload)
  }

  var legacyObject: [String: Any] {
    ["kind": kind.rawValue, "payload": payload.anyValue]
  }

  var jsonValue: CoreJSONValue {
    .object(["kind": .string(kind.rawValue), "payload": payload])
  }

  subscript(key: String) -> Any? {
    switch key {
    case "kind": kind.rawValue
    case "payload": payload.anyValue
    default: nil
    }
  }
}

private struct DynamicCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(intValue: Int) {
    self.stringValue = "\(intValue)"
    self.intValue = intValue
  }
}

enum CoreControlPoint: String, Codable, Hashable {
  case start
  case end
  case center
}

enum CoreConstraintTarget: Codable, Hashable {
  case entity(String)
  case controlPoint(entityID: String, point: CoreControlPoint)

  private enum CodingKeys: String, CodingKey {
    case entity
    case controlPoint
  }

  private enum ControlPointCodingKeys: String, CodingKey {
    case entityID = "entity_id"
    case point
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let entityID = try container.decodeIfPresent(String.self, forKey: .entity) {
      self = .entity(entityID)
      return
    }
    let pointContainer = try container.nestedContainer(
      keyedBy: ControlPointCodingKeys.self,
      forKey: .controlPoint
    )
    self = .controlPoint(
      entityID: try pointContainer.decode(String.self, forKey: .entityID),
      point: try pointContainer.decode(CoreControlPoint.self, forKey: .point)
    )
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .entity(let entityID):
      try container.encode(entityID, forKey: .entity)
    case .controlPoint(let entityID, let point):
      var pointContainer = container.nestedContainer(
        keyedBy: ControlPointCodingKeys.self,
        forKey: .controlPoint
      )
      try pointContainer.encode(entityID, forKey: .entityID)
      try pointContainer.encode(point, forKey: .point)
    }
  }

  var entityID: String {
    switch self {
    case .entity(let entityID):
      return entityID
    case .controlPoint(let entityID, _):
      return entityID
    }
  }

  var jsonObject: [String: Any] {
    switch self {
    case .entity(let entityID):
      return ["entity": entityID]
    case .controlPoint(let entityID, let point):
      return [
        "controlPoint": [
          "entity_id": entityID,
          "point": point.rawValue,
        ]
      ]
    }
  }

  static func decodeList(from json: String) -> [CoreConstraintTarget]? {
    guard let data = json.data(using: .utf8) else {
      return nil
    }
    return try? JSONDecoder().decode([CoreConstraintTarget].self, from: data)
  }

  static func decodeList(from data: Data) -> [CoreConstraintTarget]? {
    try? JSONDecoder().decode([CoreConstraintTarget].self, from: data)
  }
}

enum CoreConstraintValue: Codable, Equatable {
  case fixedMm(Double)
  case fixedDegrees(Double)
  case parameter(String)

  private enum CodingKeys: String, CodingKey {
    case fixedMm
    case fixedDegrees
    case parameter
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let value = try container.decodeIfPresent(Double.self, forKey: .fixedMm) {
      self = .fixedMm(value)
      return
    }
    if let value = try container.decodeIfPresent(Double.self, forKey: .fixedDegrees) {
      self = .fixedDegrees(value)
      return
    }
    if let value = try container.decodeIfPresent(String.self, forKey: .parameter) {
      self = .parameter(value)
      return
    }
    throw DecodingError.dataCorrupted(
      DecodingError.Context(
        codingPath: decoder.codingPath,
        debugDescription: "constraint value must contain fixedMm, fixedDegrees, or parameter"
      )
    )
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .fixedMm(let value):
      try container.encode(value, forKey: .fixedMm)
    case .fixedDegrees(let value):
      try container.encode(value, forKey: .fixedDegrees)
    case .parameter(let parameterID):
      try container.encode(parameterID, forKey: .parameter)
    }
  }

  var jsonObject: [String: Any] {
    switch self {
    case .fixedMm(let value):
      return ["fixedMm": value]
    case .fixedDegrees(let value):
      return ["fixedDegrees": value]
    case .parameter(let parameterID):
      return ["parameter": parameterID]
    }
  }
}

struct ConstraintPreflightResult: Codable, Equatable {
  let kind: String
  let value: CoreConstraintValue?
  let normalizedTargets: [CoreConstraintTarget]?

  init(
    kind: String,
    value: CoreConstraintValue?,
    normalizedTargets: [CoreConstraintTarget]? = nil
  ) {
    self.kind = kind
    self.value = value
    self.normalizedTargets = normalizedTargets
  }
}

struct LayerDeletionImpact: Codable, Equatable {
  let layerID: String
  let entityCount: Int
  let derivedElementCount: Int
  var affectedCount: Int { entityCount + derivedElementCount }

  private enum CodingKeys: String, CodingKey {
    case layerID = "layerId"
    case entityCount
    case derivedElementCount
  }
}

struct CorePoint: Codable, Equatable, Hashable {
  let xMm: Double
  let yMm: Double

  var modelPoint: ModelPoint { ModelPoint(xMM: xMm, yMM: yMm) }
  var jsonValue: CoreJSONValue { .object(["xMm": .number(xMm), "yMm": .number(yMm)]) }
}

enum DerivedElementPreflightKind: String, Codable { case offsetCurve, fillet }

struct DerivedElementPreflightResult: Codable, Equatable {
  struct OffsetOption: Codable, Equatable {
    let scope: String
    let sourceEntityIds: [String]
    let sourceResolvedEntityIds: [String]?
    let direction: String

    init(
      scope: String,
      sourceEntityIds: [String],
      sourceResolvedEntityIds: [String]? = nil,
      direction: String
    ) {
      self.scope = scope
      self.sourceEntityIds = sourceEntityIds
      self.sourceResolvedEntityIds = sourceResolvedEntityIds
      self.direction = direction
    }
  }

  let kind: DerivedElementPreflightKind
  let offsetOptions: [OffsetOption]
  let sourceEntityIds: [String]
  let updateDerivedElementId: String?
  let closed: Bool
}

struct MeasurementEvaluation: Codable, Equatable {
  let annotationId: String
  let kind: String
  let value: CoreConstraintValue
  let center: CorePoint?
  let start: CorePoint?
  let end: CorePoint?
}

struct CoreSelectionReference: Codable, Equatable {
  let entityIds: [String]
  let derivedElementIds: [String]
  let constraintIds: [String]
  let measurementAnnotationIds: [String]
  let stitchStartPointIds: [String]
  let freeTextIds: [String]

  var rootCount: Int {
    entityIds.count + derivedElementIds.count + constraintIds.count
      + measurementAnnotationIds.count + stitchStartPointIds.count + freeTextIds.count
  }

  var jsonValue: CoreJSONValue {
    .object([
      "entityIds": .array(entityIds.map(CoreJSONValue.string)),
      "derivedElementIds": .array(derivedElementIds.map(CoreJSONValue.string)),
      "constraintIds": .array(constraintIds.map(CoreJSONValue.string)),
      "measurementAnnotationIds": .array(measurementAnnotationIds.map(CoreJSONValue.string)),
      "stitchStartPointIds": .array(stitchStartPointIds.map(CoreJSONValue.string)),
      "freeTextIds": .array(freeTextIds.map(CoreJSONValue.string)),
    ])
  }
}

struct SelectionClipboardExport: Codable, Equatable {
  let clipboardJson: String
  let rootCount: Int
  let anchorPoint: CorePoint?
  let bounds: CoreBounds?
}

struct CoreBounds: Codable, Equatable {
  let minPoint: CorePoint
  let maxPoint: CorePoint
}

struct PartLibraryExport: Codable, Equatable {
  let libraryJSON: String
  let sourcePart: ProjectPart

  private enum CodingKeys: String, CodingKey {
    case libraryJSON = "libraryJson"
    case sourcePart
  }
}

extension CoreConstraintTarget {
  var jsonValue: CoreJSONValue {
    switch self {
    case .entity(let entityID):
      .object(["entity": .string(entityID)])
    case .controlPoint(let entityID, let point):
      .object([
        "controlPoint": .object([
          "entity_id": .string(entityID),
          "point": .string(point.rawValue),
        ])
      ])
    }
  }

  init?(jsonObject: [String: Any]) {
    if let entityID = jsonObject["entity"] as? String {
      self = .entity(entityID)
      return
    }
    guard let control = jsonObject["controlPoint"] as? [String: Any],
      let entityID = control["entity_id"] as? String,
      let rawPoint = control["point"] as? String,
      let point = CoreControlPoint(rawValue: rawPoint)
    else { return nil }
    self = .controlPoint(entityID: entityID, point: point)
  }
}

extension CanvasControlPoint {
  var wirePoint: CoreControlPoint {
    switch self {
    case .start, .arcStart:
      return .start
    case .end, .arcEnd:
      return .end
    case .center:
      return .center
    case .radius:
      return .center
    }
  }
}
