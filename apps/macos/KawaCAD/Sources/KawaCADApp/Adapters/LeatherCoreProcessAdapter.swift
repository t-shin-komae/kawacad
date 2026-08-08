import Foundation
import KawaCADOutput

struct CoreFailure: Error, Decodable, Equatable, ExpressibleByStringLiteral, CustomStringConvertible
{
  let code: String
  let message: String
  let details: CoreJSONValue?

  init(code: String, message: String, details: CoreJSONValue? = nil) {
    self.code = code
    self.message = message
    self.details = details
  }

  init(stringLiteral value: String) {
    self.init(code: "transportError", message: value)
  }

  static func transport(_ message: String) -> CoreFailure {
    CoreFailure(code: "transportError", message: message)
  }

  var localizedDescription: String {
    LeatherCoreProcessAdapter.localizedCoreErrorMessage(self)
  }

  var description: String { localizedDescription }
}

private struct CoreErrorEnvelope: Decodable {
  let error: CoreFailure
}

enum LeatherCoreResult<T> {
  case success(T)
  case failure(CoreFailure)

  static func failure(_ message: String) -> LeatherCoreResult<T> {
    .failure(.transport(message))
  }
}

enum LeatherCoreStatus: Equatable {
  case connected(LeatherCoreVersionInfo)
  case unavailable(String)

  var summary: String {
    switch self {
    case .connected(let info):
      return AppStrings.tr("core.status.connected", info.fileFormatMajor, info.schemaMajor)
    case .unavailable(let reason):
      return AppStrings.tr("core.status.unavailable", reason)
    }
  }
}

private enum LeatherRPCRequest {
  case loadDocument(json: String, viewMode: CanvasViewMode)
  case documentState(viewMode: CanvasViewMode)
  case previewCommand(command: CoreDocumentCommand, viewMode: CanvasViewMode)
  case preflightConstraint(kind: String, targets: [CoreConstraintTarget])
  case layerDeletionImpact(layerID: String)
  case preflightDerivedElement(
    kind: DerivedElementPreflightKind,
    hitEntityID: String?,
    selectedEntityIDs: [String],
    clickPoint: CorePoint?
  )
  case evaluateMeasurement(annotationID: String)
  case exportSelection(selection: CoreSelectionReference)
  case exportPartLibraryItem(partID: String)
  case applyCommand(command: CoreDocumentCommand, viewMode: CanvasViewMode)
  case undo(viewMode: CanvasViewMode)
  case redo(viewMode: CanvasViewMode)
  case writeKawaFile(path: String, markClean: Bool)
  case buildOutputDocumentModel(options: OutputBuildOptions)
  case renderPDF(outputDocumentModelJSON: String)
  case renderPrint(outputDocumentModelJSON: String)

  private struct Envelope: Encodable {
    let kind: String
    let payload: CoreJSONValue
  }

  func encodedData() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(Envelope(kind: kind, payload: payload))
  }

  private var kind: String {
    switch self {
    case .loadDocument: return "loadDocument"
    case .documentState: return "documentState"
    case .previewCommand: return "previewCommand"
    case .preflightConstraint: return "preflightConstraint"
    case .layerDeletionImpact: return "layerDeletionImpact"
    case .preflightDerivedElement: return "preflightDerivedElement"
    case .evaluateMeasurement: return "evaluateMeasurement"
    case .exportSelection: return "exportSelection"
    case .exportPartLibraryItem: return "exportPartLibraryItem"
    case .applyCommand: return "applyCommand"
    case .undo: return "undo"
    case .redo: return "redo"
    case .writeKawaFile: return "writeKawaFile"
    case .buildOutputDocumentModel: return "buildOutputDocumentModel"
    case .renderPDF: return "renderPdf"
    case .renderPrint: return "renderPrint"
    }
  }

  private var payload: CoreJSONValue {
    switch self {
    case .loadDocument(let json, let viewMode):
      return .object(["json": .string(json), "viewMode": .string(viewMode.rawValue)])
    case .documentState(let viewMode):
      return .object(["viewMode": .string(viewMode.rawValue)])
    case .previewCommand(let command, let viewMode):
      return .object([
        "command": command.jsonValue,
        "viewMode": .string(viewMode.rawValue),
      ])
    case .preflightConstraint(let kind, let targets):
      return .object([
        "kind": .string(kind),
        "targets": .array(targets.map(\.jsonValue)),
      ])
    case .layerDeletionImpact(let layerID):
      return .object(["layerId": .string(layerID)])
    case .preflightDerivedElement(let kind, let hitEntityID, let selectedEntityIDs, let clickPoint):
      var object: [String: CoreJSONValue] = [
        "kind": .string(kind.rawValue),
        "selectedEntityIds": .array(selectedEntityIDs.map(CoreJSONValue.string)),
      ]
      object["hitEntityId"] = hitEntityID.map(CoreJSONValue.string) ?? .null
      object["clickPoint"] = clickPoint?.jsonValue ?? .null
      return .object(object)
    case .evaluateMeasurement(let annotationID):
      return .object(["annotationId": .string(annotationID)])
    case .exportSelection(let selection):
      return .object(["selection": selection.jsonValue])
    case .exportPartLibraryItem(let partID):
      return .object(["partId": .string(partID)])
    case .applyCommand(let command, let viewMode):
      return .object([
        "command": command.jsonValue,
        "viewMode": .string(viewMode.rawValue),
      ])
    case .undo(let viewMode), .redo(let viewMode):
      return .object(["viewMode": .string(viewMode.rawValue)])
    case .writeKawaFile(let path, let markClean):
      return .object(["path": .string(path), "markClean": .bool(markClean)])
    case .buildOutputDocumentModel(let options):
      return .object([
        "orientation": .string(options.orientation.rawValue),
        "includeDimensionLabels": .bool(options.includeDimensionLabels),
        "includeScaleGuide": .bool(options.includeScaleGuide),
        "rotationDeg": .number(Double(options.rotationDeg)),
        "printableAreaMm": try! CoreJSONValue(any: options.printableAreaMm.jsonObject),
      ])
    case .renderPDF(let outputDocumentModelJSON), .renderPrint(let outputDocumentModelJSON):
      return .object(["outputDocumentModelJson": .string(outputDocumentModelJSON)])
    }
  }
}

private enum LeatherProcessAdapterError: LocalizedError {
  case processNotFound
  case processStartFailed(String)
  case processClosed(String)

  var errorDescription: String? {
    switch self {
    case .processNotFound:
      return AppStrings.tr("core.error.process_not_found")
    case .processStartFailed(let message):
      return AppStrings.tr("core.error.process_start_failed", message)
    case .processClosed(let message):
      return AppStrings.tr("core.error.process_closed", message)
    }
  }
}

final class LeatherDocumentSession {
  private let process: Process
  private let inputWriter: FileHandle
  private let outputReader: FileHandle
  private let stderrReader: FileHandle
  private let lock = NSLock()

