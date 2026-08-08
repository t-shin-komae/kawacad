import Foundation
import KawaCADOutput

@testable import KawaCADApp

extension ModelPoint {
  static let zero = ModelPoint(xMM: 0.0, yMM: 0.0)
}

func resolvedCanvasPoint(
  id: String,
  position: ModelPoint,
  visible: Bool = true
) -> ResolvedCanvasPoint {
  ResolvedCanvasPoint(id: id, positionMM: position, visible: visible)
}

func resolvedCanvasGeometry(
  id: String,
  visible: Bool = true,
  arc: Bool? = nil,
  center: ModelPoint? = nil,
  start: ModelPoint? = nil,
  end: ModelPoint? = nil
) -> ResolvedCanvasGeometry {
  ResolvedCanvasGeometry(
    id: id,
    visible: visible,
    arc: arc,
    centerMM: center,
    startMM: start,
    endMM: end
  )
}

func canvasProjection(
  visibleFreeTextIDs: [String] = [],
  stitchStartPoints: [ResolvedCanvasPoint] = [],
  measurementAnnotations: [ResolvedCanvasGeometry] = [],
  dimensionConstraints: [ResolvedCanvasGeometry] = [],
  constraintMarkers: [ResolvedCanvasPoint] = []
) -> LeatherCanvasProjection {
  LeatherCanvasProjection(
    visibleFreeTextIDs: visibleFreeTextIDs,
    stitchStartPoints: stitchStartPoints,
    measurementAnnotations: measurementAnnotations,
    dimensionConstraints: dimensionConstraints,
    constraintMarkers: constraintMarkers
  )
}

func makeDocumentState(
  name: String = "Test Project",
  history: LeatherHistoryState = LeatherHistoryState(canUndo: false, canRedo: false),
  layers: [ProjectLayer] = defaultLayers(),
  sharedStyles: [ProjectSharedStyle] = [],
  parameters: [ProjectParameter] = [],
  parts: [ProjectPart] = [],
  entities: [CanvasEntity] = [],
  derivedElements: [ProjectDerivedElement] = [],
  freeTexts: [ProjectFreeText] = [],
  roundHoles: [ProjectRoundHole] = [],
  stitchStartPoints: [ProjectStitchStartPoint] = [],
  warnings: [String] = [],
  coincidentPointGroups: [CoincidentPointGroup] = [],
  constraints: [ProjectConstraint] = [],
  measurementAnnotations: [ProjectMeasurementAnnotation] = [],
  dimensionConstraintAnnotations: [ProjectDimensionConstraintAnnotation] = [],
  constraintStatus: ConstraintStatus = .unknown
) -> LeatherDocumentState {
  let statistics = LeatherDocumentStatistics(
    layerCount: layers.count,
    sharedStyleCount: sharedStyles.count,
    parameterCount: parameters.count,
    entityCount: entities.count,
    derivedElementCount: derivedElements.count,
    constraintCount: constraints.count
  )
  let summary = LeatherSnapshotSummary(
    visibleEntityCount: entities.count,
    constraintCount: constraints.count,
    constraintStatus: constraintStatus
  )
  let snapshot = LeatherDocumentSnapshot(
    name: name,
    statistics: statistics,
    editDisplaySummary: summary,
    outputPreviewSummary: summary
  )
  var state = LeatherDocumentState(
    snapshot: snapshot,
    history: history,
    layers: layers,
    sharedStyles: sharedStyles,
    parameters: parameters,
    entities: entities,
    derivedElements: derivedElements,
    freeTexts: freeTexts,
    roundHoles: roundHoles,
    stitchStartPoints: stitchStartPoints,
    warnings: warnings,
    coincidentPointGroups: coincidentPointGroups,
    constraints: constraints,
    measurementAnnotations: measurementAnnotations,
    measurementEvaluations: [],
    dimensionConstraintAnnotations: dimensionConstraintAnnotations
  )
  state.parts = parts
  return state
}

