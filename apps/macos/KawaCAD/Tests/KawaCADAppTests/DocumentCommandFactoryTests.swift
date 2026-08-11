import Foundation
import Testing

@testable import KawaCADApp

@Test("CommandFactory はパーツの作成・更新・解除コマンドを生成する")
func command_service_builds_part_commands() {
  let service = DocumentCommandFactory(uuidProvider: { "part-id" })
  let create = service.makeCreatePartCommand(
    name: "札入れ外装",
    originMM: ModelPoint(xMM: 12.0, yMM: -4.0),
    entityIDs: ["entity:a", "entity:b"]
  )
  #expect((create.payload["kind"] as? String) == "createPart")
  let createPayload = unwrap(create.payload["payload"] as? [String: Any])
  #expect((createPayload["id"] as? String) == "part:part-id")
  #expect((createPayload["name"] as? String) == "札入れ外装")
  #expect((createPayload["entityIds"] as? [String]) == ["entity:a", "entity:b"])
  let origin = unwrap(createPayload["originMm"] as? [String: Double])
  #expect(origin["xMm"] == 12.0)
  #expect(origin["yMm"] == -4.0)

  let part = ProjectPart(
    id: "part:wallet",
    name: "財布外装",
    originMM: .zero,
    outlineEntityIDs: ["entity:a"],
    holeEntityIDGroups: [],
    entityIDs: ["entity:a"],
    derivedElementIDs: [],
    freeTextIDs: [],
    measurementAnnotationIDs: []
  )
  let rename = service.makeRenamePartCommand(partID: part.id, name: part.name)
  #expect((rename.payload["kind"] as? String) == "renamePart")
  let renamePayload = unwrap(rename.payload["payload"] as? [String: Any])
  #expect((renamePayload["partId"] as? String) == part.id)
  #expect((renamePayload["name"] as? String) == part.name)
  #expect(renamePayload["originMm"] == nil)
  let delete = service.makeDeletePartCommand(part)
  #expect((delete.payload["kind"] as? String) == "deletePart")
  #expect((delete.payload["payload"] as? String) == "part:wallet")
}

@Test("CommandFactory はパーツ移動・複製・所属編集コマンドを生成する")
func command_service_builds_part_editing_commands() {
  var ids = ["namespace", "new-part"].makeIterator()
  let service = DocumentCommandFactory(uuidProvider: { ids.next() ?? "fallback" })
  let part = ProjectPart(
    id: "part:wallet",
    name: "財布外装",
    originMM: .zero,
    outlineEntityIDs: ["entity:a"],
    holeEntityIDGroups: [],
    entityIDs: ["entity:a"],
    derivedElementIDs: [],
    freeTextIDs: [],
    measurementAnnotationIDs: []
  )

  let move = service.makeMovePartCommand(part, delta: ModelPoint(xMM: 10, yMM: -5))
  #expect((move.payload["kind"] as? String) == "movePart")
  let movePayload = unwrap(move.payload["payload"] as? [String: Any])
  #expect((movePayload["partId"] as? String) == "part:wallet")

  let duplicate = service.makeDuplicatePartCommand(
    part,
    newName: "財布外装 のコピー",
    delta: ModelPoint(xMM: 10, yMM: -10)
  )
  #expect(duplicate.partID == "part:new-part")
  #expect((duplicate.request.payload["kind"] as? String) == "duplicatePart")
  let duplicatePayload = unwrap(duplicate.request.payload["payload"] as? [String: Any])
  #expect((duplicatePayload["idNamespace"] as? String) == "namespace")
  #expect((duplicatePayload["newPartId"] as? String) == "part:new-part")

  let add = service.makeAddEntitiesToPartCommand(part, entityIDs: ["entity:b"])
  let remove = service.makeRemoveEntitiesFromPartCommand(part, entityIDs: ["entity:b"])
  let boundary = service.makeSetPartBoundaryCommand(part, entityIDs: ["entity:a"])
  #expect((add.payload["kind"] as? String) == "addEntitiesToPart")
  #expect((remove.payload["kind"] as? String) == "removeEntitiesFromPart")
  #expect((boundary.payload["kind"] as? String) == "setPartBoundary")
}

