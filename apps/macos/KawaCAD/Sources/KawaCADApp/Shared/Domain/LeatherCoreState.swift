import KawaCADOutput

struct LeatherCoreVersionInfo: Equatable {
  let fileFormatMajor: UInt32
  let schemaMajor: UInt32
}

struct LeatherDocumentStatistics: Equatable {
  let layerCount: Int
  let sharedStyleCount: Int
  let parameterCount: Int
  var partCount: Int = 0
  let entityCount: Int
  let derivedElementCount: Int
  let constraintCount: Int
}

struct LeatherSnapshotSummary: Equatable {
  let visibleEntityCount: Int
  let constraintCount: Int
  let constraintStatus: ConstraintStatus
}

struct LeatherDocumentSnapshot: Equatable {
  let name: String
  let statistics: LeatherDocumentStatistics
  let editDisplaySummary: LeatherSnapshotSummary
  let outputPreviewSummary: LeatherSnapshotSummary
}

struct LeatherHistoryState: Equatable {
  let canUndo: Bool
  let canRedo: Bool
}

struct LeatherPersistenceState: Equatable {
  let isDirty: Bool
  let revision: String

  static let clean = LeatherPersistenceState(isDirty: false, revision: "")
}

struct ResolvedCanvasPoint: Codable, Equatable {
  let id: String
  let positionMM: ModelPoint
  let visible: Bool

  private enum CodingKeys: String, CodingKey {
    case id
    case positionMM = "positionMm"
    case visible
  }
}

struct ResolvedCanvasGeometry: Codable, Equatable {
  let id: String
  let visible: Bool
  let arc: Bool?
  let centerMM: ModelPoint?
  let startMM: ModelPoint?
  let endMM: ModelPoint?

  private enum CodingKeys: String, CodingKey {
    case id, visible, arc
    case centerMM = "centerMm"
    case startMM = "startMm"
    case endMM = "endMm"
  }
}

struct LeatherCanvasProjection: Codable, Equatable {
  let visibleFreeTextIDs: [String]
  let stitchStartPoints: [ResolvedCanvasPoint]
  let measurementAnnotations: [ResolvedCanvasGeometry]
  let dimensionConstraints: [ResolvedCanvasGeometry]
  let constraintMarkers: [ResolvedCanvasPoint]

  static let empty = LeatherCanvasProjection(
    visibleFreeTextIDs: [],
    stitchStartPoints: [],
    measurementAnnotations: [],
    dimensionConstraints: [],
    constraintMarkers: []
  )

  private enum CodingKeys: String, CodingKey {
    case visibleFreeTextIDs = "visibleFreeTextIds"
    case stitchStartPoints, measurementAnnotations, dimensionConstraints, constraintMarkers
  }
}

struct LeatherMutationResult: Codable, Equatable {
  let created: LeatherMutationIDs
  let updated: LeatherMutationIDs
  let deleted: LeatherMutationIDs
}

struct LeatherMutationIDs: Codable, Equatable {
  let layerIDs: [String]
  let sharedStyleIDs: [String]
  let parameterIDs: [String]
  let partIDs: [String]
  let entityIDs: [String]
  let derivedElementIDs: [String]
  let freeTextIDs: [String]
  let roundHoleIDs: [String]
  let stitchStartPointIDs: [String]
  let constraintIDs: [String]
  let measurementAnnotationIDs: [String]
  let dimensionConstraintAnnotationIDs: [String]

  init(
    layerIDs: [String] = [],
    sharedStyleIDs: [String] = [],
    parameterIDs: [String] = [],
    partIDs: [String] = [],
    entityIDs: [String] = [],
    derivedElementIDs: [String] = [],
    freeTextIDs: [String] = [],
    roundHoleIDs: [String] = [],
    stitchStartPointIDs: [String] = [],
    constraintIDs: [String] = [],
    measurementAnnotationIDs: [String] = [],
    dimensionConstraintAnnotationIDs: [String] = []
  ) {
    self.layerIDs = layerIDs
    self.sharedStyleIDs = sharedStyleIDs
    self.parameterIDs = parameterIDs
    self.partIDs = partIDs
    self.entityIDs = entityIDs
    self.derivedElementIDs = derivedElementIDs
    self.freeTextIDs = freeTextIDs
    self.roundHoleIDs = roundHoleIDs
    self.stitchStartPointIDs = stitchStartPointIDs
    self.constraintIDs = constraintIDs
    self.measurementAnnotationIDs = measurementAnnotationIDs
    self.dimensionConstraintAnnotationIDs = dimensionConstraintAnnotationIDs
  }

  private enum CodingKeys: String, CodingKey {
    case layerIDs = "layerIds"
    case sharedStyleIDs = "sharedStyleIds"
    case parameterIDs = "parameterIds"
    case partIDs = "partIds"
    case entityIDs = "entityIds"
    case derivedElementIDs = "derivedElementIds"
    case freeTextIDs = "freeTextIds"
    case roundHoleIDs = "roundHoleIds"
    case stitchStartPointIDs = "stitchStartPointIds"
    case constraintIDs = "constraintIds"
    case measurementAnnotationIDs = "measurementAnnotationIds"
    case dimensionConstraintAnnotationIDs = "dimensionConstraintAnnotationIds"
  }
}

struct LeatherDocumentState: Equatable {
  let snapshot: LeatherDocumentSnapshot
  let history: LeatherHistoryState
  var printOrientation: OutputPrintOrientation = .portrait
  var persistence: LeatherPersistenceState = .clean
  var mutation: LeatherMutationResult?
  let layers: [ProjectLayer]
  let sharedStyles: [ProjectSharedStyle]
  let parameters: [ProjectParameter]
  var parts: [ProjectPart] = []
  let entities: [CanvasEntity]
  var canvasProjection: LeatherCanvasProjection = .empty
  let derivedElements: [ProjectDerivedElement]
  let freeTexts: [ProjectFreeText]
  let roundHoles: [ProjectRoundHole]
  let stitchStartPoints: [ProjectStitchStartPoint]
  let warnings: [String]
  let coincidentPointGroups: [CoincidentPointGroup]
  let constraints: [ProjectConstraint]
  let measurementAnnotations: [ProjectMeasurementAnnotation]
  let measurementEvaluations: [MeasurementEvaluation]
  let dimensionConstraintAnnotations: [ProjectDimensionConstraintAnnotation]
}