  fileprivate init(process: Process, inputPipe: Pipe, outputPipe: Pipe, stderrPipe: Pipe) {
    self.process = process
    self.inputWriter = inputPipe.fileHandleForWriting
    self.outputReader = outputPipe.fileHandleForReading
    self.stderrReader = stderrPipe.fileHandleForReading
  }

  deinit {
    try? inputWriter.close()
    if process.isRunning {
      process.terminate()
    }
  }

  func loadState(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    switch call(.documentState(viewMode: viewMode)) {
    case .success(let json):
      do {
        return .success(try LeatherCoreProcessAdapter.decodeDocumentState(json: json))
      } catch {
        return .failure(error.localizedDescription)
      }
    case .failure(let message):
      return .failure(message)
    }
  }

  func previewCommand(_ payload: CoreDocumentCommand, viewMode: CanvasViewMode)
    -> LeatherCoreResult<LeatherDocumentState>
  {
    switch call(.previewCommand(command: payload, viewMode: viewMode)) {
    case .success(let json):
      do {
        return .success(try LeatherCoreProcessAdapter.decodeDocumentState(json: json))
      } catch {
        return .failure(error.localizedDescription)
      }
    case .failure(let message):
      return .failure(message)
    }
  }

  func preflightConstraint(kind: String, targets: [CoreConstraintTarget]) -> LeatherCoreResult<
    ConstraintPreflightResult
  > {
    switch call(.preflightConstraint(kind: kind, targets: targets)) {
    case .success(let json):
      do {
        return .success(try LeatherCoreProcessAdapter.decodeConstraintPreflightResult(json: json))
      } catch {
        return .failure(error.localizedDescription)
      }
    case .failure(let message):
      return .failure(message)
    }
  }

  func layerDeletionImpact(layerID: String) -> LeatherCoreResult<LayerDeletionImpact> {
    switch call(.layerDeletionImpact(layerID: layerID)) {
    case .success(let json):
      guard let data = json.data(using: .utf8),
        let result = try? JSONDecoder().decode(LayerDeletionImpact.self, from: data)
      else { return .failure("invalid layer deletion impact") }
      return .success(result)
    case .failure(let error): return .failure(error)
    }
  }

  func preflightDerivedElement(
    kind: DerivedElementPreflightKind,
    hitEntityID: String?,
    selectedEntityIDs: [String],
    clickPoint: ModelPoint?
  ) -> LeatherCoreResult<DerivedElementPreflightResult> {
    switch call(
      .preflightDerivedElement(
        kind: kind,
        hitEntityID: hitEntityID,
        selectedEntityIDs: selectedEntityIDs,
        clickPoint: clickPoint.map { CorePoint(xMm: $0.xMM, yMm: $0.yMM) }
      ))
    {
    case .success(let json):
      do {
        return .success(
          try JSONDecoder().decode(
            DerivedElementPreflightResult.self,
            from: Data(json.utf8)
          ))
      } catch {
        return .failure(error.localizedDescription)
      }
    case .failure(let failure):
      return .failure(failure)
    }
  }

  func evaluateMeasurement(annotationID: String) -> LeatherCoreResult<MeasurementEvaluation> {
    switch call(.evaluateMeasurement(annotationID: annotationID)) {
    case .success(let json):
      do {
        return .success(try JSONDecoder().decode(MeasurementEvaluation.self, from: Data(json.utf8)))
      } catch {
        return .failure(error.localizedDescription)
      }
    case .failure(let failure):
      return .failure(failure)
    }
  }

  func exportSelection(_ selection: CoreSelectionReference) -> LeatherCoreResult<
    SelectionClipboardExport
  > {
    switch call(.exportSelection(selection: selection)) {
    case .success(let json):
      do {
        return .success(
          try JSONDecoder().decode(SelectionClipboardExport.self, from: Data(json.utf8)))
      } catch {
        return .failure(error.localizedDescription)
      }
    case .failure(let failure):
      return .failure(failure)
    }
  }

  func exportPartLibraryItem(partID: String) -> LeatherCoreResult<PartLibraryExport> {
    switch call(.exportPartLibraryItem(partID: partID)) {
    case .success(let json):
      do {
        return .success(try JSONDecoder().decode(PartLibraryExport.self, from: Data(json.utf8)))
      } catch {
        return .failure(error.localizedDescription)
      }
    case .failure(let failure):
      return .failure(failure)
    }
  }

  func applyCommand(_ payload: CoreDocumentCommand, viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  > {
    switch call(.applyCommand(command: payload, viewMode: viewMode)) {
    case .success(let json):
      do {
        return .success(try LeatherCoreProcessAdapter.decodeDocumentState(json: json))
      } catch {
        return .failure(error.localizedDescription)
      }
    case .failure(let message):
      return .failure(message)
    }
  }

  func loadDocument(json documentJSON: String, viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  > {
    switch call(.loadDocument(json: documentJSON, viewMode: viewMode)) {
    case .success(let json):
      do {
        return .success(try LeatherCoreProcessAdapter.decodeDocumentState(json: json))
      } catch {
        return .failure(error.localizedDescription)
      }
    case .failure(let message):
      return .failure(message)
    }
  }

  func undo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    switch call(.undo(viewMode: viewMode)) {
    case .success(let json):
      do {
        return .success(try LeatherCoreProcessAdapter.decodeDocumentState(json: json))
      } catch {
        return .failure(error.localizedDescription)
      }
    case .failure(let message):
      return .failure(message)
    }
  }

  func redo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    switch call(.redo(viewMode: viewMode)) {
    case .success(let json):
      do {
        return .success(try LeatherCoreProcessAdapter.decodeDocumentState(json: json))
      } catch {
        return .failure(error.localizedDescription)
      }
    case .failure(let message):
      return .failure(message)
    }
  }

  func writeJSONFile(to url: URL) -> LeatherCoreResult<Void> {
    writeJSONFile(to: url, markClean: true)
  }

  func writeSnapshotFile(to url: URL) -> LeatherCoreResult<Void> {
    writeJSONFile(to: url, markClean: false)
  }

  private func writeJSONFile(to url: URL, markClean: Bool) -> LeatherCoreResult<Void> {
    switch call(.writeKawaFile(path: url.path, markClean: markClean)) {
    case .success(let json):
      guard let data = json.data(using: .utf8),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        object["written"] as? Bool == true
      else {
        return .failure("write json response was invalid")
      }
      return .success(())
    case .failure(let message):
      return .failure(message)
    }
  }

  func buildOutputDocumentModel(options: OutputBuildOptions) -> OutputResult<OutputBuildResult> {
    switch callOutput(.buildOutputDocumentModel(options: options)) {
    case .success(let json):
      do {
        return .success(try LeatherCoreProcessAdapter.decodeOutputBuildResult(json: json))
      } catch let error as OutputError {
        return .failure(error)
      } catch {
        return .failure(OutputError(error.localizedDescription))
      }
    case .failure(let error):
      return .failure(error)
    }
  }