@Test("CommandFactory はパーツ管理設定・配置・ライブラリ配置コマンドを生成する")
func command_service_builds_part_management_improvement_commands() {
  var ids = ["library-namespace", "library-part"].makeIterator()
  let service = DocumentCommandFactory(uuidProvider: { ids.next() ?? "fallback" })
  let part = ProjectPart(
    id: "part:source",
    name: "カードポケット",
    originMM: .zero,
    outlineEntityIDs: ["entity:a"],
    holeEntityIDGroups: [],
    entityIDs: ["entity:a"],
    derivedElementIDs: [],
    freeTextIDs: [],
    measurementAnnotationIDs: [],
    visible: false,
    printable: true,
    locked: false,
    quantity: 3
  )
  let visibility = service.makeSetPartVisibilityCommand(
    partID: part.id, visible: part.visible, name: part.name)
  let printable = service.makeSetPartPrintableCommand(
    partID: part.id, printable: part.printable, name: part.name)
  let quantity = service.makeSetPartQuantityCommand(
    partID: part.id, quantity: part.quantity, name: part.name)
  #expect((visibility.payload["kind"] as? String) == "setPartVisibility")
  #expect((printable.payload["kind"] as? String) == "setPartPrintable")
  #expect((quantity.payload["kind"] as? String) == "setPartQuantity")
  #expect((unwrap(visibility.payload["payload"] as? [String: Any])["visible"] as? Bool) == false)
  #expect((unwrap(printable.payload["payload"] as? [String: Any])["printable"] as? Bool) == true)
  #expect((unwrap(quantity.payload["payload"] as? [String: Any])["quantity"] as? Double) == 3)

  #expect(
    (service.makeAlignPartsCommand(partIDs: ["part:a", "part:b"], alignment: "left").payload["kind"]
      as? String) == "alignParts")
  #expect(
    (service.makeDistributePartsCommand(
      partIDs: ["part:a", "part:b", "part:c"], axis: "horizontal"
    ).payload["kind"] as? String) == "distributeParts")

  let entry = PartLibraryEntry(
    id: "entry:a",
    name: part.name,
    sourcePart: part,
    clipboardJSON: "{\"token\":true}",
    createdAt: Date(timeIntervalSince1970: 0)
  )
  let request = service.makeInsertLibraryPartCommand(
    entry: entry,
    newName: "カードポケット 2",
    delta: ModelPoint(xMM: 20, yMM: 10)
  )
  #expect((request.payload["kind"] as? String) == "insertPartLibraryItem")
  let payload = unwrap(request.payload["payload"] as? [String: Any])
  #expect((payload["newPartId"] as? String) == "part:library-part")
  #expect((payload["libraryJson"] as? String) == entry.clipboardJSON)
  #expect((payload["legacySourcePart"] as? [String: Any])?["id"] as? String == part.id)
}

@Test("CommandFactory は線分追加コマンドを生成する")
func command_service_builds_add_line_entity_command() {
  let service = DocumentCommandFactory(uuidProvider: { "fixed-id" })

  let prepared = service.makeAddEntityCommand(
    tool: .line,
    start: .zero,
    end: .init(xMM: 20.0, yMM: 5.0),
    layerID: "layer:cut-line"
  )

  #expect(prepared != nil)
  let payload = unwrap(prepared?.request.payload["payload"] as? [String: Any])
  #expect((prepared?.request.payload["kind"] as? String) == "createEntityFromGesture")
  #expect(prepared?.entityID == "entity:line-fixed-id")
  #expect((payload["id"] as? String) == "entity:line-fixed-id")
  #expect((payload["layerId"] as? String) == "layer:cut-line")
  #expect(payload["styleId"] == nil)
  let gesture = unwrap(payload["gesture"] as? [String: Any])
  #expect((gesture["kind"] as? String) == "line")
  let end = unwrap(gesture["end"] as? [String: Double])
  #expect(end["xMm"] == 20.0)
  #expect(end["yMm"] == 5.0)
}

@Test(
  "CommandFactory は作図時の共有スタイル ID を通常図形へ付与する",
  arguments: [
    (CanvasTool.line, "line", "style:outer-cut-line"),
    (CanvasTool.line, "line", "style:stitch-line"),
    (CanvasTool.arc, "arc", "style:fold-line"),
    (CanvasTool.centerLine, "line", "style:center-line"),
    (CanvasTool.horizontalCenterLine, "line", "style:construction-line"),
    (CanvasTool.verticalCenterLine, "line", "style:dimension-line"),
  ]
)
func command_service_add_entity_command_accepts_drawing_style(
  tool: CanvasTool,
  expectedKind: String,
  styleID: String
) {
  let service = DocumentCommandFactory(uuidProvider: { "styled-id" })

  let prepared = service.makeAddEntityCommand(
    tool: tool,
    start: .zero,
    end: .init(xMM: 20.0, yMM: 5.0),
    layerID: "layer:cut-line",
    styleID: styleID
  )

  let payload = unwrap(prepared?.request.payload["payload"] as? [String: Any])
  #expect((payload["styleId"] as? String) == styleID)
  let gesture = unwrap(payload["gesture"] as? [String: Any])
  #expect((gesture["kind"] as? String) == expectedKind)
}

@Test("CommandFactory は三点円弧コマンドへ共有スタイル ID を付与する")
func command_service_add_arc_command_accepts_drawing_style() {
  let service = DocumentCommandFactory(uuidProvider: { "arc-id" })

  let request = service.makeAddArcEntityCommand(
    center: .zero,
    start: ModelPoint(xMM: 10.0, yMM: 0.0),
    sweepAngleRad: Double.pi / 2,
    layerID: "layer:cut-line",
    styleID: "style:fold-line"
  )

  let payload = unwrap(request?.payload["payload"] as? [String: Any])
  #expect((payload["styleId"] as? String) == "style:fold-line")
  let gesture = unwrap(payload["gesture"] as? [String: Any])
  #expect((gesture["kind"] as? String) == "arc")
}

