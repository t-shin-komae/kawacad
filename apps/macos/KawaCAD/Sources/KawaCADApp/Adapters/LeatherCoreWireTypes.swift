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

struct CoreErrorEnvelope: Decodable {
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

enum LeatherRPCRequest {
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

enum LeatherProcessAdapterError: LocalizedError {
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