  func renderPDF(outputDocumentModel: OutputDocumentModel) -> OutputResult<Data> {
    let outputDocumentModelJSON: String
    do {
      outputDocumentModelJSON = try LeatherCoreProcessAdapter.encodeOutputDocumentModelJSON(
        outputDocumentModel)
    } catch let error as OutputError {
      return .failure(error)
    } catch {
      return .failure(OutputError(error.localizedDescription))
    }

    switch callOutput(.renderPDF(outputDocumentModelJSON: outputDocumentModelJSON)) {
    case .success(let json):
      do {
        return .success(try LeatherCoreProcessAdapter.decodePDFData(json: json))
      } catch {
        return .failure(OutputError(error.localizedDescription))
      }
    case .failure(let error):
      return .failure(error)
    }
  }

  func renderPrint(outputDocumentModel: OutputDocumentModel) -> OutputResult<OutputPrintRenderData>
  {
    let outputDocumentModelJSON: String
    do {
      outputDocumentModelJSON = try LeatherCoreProcessAdapter.encodeOutputDocumentModelJSON(
        outputDocumentModel)
    } catch let error as OutputError {
      return .failure(error)
    } catch {
      return .failure(OutputError(error.localizedDescription))
    }

    switch callOutput(.renderPrint(outputDocumentModelJSON: outputDocumentModelJSON)) {
    case .success(let json):
      do {
        return .success(try LeatherCoreProcessAdapter.decodePrintRenderData(json: json))
      } catch let error as OutputError {
        return .failure(error)
      } catch {
        return .failure(OutputError(error.localizedDescription))
      }
    case .failure(let error):
      return .failure(error)
    }
  }

  private func call(_ request: LeatherRPCRequest) -> LeatherCoreResult<String> {
    lock.lock()
    defer { lock.unlock() }

    do {
      let data = try request.encodedData()
      guard let requestJSONString = String(data: data, encoding: .utf8) else {
        return .failure("rpc request json encoding failed")
      }
      guard process.isRunning else {
        return .failure(terminatedProcessMessage())
      }
      guard var requestData = requestJSONString.data(using: .utf8) else {
        return .failure("rpc request json encoding failed")
      }
      requestData.append(0x0A)
      try inputWriter.write(contentsOf: requestData)
      let response = try readResponseLine()
      if let failure = LeatherCoreProcessAdapter.decodeCoreFailure(json: response) {
        return .failure(failure)
      }
      return .success(response)
    } catch {
      return .failure("rpc request serialization failed: \(error.localizedDescription)")
    }
  }

  private func callOutput(_ request: LeatherRPCRequest) -> OutputResult<String> {
    switch call(request) {
    case .success(let json):
      return .success(json)
    case .failure(let message):
      return .failure(OutputError(message.localizedDescription))
    }
  }

  private func readResponseLine() throws -> String {
    while true {
      var data = Data()
      while true {
        let chunk = try outputReader.read(upToCount: 1) ?? Data()
        guard !chunk.isEmpty else {
          throw LeatherProcessAdapterError.processClosed(terminatedProcessMessage())
        }
        if chunk[chunk.startIndex] == 0x0A {
          break
        }
        data.append(chunk)
      }
      guard let response = String(data: data, encoding: .utf8) else {
        throw LeatherProcessAdapterError.processClosed(
          AppStrings.tr("core.error.response_not_utf8"))
      }
      let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty {
        continue
      }
      return trimmed
    }
  }

  private func terminatedProcessMessage() -> String {
    let stderr = stderrReader.readDataToEndOfFile()
    let stderrText = String(data: stderr, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if let stderrText, !stderrText.isEmpty {
      return stderrText
    }
    return "exit status \(process.terminationStatus)"
  }
}

enum LeatherCoreProcessAdapter {
  private static let processURLResult: LeatherCoreResult<URL> = {
    let fileManager = FileManager.default
    let environmentPath = ProcessInfo.processInfo.environment["KAWACAD_CORE_PROCESS"]

    var candidates: [String] = []

    // 1. Environment variable (highest priority)
    if let envPath = environmentPath {
      candidates.append(envPath)
    }

    // 2. App bundle paths (when running from packaged .app)
    if let executableURL = Bundle.main.executableURL?.deletingLastPathComponent() {
      candidates.append(executableURL.appendingPathComponent("kawacad-core-process").path)
    }
    let bundleURL = Bundle.main.bundleURL
    candidates.append(bundleURL.appendingPathComponent("Contents/MacOS/kawacad-core-process").path)
    candidates.append(bundleURL.appendingPathComponent("MacOS/kawacad-core-process").path)

    // 3. Development build paths (prefer debug binaries and walk parent dirs)
    let workingDirectory = fileManager.currentDirectoryPath
    let workingDirURL = URL(fileURLWithPath: workingDirectory)
    var searchBaseURLs: [URL] = [workingDirURL]
    var parentURL = workingDirURL
    for _ in 0..<4 {
      parentURL.deleteLastPathComponent()
      searchBaseURLs.append(parentURL)
    }
    for baseURL in searchBaseURLs {
      candidates.append(baseURL.appendingPathComponent("target/debug/kawacad-core-process").path)
      candidates.append(baseURL.appendingPathComponent("target/release/kawacad-core-process").path)
    }

    guard let processPath = candidates.first(where: fileManager.fileExists(atPath:)) else {
      return .failure(LeatherProcessAdapterError.processNotFound.localizedDescription)
    }
    return .success(URL(fileURLWithPath: processPath))
  }()

  static func loadVersionInfo() -> LeatherCoreStatus {
    switch runOneShot(arguments: ["--version-json"]) {
    case .success(let json):
      guard let data = json.data(using: .utf8),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let fileFormatVersion = object["fileFormatVersion"] as? String,
        let schemaVersion = object["schemaVersion"] as? String
      else {
        return .unavailable(AppStrings.tr("core.error.invalid_version_response"))
      }
      return .connected(
        LeatherCoreVersionInfo(
          fileFormatMajor: majorVersion(from: fileFormatVersion),
          schemaMajor: majorVersion(from: schemaVersion)
        )
      )
    case .failure(let message):
      return .unavailable(message.localizedDescription)
    }
  }

  static func createDocument(named name: String) -> LeatherCoreResult<LeatherDocumentSession> {
    startSession(arguments: ["--new", name])
  }

  static func createDocument(fromJSON json: String) -> LeatherCoreResult<LeatherDocumentSession> {
    switch startSession(arguments: ["--new", "Loaded Document"]) {
    case .success(let session):
      switch session.loadDocument(json: json, viewMode: .editDisplay) {
      case .success:
        return .success(session)
      case .failure(let message):
        return .failure(message)
      }
    case .failure(let message):
      return .failure(message)
    }
  }

  static func readDocument(from url: URL) -> LeatherCoreResult<LeatherDocumentSession> {
    startSession(arguments: ["--read-kawa-file", url.path])
  }