@Test("CommandFactory は自由テキスト追加・更新・削除コマンドを生成する")
func command_service_builds_free_text_commands() {
  let service = DocumentCommandFactory(uuidProvider: { "free-text-id" })
  let freeText = ProjectFreeText(
    id: "free-text:note",
    content: "Skive edge",
    positionMM: ModelPoint(xMM: 12.0, yMM: -8.0),
    fontSizeMM: 4.5
  )

  let add = service.makeAddFreeTextCommand(freeText)
  #expect((add.payload["kind"] as? String) == "addFreeText")
  let addPayload = unwrap(add.payload["payload"] as? [String: Any])
  #expect((addPayload["id"] as? String) == "free-text:note")
  #expect((addPayload["content"] as? String) == "Skive edge")
  #expect((addPayload["fontSizeMm"] as? Double) == 4.5)
  let position = unwrap(addPayload["positionMm"] as? [String: Double])
  #expect(position["xMm"] == 12.0)
  #expect(position["yMm"] == -8.0)

  let update = service.makeUpdateFreeTextCommand(freeText.withContent("Updated note"))
  #expect((update.payload["kind"] as? String) == "updateFreeText")
  let updatePayload = unwrap(update.payload["payload"] as? [String: Any])
  #expect((updatePayload["content"] as? String) == "Updated note")

  let delete = service.makeDeleteFreeTextCommand(id: "free-text:note")
  #expect((delete.payload["kind"] as? String) == "deleteFreeText")
  #expect((delete.payload["payload"] as? String) == "free-text:note")
}

@Test(
  "CommandFactory は丸穴追加意図コマンドを生成する",
  arguments: [
    ProjectRoundHoleKind.keyRing,
    ProjectRoundHoleKind.rivet,
    ProjectRoundHoleKind.snapFastener,
    ProjectRoundHoleKind.decorative,
  ]
)
func command_service_builds_round_hole_add_command(kind: ProjectRoundHoleKind) {
  let service = DocumentCommandFactory(uuidProvider: { "fixed-id" })

  let request = service.makeAddRoundHoleCommand(
    center: ModelPoint(xMM: 12.0, yMM: -8.0),
    diameterMM: 6.0,
    kind: kind,
    layerID: "layer:cut-line",
    styleID: "style:stitch-line"
  )

  #expect((request?.payload["kind"] as? String) == "createRoundHole")
  let payload = unwrap(request?.payload["payload"] as? [String: Any])
  #expect((payload["id"] as? String) == "round-hole:fixed-id")
  #expect((payload["entityId"] as? String) == "entity:round-hole-fixed-id")
  #expect((payload["diameterMm"] as? Double) == 6.0)
  #expect((payload["roundHoleKind"] as? String) == kind.rawValue)
  #expect((payload["layerId"] as? String) == "layer:cut-line")
  #expect((payload["styleId"] as? String) == "style:stitch-line")
  let center = unwrap(payload["center"] as? [String: Double])
  #expect(center["xMm"] == 12.0)
  #expect(center["yMm"] == -8.0)
}

@Test(
  "CommandFactory は丸穴の不正な直径を拒否する",
  arguments: [0.0, -1.0, Double.infinity]
)
func command_service_rejects_invalid_round_hole_diameter(diameterMM: Double) {
  let service = DocumentCommandFactory(uuidProvider: { "fixed-id" })

  let request = service.makeAddRoundHoleCommand(
    center: .zero,
    diameterMM: diameterMM,
    kind: .keyRing,
    layerID: "layer:cut-line"
  )

  #expect(request == nil)
}

@Test("CommandFactory は丸穴用途変更コマンドを生成する")
func command_service_builds_round_hole_kind_command() {
  let service = DocumentCommandFactory(uuidProvider: { "unused" })
  let roundHole = ProjectRoundHole(
    id: "round-hole:a",
    entityID: "entity:circle",
    kind: .decorative
  )

  let request = service.makeSetRoundHoleKindCommand(roundHoleID: roundHole.id, kind: roundHole.kind)

  #expect((request.payload["kind"] as? String) == "setRoundHoleKind")
  let payload = unwrap(request.payload["payload"] as? [String: Any])
  #expect((payload["roundHoleId"] as? String) == "round-hole:a")
  #expect((payload["kind"] as? String) == "decorative")
}

@Test(
  "CommandFactory は縫い始め点コマンドを生成する",
  arguments: [
    ProjectStitchStartPoint(
      id: "stitch-start:a", targetID: "entity:line", resolvedIndex: nil, positionRatio: 0.25),
    ProjectStitchStartPoint(
      id: "stitch-start:b", targetID: "derived:offset", resolvedIndex: 2, positionRatio: 0.75),
  ]
)
func command_service_builds_stitch_start_point_commands(stitchStartPoint: ProjectStitchStartPoint) {
  let service = DocumentCommandFactory(uuidProvider: { "unused" })

  let add = service.makeAddStitchStartPointCommand(stitchStartPoint)
  #expect((add.payload["kind"] as? String) == "addStitchStartPoint")
  let addPayload = unwrap(add.payload["payload"] as? [String: Any])
  #expect((addPayload["id"] as? String) == stitchStartPoint.id)
  #expect((addPayload["targetId"] as? String) == stitchStartPoint.targetID)
  #expect((addPayload["resolvedIndex"] as? Double).map(Int.init) == stitchStartPoint.resolvedIndex)
  #expect((addPayload["positionRatio"] as? Double) == stitchStartPoint.positionRatio)

  let update = service.makeUpdateStitchStartPointCommand(stitchStartPoint)
  #expect((update.payload["kind"] as? String) == "updateStitchStartPoint")
  let updatePayload = unwrap(update.payload["payload"] as? [String: Any])
  #expect((updatePayload["id"] as? String) == stitchStartPoint.id)
  #expect((updatePayload["targetId"] as? String) == stitchStartPoint.targetID)
  #expect(
    (updatePayload["resolvedIndex"] as? Double).map(Int.init) == stitchStartPoint.resolvedIndex)
  #expect((updatePayload["positionRatio"] as? Double) == stitchStartPoint.positionRatio)

  let delete = service.makeDeleteStitchStartPointCommand(id: stitchStartPoint.id)
  #expect((delete.payload["kind"] as? String) == "deleteStitchStartPoint")
  #expect((delete.payload["payload"] as? String) == stitchStartPoint.id)
}