func defaultLayers() -> [ProjectLayer] {
  [
    ProjectLayer(
      id: "layer:cut-line",
      name: "カット線",
      kind: .cutLine,
      visible: true,
      printable: true,
      colorHex: "#1f2937"
    ),
    ProjectLayer(
      id: "layer:construction",
      name: "補助線",
      kind: .construction,
      visible: true,
      printable: false,
      colorHex: "#94a3b8"
    ),
    ProjectLayer(
      id: "layer:dimension",
      name: "寸法",
      kind: .dimension,
      visible: true,
      printable: true,
      colorHex: "#6b7280"
    ),
  ]
}

func lineEntity(
  id: String,
  label: String? = nil,
  layerID: String? = "layer:cut-line",
  start: ModelPoint,
  end: ModelPoint
) -> CanvasEntity {
  let metadata = testDerivedMetadata(id)
  return CanvasEntity(
    id: id,
    label: label ?? id,
    kind: .lineSegment,
    layerID: layerID,
    geometry: .line(start: start, end: end, centerLine: false),
    derivedElementID: metadata?.id,
    derivedResolvedIndex: metadata?.index
  )
}

func centerLineEntity(
  id: String,
  label: String? = nil,
  layerID: String? = "layer:cut-line",
  start: ModelPoint,
  end: ModelPoint
) -> CanvasEntity {
  let metadata = testDerivedMetadata(id)
  return CanvasEntity(
    id: id,
    label: label ?? id,
    kind: .centerLine,
    layerID: layerID,
    geometry: .line(start: start, end: end, centerLine: true),
    derivedElementID: metadata?.id,
    derivedResolvedIndex: metadata?.index
  )
}

func arcEntity(
  id: String,
  label: String? = nil,
  layerID: String? = "layer:cut-line",
  center: ModelPoint,
  radiusMM: Double,
  startAngleRad: Double,
  sweepAngleRad: Double
) -> CanvasEntity {
  let metadata = testDerivedMetadata(id)
  return CanvasEntity(
    id: id,
    label: label ?? id,
    kind: .arc,
    layerID: layerID,
    geometry: .arc(
      center: center,
      radiusMM: radiusMM,
      startAngleRad: startAngleRad,
      sweepAngleRad: sweepAngleRad
    ),
    derivedElementID: metadata?.id,
    derivedResolvedIndex: metadata?.index
  )
}

func pointEntity(
  id: String,
  label: String? = nil,
  layerID: String? = "layer:cut-line",
  point: ModelPoint
) -> CanvasEntity {
  let metadata = testDerivedMetadata(id)
  return CanvasEntity(
    id: id,
    label: label ?? id,
    kind: .point,
    layerID: layerID,
    geometry: .point(point),
    derivedElementID: metadata?.id,
    derivedResolvedIndex: metadata?.index
  )
}

private func testDerivedMetadata(_ id: String) -> (id: String, index: Int)? {
  guard let range = id.range(of: ":resolved:"),
    let index = Int(id[range.upperBound...])
  else {
    return nil
  }
  return (String(id[..<range.lowerBound]), index)
}

func projectConstraint(
  id: String,
  rawKind: String,
  kind: String? = nil,
  targets: [CoreConstraintTarget],
  valueMM: Double? = nil,
  valueDegrees: Double? = nil,
  valueParameterID: String? = nil,
  status: ConstraintStatus = .underConstrained
) -> ProjectConstraint {
  let targetsData = try? JSONEncoder().encode(targets)
  let targetsJSON = targetsData.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
  return ProjectConstraint(
    id: id,
    rawKind: rawKind,
    kind: kind ?? rawKind,
    targets: targets.map(\.entityID),
    targetsJSON: targetsJSON,
    valueMM: valueMM,
    valueDegrees: valueDegrees,
    valueParameterID: valueParameterID,
    status: status
  )
}

func requireSuccess<T>(_ result: LeatherCoreResult<T>, context: String = "operation") -> T {
  switch result {
  case .success(let value):
    return value
  case .failure(let message):
    preconditionFailure("\(context) failed: \(message)")
  }
}

func requireSuccess<T>(_ result: OutputResult<T>, context: String = "operation") -> T {
  switch result {
  case .success(let value):
    return value
  case .failure(let error):
    preconditionFailure("\(context) failed: \(error.message)")
  }
}

func defaultStubPreflightConstraintResult(kind: String) -> LeatherCoreResult<
  ConstraintPreflightResult