  private static func startSession(arguments: [String]) -> LeatherCoreResult<LeatherDocumentSession>
  {
    switch processURLResult {
    case .failure(let message):
      return .failure(message)
    case .success(let processURL):
      let process = Process()
      let inputPipe = Pipe()
      let outputPipe = Pipe()
      let stderrPipe = Pipe()
      process.executableURL = processURL
      process.arguments = arguments
      process.standardInput = inputPipe
      process.standardOutput = outputPipe
      process.standardError = stderrPipe
      do {
        try process.run()
        return .success(
          LeatherDocumentSession(
            process: process,
            inputPipe: inputPipe,
            outputPipe: outputPipe,
            stderrPipe: stderrPipe
          )
        )
      } catch {
        return .failure(
          LeatherProcessAdapterError.processStartFailed(error.localizedDescription)
            .localizedDescription)
      }
    }
  }

  private static func runOneShot(arguments: [String]) -> LeatherCoreResult<String> {
    switch processURLResult {
    case .failure(let message):
      return .failure(message)
    case .success(let processURL):
      let process = Process()
      let outputPipe = Pipe()
      let stderrPipe = Pipe()
      process.executableURL = processURL
      process.arguments = arguments
      process.standardOutput = outputPipe
      process.standardError = stderrPipe
      do {
        try process.run()
        process.waitUntilExit()
        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
          let message = String(data: stderr, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
          return .failure(
            message?.isEmpty == false ? message! : AppStrings.tr("core.error.process_failed"))
        }
        let result = (String(data: output, encoding: .utf8) ?? "")
          .trimmingCharacters(in: .whitespacesAndNewlines)
        return .success(result)
      } catch {
        return .failure(
          LeatherProcessAdapterError.processStartFailed(error.localizedDescription)
            .localizedDescription)
      }
    }
  }

  static func decodeCoreFailure(json: String) -> CoreFailure? {
    guard let data = json.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(CoreErrorEnvelope.self, from: data).error
  }

  static func decodeErrorMessage(json: String) -> String? {
    decodeCoreFailure(json: json)?.localizedDescription
  }

  static func localizedCoreErrorMessage(_ error: CoreFailure) -> String {
    let details = error.details?.objectValue ?? [:]
    switch error.code {
    case "constraintInsufficientTargets":
      let constraintKind = localizedConstraintKind(details["constraintKind"]?.stringValue)
      let actual = details["actualTargetCount"]?.intValue
      let required = details["requiredTargetCount"]?.intValue
      let expectedKinds = localizedExpectedTargetKinds(
        details["expectedTargetKinds"]?.stringArrayValue)
      if let actual, let required, !expectedKinds.isEmpty {
        return AppStrings.tr(
          "core.error.constraint_insufficient_targets", constraintKind, required, actual,
          expectedKinds)
      }
      return AppStrings.tr("core.error.constraint_targets_missing", constraintKind)
    case "invalidConstraintTarget":
      let constraintKind = localizedConstraintKind(details["constraintKind"]?.stringValue)
      let expectedKinds = localizedExpectedTargetKinds(
        details["expectedTargetKinds"]?.stringArrayValue)
      if expectedKinds.isEmpty {
        return AppStrings.tr("core.error.invalid_constraint_target", constraintKind)
      }
      return AppStrings.tr("core.error.constraint_expected_targets", constraintKind, expectedKinds)
    case "duplicateConstraint":
      let constraintKind = localizedConstraintKind(details["constraintKind"]?.stringValue)
      return AppStrings.tr("core.error.duplicate_constraint", constraintKind)
    case "conflictingConstraint":
      let constraintKind = localizedConstraintKind(details["constraintKind"]?.stringValue)
      return AppStrings.tr(
        "core.error.conflicting_constraint", constraintKind, constraintFailureAction(details))
    case "brokenReference":
      return AppStrings.tr("core.error.broken_reference")
    case "invalidValue":
      return AppStrings.tr("core.error.invalid_value")
    case "renderEmptyPages":
      return AppStrings.tr("core.error.render_empty_pages")
    case "renderInvalidPageSize":
      return AppStrings.tr("core.error.render_invalid_page_size")
    case "renderPageCountMismatch":
      return AppStrings.tr("core.error.render_page_count_mismatch")
    case "renderUnsupportedRotation":
      return AppStrings.tr("core.error.render_unsupported_rotation")
    case "outputOutOfGridBounds":
      return AppStrings.tr("core.error.output_out_of_grid_bounds")
    default:
      return error.message.isEmpty
        ? AppStrings.tr("core.error.process_returned_error")
        : error.message
    }
  }

  private static func localizedExpectedTargetKinds(_ values: [String]?) -> String {
    guard let values, !values.isEmpty else {
      return ""
    }
    return values.map(localizedTargetKind).joined(
      separator: AppStrings.tr("core.target_kind.separator"))
  }

  private static func localizedConstraintKind(_ value: String?) -> String {
    guard let value else {
      return AppStrings.tr("core.constraint_fallback")
    }
    return constraintDisplayName(from: value)
  }

  private static func constraintFailureAction(_ details: [String: CoreJSONValue]) -> String {
    switch details["commandKind"]?.stringValue {
    case "updateConstraint":
      return AppStrings.tr("core.constraint_action_update_failed")
    default:
      return AppStrings.tr("core.constraint_action_add_failed")
    }
  }

  private static func localizedTargetKind(_ value: String) -> String {
    switch value {
    case "point": return AppStrings.tr("core.target_kind.point")
    case "line": return AppStrings.tr("core.target_kind.line")
    case "circle": return AppStrings.tr("core.target_kind.circle")
    case "arc": return AppStrings.tr("core.target_kind.arc")
    case "centerLine": return AppStrings.tr("core.target_kind.center_line")
    case "entity": return AppStrings.tr("core.target_kind.entity")
    case "controlPoint": return AppStrings.tr("core.target_kind.control_point")
    default: return value
    }
  }

  private static func majorVersion(from version: String) -> UInt32 {
    let major = version.split(separator: ".").first.map(String.init) ?? "0"
    return UInt32(major) ?? 0
  }

  fileprivate static func encodeOutputDocumentModelJSON(_ model: OutputDocumentModel) throws
    -> String
  {
    let encoder = JSONEncoder()
    let data = try encoder.encode(model)
    guard let json = String(data: data, encoding: .utf8) else {
      throw OutputError(AppStrings.tr("core.error.output_model_encode_failed"))
    }
    return json
  }

  static func decodeOutputBuildResult(json: String) throws -> OutputBuildResult {
    try decodeOutputPayload(json: json, context: "output document model response")
  }

  fileprivate static func decodePrintRenderData(json: String) throws -> OutputPrintRenderData {
    try decodeOutputPayload(json: json, context: "print render data")
  }

  fileprivate static func decodePDFData(json: String) throws -> Data {
    guard let data = json.data(using: .utf8),
      let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let pdfHex = object["pdfHex"] as? String
    else {
      throw BridgeError.invalidJSON("pdf response")
    }
    guard let pdfData = Data(hexEncoded: pdfHex) else {
      throw BridgeError.invalidJSON("pdf hex payload")
    }
    return pdfData
  }