@Test("CommandFactory はCore移動意図コマンドを生成する")
func command_service_builds_core_move_intent_commands() {
  let service = DocumentCommandFactory()

  let moveEntities = unwrap(
    service.makeMoveEntitiesCommand(
      entityIDs: ["entity:b", "entity:a"],
      delta: ModelPoint(xMM: 4.0, yMM: -3.0),
      allowSingleLineStretch: true,
      successMessage: "moved"
    ))
  #expect((moveEntities.payload["kind"] as? String) == "moveEntities")
  let movePayload = unwrap(moveEntities.payload["payload"] as? [String: Any])
  #expect((movePayload["entityIds"] as? [String]) == ["entity:a", "entity:b"])
  #expect((movePayload["allowSingleLineStretch"] as? Bool) == true)
  let delta = unwrap(movePayload["delta"] as? [String: Double])
  #expect(delta["xMm"] == 4.0)
  #expect(delta["yMm"] == -3.0)

  let target = CanvasSelectionTarget(
    entityID: "entity:line",
    entityLabel: "Line",
    entityKind: .lineSegment,
    controlPoint: .start,
    point: .zero
  )
  let moveControlPoint = unwrap(
    service.makeMoveControlPointCommand(
      target: target,
      position: ModelPoint(xMM: 10.0, yMM: 2.0),
      allowProjection: true
    ))
  #expect((moveControlPoint.payload["kind"] as? String) == "moveControlPoint")
  let controlPayload = unwrap(moveControlPoint.payload["payload"] as? [String: Any])
  #expect((controlPayload["allowProjection"] as? Bool) == true)
  let position = unwrap(controlPayload["position"] as? [String: Double])
  #expect(position["xMm"] == 10.0)
  #expect(position["yMm"] == 2.0)
  let controlTarget = unwrap(controlPayload["target"] as? [String: Any])
  let controlPoint = unwrap(controlTarget["controlPoint"] as? [String: Any])
  #expect((controlPoint["entity_id"] as? String) == "entity:line")
  #expect((controlPoint["point"] as? String) == "start")
}

@Test("CommandFactory は拘束追加コマンドを生成する")
func command_service_builds_add_constraint_command() {
  let service = DocumentCommandFactory(uuidProvider: { "constraint-id" })

  let request = service.makeAddConstraintCommand(
    kind: "distance",
    displayName: "距離",
    targets: [["entity": "entity:line-a"]],
    value: ["fixedMm": 32.5]
  )

  #expect((request.payload["kind"] as? String) == "addConstraint")
  let payload = unwrap(request.payload["payload"] as? [String: Any])
  #expect((payload["id"] as? String) == "constraint:distance-constraint-id")
  #expect((payload["kind"] as? String) == "distance")
  #expect((payload["value"] as? [String: Double])?["fixedMm"] == 32.5)
  #expect(request.successMessage == "距離拘束を追加しました")
}

@Test("CommandFactory はオフセット線追加コマンドを生成する")
func command_service_builds_add_offset_curve_command() {
  let service = DocumentCommandFactory(uuidProvider: { "offset-id" })

  let request = service.makeAddOffsetCurveCommand(
    sourceEntityIDs: ["entity:line-a"],
    distance: ["fixedMm": 3.0],
    direction: "left",
    layerID: "layer:cut-line"
  )

  #expect((request.payload["kind"] as? String) == "addDerivedElement")
  let payload = unwrap(request.payload["payload"] as? [String: Any])
  #expect((payload["id"] as? String) == "derived:offset-offset-id")
  #expect((payload["layerId"] as? String) == "layer:cut-line")
  let kind = unwrap(payload["kind"] as? [String: Any])
  let offset = unwrap(kind["offsetCurve"] as? [String: Any])
  #expect((offset["sourceEntityIds"] as? [String]) == ["entity:line-a"])
  #expect((offset["distance"] as? [String: Double])?["fixedMm"] == 3.0)
  #expect((offset["direction"] as? String) == "left")
  #expect(request.successMessage == "オフセット線を追加しました")
}