> {
  switch kind {
  case "angle":
    return .success(ConstraintPreflightResult(kind: kind, value: .fixedDegrees(90.0)))
  case "distance", "pointLineDistance", "horizontalDistance", "verticalDistance",
    "lineLineDistance",
    "segmentLength", "diameter", "radius":
    return .success(ConstraintPreflightResult(kind: kind, value: .fixedMm(20.0)))
  case "tangent", "pointOnLine", "symmetric", "horizontal", "vertical":
    return .success(ConstraintPreflightResult(kind: kind, value: nil))
  default:
    return .failure("unsupported preflight kind")
  }
}

func unwrap<T>(_ value: T?, context: String = "unexpected nil") -> T {
  guard let value else {
    preconditionFailure(context)
  }
  return value
}

func uniqueTempURL(_ name: String) -> URL {
  URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
    "leather-\(UUID().uuidString)-\(name)"
  )
}

func repositoryRootURL() -> URL {
  var url = URL(fileURLWithPath: #filePath)
  for _ in 0..<6 {
    url.deleteLastPathComponent()
  }
  return url
}

func interfaceFixtureData(_ name: String) throws -> Data {
  try Data(
    contentsOf: repositoryRootURL()
      .appendingPathComponent("tests/fixtures/interface")
      .appendingPathComponent(name)
  )
}

func interfaceSchemaData() throws -> Data {
  try Data(
    contentsOf: repositoryRootURL()
      .appendingPathComponent("schemas/interface/0.1.0.schema.json")
  )
}

func sampleOutputDocumentModel(
  orientation: OutputPrintOrientation = .portrait,
  rotationDeg: Int = 0
) -> OutputDocumentModel {
  let pageSize = OutputPaperDefaults.a4PageSizeMm(for: orientation)
  return OutputDocumentModel(
    paperSize: .a4,
    orientation: orientation,
    scale: .actualSize,
    pageCount: 1,
    pages: [
      OutputPage(
        widthMm: pageSize.widthMm,
        heightMm: pageSize.heightMm,
        rotationDeg: rotationDeg,
        printableAreaMm: OutputPaperDefaults.pdfPrintableAreaMm(for: orientation),
        graphics: [],
        texts: [],
        guide: nil
      )
    ]
  )
}

func sampleOutputBuildResult(
  model: OutputDocumentModel = sampleOutputDocumentModel(),
  warnings: [OutputWarning] = []
) -> OutputBuildResult {
  OutputBuildResult(outputDocumentModel: model, warnings: warnings)
}

func samplePrintRenderData(
  orientation: OutputPrintOrientation = .portrait,
  rotationDeg: Int = 0
) -> OutputPrintRenderData {
  let pageSize = OutputPaperDefaults.a4PageSizeMm(for: orientation)
  return OutputPrintRenderData(
    orientation: orientation,
    pages: [
      OutputPrintRenderPage(
        widthMm: pageSize.widthMm,
        heightMm: pageSize.heightMm,
        rotationDeg: rotationDeg,
        printableAreaMm: OutputPaperDefaults.pdfPrintableAreaMm(for: orientation),
        commands: []
      )
    ]
  )
}

final class ScriptedDocumentSession: LeatherDocumentSessionManaging {
  private let states: [String: LeatherDocumentState]
  private let statesByViewMode: [String: [String: LeatherDocumentState]]
  private let transitions: [String: [String]]
  private let loadFailuresByKey: [String: String]
  private(set) var currentKey: String
  private var cleanKey: String
  private var undoStack: [String] = []
  private var redoStack: [String] = []

  private(set) var appliedPayloads: [[String: Any]] = []
  private(set) var loadedModes: [CanvasViewMode] = []
  private(set) var writtenPaths: [URL] = []
  private(set) var outputBuildOptions: [OutputBuildOptions] = []
  private(set) var renderedOutputModels: [OutputDocumentModel] = []

  init(
    currentKey: String,
    states: [String: LeatherDocumentState],
    statesByViewMode: [String: [String: LeatherDocumentState]] = [:],
    transitions: [String: [String]] = [:],
    loadFailuresByKey: [String: String] = [:]
  ) {
    self.currentKey = currentKey
    self.cleanKey = currentKey
    self.states = states
    self.statesByViewMode = statesByViewMode
    self.transitions = transitions
    self.loadFailuresByKey = loadFailuresByKey
  }

  func loadState(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    loadedModes.append(viewMode)
    if let message = loadFailuresByKey[currentKey] {
      return .failure(message)
    }
    return stateResult(viewMode: viewMode)
  }

  func previewCommand(_ payload: CoreDocumentCommand, viewMode: CanvasViewMode)
    -> LeatherCoreResult<LeatherDocumentState>
  {
    appliedPayloads.append(payload.legacyObject)
    loadedModes.append(viewMode)
    return stateResult(viewMode: viewMode)
  }

  func preflightConstraint(kind: String, targets: [CoreConstraintTarget]) -> LeatherCoreResult<
    ConstraintPreflightResult
  > {
    _ = targets
    return defaultStubPreflightConstraintResult(kind: kind)
  }

  func preflightDerivedElement(
    kind: DerivedElementPreflightKind, hitEntityID: String?, selectedEntityIDs: [String],
    clickPoint: ModelPoint?
  ) -> LeatherCoreResult<DerivedElementPreflightResult> {
    .failure("unused derived preflight")
  }

  func evaluateMeasurement(annotationID: String) -> LeatherCoreResult<MeasurementEvaluation> {
    .failure("unused measurement evaluation")
  }

  func exportSelection(_ selection: CoreSelectionReference) -> LeatherCoreResult<
    SelectionClipboardExport
  > {
    .failure("unused selection export")
  }

  func applyCommand(_ payload: CoreDocumentCommand, viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  > {
    appliedPayloads.append(payload.legacyObject)
    loadedModes.append(viewMode)
    if let nextKey = transitions[currentKey]?.first {
      undoStack.append(currentKey)
      redoStack = []
      currentKey = nextKey
    }
    return stateResult(viewMode: viewMode)
  }

  func undo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    loadedModes.append(viewMode)
    guard let previousKey = undoStack.popLast() else {
      return .failure("no undo history")
    }
    redoStack.append(currentKey)
    currentKey = previousKey
    return stateResult(viewMode: viewMode)
  }

  func redo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    loadedModes.append(viewMode)
    guard let nextKey = redoStack.popLast() else {
      return .failure("no redo history")
    }
    undoStack.append(currentKey)
    currentKey = nextKey
    return stateResult(viewMode: viewMode)
  }

  func writeJSONFile(to url: URL) -> LeatherCoreResult<Void> {
    writtenPaths.append(url)
    cleanKey = currentKey
    try? Data("{\"fileFormatVersion\":\"0.1.0\"}\n".utf8).write(to: url)
    return .success(())
  }

  func writeSnapshotFile(to url: URL) -> LeatherCoreResult<Void> {
    writtenPaths.append(url)
    try? Data("{\"fileFormatVersion\":\"0.1.0\"}\n".utf8).write(to: url)
    return .success(())
  }

  func buildOutputDocumentModel(options: OutputBuildOptions) -> OutputResult<OutputBuildResult> {
    outputBuildOptions.append(options)
    return .success(sampleOutputBuildResult())
  }

  func renderPDF(outputDocumentModel: OutputDocumentModel) -> OutputResult<Data> {
    renderedOutputModels.append(outputDocumentModel)
    return .success(Data("%PDF-1.4\n".utf8))
  }

  func renderPrint(outputDocumentModel: OutputDocumentModel) -> OutputResult<OutputPrintRenderData>
  {
    renderedOutputModels.append(outputDocumentModel)
    return .success(samplePrintRenderData())
  }

  private func stateResult(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    let state = statesByViewMode[currentKey]?[viewMode.rawValue] ?? states[currentKey]
    guard let state else {
      return .failure("missing scripted state: \(currentKey)")
    }
    return .success(
      state
        .withHistory(canUndo: !undoStack.isEmpty, canRedo: !redoStack.isEmpty)
        .withPersistence(isDirty: currentKey != cleanKey, revision: currentKey)
    )
  }
}