  private static func decodeOutputPayload<T: Decodable>(json: String, context: String) throws -> T {
    guard let data = json.data(using: .utf8) else {
      throw OutputError(AppStrings.tr("core.error.output_decode_failed", context))
    }
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw OutputError(
        AppStrings.tr(
          "core.error.output_decode_failed_with_reason", context, error.localizedDescription))
    }
  }

  static func decodeDocumentState(json: String) throws -> LeatherDocumentState {
    guard let data = json.data(using: .utf8),
      let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let snapshotObject = object["snapshot"] as? [String: Any],
      let statisticsObject = snapshotObject["statistics"] as? [String: Any],
      let editDisplaySummaryObject = snapshotObject["editDisplaySummary"] as? [String: Any],
      let outputPreviewSummaryObject = snapshotObject["outputPreviewSummary"] as? [String: Any],
      let historyObject = object["history"] as? [String: Any],
      let layersObject = object["layers"] as? [[String: Any]],
      let parametersObject = object["parameters"] as? [[String: Any]],
      let entitiesObject = object["entities"] as? [[String: Any]],
      let derivedElementsObject = object["derivedElements"] as? [[String: Any]],
      let constraintsObject = object["constraints"] as? [[String: Any]]
    else {
      throw BridgeError.invalidJSON("document state")
    }
    let entityConstraintStatusObjects = object["entityConstraintStatuses"] as? [[String: Any]] ?? []
    let measurementAnnotationsObject = object["measurementAnnotations"] as? [[String: Any]] ?? []
    let measurementEvaluationsObject = object["measurementEvaluations"] as? [[String: Any]] ?? []
    let dimensionConstraintAnnotationsObject =
      object["dimensionConstraintAnnotations"] as? [[String: Any]] ?? []
    let freeTextObjects = object["freeTexts"] as? [[String: Any]] ?? []
    let partObjects = object["parts"] as? [[String: Any]] ?? []
    let roundHoleObjects = object["roundHoles"] as? [[String: Any]] ?? []
    let stitchStartPointObjects = object["stitchStartPoints"] as? [[String: Any]] ?? []
    let sharedStyleObjects = object["sharedStyles"] as? [[String: Any]] ?? []
    let entityConstraintStatuses = try decodeEntityConstraintStatuses(
      objects: entityConstraintStatusObjects)
    let entityStatusByID = Dictionary(
      uniqueKeysWithValues: entityConstraintStatuses.map { ($0.entityID, $0) })
    let derivedElements = try decodeDerivedElements(objects: derivedElementsObject)
    let layers = try decodeLayers(objects: layersObject)
    let entities = try decodeEntities(objects: entitiesObject).map { entity in
      guard let status = entityStatusByID[entity.id] else {
        return entity
      }
      return entity.withConstraintStatus(status.status, remainingDof: status.remainingDof)
    }

    let snapshot = LeatherDocumentSnapshot(
      name: snapshotObject["name"] as? String ?? "",
      statistics: try decodeStatistics(statisticsObject),
      editDisplaySummary: try decodeSnapshotSummary(editDisplaySummaryObject),
      outputPreviewSummary: try decodeSnapshotSummary(outputPreviewSummaryObject)
    )

    var state = LeatherDocumentState(
      snapshot: snapshot,
      history: try decodeHistoryState(historyObject),
      layers: layers,
      sharedStyles: try decodeSharedStyles(objects: sharedStyleObjects),
      parameters: try decodeParameters(objects: parametersObject),
      entities: entities,
      derivedElements: derivedElements,
      freeTexts: try decodeFreeTexts(objects: freeTextObjects),
      roundHoles: try decodeRoundHoles(objects: roundHoleObjects),
      stitchStartPoints: try decodeStitchStartPoints(objects: stitchStartPointObjects),
      warnings: decodeWarnings(objects: object["warnings"] as? [[String: Any]] ?? []),
      coincidentPointGroups: try decodeCoincidentPointGroups(
        objects: object["coincidentPointGroups"] as? [[String: Any]] ?? []
      ),
      constraints: try decodeConstraints(objects: constraintsObject),
      measurementAnnotations: try decodeMeasurementAnnotations(
        objects: measurementAnnotationsObject),
      measurementEvaluations: try decodeMeasurementEvaluations(
        objects: measurementEvaluationsObject),
      dimensionConstraintAnnotations: try decodeDimensionConstraintAnnotations(
        objects: dimensionConstraintAnnotationsObject
      )
    )
    if let canvasProjection = object["canvasProjection"] {
      let projectionData = try JSONSerialization.data(withJSONObject: canvasProjection)
      state.canvasProjection = try JSONDecoder().decode(
        LeatherCanvasProjection.self,
        from: projectionData
      )
    }
    state.parts = try decodeParts(objects: partObjects)
    if let persistence = object["persistence"] as? [String: Any] {
      state.persistence = LeatherPersistenceState(
        isDirty: persistence["isDirty"] as? Bool ?? false,
        revision: persistence["revision"] as? String ?? ""
      )
    }
    if let mutation = object["mutation"] as? [String: Any] {
      let mutationData = try JSONSerialization.data(withJSONObject: mutation)
      state.mutation = try JSONDecoder().decode(LeatherMutationResult.self, from: mutationData)
    }
    return state
  }

  private static func decodeParts(objects: [[String: Any]]) throws -> [ProjectPart] {
    let data = try JSONSerialization.data(withJSONObject: objects)
    return try JSONDecoder().decode([ProjectPart].self, from: data)
  }

  private static func decodeMeasurementEvaluations(
    objects: [[String: Any]]
  ) throws -> [MeasurementEvaluation] {
    let data = try JSONSerialization.data(withJSONObject: objects)
    return try JSONDecoder().decode([MeasurementEvaluation].self, from: data)
  }

  static func decodeConstraintPreflightResult(json: String) throws -> ConstraintPreflightResult {
    guard let data = json.data(using: .utf8) else {
      throw BridgeError.invalidJSON("constraint preflight")
    }
    return try JSONDecoder().decode(ConstraintPreflightResult.self, from: data)
  }

  private static func decodeHistoryState(_ object: [String: Any]) throws -> LeatherHistoryState {
    guard let canUndo = object["canUndo"] as? Bool,
      let canRedo = object["canRedo"] as? Bool
    else {
      throw BridgeError.invalidJSON("history state")
    }
    return LeatherHistoryState(canUndo: canUndo, canRedo: canRedo)
  }

  private static func decodeStatistics(_ object: [String: Any]) throws -> LeatherDocumentStatistics
  {
    guard let layerCount = object["layerCount"] as? Int,
      let parameterCount = object["parameterCount"] as? Int,
      let entityCount = object["entityCount"] as? Int,
      let derivedElementCount = object["derivedElementCount"] as? Int,
      let constraintCount = object["constraintCount"] as? Int
    else {
      throw BridgeError.invalidJSON("document statistics")
    }
    return LeatherDocumentStatistics(
      layerCount: layerCount,
      sharedStyleCount: object["sharedStyleCount"] as? Int ?? 0,
      parameterCount: parameterCount,
      partCount: object["partCount"] as? Int ?? 0,
      entityCount: entityCount,
      derivedElementCount: derivedElementCount,
      constraintCount: constraintCount
    )
  }