@Test(
  "CommandFactory はオフセット線追加コマンドへ共有スタイル ID を付与する",
  arguments: [
    (["entity:line-a"], ["fixedMm": 3.0] as [String: Any], "left"),
    (
      ["entity:line-a", "entity:arc-b"], ["parameter": "parameter:offset"] as [String: Any],
      "inside"
    ),
  ]
)
func command_service_add_offset_curve_command_accepts_drawing_style(
  sourceEntityIDs: [String],
  distance: [String: Any],
  direction: String
) {
  let service = DocumentCommandFactory(uuidProvider: { "styled-offset" })

  let request = service.makeAddOffsetCurveCommand(
    sourceEntityIDs: sourceEntityIDs,
    distance: distance,
    direction: direction,
    layerID: "layer:cut-line",
    styleID: "style:stitch-line"
  )

  let payload = unwrap(request.payload["payload"] as? [String: Any])
  #expect((payload["styleId"] as? String) == "style:stitch-line")
  let kind = unwrap(payload["kind"] as? [String: Any])
  let offset = unwrap(kind["offsetCurve"] as? [String: Any])
  #expect((offset["sourceEntityIds"] as? [String]) == sourceEntityIDs)
  #expect((offset["direction"] as? String) == direction)
  if let fixed = distance["fixedMm"] as? Double {
    #expect((offset["distance"] as? [String: Double])?["fixedMm"] == fixed)
  } else {
    #expect((offset["distance"] as? [String: String])?["parameter"] == "parameter:offset")
  }
}

@Test("CommandFactory はフィレット追加コマンドを生成する")
func command_service_builds_add_fillet_command() {
  let service = DocumentCommandFactory(uuidProvider: { "fillet-id" })

  let request = service.makeAddFilletCommand(
    sourceEntityIDs: ["entity:first", "entity:second"],
    radius: ["fixedMm": 2.0],
    layerID: "layer:cut-line"
  )

  #expect((request.payload["kind"] as? String) == "addDerivedElement")
  let payload = unwrap(request.payload["payload"] as? [String: Any])
  #expect((payload["id"] as? String) == "derived:fillet-fillet-id")
  #expect((payload["layerId"] as? String) == "layer:cut-line")
  let kind = unwrap(payload["kind"] as? [String: Any])
  let fillet = unwrap(kind["fillet"] as? [String: Any])
  #expect((fillet["sourceEntityIds"] as? [String]) == ["entity:first", "entity:second"])
  #expect((fillet["radius"] as? [String: Double])?["fixedMm"] == 2.0)
  #expect(request.successMessage == "フィレットを追加しました。")
}

@Test("CommandFactory は3本以上のフィレット元 ID を保持する")
func command_service_builds_add_fillet_command_with_multiple_sources() {
  let service = DocumentCommandFactory(uuidProvider: { "fillet-id" })

  let request = service.makeAddFilletCommand(
    sourceEntityIDs: ["entity:first", "entity:second", "entity:third"],
    radius: ["fixedMm": 2.0],
    layerID: "layer:cut-line"
  )

  let payload = unwrap(request.payload["payload"] as? [String: Any])
  let kind = unwrap(payload["kind"] as? [String: Any])
  let fillet = unwrap(kind["fillet"] as? [String: Any])
  #expect(
    (fillet["sourceEntityIds"] as? [String]) == [
      "entity:first",
      "entity:second",
      "entity:third",
    ])
}

@Test("CommandFactory はオフセット線更新・削除コマンドを生成する")
func command_service_builds_update_and_delete_offset_curve_commands() {
  let service = DocumentCommandFactory()
  let derivedElement = ProjectDerivedElement(
    id: "derived:offset-a",
    layerID: "layer:cut-line",
    styleID: "style:stitch",
    sourceEntityIDs: ["entity:line-a"],
    distanceMM: nil,
    distanceParameterID: "parameter:offset",
    direction: .right
  )

  let entityLayer = service.makeSetEntityLayerCommand(
    entityID: "entity:line-a", layerID: "layer:guide")
  #expect((entityLayer.payload["kind"] as? String) == "setEntityLayer")
  let entityLayerPayload = unwrap(entityLayer.payload["payload"] as? [String: Any])
  #expect((entityLayerPayload["entityId"] as? String) == "entity:line-a")
  #expect((entityLayerPayload["layerId"] as? String) == "layer:guide")

  let derivedLayer = service.makeSetDerivedLayerCommand(
    derivedElementID: derivedElement.id, layerID: "layer:guide")
  #expect((derivedLayer.payload["kind"] as? String) == "setDerivedLayer")
  let derivedLayerPayload = unwrap(derivedLayer.payload["payload"] as? [String: Any])
  #expect((derivedLayerPayload["derivedElementId"] as? String) == derivedElement.id)
  #expect((derivedLayerPayload["layerId"] as? String) == "layer:guide")

  let update = service.makeSetDerivedSharedStyleCommand(
    derivedElementID: derivedElement.id, styleID: derivedElement.styleID)
  #expect((update.payload["kind"] as? String) == "setDerivedSharedStyle")
  let updatePayload = unwrap(update.payload["payload"] as? [String: Any])
  #expect((updatePayload["derivedElementId"] as? String) == derivedElement.id)
  #expect((updatePayload["styleId"] as? String) == "style:stitch")

  let delete = service.makeDeleteDerivedElementCommand(derivedElement)
  #expect((delete.payload["kind"] as? String) == "deleteDerivedElement")
  #expect((delete.payload["payload"] as? String) == "derived:offset-a")
}

