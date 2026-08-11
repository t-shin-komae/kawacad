import Foundation
import KawaCADOutput

struct DocumentCommandRequest {
  let payload: CoreDocumentCommand
  let successMessage: String

  init(payload: [String: Any], successMessage: String) {
    self.payload = try! CoreDocumentCommand(legacyObject: payload)
    self.successMessage = successMessage
  }

  init(payload: CoreDocumentCommand, successMessage: String) {
    self.payload = payload
    self.successMessage = successMessage
  }
}

enum DocumentCommandExecutionResult {
  case success(LeatherDocumentState, successMessage: String)
  case failure(CoreFailure)
}

/// Pure semantic command construction. Core execution belongs to
/// `CadSessionState`.
struct DocumentCommandFactory {
  var uuidProvider: () -> String = { UUID().uuidString.lowercased() }

  func makeSetPrintOrientationCommand(
    _ orientation: OutputPrintOrientation
  ) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setPrintOrientation,
        payload: .object(["orientation": .string(orientation.rawValue)])
      ),
      successMessage: AppStrings.tr("status.a4_reference_orientation", orientation.displayName)
    )
  }

  func makeCreatePartCommand(
    name: String,
    originMM: ModelPoint? = nil,
    entityIDs: [String]
  ) -> DocumentCommandRequest {
    var payload: [String: CoreJSONValue] = [
      "id": .string("part:\(uuidProvider())"),
      "name": .string(name),
      "entityIds": .array(entityIDs.map(CoreJSONValue.string)),
    ]
    if let originMM {
      payload["originMm"] = .object([
        "xMm": .number(originMM.xMM),
        "yMm": .number(originMM.yMM),
      ])
    }
    return DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .createPart,
        payload: .object(payload)
      ),
      successMessage: AppStrings.tr("command.part_created", name)
    )
  }

  func makeRenamePartCommand(partID: String, name: String) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .renamePart, payload: .object(["partId": .string(partID), "name": .string(name)])),
      successMessage: AppStrings.tr("command.part_updated", name))
  }

  func makeSetPartVisibilityCommand(partID: String, visible: Bool, name: String)
    -> DocumentCommandRequest
  {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setPartVisibility,
        payload: .object(["partId": .string(partID), "visible": .bool(visible)])),
      successMessage: AppStrings.tr("command.part_settings_updated", name))
  }
  func makeSetPartPrintableCommand(partID: String, printable: Bool, name: String)
    -> DocumentCommandRequest
  {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setPartPrintable,
        payload: .object(["partId": .string(partID), "printable": .bool(printable)])),
      successMessage: AppStrings.tr("command.part_settings_updated", name))
  }
  func makeSetPartQuantityCommand(partID: String, quantity: Int, name: String)
    -> DocumentCommandRequest
  {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setPartQuantity,
        payload: .object(["partId": .string(partID), "quantity": .number(Double(quantity))])),
      successMessage: AppStrings.tr("command.part_settings_updated", name))
  }

  func makeAlignPartsCommand(partIDs: [String], alignment: String) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .alignParts,
        payload: .object([
          "partIds": .array(partIDs.map(CoreJSONValue.string)),
          "alignment": .string(alignment),
        ])
      ),
      successMessage: AppStrings.tr("command.parts_aligned", partIDs.count)
    )
  }

  func makeDistributePartsCommand(partIDs: [String], axis: String) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .distributeParts,
        payload: .object([
          "partIds": .array(partIDs.map(CoreJSONValue.string)),
          "axis": .string(axis),
        ])
      ),
      successMessage: AppStrings.tr("command.parts_distributed", partIDs.count)
    )
  }

  func makeDeletePartCommand(_ part: ProjectPart) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(kind: .deletePart, payload: .string(part.id)),
      successMessage: AppStrings.tr("command.part_deleted", part.name)
    )
  }

  func makeMovePartCommand(_ part: ProjectPart, delta: ModelPoint) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .movePart,
        payload: .object([
          "partId": .string(part.id),
          "delta": CorePoint(xMm: delta.xMM, yMm: delta.yMM).jsonValue,
        ])
      ),
      successMessage: AppStrings.tr("command.part_moved", part.name)
    )
  }

  func makeSetPartPositionCommand(_ part: ProjectPart, position: ModelPoint)
    -> DocumentCommandRequest
  {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setPartPosition,
        payload: .object([
          "partId": .string(part.id),
          "position": CorePoint(xMm: position.xMM, yMm: position.yMM).jsonValue,
        ])
      ),
      successMessage: AppStrings.tr("command.part_moved", part.name)
    )
  }

  func makeDuplicatePartCommand(
    _ part: ProjectPart,
    newName: String,
    delta: ModelPoint
  ) -> (request: DocumentCommandRequest, partID: String) {
    let namespace = uuidProvider()
    let partID = "part:\(uuidProvider())"
    return (
      DocumentCommandRequest(
        payload: CoreDocumentCommand(
          kind: .duplicatePart,
          payload: .object([
            "partId": .string(part.id),
            "newPartId": .string(partID),
            "newName": .string(newName),
            "idNamespace": .string(namespace),
            "delta": CorePoint(xMm: delta.xMM, yMm: delta.yMM).jsonValue,
          ])
        ),
        successMessage: AppStrings.tr("command.part_duplicated", newName)
      ),
      partID
    )
  }

  func makeAddEntitiesToPartCommand(_ part: ProjectPart, entityIDs: [String])
    -> DocumentCommandRequest
  {
    partMembershipCommand(
      kind: .addEntitiesToPart,
      part: part,
      entityIDs: entityIDs,
      successKey: "command.part_members_added"
    )
  }

  func makeRemoveEntitiesFromPartCommand(_ part: ProjectPart, entityIDs: [String])
    -> DocumentCommandRequest
  {
    partMembershipCommand(
      kind: .removeEntitiesFromPart,
      part: part,
      entityIDs: entityIDs,
      successKey: "command.part_members_removed"
    )
  }

  func makeSetPartBoundaryCommand(_ part: ProjectPart, entityIDs: [String])
    -> DocumentCommandRequest
  {
    partMembershipCommand(
      kind: .setPartBoundary,
      part: part,
      entityIDs: entityIDs,
      successKey: "command.part_boundary_updated"
    )
  }

  private func partMembershipCommand(
    kind: CoreDocumentCommandKind,
    part: ProjectPart,
    entityIDs: [String],
    successKey: String
  ) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: kind,
        payload: .object([
          "partId": .string(part.id),
          "entityIds": .array(entityIDs.map(CoreJSONValue.string)),
        ])
      ),
      successMessage: AppStrings.tr(successKey, part.name, entityIDs.count)
    )
  }

  func makeDuplicateSelectionCommand(
    selection: CoreSelectionReference,
    dxMM: Double,
    dyMM: Double,
    successMessage: String
  ) -> DocumentCommandRequest {
    let namespace = uuidProvider()
    return DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .duplicateSelection,
        payload: .object([
          "selection": selection.jsonValue,
          "idNamespace": .string(namespace),
          "delta": CorePoint(xMm: dxMM, yMm: dyMM).jsonValue,
        ])
      ),
      successMessage: successMessage
    )
  }

  func makePasteSelectionCommand(
    clipboardJSON: String,
    dxMM: Double,
    dyMM: Double,
    idNamespace: String? = nil,
    successMessage: String
  ) -> DocumentCommandRequest {
    let namespace = idNamespace ?? uuidProvider()
    return DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .pasteSelection,
        payload: .object([
          "clipboardJson": .string(clipboardJSON),
          "idNamespace": .string(namespace),
          "delta": CorePoint(xMm: dxMM, yMm: dyMM).jsonValue,
        ])
      ),
      successMessage: successMessage
    )
  }

  func makeInsertLibraryPartCommand(
    entry: PartLibraryEntry,
    newName: String,
    delta: ModelPoint
  ) -> DocumentCommandRequest {
    let namespace = uuidProvider()
    let partID = "part:\(uuidProvider())"
    let legacySourcePart = try! CoreJSONValue(
      any: JSONSerialization.jsonObject(with: JSONEncoder().encode(entry.sourcePart))
    )
    return DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .insertPartLibraryItem,
        payload: .object([
          "libraryJson": .string(entry.clipboardJSON),
          "legacySourcePart": legacySourcePart,
          "newPartId": .string(partID),
          "newName": .string(newName),
          "idNamespace": .string(namespace),
          "delta": CorePoint(xMm: delta.xMM, yMm: delta.yMM).jsonValue,
        ])
      ),
      successMessage: AppStrings.tr("command.part_library_inserted", newName)
    )
  }

  func makeSetSegmentLengthCommand(entityID: String, valueMM: Double) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setEntityMetric,
        payload: .object([
          "entityId": .string(entityID),
          "metric": .object(["kind": .string("segmentLength"), "valueMm": .number(valueMM)]),
        ])
      ),
      successMessage: AppStrings.tr("command.entity_updated", entityID)
    )
  }

  func makeSetCircleRadiusCommand(entityID: String, valueMM: Double) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setEntityMetric,
        payload: .object([
          "entityId": .string(entityID),
          "metric": .object(["kind": .string("circleRadius"), "valueMm": .number(valueMM)]),
        ])
      ),
      successMessage: AppStrings.tr("command.entity_updated", entityID)
    )
  }

  func makeSetArcCommand(
    entityID: String,
    radiusMM: Double?,
    startAngleRad: Double?,
    sweepAngleRad: Double?
  ) -> DocumentCommandRequest {
    var metric: [String: CoreJSONValue] = ["kind": .string("arcUpdate")]
    if let radiusMM { metric["radiusMm"] = .number(radiusMM) }
    if let startAngleRad { metric["startAngleRad"] = .number(startAngleRad) }
    if let sweepAngleRad { metric["sweepAngleRad"] = .number(sweepAngleRad) }
    return DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setEntityMetric,
        payload: .object([
          "entityId": .string(entityID),
          "metric": .object(metric),
        ])
      ),
      successMessage: AppStrings.tr("command.entity_updated", entityID)
    )
  }

  func makeSmoothArcTangenciesCommand(arcEntityID: String) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .smoothArcTangencies,
        payload: .object(["arcEntityId": .string(arcEntityID)])
      ),
      successMessage: AppStrings.tr("command.smooth_arc_tangencies_prototype")
    )
  }

  func makeConvertMeasurementCommand(
    annotationID: String,
    constraintID: String
  ) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .convertMeasurementToConstraint,
        payload: .object([
          "annotationId": .string(annotationID),
          "constraintId": .string(constraintID),
        ])
      ),
      successMessage: AppStrings.tr("command.measurement_annotation_converted", "")
    )
  }

  func makePlaceStitchStartPointCommand(
    id: String,
    position: ModelPoint,
    candidateTargetIDs: [String] = [],
    maxDistanceMM: Double = 3.0
  ) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .placeStitchStartPoint,
        payload: .object([
          "id": .string(id),
          "position": CorePoint(xMm: position.xMM, yMm: position.yMM).jsonValue,
          "candidateTargetIds": .array(candidateTargetIDs.map(CoreJSONValue.string)),
          "maxDistanceMm": .number(maxDistanceMM),
        ])
      ),
      successMessage: AppStrings.tr("command.stitch_start_point_added")
    )
  }

  func makeAddEntityCommand(
    tool: CanvasTool,
    start: ModelPoint,
    end: ModelPoint,
    layerID: String,
    styleID: String? = nil
  ) -> (request: DocumentCommandRequest, entityID: String)? {
    let entityID = "entity:\(tool.rawValue)-\(uuidProvider())"
    let gesture: [String: Any]

    switch tool {
    case .point:
      gesture = ["kind": "point", "position": start.jsonObject]
    case .line:
      gesture = [
        "kind": "line",
        "start": start.jsonObject,
        "end": end.jsonObject,
        "centerLine": false,
      ]
    case .circle:
      gesture = [
        "kind": "circle",
        "center": start.jsonObject,
        "radiusPoint": end.jsonObject,
      ]
    case .arc:
      let radiusVector = ModelPoint(xMM: end.xMM - start.xMM, yMM: end.yMM - start.yMM)
      gesture = [
        "kind": "arc",
        "center": start.jsonObject,
        "start": end.jsonObject,
        "end": ModelPoint(
          xMM: start.xMM - radiusVector.yMM,
          yMM: start.yMM + radiusVector.xMM
        ).jsonObject,
        "sweepReferenceRad": Double.pi / 2,
      ]
    case .centerLine, .horizontalCenterLine, .verticalCenterLine:
      let axis: String?
      switch tool {
      case .horizontalCenterLine:
        axis = "horizontal"
      case .verticalCenterLine:
        axis = "vertical"
      default:
        axis = nil
      }
      var lineGesture: [String: Any] = [
        "kind": "line",
        "start": start.jsonObject,
        "end": end.jsonObject,
        "centerLine": true,
      ]
      if let axis { lineGesture["axis"] = axis }
      gesture = lineGesture
    case .select, .roundHole, .stitchStartPoint, .freeText, .coincident, .horizontal, .vertical,
      .parallel, .perpendicular, .tangent, .equalLength,
      .angle, .symmetric, .pointOnLine, .distance, .horizontalDistance, .verticalDistance,
      .lineLineDistance, .segmentLength, .diameter, .radius, .fixed, .offset, .fillet,
      .measureDistance, .measureSegmentLength, .measureAngle, .measureRadius, .measureDiameter,
      .measureArcSweepAngle:
      return nil
    }

    var payload: [String: Any] = [
      "id": entityID,
      "layerId": layerID,
      "gesture": gesture,
    ]
    if let styleID {
      payload["styleId"] = styleID
    }

    return (
      DocumentCommandRequest(
        payload: [
          "kind": "createEntityFromGesture",
          "payload": payload,
        ],
        successMessage: AppStrings.tr("command.entity_added", tool.displayName)
      ),
      entityID
    )
  }

  func makeCreateLineGestureCommand(
    start: ModelPoint,
    end: ModelPoint,
    layerID: String,
    styleID: String?,
    startTarget: [String: Any]?,
    endTarget: [String: Any]?,
    axis: String?
  ) -> (request: DocumentCommandRequest, entityID: String) {
    let entityID = "entity:line-\(uuidProvider())"
    var gesture: [String: Any] = [
      "kind": "line",
      "start": start.jsonObject,
      "end": end.jsonObject,
      "centerLine": false,
    ]
    if let axis { gesture["axis"] = axis }
    var payload: [String: Any] = [
      "id": entityID,
      "layerId": layerID,
      "gesture": gesture,
    ]
    if let styleID { payload["styleId"] = styleID }
    if let startTarget {
      payload["startSnap"] = [
        "constraintId": "constraint:coincident-\(uuidProvider())",
        "target": startTarget,
      ]
    }
    if let endTarget {
      payload["endSnap"] = [
        "constraintId": "constraint:coincident-\(uuidProvider())",
        "target": endTarget,
      ]
    }
    if axis != nil {
      payload["axisConstraintId"] = "constraint:\(axis!)-\(uuidProvider())"
    }
    return (
      DocumentCommandRequest(
        payload: [
          "kind": "createEntityFromGesture",
          "payload": payload,
        ],
        successMessage: AppStrings.tr("command.entity_added", CanvasTool.line.displayName)
      ),
      entityID
    )
  }

  func makeAddArcEntityCommand(
    center: ModelPoint,
    start: ModelPoint,
    end: ModelPoint,
    sweepReferenceRad: Double? = nil,
    layerID: String,
    styleID: String? = nil
  ) -> DocumentCommandRequest? {
    let radius = hypot(start.xMM - center.xMM, start.yMM - center.yMM)
    guard radius > 0.0001 else {
      return nil
    }
    let startAngle = angleRadians(from: center, to: start)
    let endAngle = angleRadians(from: center, to: end)
    let sweepAngle =
      sweepReferenceRad
      ?? normalizedSignedSweepAngle(startAngleRad: startAngle, endAngleRad: endAngle)
    return makeArcGestureCommand(
      center: center,
      start: start,
      end: end,
      sweepReferenceRad: sweepAngle,
      layerID: layerID,
      styleID: styleID
    )
  }

  func makeAddRoundHoleCommand(
    center: ModelPoint,
    diameterMM: Double,
    kind: ProjectRoundHoleKind,
    layerID: String,
    styleID: String? = nil
  ) -> DocumentCommandRequest? {
    guard diameterMM.isFinite, diameterMM > 0 else {
      return nil
    }
    let roundHoleID = "round-hole:\(uuidProvider())"
    let entityID = "entity:round-hole-\(uuidProvider())"
    return DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .createRoundHole,
        payload: .object([
          "id": .string(roundHoleID),
          "entityId": .string(entityID),
          "center": CorePoint(xMm: center.xMM, yMm: center.yMM).jsonValue,
          "diameterMm": .number(diameterMM),
          "roundHoleKind": .string(kind.rawValue),
          "layerId": .string(layerID),
          "styleId": styleID.map(CoreJSONValue.string) ?? .null,
        ])
      ),
      successMessage: AppStrings.tr("command.entity_added", CanvasTool.roundHole.displayName)
    )
  }

  func makeSetRoundHoleDiameterCommand(
    roundHoleID: String,
    diameterMM: Double
  ) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setRoundHoleDiameter,
        payload: .object([
          "roundHoleId": .string(roundHoleID),
          "diameterMm": .number(diameterMM),
        ])
      ),
      successMessage: AppStrings.tr(
        "status.round_hole_diameter_changed",
        String(format: "%.2f", diameterMM)
      )
    )
  }

  func makeSetRoundHoleKindCommand(
    roundHoleID: String,
    kind: ProjectRoundHoleKind
  ) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setRoundHoleKind,
        payload: .object([
          "roundHoleId": .string(roundHoleID),
          "kind": .string(kind.rawValue),
        ])
      ),
      successMessage: AppStrings.tr("command.round_hole_updated")
    )
  }

  func makeAddRoundHoleCommand(_ roundHole: ProjectRoundHole) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "addRoundHole",
        "payload": roundHole.documentCommandPayload,
      ],
      successMessage: AppStrings.tr("command.round_hole_updated")
    )
  }

  func makeAddStitchStartPointCommand(_ stitchStartPoint: ProjectStitchStartPoint)
    -> DocumentCommandRequest
  {
    DocumentCommandRequest(
      payload: [
        "kind": "addStitchStartPoint",
        "payload": stitchStartPoint.documentCommandPayload,
      ],
      successMessage: AppStrings.tr("command.stitch_start_point_added")
    )
  }

  func makeUpdateStitchStartPointCommand(_ stitchStartPoint: ProjectStitchStartPoint)
    -> DocumentCommandRequest
  {
    DocumentCommandRequest(
      payload: [
        "kind": "updateStitchStartPoint",
        "payload": stitchStartPoint.documentCommandPayload,
      ],
      successMessage: AppStrings.tr("command.stitch_start_point_updated")
    )
  }

  func makeDeleteStitchStartPointCommand(id: String) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "deleteStitchStartPoint",
        "payload": id,
      ],
      successMessage: AppStrings.tr("command.stitch_start_point_deleted")
    )
  }

  func makeAddArcEntityCommand(
    center: ModelPoint,
    start: ModelPoint,
    sweepAngleRad: Double,
    layerID: String,
    styleID: String? = nil
  ) -> DocumentCommandRequest? {
    let radius = hypot(start.xMM - center.xMM, start.yMM - center.yMM)
    guard radius > 0.0001 else {
      return nil
    }
    let startAngle = angleRadians(from: center, to: start)
    let end = ModelPoint(
      xMM: center.xMM + radius * cos(startAngle + sweepAngleRad),
      yMM: center.yMM + radius * sin(startAngle + sweepAngleRad)
    )
    return makeArcGestureCommand(
      center: center,
      start: start,
      end: end,
      sweepReferenceRad: sweepAngleRad,
      layerID: layerID,
      styleID: styleID
    )
  }

  private func makeArcGestureCommand(
    center: ModelPoint,
    start: ModelPoint,
    end: ModelPoint,
    sweepReferenceRad: Double,
    layerID: String,
    styleID: String? = nil
  ) -> DocumentCommandRequest? {
    let fullTurn = 2.0 * Double.pi
    guard abs(sweepReferenceRad) > 0.0001,
      abs(abs(sweepReferenceRad) - fullTurn) > 0.0001,
      abs(sweepReferenceRad) < fullTurn
    else {
      return nil
    }
    let entityID = "entity:arc-\(uuidProvider())"
    var payload: [String: Any] = [
      "id": entityID,
      "layerId": layerID,
      "gesture": [
        "kind": "arc",
        "center": center.jsonObject,
        "start": start.jsonObject,
        "end": end.jsonObject,
        "sweepReferenceRad": sweepReferenceRad,
      ],
    ]
    if let styleID {
      payload["styleId"] = styleID
    }

    return DocumentCommandRequest(
      payload: [
        "kind": "createEntityFromGesture",
        "payload": payload,
      ],
      successMessage: AppStrings.tr("command.entity_added", CanvasTool.arc.displayName)
    )
  }

  func makeAddConstraintCommand(
    kind: String,
    displayName: String,
    targets: [[String: Any]],
    value: Any = NSNull()
  ) -> DocumentCommandRequest {
    return DocumentCommandRequest(
      payload: [
        "kind": "addConstraint",
        "payload": [
          "id": "constraint:\(kind)-\(uuidProvider())",
          "kind": kind,
          "targets": targets,
          "value": value,
          "status": "unknown",
        ],
      ],
      successMessage: AppStrings.tr("command.constraint_added", displayName)
    )
  }

  func makeAddMeasurementAnnotationCommand(
    kind: String,
    displayName: String,
    targets: [[String: Any]]
  ) -> DocumentCommandRequest {
    return DocumentCommandRequest(
      payload: [
        "kind": "addMeasurementAnnotation",
        "payload": [
          "id": "measurement:\(kind)-\(uuidProvider())",
          "kind": kind,
          "targets": targets,
          "labelOffsetMm": ["xMm": 0.0, "yMm": 0.0],
          "overallOffsetMm": ["xMm": 0.0, "yMm": 0.0],
          "visible": true,
        ],
      ],
      successMessage: AppStrings.tr("command.measurement_annotation_added", displayName)
    )
  }

  func makeDeleteMeasurementAnnotationCommand(
    _ annotation: ProjectMeasurementAnnotation
  ) -> DocumentCommandRequest {
    return DocumentCommandRequest(
      payload: [
        "kind": "deleteMeasurementAnnotation",
        "payload": annotation.id,
      ],
      successMessage: AppStrings.tr("command.measurement_annotation_deleted", annotation.kind)
    )
  }

  func makeAddDimensionConstraintAnnotationCommand(
    _ annotation: ProjectDimensionConstraintAnnotation
  ) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "addDimensionConstraintAnnotation",
        "payload": annotation.documentCommandPayload,
      ],
      successMessage: AppStrings.tr("command.dimension_constraint_annotation_updated")
    )
  }

  func makeAddConstraintCommand(_ constraint: ProjectConstraint) -> DocumentCommandRequest? {
    guard let targets = decodeTargetsJSON(constraint.targetsJSON) else {
      return nil
    }
    let value = makeConstraintValuePayload(constraint)
    return DocumentCommandRequest(
      payload: [
        "kind": "addConstraint",
        "payload": [
          "id": constraint.id,
          "kind": constraint.rawKind,
          "targets": targets,
          "value": value,
          "status": constraint.status.rawValue,
        ],
      ],
      successMessage: AppStrings.tr("command.constraint_added", constraint.kind)
    )
  }

  func makeAddMeasurementAnnotationCommand(
    _ annotation: ProjectMeasurementAnnotation
  ) -> DocumentCommandRequest? {
    guard let payload = annotation.documentCommandPayload else {
      return nil
    }
    return DocumentCommandRequest(
      payload: [
        "kind": "addMeasurementAnnotation",
        "payload": payload,
      ],
      successMessage: AppStrings.tr("command.measurement_annotation_added", annotation.kind)
    )
  }

  func makeConvertMeasurementAnnotationCommand(
    _ annotation: ProjectMeasurementAnnotation,
    value: [String: Any]
  ) -> DocumentCommandRequest? {
    guard let targets = decodeTargetsJSON(annotation.targetsJSON) else {
      return nil
    }
    let constraintKind = annotation.rawKind == "arcSweepAngle" ? "angle" : annotation.rawKind
    let addConstraint = makeAddConstraintCommand(
      kind: constraintKind,
      displayName: annotation.kind,
      targets: targets,
      value: value
    )
    let deleteAnnotation = makeDeleteMeasurementAnnotationCommand(annotation)
    return makeCompoundCommand(
      [addConstraint, deleteAnnotation],
      successMessage: AppStrings.tr("command.measurement_annotation_converted", annotation.kind)
    )
  }

  func makeCompoundCommand(
    _ commands: [DocumentCommandRequest],
    successMessage: String
  ) -> DocumentCommandRequest? {
    guard !commands.isEmpty else {
      return nil
    }
    return DocumentCommandRequest(
      payload: [
        "kind": "compound",
        "payload": commands.map { $0.payload.legacyObject },
      ],
      successMessage: successMessage
    )
  }

  func makeAddEntityCommand(
    _ entity: CanvasEntity,
    successMessage: String
  ) -> DocumentCommandRequest? {
    guard let payload = entity.documentCommandPayload else {
      return nil
    }
    return DocumentCommandRequest(
      payload: [
        "kind": "addEntity",
        "payload": payload,
      ],
      successMessage: successMessage
    )
  }

  func makeUpdateEntityCommand(_ entity: CanvasEntity) -> DocumentCommandRequest? {
    guard let payload = entity.documentCommandPayload else {
      return nil
    }
    return DocumentCommandRequest(
      payload: [
        "kind": "updateEntity",
        "payload": payload,
      ],
      successMessage: AppStrings.tr("command.entity_updated", entity.label)
    )
  }

  func makeMoveEntitiesCommand(
    entityIDs: Set<String>,
    delta: ModelPoint,
    allowSingleLineStretch: Bool,
    successMessage: String
  ) -> DocumentCommandRequest? {
    let sortedEntityIDs = entityIDs.sorted()
    guard !sortedEntityIDs.isEmpty else {
      return nil
    }
    return DocumentCommandRequest(
      payload: [
        "kind": "moveEntities",
        "payload": [
          "entityIds": sortedEntityIDs,
          "delta": delta.jsonObject,
          "allowSingleLineStretch": allowSingleLineStretch,
        ],
      ],
      successMessage: successMessage
    )
  }

  func makeMoveControlPointCommand(
    target: CanvasSelectionTarget,
    position: ModelPoint,
    allowProjection: Bool
  ) -> DocumentCommandRequest? {
    guard target.controlPoint != nil else {
      return nil
    }
    return DocumentCommandRequest(
      payload: [
        "kind": "moveControlPoint",
        "payload": [
          "target": target.constraintJSON,
          "position": position.jsonObject,
          "allowProjection": allowProjection,
        ],
      ],
      successMessage: AppStrings.tr("command.entity_updated", target.entityLabel)
    )
  }

  func makeSetLayerVisibilityCommand(_ layer: ProjectLayer, visible: Bool) -> DocumentCommandRequest
  {
    DocumentCommandRequest(
      payload: [
        "kind": "setLayerVisibility",
        "payload": [
          "layerId": layer.id,
          "visible": visible,
        ],
      ],
      successMessage: AppStrings.tr(
        "command.layer_visibility_changed", layer.name,
        AppStrings.tr(visible ? "command.enabled" : "command.disabled"))
    )
  }

  func makeSetLayerPrintableCommand(_ layer: ProjectLayer, printable: Bool)
    -> DocumentCommandRequest
  {
    DocumentCommandRequest(
      payload: [
        "kind": "setLayerPrintable",
        "payload": [
          "layerId": layer.id,
          "printable": printable,
        ],
      ],
      successMessage: AppStrings.tr(
        "command.layer_printable_changed", layer.name,
        AppStrings.tr(printable ? "command.enabled" : "command.disabled"))
    )
  }

  func makeSetLayerStyleCommand(_ layer: ProjectLayer) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "setLayerStyle",
        "payload": [
          "layerId": layer.id,
          "style": [
            "stroke": rgbaPayload(fromHex: layer.colorHex),
            "strokeWidthMm": layer.strokeWidthMM,
            "pattern": layer.linePattern.rawValue,
          ],
        ],
      ],
      successMessage: AppStrings.tr("command.layer_style_updated", layer.name)
    )
  }

  func makeAddSharedStyleCommand(number: Int) -> DocumentCommandRequest {
    let style = ProjectSharedStyle(
      id: "style:user-\(uuidProvider())",
      name: SharedStyleDefaults.name(number: number),
      colorHex: SharedStyleDefaults.colorHex,
      strokeWidthMM: SharedStyleDefaults.strokeWidthMM,
      linePattern: SharedStyleDefaults.linePattern
    )
    return DocumentCommandRequest(
      payload: [
        "kind": "addSharedStyle",
        "payload": style.documentCommandPayload,
      ],
      successMessage: AppStrings.tr("command.shared_style_added")
    )
  }

  func makeUpdateSharedStyleCommand(_ style: ProjectSharedStyle) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "updateSharedStyle",
        "payload": style.documentCommandPayload,
      ],
      successMessage: AppStrings.tr("command.shared_style_updated", style.name)
    )
  }

  func makeDeleteSharedStyleCommand(_ style: ProjectSharedStyle) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "deleteSharedStyle",
        "payload": style.id,
      ],
      successMessage: AppStrings.tr("command.shared_style_deleted", style.name)
    )
  }

  func makeSetEntitySharedStyleCommand(entityID: String, styleID: String?) -> DocumentCommandRequest
  {
    let payload: [String: Any] = [
      "entityId": entityID,
      "styleId": styleID ?? NSNull(),
    ]
    return DocumentCommandRequest(
      payload: [
        "kind": "setEntitySharedStyle",
        "payload": payload,
      ],
      successMessage: AppStrings.tr("command.entity_shared_style_updated")
    )
  }

  func makeSetEntityLayerCommand(entityID: String, layerID: String?) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setEntityLayer,
        payload: .object([
          "entityId": .string(entityID), "layerId": layerID.map(CoreJSONValue.string) ?? .null,
        ])), successMessage: AppStrings.tr("command.entity_updated", entityID))
  }

  func makeSetDerivedLayerCommand(derivedElementID: String, layerID: String?)
    -> DocumentCommandRequest
  {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setDerivedLayer,
        payload: .object([
          "derivedElementId": .string(derivedElementID),
          "layerId": layerID.map(CoreJSONValue.string) ?? .null,
        ])), successMessage: AppStrings.tr("command.derived_element_updated", ""))
  }

  func makeSetDerivedSharedStyleCommand(derivedElementID: String, styleID: String?)
    -> DocumentCommandRequest
  {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setDerivedSharedStyle,
        payload: .object([
          "derivedElementId": .string(derivedElementID),
          "styleId": styleID.map(CoreJSONValue.string) ?? .null,
        ])), successMessage: AppStrings.tr("command.entity_shared_style_updated"))
  }

  func makeSetFilletSourcesCommand(
    derivedElementID: String, sourceEntityIDs: [String], closed: Bool
  ) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setFilletSources,
        payload: .object([
          "derivedElementId": .string(derivedElementID),
          "sourceEntityIds": .array(sourceEntityIDs.map(CoreJSONValue.string)),
          "closed": .bool(closed),
        ])), successMessage: AppStrings.tr("command.derived_element_updated", "フィレット"))
  }

  func makeAddParameterCommand(number: Int) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "addParameter",
        "payload": [
          "id": "parameter:param-\(uuidProvider())",
          "name": "param_\(number)",
          "valueMm": 10.0,
          "unit": "millimeter",
          "memo": "",
        ],
      ],
      successMessage: AppStrings.tr("command.parameter_added")
    )
  }

  func makeUpdateParameterCommand(_ parameter: ProjectParameter) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "updateParameter",
        "payload": parameter.documentCommandPayload,
      ],
      successMessage: AppStrings.tr("command.parameter_updated", parameter.name)
    )
  }

  func makeDeleteParameterCommand(_ parameter: ProjectParameter) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "deleteParameter",
        "payload": [
          "parameterId": parameter.id,
          "replacementValueMm": parameter.valueMM,
        ],
      ],
      successMessage: AppStrings.tr("command.parameter_deleted", parameter.name)
    )
  }

  func makeDeleteEntityCommand(id: String, successMessage: String) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "deleteEntity",
        "payload": id,
      ],
      successMessage: successMessage
    )
  }

  func makeDeleteConstraintCommand(_ constraint: ProjectConstraint) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "deleteConstraint",
        "payload": constraint.id,
      ],
      successMessage: AppStrings.tr("command.constraint_deleted", constraint.kind)
    )
  }

  func makeAddOffsetCurveCommand(
    sourceEntityIDs: [String],
    sourceResolvedEntityIDs: [String] = [],
    distance: [String: Any],
    direction: String,
    layerID: String,
    styleID: String? = nil
  ) -> DocumentCommandRequest {
    var offset: [String: Any] = [
      "sourceEntityIds": sourceEntityIDs,
      "distance": distance,
      "direction": direction,
    ]
    if !sourceResolvedEntityIDs.isEmpty {
      offset["sourceResolvedEntityIds"] = sourceResolvedEntityIDs
    }
    var payload: [String: Any] = [
      "id": "derived:offset-\(uuidProvider())",
      "layerId": layerID,
      "kind": [
        "offsetCurve": offset
      ],
    ]
    if let styleID {
      payload["styleId"] = styleID
    }

    return DocumentCommandRequest(
      payload: [
        "kind": "addDerivedElement",
        "payload": payload,
      ],
      successMessage: AppStrings.tr("command.offset_added")
    )
  }

  func makeAddFilletCommand(
    sourceEntityIDs: [String],
    radius: [String: Any],
    layerID: String,
    closed: Bool = true
  ) -> DocumentCommandRequest {
    var fillet: [String: Any] = [
      "sourceEntityIds": sourceEntityIDs,
      "radius": radius,
    ]
    if !closed {
      fillet["closed"] = false
    }
    return DocumentCommandRequest(
      payload: [
        "kind": "addDerivedElement",
        "payload": [
          "id": "derived:fillet-\(uuidProvider())",
          "layerId": layerID,
          "kind": [
            "fillet": fillet
          ],
        ],
      ],
      successMessage: AppStrings.tr("command.fillet_added")
    )
  }

  func makeSetDerivedDistanceCommand(
    derivedElementID: String,
    value: CoreJSONValue
  ) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setDerivedDistance,
        payload: .object([
          "derivedElementId": .string(derivedElementID),
          "value": value,
        ])
      ),
      successMessage: AppStrings.tr("command.derived_element_updated", "")
    )
  }

  func makeSetDerivedRadiusCommand(
    derivedElementID: String,
    value: CoreJSONValue
  ) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setDerivedRadius,
        payload: .object([
          "derivedElementId": .string(derivedElementID),
          "value": value,
        ])
      ),
      successMessage: AppStrings.tr("command.derived_element_updated", "")
    )
  }

  func makeSetDerivedRadiusFromPointCommand(
    derivedElementID: String,
    resolvedIndex: Int,
    position: ModelPoint
  ) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setDerivedRadiusFromPoint,
        payload: .object([
          "derivedElementId": .string(derivedElementID),
          "resolvedIndex": .number(Double(resolvedIndex)),
          "position": CorePoint(xMm: position.xMM, yMm: position.yMM).jsonValue,
        ])
      ),
      successMessage: AppStrings.tr("command.derived_element_updated", "")
    )
  }

  func makeSetDerivedDirectionCommand(
    derivedElementID: String,
    direction: OffsetDirection
  ) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setDerivedDirection,
        payload: .object([
          "derivedElementId": .string(derivedElementID),
          "direction": .string(direction.rawValue),
        ])
      ),
      successMessage: AppStrings.tr("command.derived_element_updated", "")
    )
  }

  func makeAddDerivedElementCommand(_ derivedElement: ProjectDerivedElement)
    -> DocumentCommandRequest
  {
    DocumentCommandRequest(
      payload: [
        "kind": "addDerivedElement",
        "payload": derivedElement.documentCommandPayload,
      ],
      successMessage: AppStrings.tr(
        "command.derived_element_updated", derivedElement.kind.displayName)
    )
  }

  func makeAddFreeTextCommand(_ freeText: ProjectFreeText) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "addFreeText",
        "payload": freeText.jsonObject,
      ],
      successMessage: AppStrings.tr("command.free_text_added")
    )
  }

  func makeUpdateFreeTextCommand(_ freeText: ProjectFreeText) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "updateFreeText",
        "payload": freeText.jsonObject,
      ],
      successMessage: AppStrings.tr("command.free_text_updated")
    )
  }

  func makeDeleteFreeTextCommand(id: String) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "deleteFreeText",
        "payload": id,
      ],
      successMessage: AppStrings.tr("command.free_text_deleted")
    )
  }

  func makeDeleteDerivedElementCommand(_ derivedElement: ProjectDerivedElement)
    -> DocumentCommandRequest
  {
    DocumentCommandRequest(
      payload: [
        "kind": "deleteDerivedElement",
        "payload": derivedElement.id,
      ],
      successMessage: AppStrings.tr(
        "command.derived_element_deleted", derivedElement.kind.displayName)
    )
  }

  func makeUpdateConstraintCommand(
    id: String,
    rawKind: String,
    successMessage: String,
    targets: [[String: Any]],
    value: [String: Any]
  ) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "updateConstraint",
        "payload": [
          "id": id,
          "kind": rawKind,
          "targets": targets,
          "value": value,
          "status": "unknown",
        ],
      ],
      successMessage: successMessage
    )
  }

  func makeUpdateConstraintValueCommand(
    _ constraint: ProjectConstraint,
    valueMM: Double
  ) -> DocumentCommandRequest? {
    let value: CoreJSONValue
    if constraint.rawKind == "angle" {
      guard valueMM.isFinite else {
        return nil
      }
      value = .object(["fixedDegrees": .number(valueMM)])
    } else {
      guard valueMM > 0 else {
        return nil
      }
      value = .object(["fixedMm": .number(valueMM)])
    }
    return DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setConstraintValue,
        payload: .object([
          "constraintId": .string(constraint.id),
          "value": value,
        ])
      ),
      successMessage: AppStrings.tr("command.constraint_updated", constraint.kind)
    )
  }

  func makeUpdateConstraintParameterCommand(
    _ constraint: ProjectConstraint,
    parameter: ProjectParameter
  ) -> DocumentCommandRequest? {
    guard constraint.rawKind != "angle" else {
      return nil
    }
    return DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setConstraintParameter,
        payload: .object([
          "constraintId": .string(constraint.id),
          "parameterId": .string(parameter.id),
        ])
      ),
      successMessage: AppStrings.tr(
        "command.constraint_parameter_assigned", constraint.kind, parameter.name)
    )
  }

  func makeSetParameterValueCommand(parameterID: String, name: String, valueMM: Double)
    -> DocumentCommandRequest
  {
    DocumentCommandRequest(
      payload: CoreDocumentCommand(
        kind: .setParameterValue,
        payload: .object([
          "parameterId": .string(parameterID),
          "valueMm": .number(valueMM),
        ])
      ),
      successMessage: AppStrings.tr("command.parameter_updated", name)
    )
  }

  func makeAddSegmentLengthConstraintCommand(entityID: String, lengthMM: Double)
    -> DocumentCommandRequest
  {
    makeAddConstraintCommand(
      kind: "segmentLength",
      displayName: AppStrings.tr("tool.segment_length"),
      targets: [["entity": entityID]],
      value: ["fixedMm": lengthMM]
    )
  }

  func makeAddLayerCommand(number: Int) -> DocumentCommandRequest {
    let layerID = "layer:user-\(uuidProvider())"
    return DocumentCommandRequest(
      payload: [
        "kind": "addLayer",
        "payload": [
          "id": layerID,
          "name": AppStrings.tr("command.default_layer_name", number),
          "kind": "cutLine",
          "visible": true,
          "printable": true,
          "style": [
            "stroke": [
              "red": 0.0,
              "green": 0.0,
              "blue": 0.0,
              "alpha": 1.0,
            ],
            "strokeWidthMm": 0.2,
            "pattern": "solid",
          ],
        ],
      ],
      successMessage: AppStrings.tr("command.layer_added")
    )
  }

  func makeRenameDocumentCommand(name: String) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "renameDocument",
        "payload": [
          "name": name
        ],
      ],
      successMessage: AppStrings.tr("command.renamed", name)
    )
  }

  func makeRenameLayerCommand(_ layer: ProjectLayer, name: String) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "renameLayer",
        "payload": [
          "layerId": layer.id,
          "name": name,
        ],
      ],
      successMessage: AppStrings.tr("command.renamed", name)
    )
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

  func makeDeleteLayerCommand(_ layer: ProjectLayer) -> DocumentCommandRequest {
    DocumentCommandRequest(
      payload: [
        "kind": "deleteLayer",
        "payload": layer.id,
      ],
      successMessage: AppStrings.tr("command.layer_deleted", layer.name)
    )
  }

  private func decodeTargetsJSON(_ targetsJSON: String) -> [[String: Any]]? {
    guard let targetsData = targetsJSON.data(using: .utf8),
      let targets = try? JSONSerialization.jsonObject(with: targetsData) as? [[String: Any]]
    else {
      return nil
    }
    return targets
  }

  private func makeConstraintValuePayload(_ constraint: ProjectConstraint) -> Any {
    if let valueParameterID = constraint.valueParameterID {
      return ["parameter": valueParameterID]
    }
    if let valueDegrees = constraint.valueDegrees {
      return ["fixedDegrees": valueDegrees]
    }
    if let valueMM = constraint.valueMM {
      return ["fixedMm": valueMM]
    }
    return NSNull()
  }

}