  private static func decodeSnapshotSummary(_ object: [String: Any]) throws
    -> LeatherSnapshotSummary
  {
    guard let visibleEntityCount = object["visibleEntityCount"] as? Int,
      let constraintCount = object["constraintCount"] as? Int,
      let constraintStatusValue = object["constraintStatus"] as? String
    else {
      throw BridgeError.invalidJSON("snapshot summary")
    }
    return LeatherSnapshotSummary(
      visibleEntityCount: visibleEntityCount,
      constraintCount: constraintCount,
      constraintStatus: constraintStatus(from: constraintStatusValue)
    )
  }

  fileprivate static func decodeLayers(json: String) throws -> [ProjectLayer] {
    guard let data = json.data(using: .utf8),
      let objects = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else {
      throw BridgeError.invalidJSON("layer list")
    }
    return try decodeLayers(objects: objects)
  }

  private static func decodeLayers(objects: [[String: Any]]) throws -> [ProjectLayer] {
    try objects.map { object in
      guard let id = object["id"] as? String,
        let name = object["name"] as? String,
        let kindValue = object["kind"] as? String,
        let visible = object["visible"] as? Bool,
        let printable = object["printable"] as? Bool,
        let style = object["style"] as? [String: Any],
        let stroke = style["stroke"] as? [String: Any],
        let strokeWidthMM = style["strokeWidthMm"] as? Double,
        let pattern = style["pattern"] as? String
      else {
        throw BridgeError.invalidJSON("layer")
      }

      return ProjectLayer(
        id: id,
        name: name,
        kind: layerKind(from: kindValue),
        visible: visible,
        printable: printable,
        colorHex: hexColor(from: stroke),
        strokeWidthMM: strokeWidthMM,
        linePattern: linePattern(from: pattern)
      )
    }
  }

  private static func decodeSharedStyles(objects: [[String: Any]]) throws -> [ProjectSharedStyle] {
    try objects.map { object in
      guard let id = object["id"] as? String,
        let name = object["name"] as? String,
        let style = object["style"] as? [String: Any],
        let stroke = style["stroke"] as? [String: Any],
        let strokeWidthMM = style["strokeWidthMm"] as? Double,
        let pattern = style["pattern"] as? String
      else {
        throw BridgeError.invalidJSON("shared style")
      }

      return ProjectSharedStyle(
        id: id,
        name: name,
        colorHex: hexColor(from: stroke),
        strokeWidthMM: strokeWidthMM,
        linePattern: linePattern(from: pattern)
      )
    }
  }

  private static func linePattern(from value: String) -> LinePattern {
    LinePattern(rawValue: value) ?? .solid
  }

  fileprivate static func decodeParameters(json: String) throws -> [ProjectParameter] {
    guard let data = json.data(using: .utf8),
      let objects = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else {
      throw BridgeError.invalidJSON("parameter list")
    }
    return try decodeParameters(objects: objects)
  }

  private static func decodeParameters(objects: [[String: Any]]) throws -> [ProjectParameter] {
    try objects.map { object in
      guard let id = object["id"] as? String,
        let name = object["name"] as? String,
        let valueMM = object["valueMm"] as? Double,
        let unit = object["unit"] as? String
      else {
        throw BridgeError.invalidJSON("parameter")
      }

      return ProjectParameter(
        id: id,
        name: name,
        valueMM: valueMM,
        unit: unit,
        memo: object["memo"] as? String ?? "",
        usageCount: object["usageCount"] as? Int ?? 0,
        usedConstraintIDs: object["usedConstraintIds"] as? [String] ?? []
      )
    }
  }

  fileprivate static func decodeEntities(json: String) throws -> [CanvasEntity] {
    guard let data = json.data(using: .utf8),
      let objects = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else {
      throw BridgeError.invalidJSON("entity list")
    }
    return try decodeEntities(objects: objects)
  }

  private static func decodeEntities(objects: [[String: Any]]) throws -> [CanvasEntity] {
    try objects.map { object in
      guard let id = object["id"] as? String,
        let kindObject = object["kind"] as? [String: Any]
      else {
        throw BridgeError.invalidJSON("entity")
      }
      let layerID = object["layerId"] as? String
      let styleID = object["styleId"] as? String
      return decodeEntity(id: id, layerID: layerID, styleID: styleID, kindObject: kindObject)
        .withCoreMetadata(
          derivedElementID: object["derivedElementId"] as? String,
          derivedResolvedIndex: object["resolvedIndex"] as? Int,
          sourceEntityID: object["sourceEntityId"] as? String,
          isSuppressedByFillet: object["suppressedByFillet"] as? Bool ?? false
        )
    }
  }

  private static func decodeDerivedElements(objects: [[String: Any]]) throws
    -> [ProjectDerivedElement]
  {
    try objects.map { object in
      guard let id = object["id"] as? String,
        let kind = object["kind"] as? [String: Any]
      else {
        throw BridgeError.invalidJSON("derived element")
      }
      if let offset = kind["offsetCurve"] as? [String: Any],
        let sourceEntityIDs = offset["sourceEntityIds"] as? [String],
        let directionValue = offset["direction"] as? String,
        let direction = OffsetDirection(rawValue: directionValue)
      {
        return ProjectDerivedElement(
          id: id,
          layerID: object["layerId"] as? String,
          styleID: object["styleId"] as? String,
          kind: .offsetCurve,
          sourceEntityIDs: sourceEntityIDs,
          sourceResolvedEntityIDs: offset["sourceResolvedEntityIds"] as? [String] ?? [],
          distanceMM: fixedMillimeterValue(from: offset["distance"]),
          distanceParameterID: parameterValue(from: offset["distance"]),
          direction: direction
        )
      }
      if let fillet = kind["fillet"] as? [String: Any],
        let sourceEntityIDs = fillet["sourceEntityIds"] as? [String]
      {
        return ProjectDerivedElement(
          id: id,
          layerID: object["layerId"] as? String,
          styleID: object["styleId"] as? String,
          kind: .fillet,
          sourceEntityIDs: sourceEntityIDs,
          distanceMM: nil,
          distanceParameterID: nil,
          radiusMM: fixedMillimeterValue(from: fillet["radius"]),
          radiusParameterID: parameterValue(from: fillet["radius"]),
          filletClosed: fillet["closed"] as? Bool ?? true
        )
      }
      throw BridgeError.invalidJSON("derived element")
    }
  }

  private static func decodeWarnings(objects: [[String: Any]]) -> [String] {
    objects.compactMap { object in
      object["message"] as? String
    }
  }