final class ScriptedDocumentSessionBackend: DocumentSessionAdapterBackend {
  private let states: [String: LeatherDocumentState]
  private let statesByViewMode: [String: [String: LeatherDocumentState]]
  private let transitions: [String: [String]]
  private let loadFailuresByKey: [String: String]
  private let createResults: [LeatherCoreResult<String>]
  private var createAttempts = 0

  private(set) var createdNames: [String] = []
  private(set) var readURLs: [URL] = []
  private(set) var lastCreatedSession: ScriptedDocumentSession?

  init(
    states: [String: LeatherDocumentState],
    statesByViewMode: [String: [String: LeatherDocumentState]] = [:],
    transitions: [String: [String]] = [:],
    loadFailuresByKey: [String: String] = [:],
    createResults: [LeatherCoreResult<String>] = [.success("root")]
  ) {
    self.states = states
    self.statesByViewMode = statesByViewMode
    self.transitions = transitions
    self.loadFailuresByKey = loadFailuresByKey
    self.createResults = createResults
  }

  func createDocument(named name: String) -> LeatherCoreResult<any LeatherDocumentSessionManaging> {
    createdNames.append(name)
    let resultIndex = min(createAttempts, createResults.count - 1)
    createAttempts += 1
    switch createResults[resultIndex] {
    case .success(let currentKey):
      return makeSession(currentKey: currentKey)
    case .failure(let message):
      return .failure(message)
    }
  }