@Test("CommandFactory はフィレット更新コマンドを生成する")
func command_service_builds_update_fillet_command() {
  let service = DocumentCommandFactory()
  let derivedElement = ProjectDerivedElement(
    id: "derived:fillet-a",
    layerID: "layer:cut-line",
    styleID: nil,
    kind: .fillet,
    sourceEntityIDs: ["entity:first", "entity:second"],
    distanceMM: nil,
    distanceParameterID: nil,
    radiusMM: nil,
    radiusParameterID: "parameter:fillet-radius"
  )

  let update = service.makeSetFilletSourcesCommand(
    derivedElementID: derivedElement.id, sourceEntityIDs: derivedElement.sourceEntityIDs,
    closed: true)
  #expect((update.payload["kind"] as? String) == "setFilletSources")
  let updatePayload = unwrap(update.payload["payload"] as? [String: Any])
  #expect((updatePayload["derivedElementId"] as? String) == derivedElement.id)
  #expect((updatePayload["sourceEntityIds"] as? [String]) == derivedElement.sourceEntityIDs)
  #expect((updatePayload["closed"] as? Bool) == true)
}

@Test("CommandFactory は任意掃引角の円弧追加コマンドを生成する")
func command_service_builds_add_arc_entity_command() {
  let service = DocumentCommandFactory(uuidProvider: { "arc-id" })

  let request = service.makeAddArcEntityCommand(
    center: .zero,
    start: .init(xMM: 10.0, yMM: 0.0),
    end: .init(xMM: 0.0, yMM: 10.0),
    layerID: "layer:cut-line"
  )

  #expect(request != nil)
  let payload = unwrap(request?.payload["payload"] as? [String: Any])
  #expect((payload["id"] as? String) == "entity:arc-arc-id")
  let gesture = unwrap(payload["gesture"] as? [String: Any])
  #expect((gesture["kind"] as? String) == "arc")
  #expect((gesture["start"] as? [String: Double])?["xMm"] == 10.0)
  #expect(abs(((gesture["sweepReferenceRad"] as? Double) ?? 0.0) - (.pi / 2.0)) < 0.0001)
}

@Test("CommandFactory は円弧の指定metricだけを部分更新コマンドへ含める")
func command_service_builds_partial_arc_update_command() {
  let service = DocumentCommandFactory()
  let request = service.makeSetArcCommand(
    entityID: "entity:arc-a",
    radiusMM: nil,
    startAngleRad: 0.75,
    sweepAngleRad: nil
  )

  #expect((request.payload["kind"] as? String) == "setEntityMetric")
  let payload = unwrap(request.payload["payload"] as? [String: Any])
  #expect((payload["entityId"] as? String) == "entity:arc-a")
  let metric = unwrap(payload["metric"] as? [String: Any])
  #expect((metric["kind"] as? String) == "arcUpdate")
  #expect((metric["startAngleRad"] as? Double) == 0.75)
  #expect(metric["radiusMm"] == nil)
  #expect(metric["sweepAngleRad"] == nil)
}

@Test("CommandFactory は 180 度超の円弧追加コマンドを生成する")
func command_service_builds_add_arc_entity_command_with_large_sweep_angle() {
  let service = DocumentCommandFactory(uuidProvider: { "large-arc-id" })

  let request = service.makeAddArcEntityCommand(
    center: .zero,
    start: .init(xMM: 10.0, yMM: 0.0),
    sweepAngleRad: degreesToRadians(200.0),
    layerID: "layer:cut-line"
  )

  #expect(request != nil)
  let payload = unwrap(request?.payload["payload"] as? [String: Any])
  #expect((payload["id"] as? String) == "entity:arc-large-arc-id")
  let gesture = unwrap(payload["gesture"] as? [String: Any])
  #expect((gesture["kind"] as? String) == "arc")
  #expect((gesture["start"] as? [String: Double])?["xMm"] == 10.0)
  #expect(
    abs(((gesture["sweepReferenceRad"] as? Double) ?? 0.0) - degreesToRadians(200.0)) < 0.0001)
}

@Test("CommandFactory は実質 360 度の円弧追加コマンドを拒否する")
func command_service_rejects_full_turn_add_arc_entity_command() {
  let service = DocumentCommandFactory(uuidProvider: { "full-turn-arc-id" })

  let request = service.makeAddArcEntityCommand(
    center: .zero,
    start: .init(xMM: 10.0, yMM: 0.0),
    sweepAngleRad: 2.0 * Double.pi,
    layerID: "layer:cut-line"
  )

  #expect(request == nil)
}

@Test("CommandFactory は複合コマンドを生成する")
func command_service_builds_compound_command() {
  let service = DocumentCommandFactory()
  let first = DocumentCommandRequest(
    payload: ["kind": "addEntity", "payload": ["id": "entity:line-a"]],
    successMessage: "線分を追加しました"
  )
  let second = DocumentCommandRequest(
    payload: ["kind": "addConstraint", "payload": ["id": "constraint:horizontal-a"]],
    successMessage: "水平拘束を追加しました"
  )

  let request = service.makeCompoundCommand([first, second], successMessage: "線分を追加しました")

  #expect((request?.payload["kind"] as? String) == "compound")
  let payload = unwrap(request?.payload["payload"] as? [[String: Any]])
  #expect(payload.count == 2)
  #expect((payload[0]["kind"] as? String) == "addEntity")
  #expect((payload[1]["kind"] as? String) == "addConstraint")
  #expect(request?.successMessage == "線分を追加しました")
  #expect(service.makeCompoundCommand([], successMessage: "empty") == nil)
}