  private static func decodeRoundHoles(objects: [[String: Any]]) throws -> [ProjectRoundHole] {
    try objects.map { object in
      guard let id = object["id"] as? String,
        let entityID = object["entityId"] as? String,
        let kindValue = object["kind"] as? String,
        let kind = ProjectRoundHoleKind(rawValue: kindValue)
      else {
        throw BridgeError.invalidJSON("round hole")
      }
      return ProjectRoundHole(id: id, entityID: entityID, kind: kind)
    }
  }

  private static func decodeStitchStartPoints(objects: [[String: Any]]) throws
    -> [ProjectStitchStartPoint]
  {
    try objects.map { object in
      guard let id = object["id"] as? String,
        let targetID = object["targetId"] as? String,
        let positionRatio = object["positionRatio"] as? Double
      else {
        throw BridgeError.invalidJSON("stitch start point")
      }
      return ProjectStitchStartPoint(
        id: id,
        targetID: targetID,
        resolvedIndex: object["resolvedIndex"] as? Int,
        positionRatio: positionRatio
      )
    }
  }

  fileprivate static func decodeConstraints(json: String) throws -> [ProjectConstraint] {
    guard let data = json.data(using: .utf8),
      let objects = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else {
      throw BridgeError.invalidJSON("constraint list")
    }
    return try decodeConstraints(objects: objects)
  }

  private static func decodeConstraints(objects: [[String: Any]]) throws -> [ProjectConstraint] {
    try objects.map { object in
      guard let id = object["id"] as? String,
        let kind = object["kind"] as? String,
        let statusValue = object["status"] as? String
      else {
        throw BridgeError.invalidJSON("constraint")
      }

      let targetObjects = object["targets"] as? [[String: Any]] ?? []
      let targets = targetObjects.compactMap { target -> String? in
        if let entityID = target["entity"] as? String {
          return entityID
        }
        if let controlPoint = target["controlPoint"] as? [String: Any],
          let entityID = targetEntityID(from: controlPoint)
        {
          return entityID
        }
        return nil
      }
      let targetsJSON = jsonString(from: targetObjects) ?? "[]"
      let valueMM = fixedMillimeterValue(from: object["value"])
      let valueDegrees = fixedDegreesValue(from: object["value"])
      let valueParameterID = parameterValue(from: object["value"])

      return ProjectConstraint(
        id: id,
        rawKind: kind,
        kind: constraintDisplayName(from: kind),
        targets: targets,
        targetsJSON: targetsJSON,
        valueMM: valueMM,
        valueDegrees: valueDegrees,
        valueParameterID: valueParameterID,
        status: constraintStatus(from: statusValue)
      )
    }
  }

  private static func decodeMeasurementAnnotations(objects: [[String: Any]]) throws
    -> [ProjectMeasurementAnnotation]
  {
    try objects.map { object in
      guard let id = object["id"] as? String,
        let kind = object["kind"] as? String,
        let targetObjects = object["targets"] as? [[String: Any]]
      else {
        throw BridgeError.invalidJSON("measurement annotation")
      }
      let targets = targetObjects.compactMap { target -> String? in
        if let entityID = target["entity"] as? String {
          return entityID
        }
        if let controlPoint = target["controlPoint"] as? [String: Any],
          let entityID = targetEntityID(from: controlPoint)
        {
          return entityID
        }
        return nil
      }
      return ProjectMeasurementAnnotation(
        id: id,
        rawKind: kind,
        kind: measurementAnnotationDisplayName(from: kind),
        targets: targets,
        targetsJSON: jsonString(from: targetObjects) ?? "[]",
        labelOffsetMM: decodeModelPoint(object["labelOffsetMm"] as? [String: Any])
          ?? ModelPoint(xMM: 0, yMM: 0),
        overallOffsetMM: decodeModelPoint(object["overallOffsetMm"] as? [String: Any])
          ?? ModelPoint(xMM: 0, yMM: 0),
        visible: object["visible"] as? Bool ?? true
      )
    }
  }

  private static func decodeFreeTexts(objects: [[String: Any]]) throws -> [ProjectFreeText] {
    try objects.map { object in
      guard let id = object["id"] as? String,
        let content = object["content"] as? String,
        let position = decodeModelPoint(object["positionMm"] as? [String: Any]),
        let fontSizeMM = object["fontSizeMm"] as? Double
      else {
        throw BridgeError.invalidJSON("free text")
      }
      return ProjectFreeText(
        id: id,
        content: content,
        positionMM: position,
        fontSizeMM: fontSizeMM
      )
    }
  }

  private static func decodeDimensionConstraintAnnotations(
    objects: [[String: Any]]
  ) throws -> [ProjectDimensionConstraintAnnotation] {
    try objects.map { object in
      guard let constraintID = object["constraintId"] as? String else {
        throw BridgeError.invalidJSON("dimension constraint annotation")
      }
      return ProjectDimensionConstraintAnnotation(
        constraintID: constraintID,
        labelOffsetMM: decodeModelPoint(object["labelOffsetMm"] as? [String: Any])
          ?? ModelPoint(xMM: 0, yMM: 0),
        overallOffsetMM: decodeModelPoint(object["overallOffsetMm"] as? [String: Any])
          ?? ModelPoint(xMM: 0, yMM: 0),
        visible: object["visible"] as? Bool ?? true
      )
    }
  }

  private struct DecodedEntityConstraintStatus {
    let entityID: String
    let status: ConstraintStatus
    let remainingDof: Int
  }

  private static func decodeEntityConstraintStatuses(objects: [[String: Any]]) throws
    -> [DecodedEntityConstraintStatus]
  {
    try objects.map { object in
      guard let entityID = object["entityId"] as? String,
        let statusValue = object["status"] as? String,
        let remainingDof = object["remainingDof"] as? Int
      else {
        throw BridgeError.invalidJSON("entity constraint status")
      }
      return DecodedEntityConstraintStatus(
        entityID: entityID,
        status: constraintStatus(from: statusValue),
        remainingDof: remainingDof
      )
    }
  }

  private static func decodeCoincidentPointGroups(objects: [[String: Any]]) throws
    -> [CoincidentPointGroup]
  {
    try objects.map { object in
      guard let id = object["id"] as? String,
        let representative = modelPoint(from: object["representative"]),
        let targetObjects = object["targets"] as? [[String: Any]]
      else {
        throw BridgeError.invalidJSON("coincident point group")
      }
      return CoincidentPointGroup(
        id: id,
        representative: representative,
        targetsJSON: jsonString(from: targetObjects) ?? "[]"
      )
    }
  }

  private static func targetEntityID(from object: [String: Any]) -> String? {
    object["entity_id"] as? String
  }