  func readDocument(from url: URL) -> LeatherCoreResult<any LeatherDocumentSessionManaging> {
    readURLs.append(url)
    return makeSession(currentKey: url.lastPathComponent)
  }

  private func makeSession(currentKey: String) -> LeatherCoreResult<
    any LeatherDocumentSessionManaging
  > {
    guard states[currentKey] != nil else {
      return .failure("missing scripted state: \(currentKey)")
    }
    let session = ScriptedDocumentSession(
      currentKey: currentKey,
      states: states,
      statesByViewMode: statesByViewMode,
      transitions: transitions,
      loadFailuresByKey: loadFailuresByKey
    )
    lastCreatedSession = session
    return .success(session)
  }
}

final class RoundTripDocumentSessionBackend: DocumentSessionAdapterBackend {
  private let states: [String: LeatherDocumentState]
  private let transitions: [String: [String]]
  private let storage = Storage()

  private(set) var createdNames: [String] = []
  private(set) var openedPaths: [String] = []

  var savedPaths: [String] {
    storage.savedPaths
  }

  init(states: [String: LeatherDocumentState], transitions: [String: [String]] = [:]) {
    self.states = states
    self.transitions = transitions
  }

  func createDocument(named name: String) -> LeatherCoreResult<any LeatherDocumentSessionManaging> {
    createdNames.append(name)
    return makeSession(currentKey: "original")
  }

  func readDocument(from url: URL) -> LeatherCoreResult<any LeatherDocumentSessionManaging> {
    let path = url.path
    openedPaths.append(path)
    guard let key = storage.savedKeysByPath[path] else {
      return .failure("missing saved document for \(path)")
    }
    return makeSession(currentKey: key)
  }

  private func makeSession(currentKey: String) -> LeatherCoreResult<
    any LeatherDocumentSessionManaging
  > {
    guard states[currentKey] != nil else {
      return .failure("missing scripted state: \(currentKey)")
    }
    return .success(
      RoundTripDocumentSession(
        currentKey: currentKey,
        states: states,
        transitions: transitions,
        storage: storage
      ))
  }

  final class Storage {
    var savedKeysByPath: [String: String] = [:]
    var savedPaths: [String] = []
  }
}

final class RoundTripDocumentSession: LeatherDocumentSessionManaging {
  private let states: [String: LeatherDocumentState]
  private let transitions: [String: [String]]
  private var undoStack: [String] = []
  private var currentKey: String
  private var cleanKey: String
  private var redoStack: [String] = []
  private let storage: RoundTripDocumentSessionBackend.Storage

  init(
    currentKey: String,
    states: [String: LeatherDocumentState],
    transitions: [String: [String]],
    storage: RoundTripDocumentSessionBackend.Storage
  ) {
    self.currentKey = currentKey
    self.cleanKey = currentKey
    self.states = states
    self.transitions = transitions
    self.storage = storage
  }

  func loadState(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    stateResult()
  }

  func previewCommand(_ payload: CoreDocumentCommand, viewMode: CanvasViewMode)
    -> LeatherCoreResult<LeatherDocumentState>
  {
    stateResult()
  }