@Test("CommandFactory は拘束更新コマンドを生成する")
func command_service_builds_update_constraint_commands() {
  let service = DocumentCommandFactory()
  let segmentLength = ProjectConstraint(
    id: "constraint:length",
    rawKind: "segmentLength",
    kind: "線分長",
    targets: ["entity:line-a"],
    targetsJSON: #"[{"entity":"entity:line-a"}]"#,
    valueMM: 20.0,
    valueDegrees: nil,
    valueParameterID: nil,
    status: .underConstrained
  )
  let angle = ProjectConstraint(
    id: "constraint:angle",
    rawKind: "angle",
    kind: "角度",
    targets: ["entity:line-a", "entity:line-b"],
    targetsJSON: #"[{"entity":"entity:line-a"},{"entity":"entity:line-b"}]"#,
    valueMM: nil,
    valueDegrees: 45.0,
    valueParameterID: nil,
    status: .underConstrained
  )
  let parameter = ProjectParameter(
    id: "parameter:width",
    name: "width",
    valueMM: 25.0,
    unit: "millimeter",
    memo: "",
    usageCount: 0,
    usedConstraintIDs: []
  )

  let valueRequest = service.makeUpdateConstraintValueCommand(segmentLength, valueMM: 32.0)
  let angleRequest = service.makeUpdateConstraintValueCommand(angle, valueMM: 90.0)
  let parameterRequest = service.makeUpdateConstraintParameterCommand(
    segmentLength, parameter: parameter)

  let valuePayload = unwrap(valueRequest?.payload["payload"] as? [String: Any])
  #expect((valueRequest?.payload["kind"] as? String) == "setConstraintValue")
  #expect((valuePayload["constraintId"] as? String) == segmentLength.id)
  #expect((valuePayload["value"] as? [String: Double])?["fixedMm"] == 32.0)

  let anglePayload = unwrap(angleRequest?.payload["payload"] as? [String: Any])
  #expect((angleRequest?.payload["kind"] as? String) == "setConstraintValue")
  #expect((anglePayload["constraintId"] as? String) == "constraint:angle")
  #expect((anglePayload["value"] as? [String: Double])?["fixedDegrees"] == 90.0)

  let parameterPayload = unwrap(parameterRequest?.payload["payload"] as? [String: Any])
  #expect((parameterRequest?.payload["kind"] as? String) == "setConstraintParameter")
  #expect((parameterPayload["constraintId"] as? String) == segmentLength.id)
  #expect((parameterPayload["parameterId"] as? String) == "parameter:width")

  #expect(service.makeUpdateConstraintValueCommand(segmentLength, valueMM: 0) == nil)
  #expect(service.makeUpdateConstraintValueCommand(angle, valueMM: .infinity) == nil)
  #expect(service.makeUpdateConstraintParameterCommand(angle, parameter: parameter) == nil)
}

@Test("DocumentCommandFactory はレイヤー追加コマンドを生成する")
func command_service_builds_add_layer_command() {
  let service = DocumentCommandFactory(uuidProvider: { "layer-id" })

  let request = service.makeAddLayerCommand(number: 3)

  #expect((request.payload["kind"] as? String) == "addLayer")
  let payload = unwrap(request.payload["payload"] as? [String: Any])
  #expect((payload["id"] as? String) == "layer:user-layer-id")
  #expect((payload["name"] as? String) == "レイヤー 3")
  #expect((payload["kind"] as? String) == "cutLine")
  #expect((payload["printable"] as? Bool) == true)
}

@Test("CommandFactory はレイヤースタイル更新コマンドを生成する")
func command_service_builds_set_layer_style_command() {
  let service = DocumentCommandFactory()
  let layer = ProjectLayer(
    id: "layer:cut-line",
    name: "Cut Line",
    kind: .cutLine,
    visible: true,
    printable: true,
    colorHex: "#336699",
    strokeWidthMM: 0.35,
    linePattern: .dashed
  )

  let request = service.makeSetLayerStyleCommand(layer)

  #expect((request.payload["kind"] as? String) == "setLayerStyle")
  let payload = unwrap(request.payload["payload"] as? [String: Any])
  #expect((payload["layerId"] as? String) == "layer:cut-line")
  let style = unwrap(payload["style"] as? [String: Any])
  #expect((style["strokeWidthMm"] as? Double) == 0.35)
  #expect((style["pattern"] as? String) == "dashed")
  let stroke = unwrap(style["stroke"] as? [String: Double])
  #expect(stroke["red"] == 0.2)
  #expect(stroke["green"] == 0.4)
  #expect(stroke["blue"] == 0.6)
  #expect(stroke["alpha"] == 1.0)
}