  private static func decodeEntity(
    id: String, layerID: String?, styleID: String?, kindObject: [String: Any]
  ) -> CanvasEntity {
    if let payload = kindObject["point"] as? [String: Any],
      let point = modelPoint(from: payload)
    {
      return CanvasEntity(
        id: id,
        label: AppStrings.tr("entity_kind.point"),
        kind: .point,
        layerID: layerID,
        styleID: styleID,
        geometry: .point(point)
      )
    }

    if let payload = kindObject["lineSegment"] as? [String: Any],
      let start = modelPoint(from: payload["start"]),
      let end = modelPoint(from: payload["end"])
    {
      return CanvasEntity(
        id: id,
        label: AppStrings.tr("entity_kind.line_segment"),
        kind: .lineSegment,
        layerID: layerID,
        styleID: styleID,
        geometry: .line(start: start, end: end, centerLine: false)
      )
    }

    if let payload = kindObject["centerLine"] as? [String: Any],
      let start = modelPoint(from: payload["start"]),
      let end = modelPoint(from: payload["end"])
    {
      return CanvasEntity(
        id: id,
        label: AppStrings.tr("entity_kind.center_line"),
        kind: .centerLine,
        layerID: layerID,
        styleID: styleID,
        geometry: .line(start: start, end: end, centerLine: true)
      )
    }

    if let payload = kindObject["circle"] as? [String: Any],
      let center = modelPoint(from: payload["center"]),
      let radiusMM = payload["radiusMm"] as? Double
    {
      return CanvasEntity(
        id: id,
        label: AppStrings.tr("entity_kind.circle"),
        kind: .circle,
        layerID: layerID,
        styleID: styleID,
        geometry: .circle(center: center, radiusMM: radiusMM)
      )
    }

    if let payload = kindObject["arc"] as? [String: Any],
      let center = modelPoint(from: payload["center"]),
      let radiusMM = payload["radiusMm"] as? Double,
      let startAngleRad = payload["startAngleRad"] as? Double,
      let sweepAngleRad = payload["sweepAngleRad"] as? Double
    {
      return CanvasEntity(
        id: id,
        label: AppStrings.tr("entity_kind.arc"),
        kind: .arc,
        layerID: layerID,
        styleID: styleID,
        geometry: .arc(
          center: center,
          radiusMM: radiusMM,
          startAngleRad: startAngleRad,
          sweepAngleRad: sweepAngleRad
        )
      )
    }

    let key = kindObject.keys.first ?? "unsupported"
    return CanvasEntity(
      id: id,
      label: key,
      kind: .unsupported(key),
      layerID: layerID,
      styleID: styleID,
      geometry: .unsupported
    )
  }

  private static func modelPoint(from object: Any?) -> ModelPoint? {
    guard let object = object as? [String: Any],
      let xMM = object["xMm"] as? Double,
      let yMM = object["yMm"] as? Double
    else {
      return nil
    }
    return ModelPoint(xMM: xMM, yMM: yMM)
  }

  private static func fixedMillimeterValue(from object: Any?) -> Double? {
    guard let value = object as? [String: Any] else {
      return nil
    }
    return value["fixedMm"] as? Double
  }

  private static func fixedDegreesValue(from object: Any?) -> Double? {
    guard let value = object as? [String: Any] else {
      return nil
    }
    return value["fixedDegrees"] as? Double
  }

  private static func parameterValue(from object: Any?) -> String? {
    guard let value = object as? [String: Any] else {
      return nil
    }
    return value["parameter"] as? String
  }

  private static func jsonString(from object: Any) -> String? {
    guard JSONSerialization.isValidJSONObject(object),
      let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  private static func layerKind(from value: String) -> LayerKind {
    switch value {
    case "cutLine": return .cutLine
    case "dimension": return .dimension
    case "printGuide": return .printGuide
    case "construction": return .construction
    default: return .unknown(value)
    }
  }

  private static func constraintStatus(from value: String) -> ConstraintStatus {
    switch value {
    case "underConstrained": return .underConstrained
    case "fullyConstrained": return .fullyConstrained
    case "overConstrained": return .overConstrained
    case "conflicting": return .conflicting
    default: return .unknown
    }
  }

  private static func constraintDisplayName(from value: String) -> String {
    switch value {
    case "coincident": return AppStrings.tr("tool.coincident")
    case "horizontal": return AppStrings.tr("tool.horizontal")
    case "vertical": return AppStrings.tr("tool.vertical")
    case "parallel": return AppStrings.tr("tool.parallel")
    case "perpendicular": return AppStrings.tr("tool.perpendicular")
    case "tangent": return AppStrings.tr("tool.tangent")
    case "symmetric": return AppStrings.tr("tool.symmetric")
    case "distance": return AppStrings.tr("tool.distance")
    case "horizontalDistance": return AppStrings.tr("tool.horizontal_distance")
    case "verticalDistance": return AppStrings.tr("tool.vertical_distance")
    case "pointLineDistance": return AppStrings.tr("tool.point_line_distance")
    case "lineLineDistance": return AppStrings.tr("tool.line_line_distance")
    case "pointOnLine": return AppStrings.tr("tool.point_on_line")
    case "segmentLength": return AppStrings.tr("tool.segment_length")
    case "angle": return AppStrings.tr("tool.angle")
    case "fixed": return AppStrings.tr("tool.fixed")
    case "diameter": return AppStrings.tr("tool.diameter")
    case "radius": return AppStrings.tr("tool.radius")
    case "equalSegmentLength": return AppStrings.tr("tool.equal_length")
    default: return value
    }
  }

  private static func measurementAnnotationDisplayName(from value: String) -> String {
    switch value {
    case "distance": return AppStrings.tr("tool.measure_distance")
    case "segmentLength": return AppStrings.tr("tool.measure_segment_length")
    case "angle": return AppStrings.tr("tool.measure_angle")
    case "radius": return AppStrings.tr("tool.measure_radius")
    case "diameter": return AppStrings.tr("tool.measure_diameter")
    case "arcSweepAngle": return AppStrings.tr("tool.measure_arc_sweep_angle")
    default: return value
    }
  }

  private static func decodeModelPoint(_ object: [String: Any]?) -> ModelPoint? {
    guard let object,
      let xMM = object["xMm"] as? Double,
      let yMM = object["yMm"] as? Double
    else {
      return nil
    }
    return ModelPoint(xMM: xMM, yMM: yMM)
  }

  private static func hexColor(from rgba: [String: Any]) -> String {
    let red = Int(((rgba["red"] as? Double) ?? 0) * 255.0)
    let green = Int(((rgba["green"] as? Double) ?? 0) * 255.0)
    let blue = Int(((rgba["blue"] as? Double) ?? 0) * 255.0)
    return String(format: "#%02X%02X%02X", red, green, blue)
  }

  private enum BridgeError: LocalizedError {
    case invalidJSON(String)

    var errorDescription: String? {
      switch self {
      case .invalidJSON(let label):
        return AppStrings.tr("core.error.invalid_json", label)
      }
    }
  }
}

extension Data {
  fileprivate init?(hexEncoded string: String) {
    guard string.count.isMultiple(of: 2) else {
      return nil
    }
    var data = Data(capacity: string.count / 2)
    var index = string.startIndex
    while index < string.endIndex {
      let next = string.index(index, offsetBy: 2)
      guard let byte = UInt8(string[index..<next], radix: 16) else {
        return nil
      }
      data.append(byte)
      index = next
    }
    self = data
  }
}