  func preflightConstraint(kind: String, targets: [CoreConstraintTarget]) -> LeatherCoreResult<
    ConstraintPreflightResult
  > {
    _ = targets
    return defaultStubPreflightConstraintResult(kind: kind)
  }

  func preflightDerivedElement(
    kind: DerivedElementPreflightKind, hitEntityID: String?, selectedEntityIDs: [String],
    clickPoint: ModelPoint?
  ) -> LeatherCoreResult<DerivedElementPreflightResult> {
    .failure("unused derived preflight")
  }

  func evaluateMeasurement(annotationID: String) -> LeatherCoreResult<MeasurementEvaluation> {
    .failure("unused measurement evaluation")
  }

  func exportSelection(_ selection: CoreSelectionReference) -> LeatherCoreResult<
    SelectionClipboardExport
  > {
    .failure("unused selection export")
  }

  func applyCommand(_ payload: CoreDocumentCommand, viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  > {
    if let nextKey = transitions[currentKey]?.first {
      undoStack.append(currentKey)
      redoStack = []
      currentKey = nextKey
    }
    return stateResult()
  }

  func undo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    guard let previousKey = undoStack.popLast() else {
      return .failure("no undo history")
    }
    redoStack.append(currentKey)
    currentKey = previousKey
    return stateResult()
  }

  func redo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    guard let nextKey = redoStack.popLast() else {
      return .failure("no redo history")
    }
    undoStack.append(currentKey)
    currentKey = nextKey
    return stateResult()
  }

  func writeJSONFile(to url: URL) -> LeatherCoreResult<Void> {
    storage.savedKeysByPath[url.path] = currentKey
    storage.savedPaths.append(url.path)
    cleanKey = currentKey
    try? Data("{\"fileFormatVersion\":\"0.1.0\"}\n".utf8).write(to: url)
    return .success(())
  }

  func writeSnapshotFile(to url: URL) -> LeatherCoreResult<Void> {
    storage.savedKeysByPath[url.path] = currentKey
    storage.savedPaths.append(url.path)
    try? Data("{\"fileFormatVersion\":\"0.1.0\"}\n".utf8).write(to: url)
    return .success(())
  }

  func buildOutputDocumentModel(options: OutputBuildOptions) -> OutputResult<OutputBuildResult> {
    _ = options
    return .success(sampleOutputBuildResult())
  }

  func renderPDF(outputDocumentModel: OutputDocumentModel) -> OutputResult<Data> {
    _ = outputDocumentModel
    return .success(Data("%PDF-1.4\n".utf8))
  }

  func renderPrint(outputDocumentModel: OutputDocumentModel) -> OutputResult<OutputPrintRenderData>
  {
    _ = outputDocumentModel
    return .success(samplePrintRenderData())
  }

  private func stateResult() -> LeatherCoreResult<LeatherDocumentState> {
    guard let state = states[currentKey] else {
      return .failure("missing scripted state: \(currentKey)")
    }
    return .success(
      state
        .withHistory(canUndo: !undoStack.isEmpty, canRedo: !redoStack.isEmpty)
        .withPersistence(isDirty: currentKey != cleanKey, revision: currentKey)
    )
  }
}

extension LeatherDocumentState {
  func withHistory(canUndo: Bool, canRedo: Bool) -> LeatherDocumentState {
    var state = LeatherDocumentState(
      snapshot: snapshot,
      history: LeatherHistoryState(canUndo: canUndo, canRedo: canRedo),
      layers: layers,
      sharedStyles: sharedStyles,
      parameters: parameters,
      entities: entities,
      derivedElements: derivedElements,
      freeTexts: freeTexts,
      roundHoles: roundHoles,
      stitchStartPoints: stitchStartPoints,
      warnings: warnings,
      coincidentPointGroups: coincidentPointGroups,
      constraints: constraints,
      measurementAnnotations: measurementAnnotations,
      measurementEvaluations: measurementEvaluations,
      dimensionConstraintAnnotations: dimensionConstraintAnnotations
    )
    state.parts = parts
    state.persistence = persistence
    state.mutation = mutation
    return state
  }

  func withPersistence(isDirty: Bool, revision: String) -> LeatherDocumentState {
    var state = self
    state.persistence = LeatherPersistenceState(isDirty: isDirty, revision: revision)
    return state
  }
}