@Test("CommandFactory は共有スタイルの追加/更新/削除/図形適用コマンドを生成する")
func command_service_builds_shared_style_commands() {
  let service = DocumentCommandFactory(uuidProvider: { "style-id" })
  let add = service.makeAddSharedStyleCommand(number: 2)

  #expect((add.payload["kind"] as? String) == "addSharedStyle")
  let addPayload = unwrap(add.payload["payload"] as? [String: Any])
  #expect((addPayload["id"] as? String) == "style:user-style-id")
  #expect((addPayload["name"] as? String) == "共有スタイル 2")
  let addStyle = unwrap(addPayload["style"] as? [String: Any])
  #expect((addStyle["strokeWidthMm"] as? Double) == 0.2)
  #expect((addStyle["pattern"] as? String) == "solid")
  let addStroke = unwrap(addStyle["stroke"] as? [String: Double])
  #expect(abs((addStroke["red"] ?? 0) - 17.0 / 255.0) < 0.000001)
  #expect(abs((addStroke["green"] ?? 0) - 24.0 / 255.0) < 0.000001)
  #expect(abs((addStroke["blue"] ?? 0) - 39.0 / 255.0) < 0.000001)

  let style = ProjectSharedStyle(
    id: "style:stitch",
    name: "縫い線",
    colorHex: "#336699",
    strokeWidthMM: 0.35,
    linePattern: .dashed
  )
  let update = service.makeUpdateSharedStyleCommand(style)
  #expect((update.payload["kind"] as? String) == "updateSharedStyle")
  let updatePayload = unwrap(update.payload["payload"] as? [String: Any])
  #expect((updatePayload["id"] as? String) == "style:stitch")
  #expect((updatePayload["name"] as? String) == "縫い線")
  let stylePayload = unwrap(updatePayload["style"] as? [String: Any])
  #expect((stylePayload["strokeWidthMm"] as? Double) == 0.35)
  #expect((stylePayload["pattern"] as? String) == "dashed")

  let apply = service.makeSetEntitySharedStyleCommand(
    entityID: "entity:line", styleID: "style:stitch")
  #expect((apply.payload["kind"] as? String) == "setEntitySharedStyle")
  let applyPayload = unwrap(apply.payload["payload"] as? [String: Any])
  #expect((applyPayload["entityId"] as? String) == "entity:line")
  #expect((applyPayload["styleId"] as? String) == "style:stitch")

  let clear = service.makeSetEntitySharedStyleCommand(entityID: "entity:line", styleID: nil)
  let clearPayload = unwrap(clear.payload["payload"] as? [String: Any])
  #expect(clearPayload["styleId"] is NSNull)

  let delete = service.makeDeleteSharedStyleCommand(style)
  #expect((delete.payload["kind"] as? String) == "deleteSharedStyle")
  #expect((delete.payload["payload"] as? String) == "style:stitch")
}

@Test("CommandFactory はパラメータ更新コマンドを生成する")
func command_service_builds_update_parameter_command() {
  let service = DocumentCommandFactory()
  let parameter = ProjectParameter(
    id: "parameter:width",
    name: "width",
    valueMM: 25.0,
    unit: "millimeter",
    memo: "",
    usageCount: 0,
    usedConstraintIDs: []
  )

  let request = service.makeUpdateParameterCommand(parameter)

  #expect((request.payload["kind"] as? String) == "updateParameter")
  let payload = unwrap(request.payload["payload"] as? [String: Any])
  #expect((payload["id"] as? String) == "parameter:width")
  #expect((payload["valueMm"] as? Double) == 25.0)
  #expect(request.successMessage == "width を更新しました")
}

@Test("CommandFactory はプロジェクト名変更コマンドを生成する")
func command_service_builds_rename_document_command() {
  let service = DocumentCommandFactory()

  let request = service.makeRenameDocumentCommand(name: "Pattern A")

  #expect((request.payload["kind"] as? String) == "renameDocument")
  let payload = unwrap(request.payload["payload"] as? [String: Any])
  #expect((payload["name"] as? String) == "Pattern A")
  #expect(request.successMessage == "Pattern A に変更しました")
}

@Test("CadSessionState は内部Adapterを通じてコマンドを実行する")
func cad_session_executes_request_through_document_adapter() {
  let state = makeDocumentState(name: "Executed")
  let store = StubDocumentSessionAdapter(createNewDocumentState: state)
  store.hasDocument = true
  store.applyCommandState = state
  let session = CadSessionState(
    documentAdapter: store,
    coreStatusProvider: { .unavailable("test") }
  )
  let request = DocumentCommandRequest(
    payload: ["kind": "deleteEntity", "payload": "entity:line-a"],
    successMessage: "削除しました"
  )

  let result = session.execute(request, viewMode: .editDisplay)

  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "deleteEntity")
  switch result {
  case .success(let executedState, let successMessage):
    #expect(executedState.snapshot.name == "Executed")
    #expect(successMessage == "削除しました")
    #expect(session.state == executedState)
  case .failure(let message):
    Issue.record("expected success, got failure: \(message)")
  }
}

@Test("CadSessionState はAdapterの実行失敗をそのまま返す")
func cad_session_returns_execution_failure() {
  let state = makeDocumentState(name: "Failure")
  let store = StubDocumentSessionAdapter(createNewDocumentState: state)
  store.hasDocument = true
  store.applyCommandFailure = "backend rejected command"
  let session = CadSessionState(
    documentAdapter: store,
    coreStatusProvider: { .unavailable("test") }
  )
  let request = DocumentCommandRequest(
    payload: ["kind": "deleteEntity", "payload": "entity:line-a"],
    successMessage: "削除しました"
  )

  let result = session.execute(request, viewMode: .editDisplay)

  switch result {
  case .success:
    Issue.record("expected failure")
  case .failure(let message):
    #expect(message == "backend rejected command")
  }
}
