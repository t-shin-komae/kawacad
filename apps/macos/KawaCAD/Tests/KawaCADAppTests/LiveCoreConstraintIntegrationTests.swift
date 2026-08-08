import AppKit
import Foundation
import KawaCADOutput
import Testing

@testable import KawaCADApp

@Test("Live Core 意味境界は preflight・計測・数値編集・縫い始め・clipboard を Swift/Rust 間で往復する")
func live_core_semantic_interface_round_trips_through_swift_and_rust() {
  let session = requireSuccess(
    LeatherCoreProcessAdapter.createDocument(named: "Live Semantic Interface"),
    context: "create live core session"
  )
  let commandFactory = DocumentCommandFactory(uuidProvider: { "live-semantic" })
  let rectangle = [
    lineEntity(id: "entity:bottom", start: .zero, end: ModelPoint(xMM: 20, yMM: 0)),
    lineEntity(
      id: "entity:right", start: ModelPoint(xMM: 20, yMM: 0), end: ModelPoint(xMM: 20, yMM: 10)),
    lineEntity(
      id: "entity:top", start: ModelPoint(xMM: 20, yMM: 10), end: ModelPoint(xMM: 0, yMM: 10)),
    lineEntity(id: "entity:left", start: ModelPoint(xMM: 0, yMM: 10), end: .zero),
  ]
  for entity in rectangle {
    let request = unwrap(commandFactory.makeAddEntityCommand(entity, successMessage: "add"))
    _ = requireSuccess(session.applyCommand(request.payload, viewMode: .editDisplay))
  }

  let preflight = requireSuccess(
    session.preflightDerivedElement(
      kind: .offsetCurve,
      hitEntityID: "entity:bottom",
      selectedEntityIDs: [],
      clickPoint: ModelPoint(xMM: 10, yMM: 5)
    ))
  #expect(preflight.offsetOptions.first?.scope == "closedContour")
  #expect(preflight.offsetOptions.first?.direction == "inward")
  #expect(preflight.offsetOptions.first?.sourceEntityIds.count == 4)

  _ = requireSuccess(
    session.applyCommand(
      commandFactory.makeSetSegmentLengthCommand(entityID: "entity:bottom", valueMM: 30).payload,
      viewMode: .editDisplay
    ))
  let annotation = ProjectMeasurementAnnotation(
    id: "measurement:bottom",
    rawKind: "segmentLength",
    kind: "線分長",
    targets: ["entity:bottom"],
    targetsJSON: #"[{"entity":"entity:bottom"}]"#,
    labelOffsetMM: .zero,
    overallOffsetMM: .zero,
    visible: true
  )
  let addMeasurement = unwrap(commandFactory.makeAddMeasurementAnnotationCommand(annotation))
  _ = requireSuccess(session.applyCommand(addMeasurement.payload, viewMode: .editDisplay))
  let evaluation = requireSuccess(session.evaluateMeasurement(annotationID: annotation.id))
  #expect(evaluation.value == .fixedMm(30))
  let converted = requireSuccess(
    session.applyCommand(
      commandFactory.makeConvertMeasurementCommand(
        annotationID: annotation.id,
        constraintID: "constraint:bottom"
      ).payload,
      viewMode: .editDisplay
    ))
  #expect(converted.constraints.contains { $0.id == "constraint:bottom" && $0.valueMM == 30 })
  #expect(converted.measurementAnnotations.allSatisfy { $0.id != annotation.id })

  var stitchLine = lineEntity(
    id: "entity:stitch",
    start: ModelPoint(xMM: 0, yMM: 20),
    end: ModelPoint(xMM: 100, yMM: 20)
  )
  stitchLine = CanvasEntity(
    id: stitchLine.id,
    label: stitchLine.label,
    kind: stitchLine.kind,
    layerID: stitchLine.layerID,
    styleID: "style:stitch-line",
    geometry: stitchLine.geometry
  )
  let addStitchLine = unwrap(commandFactory.makeAddEntityCommand(stitchLine, successMessage: "add"))
  _ = requireSuccess(session.applyCommand(addStitchLine.payload, viewMode: .editDisplay))
  let place = commandFactory.makePlaceStitchStartPointCommand(
    id: "stitch:start",
    position: ModelPoint(xMM: 40, yMM: 21),
    candidateTargetIDs: [],
    maxDistanceMM: 3
  )
  let placed = requireSuccess(session.applyCommand(place.payload, viewMode: .editDisplay))
  #expect(placed.stitchStartPoints.first { $0.id == "stitch:start" }?.targetID == "entity:stitch")
  #expect(placed.stitchStartPoints.first { $0.id == "stitch:start" }?.positionRatio == 0.4)

  let selection = CoreSelectionReference(
    entityIds: ["entity:stitch"],
    derivedElementIds: [],
    constraintIds: [],
    measurementAnnotationIds: [],
    stitchStartPointIds: [],
    freeTextIds: []
  )
  let exported = requireSuccess(session.exportSelection(selection))
  #expect(exported.rootCount == 1)
  let paste = commandFactory.makePasteSelectionCommand(
    clipboardJSON: exported.clipboardJson,
    dxMM: 5,
    dyMM: 5,
    successMessage: "paste"
  )
  let pasted = requireSuccess(session.applyCommand(paste.payload, viewMode: .editDisplay))
  #expect(pasted.entities.contains { $0.id.hasPrefix("entity:copy-live-semantic:") })
  #expect(pasted.stitchStartPoints.contains { $0.id.hasPrefix("stitch:copy-live-semantic:") })
}

@Test("Live Core Output は複数ページ renderPrint / renderPDF の新インターフェースをSwiftで受け取れる")
func live_core_output_engine_decodes_multi_page_clip_and_paste_up_guides() {
  let session = requireSuccess(
    LeatherCoreProcessAdapter.createDocument(named: "Live Multi Page Output"),
    context: "create live core session"
  )
  let model = liveCoreMultiPageOutputDocumentModel()

  let printData = requireSuccess(
    session.renderPrint(outputDocumentModel: model),
    context: "renderPrint"
  )

  #expect(printData.orientation == .portrait)
  #expect(printData.pages.count == 2)
  #expect(
    printData.pages[0].clipAreaMm
      == OutputPrintableAreaMm(
        leftMm: -105.0,
        rightMm: 105.0,
        topMm: 148.5,
        bottomMm: -148.5
      ))
  let unsplitGraphicEnd = printData.pages[0].commands.compactMap { command -> OutputPointMm? in
    if case .strokeLine(_, let endMm, _, .graphic) = command {
      return endMm
    }
    return nil
  }.first
  #expect(unsplitGraphicEnd == OutputPointMm(xMm: 220.0, yMm: 0.0))
  let guideLabels = printData.pages[0].commands.compactMap { command -> String? in
    if case .drawText(_, let content, .guideLabel, _) = command {
      return content
    }
    return nil
  }
  #expect(guideLabels.contains("PAGE 1/2"))
  #expect(guideLabels.contains("JOIN TOP"))

  let pdfData = requireSuccess(
    session.renderPDF(outputDocumentModel: model),
    context: "renderPDF"
  )

  #expect(pdfData.prefix(8) == Data("%PDF-1.4".utf8))
  #expect(pdfData.range(of: Data("/Count 2".utf8)) != nil)
  #expect(pdfData.range(of: Data("(PAGE 1/2)".utf8)) != nil)
  #expect(pdfData.range(of: Data("(PAGE 2/2)".utf8)) != nil)
}

@MainActor
@Test("Live Core 自由テキストは追加・更新・削除と出力モデル反映ができる")
func live_core_free_text_round_trips_through_swift_boundary() {
  let appState = makeLiveCoreAppState(name: "Live Free Text")

  appState.actions.canvas.selectedTool = .freeText
  appState.actions.canvas.handleCanvasPlacement(ModelPoint(xMM: 12.0, yMM: -8.0))

  let added = unwrap(appState.actions.document.freeTexts.first)
  #expect(added.content == "注記")
  #expect(added.positionMM == ModelPoint(xMM: 12.0, yMM: -8.0))
  #expect(added.fontSizeMM == 4.0)

  let updated =
    added
    .withContent("Skive edge")
    .withPosition(ModelPoint(xMM: 18.0, yMM: -4.0))
    .withFontSize(5.0)
  #expect(appState.actions.canvas.updateFreeText(updated))
  #expect(appState.actions.document.freeTexts.first == updated)

  let output = requireSuccess(
    appState.cadSession.buildOutputDocumentModel(
      options: OutputBuildOptions(
        orientation: .portrait,
        includeDimensionLabels: false,
        includeScaleGuide: true,
        rotationDeg: 0,
        printableAreaMm: OutputPaperDefaults.pdfPrintableAreaMm(for: .portrait)
      )),
    context: "buildOutputDocumentModel"
  )
  let texts = output.outputDocumentModel.pages.flatMap(\.texts)
  let containsFreeText = texts.contains(where: { text in
    text.kind == .freeText
      && text.content == "Skive edge"
      && text.positionMm == OutputPointMm(xMm: 18.0, yMm: -4.0)
      && text.fontSizeMm == 5.0
  })
  let containsGuideLabel = texts.contains(where: { $0.kind == .guideLabel })
  #expect(containsFreeText)
  #expect(containsGuideLabel)

  appState.actions.canvas.deleteSelectedFreeText()
  #expect(appState.actions.document.freeTexts.isEmpty)
}

@MainActor
@Test("Live Core パーツ管理は固定パーツの作成・独立作図・名称更新・解除をSwift境界で扱える")
func live_core_part_management_round_trips_through_swift_boundary() {
  let appState = makeLiveCoreAppState(name: "Live Parts")
  let corners = [
    ModelPoint(xMM: 0.0, yMM: 0.0),
    ModelPoint(xMM: 60.0, yMM: 0.0),
    ModelPoint(xMM: 60.0, yMM: 40.0),
    ModelPoint(xMM: 0.0, yMM: 40.0),
  ]
  for index in corners.indices {
    appState.actions.canvas.applyLineEntityCommand(
      start: corners[index],
      end: corners[(index + 1) % corners.count],
      startTarget: nil,
      endTarget: nil,
      orientation: nil
    )
  }
  let outlineIDs = Set(appState.actions.document.entities.map(\.id))
  appState.actions.canvas.selectedEntityIDs = outlineIDs
  appState.actions.parts.createPartFromSelection()

  let created = unwrap(appState.actions.document.parts.first)
  #expect(created.name == "パーツ 1")
  #expect(Set(created.outlineEntityIDs) == outlineIDs)
  #expect(created.locked)
  #expect(appState.actions.document.currentDocumentState?.snapshot.statistics.partCount == 1)

  appState.actions.canvas.applyLineEntityCommand(
    start: ModelPoint(xMM: 5.0, yMM: 20.0),
    end: ModelPoint(xMM: 55.0, yMM: 20.0),
    startTarget: nil,
    endTarget: nil,
    orientation: nil
  )
  let foldID = unwrap(appState.actions.document.entities.first { !outlineIDs.contains($0.id) }?.id)
  #expect(appState.actions.document.parts.first?.entityIDs.contains(foldID) == false)

  let renamed = created.withMetadata(
    name: "札入れ外装",
    originMM: created.originMM
  )
  #expect(appState.actions.parts.updatePart(renamed))
  #expect(appState.actions.document.parts.first?.name == "札入れ外装")
  #expect(appState.actions.document.parts.first?.originMM == created.originMM)

  appState.actions.parts.deletePart(unwrap(appState.actions.document.parts.first))
  #expect(appState.actions.document.parts.isEmpty)
  #expect(appState.actions.document.entities.count == 5)
}

@Test("Live Core パーツライブラリは不透明データのexport・ID再割り当て・配置結果をSwift境界で扱える")
func live_core_part_library_round_trips_opaque_item_through_swift_boundary() {
  let sourceSession = requireSuccess(
    LeatherCoreProcessAdapter.createDocument(named: "Live Part Library Source"),
    context: "create source session"
  )
  let sourceCommandFactory = DocumentCommandFactory(uuidProvider: { "live-library-source" })
  let outline = CanvasEntity(
    id: "entity:outline",
    label: "Outline",
    kind: .circle,
    layerID: "layer:cut-line",
    geometry: .circle(center: ModelPoint(xMM: 10, yMM: 20), radiusMM: 15)
  )
  let addOutline = unwrap(sourceCommandFactory.makeAddEntityCommand(outline, successMessage: "add"))
  _ = requireSuccess(sourceSession.applyCommand(addOutline.payload, viewMode: .editDisplay))
  let createPart = sourceCommandFactory.makeCreatePartCommand(
    name: "Library Part",
    originMM: ModelPoint(xMM: 10, yMM: 20),
    entityIDs: [outline.id]
  )
  let sourceState = requireSuccess(
    sourceSession.applyCommand(createPart.payload, viewMode: .editDisplay)
  )
  let sourcePart = unwrap(sourceState.parts.first)
  let export = requireSuccess(sourceSession.exportPartLibraryItem(partID: sourcePart.id))

  let entry = PartLibraryEntry(
    id: "library:live",
    name: sourcePart.name,
    sourcePart: export.sourcePart,
    clipboardJSON: export.libraryJSON,
    createdAt: Date(timeIntervalSince1970: 0)
  )
  let targetSession = requireSuccess(
    LeatherCoreProcessAdapter.createDocument(named: "Live Part Library Target"),
    context: "create target session"
  )
  let targetCommandFactory = DocumentCommandFactory(uuidProvider: { "live-library-target" })
  let insert = targetCommandFactory.makeInsertLibraryPartCommand(
    entry: entry,
    newName: "Inserted Part",
    delta: ModelPoint(xMM: 5, yMM: -5)
  )
  let inserted = requireSuccess(
    targetSession.applyCommand(insert.payload, viewMode: .editDisplay)
  )

  #expect(inserted.mutation?.created.partIDs.count == 1)
  #expect(inserted.mutation?.created.entityIDs.count == 1)
  let insertedPart = unwrap(inserted.parts.first)
  #expect(insertedPart.name == "Inserted Part")
  #expect(insertedPart.originMM == ModelPoint(xMM: 15, yMM: 15))
  #expect(insertedPart.entityIDs == inserted.mutation?.created.entityIDs)
}

@MainActor
@Test("Live Core 固定パーツは強調選択・複製・移動・位置指定を一貫して扱える")
func live_core_part_editing_workflow_round_trips_through_swift_boundary() {
  let appState = makeLiveCoreAppState(name: "Live Part Editing")

  func addRectangle(_ corners: [ModelPoint]) -> Set<String> {
    let before = Set(appState.actions.document.entities.map(\.id))
    for index in corners.indices {
      appState.actions.canvas.applyLineEntityCommand(
        start: corners[index],
        end: corners[(index + 1) % corners.count],
        startTarget: nil,
        endTarget: nil,
        orientation: nil
      )
    }
    return Set(appState.actions.document.entities.map(\.id)).subtracting(before)
  }

  let outerIDs = addRectangle([
    ModelPoint(xMM: 0, yMM: 0), ModelPoint(xMM: 80, yMM: 0),
    ModelPoint(xMM: 80, yMM: 50), ModelPoint(xMM: 0, yMM: 50),
  ])
  let innerIDs = addRectangle([
    ModelPoint(xMM: 20, yMM: 15), ModelPoint(xMM: 50, yMM: 15),
    ModelPoint(xMM: 50, yMM: 35), ModelPoint(xMM: 20, yMM: 35),
  ])

  appState.actions.canvas.selectedEntityIDs = outerIDs.union(innerIDs)
  appState.actions.parts.createPartFromSelection()
  let originalID = unwrap(appState.actions.document.parts.first?.id)
  #expect(appState.actions.inspector.inspectorSelectedPartID == originalID)
  #expect(appState.actions.canvas.selectedEntityIDs == outerIDs.union(innerIDs))
  let fixed = unwrap(appState.actions.document.parts.first)
  #expect(fixed.locked)
  #expect(Set(fixed.outlineEntityIDs) == outerIDs)
  #expect(Set(fixed.entityIDs) == outerIDs.union(innerIDs))

  appState.actions.parts.duplicatePart(fixed)
  #expect(appState.actions.document.parts.count == 2)
  let copy = unwrap(liveSelectedInspectorPart(appState))
  #expect(copy.id != originalID)
  #expect(appState.actions.canvas.selectedEntityIDs == Set(copy.entityIDs))
  let duplicatedOrigin = copy.originMM

  #expect(appState.actions.parts.movePart(copy, delta: ModelPoint(xMM: 5, yMM: 3)))
  let moved = unwrap(liveSelectedInspectorPart(appState))
  #expect(
    moved.originMM
      == ModelPoint(
        xMM: duplicatedOrigin.xMM + 5,
        yMM: duplicatedOrigin.yMM + 3
      ))

  appState.actions.parts.beginSettingPartOrigin(moved)
  #expect(appState.actions.inspector.isSettingPartOrigin)
  let beforePositionEntity = unwrap(
    appState.actions.document.entities.first { $0.id == moved.outlineEntityIDs[0] })
  appState.actions.parts.setSelectedPartOrigin(ModelPoint(xMM: 123, yMM: -45))
  #expect(!appState.actions.inspector.isSettingPartOrigin)
  #expect(liveSelectedInspectorPart(appState)?.originMM == ModelPoint(xMM: 123, yMM: -45))
  #expect(appState.actions.canvas.canvasState.selectedPartOrigin == ModelPoint(xMM: 123, yMM: -45))
  let afterPositionEntity = unwrap(
    appState.actions.document.entities.first { $0.id == moved.outlineEntityIDs[0] })
  #expect(afterPositionEntity.geometry != beforePositionEntity.geometry)
}

@MainActor
@Test("Live Core 丸穴は配置・更新・出力モデル反映をSwift境界で扱える")
func live_core_round_hole_round_trips_through_swift_boundary() {
  let appState = makeLiveCoreAppState(name: "Live Round Hole")

  appState.actions.document.setActivePatternLineStyle("style:stitch-line")
  appState.actions.document.setActiveRoundHoleKind(.keyRing)
  #expect(appState.actions.document.setActiveRoundHoleDiameter(6.0))
  appState.actions.canvas.selectedTool = .roundHole
  appState.actions.canvas.handleCanvasPlacement(ModelPoint(xMM: 14.0, yMM: -9.0))

  let added = unwrap(appState.actions.document.roundHoles.first)
  let circle = unwrap(appState.actions.document.entities.first { $0.id == added.entityID })
  #expect(added.kind == .keyRing)
  #expect(circle.styleID == "style:stitch-line")
  #expect(circle.geometry == .circle(center: ModelPoint(xMM: 14.0, yMM: -9.0), radiusMM: 3.0))
  #expect(appState.actions.canvas.selectedEntityID == added.entityID)

  #expect(appState.actions.document.setSelectedRoundHoleKind(.decorative))
  #expect(appState.actions.document.roundHoles.first?.kind == .decorative)

  #expect(appState.actions.document.setSelectedRoundHoleDiameter(8.0))
  let resizedCircle = unwrap(appState.actions.document.entities.first { $0.id == added.entityID })
  #expect(
    resizedCircle.geometry == .circle(center: ModelPoint(xMM: 14.0, yMM: -9.0), radiusMM: 4.0))

  let output = requireSuccess(
    appState.cadSession.buildOutputDocumentModel(
      options: OutputBuildOptions(
        orientation: .portrait,
        includeDimensionLabels: false,
        includeScaleGuide: false,
        rotationDeg: 0,
        printableAreaMm: OutputPaperDefaults.pdfPrintableAreaMm(for: .portrait)
      )),
    context: "buildOutputDocumentModel"
  )
  let graphic = unwrap(
    output.outputDocumentModel.pages
      .flatMap(\.graphics)
      .first { $0.entityId == added.entityID })
  #expect(graphic.kind == .circle)
  if case .circle(let centerMm, let radiusMm) = graphic.geometry {
    #expect(centerMm == OutputPointMm(xMm: 14.0, yMm: -9.0))
    #expect(radiusMm == 4.0)
  } else {
    Issue.record("expected round hole output to be a circle")
  }
  #expect(graphic.style.pattern == .dashed)
}

@MainActor
@Test("Live Core 縫い始め点は縫い線への配置・保存状態・出力モデル反映をSwift境界で扱える")
func live_core_stitch_start_point_round_trips_through_swift_boundary() {
  let appState = makeLiveCoreAppState(name: "Live Stitch Start")

  appState.actions.document.setActivePatternLineStyle("style:stitch-line")
  appState.actions.canvas.applyLineEntityCommand(
    start: ModelPoint(xMM: 0.0, yMM: 0.0),
    end: ModelPoint(xMM: 100.0, yMM: 0.0),
    startTarget: nil,
    endTarget: nil,
    orientation: nil
  )
  let stitchLine = unwrap(appState.actions.document.entities.first)
  #expect(stitchLine.styleID == "style:stitch-line")

  appState.actions.canvas.selectedTool = .stitchStartPoint
  appState.actions.canvas.handleCanvasPlacement(ModelPoint(xMM: 40.0, yMM: 0.0))

  let stitchStartPoint = unwrap(appState.actions.document.stitchStartPoints.first)
  #expect(stitchStartPoint.targetID == stitchLine.id)
  #expect(stitchStartPoint.resolvedIndex == nil)
  #expect(abs(stitchStartPoint.positionRatio - 0.4) < 0.000_001)
  #expect(appState.actions.canvas.selectedStitchStartPointID == stitchStartPoint.id)

  let output = requireSuccess(
    appState.cadSession.buildOutputDocumentModel(
      options: OutputBuildOptions(
        orientation: .portrait,
        includeDimensionLabels: false,
        includeScaleGuide: false,
        rotationDeg: 0,
        printableAreaMm: OutputPaperDefaults.pdfPrintableAreaMm(for: .portrait)
      )),
    context: "buildOutputDocumentModel"
  )
  let marker = unwrap(
    output.outputDocumentModel.pages
      .flatMap(\.graphics)
      .first { $0.entityId == stitchStartPoint.id })
  #expect(marker.kind == .point)
  if case .point(let positionMm) = marker.geometry {
    #expect(positionMm == OutputPointMm(xMm: 40.0, yMm: 0.0))
  } else {
    Issue.record("expected stitch start marker output to be a point")
  }
}

@MainActor
@Test("Live Core 共有スタイルは初期プリセットをSwift境界で受け取り編集・図形適用・出力反映できる")
func live_core_shared_style_round_trips_through_swift_boundary() {
  let appState = makeLiveCoreAppState(name: "Live Shared Style")
  #expect(
    appState.actions.document.sharedStyles.map(\.id) == [
      "style:outer-cut-line",
      "style:stitch-line",
      "style:fold-line",
      "style:center-line",
      "style:construction-line",
      "style:dimension-line",
    ])
  #expect(
    appState.actions.document.sharedStyles.map(\.name) == [
      "外形カット線", "縫い線", "折り線", "中心線", "補助線", "寸法線",
    ])

  appState.actions.canvas.applyEntityCommand(
    for: .line,
    start: ModelPoint(xMM: 0.0, yMM: 0.0),
    end: ModelPoint(xMM: 30.0, yMM: 0.0)
  )
  let entity = unwrap(appState.actions.document.entities.first)

  let style = unwrap(
    appState.actions.document.sharedStyles.first(where: { $0.id == "style:stitch-line" }))
  let updatedStyle = ProjectSharedStyle(
    id: style.id,
    name: "縫い線",
    colorHex: "#DC2626",
    strokeWidthMM: 0.45,
    linePattern: .dashed
  )
  #expect(appState.actions.document.updateSharedStyle(updatedStyle))
  appState.actions.canvas.selectedEntityID = entity.id
  appState.actions.canvas.selectedEntityIDs = [entity.id]
  #expect(appState.actions.document.setSelectedEntitiesSharedStyle(style.id))
  #expect(appState.actions.canvas.selectedEntity?.styleID == style.id)

  let output = requireSuccess(
    appState.cadSession.buildOutputDocumentModel(
      options: OutputBuildOptions(
        orientation: .portrait,
        includeDimensionLabels: false,
        includeScaleGuide: false,
        rotationDeg: 0,
        printableAreaMm: OutputPaperDefaults.pdfPrintableAreaMm(for: .portrait)
      )),
    context: "buildOutputDocumentModel"
  )
  let graphic = unwrap(output.outputDocumentModel.pages.flatMap(\.graphics).first)
  #expect(graphic.style.strokeWidthMm == 0.45)
  #expect(graphic.style.pattern == .dashed)
  #expect(graphic.style.stroke.red > 0.85)
}

@MainActor
@Test("Live Core 派生要素共有スタイルはSwift境界で適用・解除・出力反映できる")
func live_core_derived_element_shared_style_round_trips_through_swift_boundary() {
  let appState = makeLiveCoreAppState(name: "Live Derived Shared Style")
  let source = addLiveLine(
    appState,
    idHint: "source",
    start: ModelPoint(xMM: 0.0, yMM: 0.0),
    end: ModelPoint(xMM: 30.0, yMM: 0.0)
  )

  appState.actions.canvas.selectedTool = .offset
  appState.actions.constraints.handleConstraintTargetSelection(
    clickedLineTarget(source, at: ModelPoint(xMM: 10.0, yMM: 2.0)))
  appState.actions.constraints.updatePendingConstraintValueText("3.0")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  let derived = unwrap(appState.actions.document.derivedElements.last)
  let resolved = unwrap(
    appState.actions.document.entities.first { $0.id.hasPrefix("\(derived.id):resolved:") })
  let style = unwrap(
    appState.actions.document.sharedStyles.first(where: { $0.id == "style:stitch-line" }))
  appState.actions.canvas.selectedEntityID = resolved.id
  appState.actions.canvas.selectedEntityIDs = [resolved.id]

  #expect(appState.actions.document.setSelectedEntitiesSharedStyle(style.id))
  #expect(appState.actions.canvas.selectedDerivedElement?.styleID == style.id)
  #expect(appState.actions.canvas.selectedEntity?.styleID == style.id)

  let output = requireSuccess(
    appState.cadSession.buildOutputDocumentModel(
      options: OutputBuildOptions(
        orientation: .portrait,
        includeDimensionLabels: false,
        includeScaleGuide: false,
        rotationDeg: 0,
        printableAreaMm: OutputPaperDefaults.pdfPrintableAreaMm(for: .portrait)
      )),
    context: "buildOutputDocumentModel"
  )
  let derivedGraphic = unwrap(
    output.outputDocumentModel.pages
      .flatMap(\.graphics)
      .first { $0.entityId.hasPrefix("\(derived.id):resolved:") })
  #expect(derivedGraphic.style.pattern == .dashed)

  #expect(appState.actions.document.setSelectedEntitiesSharedStyle(nil))
  #expect(appState.actions.canvas.selectedDerivedElement?.styleID == nil)
  #expect(appState.actions.canvas.selectedEntity?.styleID == nil)
}

@MainActor
@Test("Live Core 型紙線種セレクタは作図・拘束付きオフセット作成時に共有スタイルを境界へ渡して出力反映する")
func live_core_pattern_line_style_selector_applies_styles_when_creating_geometry() {
  let appState = makeLiveCoreAppState(name: "Live Pattern Line Style")

  appState.actions.document.setActivePatternLineStyle("style:stitch-line")
  appState.actions.canvas.applyEntityCommand(
    for: .line,
    start: ModelPoint(xMM: 0.0, yMM: 0.0),
    end: ModelPoint(xMM: 30.0, yMM: 0.0)
  )
  let stitchLine = unwrap(appState.actions.document.entities.last)
  #expect(stitchLine.styleID == "style:stitch-line")

  appState.actions.document.setActivePatternLineStyle("style:fold-line")
  appState.actions.canvas.applyArcEntityCommand(
    center: ModelPoint(xMM: 50.0, yMM: 0.0),
    start: ModelPoint(xMM: 60.0, yMM: 0.0),
    end: ModelPoint(xMM: 50.0, yMM: 10.0),
    sweepReferenceRad: Double.pi / 2
  )
  let foldArc = unwrap(appState.actions.document.entities.last { $0.kind == .arc })
  #expect(foldArc.styleID == "style:fold-line")

  appState.actions.document.setActivePatternLineStyle("style:center-line")
  appState.actions.canvas.applyEntityCommand(
    for: .centerLine,
    start: ModelPoint(xMM: 0.0, yMM: 20.0),
    end: ModelPoint(xMM: 30.0, yMM: 20.0)
  )
  let centerLine = unwrap(appState.actions.document.entities.last { $0.kind == .centerLine })
  #expect(centerLine.styleID == "style:center-line")

  appState.actions.canvas.selectedTool = .segmentLength
  appState.actions.constraints.handleConstraintTargetSelection(
    clickedLineTarget(stitchLine, at: ModelPoint(xMM: 8.0, yMM: 0.0)))
  appState.actions.constraints.updatePendingConstraintValueText("30.0")
  appState.actions.constraints.commitPendingConstraintValueEntry()
  #expect(appState.actions.document.constraints.contains { $0.rawKind == "segmentLength" })

  appState.actions.document.setActivePatternLineStyle("style:stitch-line")
  appState.actions.canvas.selectedTool = .offset
  appState.actions.constraints.handleConstraintTargetSelection(
    clickedLineTarget(stitchLine, at: ModelPoint(xMM: 8.0, yMM: 4.0)))
  appState.actions.constraints.updatePendingConstraintValueText("3.0")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  let offset = unwrap(appState.actions.document.derivedElements.last { $0.kind == .offsetCurve })
  let offsetResolved = unwrap(
    appState.actions.document.entities.first { $0.id.hasPrefix("\(offset.id):resolved:") })
  #expect(offset.sourceEntityIDs == [stitchLine.id])
  #expect(offset.styleID == "style:stitch-line")
  #expect(offsetResolved.styleID == "style:stitch-line")

  let output = requireSuccess(
    appState.cadSession.buildOutputDocumentModel(
      options: OutputBuildOptions(
        orientation: .portrait,
        includeDimensionLabels: false,
        includeScaleGuide: false,
        rotationDeg: 0,
        printableAreaMm: OutputPaperDefaults.pdfPrintableAreaMm(for: .portrait)
      )),
    context: "buildOutputDocumentModel"
  )
  let offsetGraphic = unwrap(
    output.outputDocumentModel.pages
      .flatMap(\.graphics)
      .first { $0.entityId.hasPrefix("\(offset.id):resolved:") })
  #expect(offsetGraphic.style.pattern == .dashed)
}

@MainActor
@Test("Live Core OutputDocumentModel は A4グリッド位置をSwiftで受け取れる")
func live_core_output_document_model_decodes_a4_tile_grid_positions() {
  let appState = makeLiveCoreAppState(name: "Live Output Preview Grid")
  _ = addLivePoint(appState, idHint: "top-left", at: ModelPoint(xMM: -210.0, yMM: 297.0))
  _ = addLivePoint(appState, idHint: "bottom-right", at: ModelPoint(xMM: 210.0, yMM: -297.0))

  let result = requireSuccess(
    appState.cadSession.buildOutputDocumentModel(
      options: OutputBuildOptions(
        orientation: .portrait,
        includeDimensionLabels: false,
        includeScaleGuide: false,
        rotationDeg: 0,
        printableAreaMm: OutputPaperDefaults.pdfPrintableAreaMm(for: .portrait)
      )),
    context: "buildOutputDocumentModel"
  )

  #expect(result.outputDocumentModel.pages.map(\.gridColumn) == [-1, 1])
  #expect(result.outputDocumentModel.pages.map(\.gridRow) == [1, -1])
}

@MainActor
@Test("Live Core 直線上拘束は点から線のUI操作相当で追加できる")
func live_core_point_on_line_accepts_point_then_line_ui_flow() {
  let appState = makeLiveCoreAppState(name: "Live Point On Line Point First")
  let point = addLivePoint(appState, idHint: "point", at: ModelPoint(xMM: 4.0, yMM: 6.0))
  let line = addLiveLine(
    appState, idHint: "line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))

  appState.actions.canvas.selectedTool = .pointOnLine
  appState.actions.constraints.handleConstraintTargetSelection(point.entitySelectionTarget)
  appState.actions.constraints.handleConstraintTargetSelection(
    unwrap(line.lineSelectionTargets.first?.target))

  let constraint = unwrap(
    appState.actions.document.constraints.first(where: { $0.rawKind == "pointOnLine" }))
  let targets = unwrap(CoreConstraintTarget.decodeList(from: constraint.targetsJSON))
  #expect(
    targets == [
      .entity(point.id),
      .entity(line.id),
    ])
}

@MainActor
@Test("Live Core E2E 直線上拘束は点選択後の端点クリックを線targetとしてCoreへ渡す")
func live_core_e2e_point_on_line_hit_testing_prefers_line_after_pending_point() {
  let appState = makeLiveCoreAppState(name: "Live E2E Point On Line Hit Testing")
  let point = addLivePoint(appState, idHint: "point", at: ModelPoint(xMM: 4.0, yMM: 6.0))
  let line = addLiveLine(
    appState, idHint: "line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
  let harness = makeLiveCoreCanvasHarness(appState: appState, selectedTool: .pointOnLine)

  harness.click(pointAt(point))
  harness.click(lineStart(line))

  guard
    let constraint = appState.actions.document.constraints.first(where: {
      $0.rawKind == "pointOnLine"
    })
  else {
    Issue.record(
      "expected pointOnLine constraint after AppKit clicks; selected targets: \(harness.selectedTargets.map(\.wireTarget))"
    )
    return
  }
  guard let targets = CoreConstraintTarget.decodeList(from: constraint.targetsJSON) else {
    Issue.record("expected decodable pointOnLine targets")
    return
  }
  #expect(targets == [.entity(point.id), .entity(line.id)])
}

@MainActor
@Test("Live Core E2E #284 距離拘束はキャンバスで線分と点を選択して追加できる")
func live_core_e2e_distance_accepts_clicked_line_and_point_issue_284() {
  let appState = makeLiveCoreAppState(name: "Live E2E Point Line Distance")
  let line = addLiveLine(
    appState,
    idHint: "line",
    start: .zero,
    end: ModelPoint(xMM: 20.0, yMM: 0.0)
  )
  let point = addLivePoint(
    appState,
    idHint: "point",
    at: ModelPoint(xMM: 4.0, yMM: 6.0)
  )
  let harness = makeLiveCoreCanvasHarness(appState: appState, selectedTool: .distance)

  harness.click(translated(pointAt(point), by: ModelPoint(xMM: 1.0, yMM: 1.0)))
  harness.click(ModelPoint(xMM: 10.0, yMM: 0.0))

  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "pointLineDistance")
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.valueText == "6.00")
  appState.actions.constraints.updatePendingConstraintValueText("6.0")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  assertLastLiveConstraint(appState, kind: "pointLineDistance")
  #expect(line.kind == .lineSegment)
}

@MainActor
@Test("Live Core E2E #284 距離拘束はキャンバスで線分と円中心を選択して追加できる")
func live_core_e2e_distance_accepts_clicked_line_and_circle_center_issue_284() {
  let appState = makeLiveCoreAppState(name: "Live E2E Circle Center Line Distance")
  let line = addLiveLine(
    appState,
    idHint: "line",
    start: .zero,
    end: ModelPoint(xMM: 20.0, yMM: 0.0)
  )
  let circle = addLiveCircle(
    appState,
    idHint: "circle",
    center: ModelPoint(xMM: 4.0, yMM: 6.0),
    edge: ModelPoint(xMM: 6.0, yMM: 6.0)
  )
  let harness = makeLiveCoreCanvasHarness(appState: appState, selectedTool: .distance)

  harness.click(ModelPoint(xMM: 10.0, yMM: 0.0))
  harness.click(translated(circleCenter(circle), by: ModelPoint(xMM: 1.0, yMM: 1.0)))

  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "pointLineDistance")
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.valueText == "6.00")
  appState.actions.constraints.updatePendingConstraintValueText("6.0")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  assertLastLiveConstraint(appState, kind: "pointLineDistance")
  #expect(line.kind == .lineSegment)
}

@MainActor
@Test("Live Core E2E #288 接線拘束は重なった線分端点と円弧端点をキャンバスクリックで追加できる")
func live_core_e2e_tangent_accepts_overlapped_line_and_arc_endpoints_issue_288() {
  let appState = makeLiveCoreAppState(name: "Live E2E Tangent Overlapped Endpoints")
  let arc = addLiveArc(
    to: appState,
    idHint: "arc",
    center: ModelPoint(xMM: 10.0, yMM: 0.0),
    radiusMM: 10.0,
    startAngleRad: .pi,
    sweepAngleRad: .pi / 2
  )
  let line = addLiveLine(
    appState,
    idHint: "line",
    start: ModelPoint(xMM: -10.0, yMM: 0.0),
    end: .zero
  )
  let harness = makeLiveCoreCanvasHarness(appState: appState, selectedTool: .tangent)

  harness.click(lineEnd(line))
  harness.click(lineEnd(line))

  guard
    let constraint = appState.actions.document.constraints.first(where: { $0.rawKind == "tangent" })
  else {
    Issue.record(
      "expected tangent constraint after overlapped endpoint clicks; selected targets: \(harness.selectedTargets.map(\.wireTarget)); status: \(appState.actions.document.statusMessage)"
    )
    return
  }
  guard let targets = CoreConstraintTarget.decodeList(from: constraint.targetsJSON) else {
    Issue.record("expected decodable tangent targets")
    return
  }
  #expect(
    targets == [
      .controlPoint(entityID: line.id, point: .end),
      .controlPoint(entityID: arc.id, point: .start),
    ])

  let updatedArc = unwrap(appState.actions.document.entities.first { $0.id == arc.id })
  #expect(pointsAreClose(arcStart(updatedArc), lineEnd(line)))
  #expect(
    vectorsPointSameDirection(
      ModelPoint(xMM: 1.0, yMM: 0.0),
      arcTangentDirection(updatedArc, endpoint: .arcStart)
    ))
}

@MainActor
@Test("Live Core E2E 試作の両端接線化は接線サンプル形状を一致拘束後に作れる")
func live_core_e2e_prototype_smooths_sample_arc_after_coincident_constraints() {
  let appState = makeLiveCoreAppState(name: "Live E2E Smooth Sample Arc")
  let rightLine = addLiveLine(
    appState,
    idHint: "right-line",
    start: ModelPoint(xMM: 5.0, yMM: 65.0),
    end: ModelPoint(xMM: 15.215188501565995, yMM: 19.0430377003132)
  )
  let leftLine = addLiveLine(
    appState,
    idHint: "left-line",
    start: ModelPoint(xMM: -15.0, yMM: 65.0),
    end: ModelPoint(xMM: -25.0, yMM: 20.0)
  )
  let arc = addLiveArc(
    to: appState,
    idHint: "sample-arc",
    center: ModelPoint(xMM: -5.0, yMM: 15.0),
    radiusMM: 20.615528128088304,
    startAngleRad: 0.19739555984988075,
    sweepAngleRad: -3.5839668765665382
  )
  appState.actions.canvas.selectedTool = .coincident
  appState.actions.constraints.handleConstraintTargetSelection(
    unwrap(rightLine.pointSelectionTargets.first { $0.target.controlPoint == .end }?.target)
  )
  let arcAfterRightLine = unwrap(appState.actions.document.entities.first { $0.id == arc.id })
  appState.actions.constraints.handleConstraintTargetSelection(
    unwrap(
      arcAfterRightLine.pointSelectionTargets.first { $0.target.controlPoint == .arcStart }?.target)
  )
  appState.actions.constraints.handleConstraintTargetSelection(
    unwrap(leftLine.pointSelectionTargets.first { $0.target.controlPoint == .end }?.target)
  )
  let arcAfterLeftLine = unwrap(appState.actions.document.entities.first { $0.id == arc.id })
  appState.actions.constraints.handleConstraintTargetSelection(
    unwrap(
      arcAfterLeftLine.pointSelectionTargets.first { $0.target.controlPoint == .arcEnd }?.target)
  )

  let coincidentCount = appState.actions.document.constraints.filter { $0.rawKind == "coincident" }
    .count
  guard coincidentCount == 2 else {
    Issue.record(
      "expected 2 coincident constraints; got \(coincidentCount); targets: \(appState.actions.canvas.pendingConstraintTargets.map(\.wireTarget)); status: \(appState.actions.document.statusMessage)"
    )
    return
  }
  let arcAfterCoincident = unwrap(appState.actions.document.entities.first { $0.id == arc.id })
  guard case .arc(_, _, _, let sweepAfterCoincident) = arcAfterCoincident.geometry else {
    Issue.record("expected sample arc after coincident constraints")
    return
  }
  #expect(sweepAfterCoincident < 0.0)
  #expect(abs(sweepAfterCoincident) > .pi)

  appState.actions.canvas.selectEntity(arc.id)
  appState.actions.constraints.smoothSelectedArcTangenciesPrototype()

  let tangentConstraints = appState.actions.document.constraints.filter { $0.rawKind == "tangent" }
  #expect(tangentConstraints.count == 2)
  let smoothedArc = unwrap(appState.actions.document.entities.first { $0.id == arc.id })
  let smoothedRightLine = unwrap(appState.actions.document.entities.first { $0.id == rightLine.id })
  let smoothedLeftLine = unwrap(appState.actions.document.entities.first { $0.id == leftLine.id })
  #expect(pointsAreClose(arcStart(smoothedArc), lineEnd(smoothedRightLine)))
  #expect(pointsAreClose(arcEnd(smoothedArc), lineEnd(smoothedLeftLine)))
  #expect(
    vectorsPointSameDirection(
      lineDirection(from: lineStart(smoothedRightLine), to: lineEnd(smoothedRightLine)),
      arcTangentDirection(smoothedArc, endpoint: .arcStart)
    ))
  #expect(
    vectorsPointSameDirection(
      lineDirection(from: lineEnd(smoothedLeftLine), to: lineStart(smoothedLeftLine)),
      arcTangentDirection(smoothedArc, endpoint: .arcEnd)
    ))
}

@MainActor
@Test("Live Core E2E 接線2の状態から円弧2点目へ一致拘束を追加できる")
func live_core_e2e_second_arc_endpoint_coincident_after_existing_tangent_is_accepted() {
  let appState = makeLiveCoreAppState(name: "Live E2E Second Arc Endpoint Coincident")
  let leftLine = addLiveLine(
    appState,
    idHint: "left-line",
    start: ModelPoint(xMM: -25.0, yMM: 75.0),
    end: ModelPoint(xMM: -50.00000000000001, yMM: 0.0)
  )
  let rightLine = addLiveLine(
    appState,
    idHint: "right-line",
    start: ModelPoint(xMM: -5.0, yMM: 75.0),
    end: ModelPoint(xMM: 15.0, yMM: 0.0)
  )
  let arc = addLiveArc(
    to: appState,
    idHint: "sample-arc-2",
    center: ModelPoint(xMM: -9.195588473793663, yMM: -13.601470508735437),
    radiusMM: 43.011626335213144,
    startAngleRad: -3.4633432079864352,
    sweepAngleRad: 4.006820802699478
  )

  addLiveConstraint(
    to: appState,
    idHint: "start-coincident",
    kind: "coincident",
    targets: [
      .controlPoint(entityID: leftLine.id, point: .end),
      .controlPoint(entityID: arc.id, point: .start),
    ]
  )
  addLiveConstraint(
    to: appState,
    idHint: "left-start-fixed",
    kind: "fixed",
    targets: [.controlPoint(entityID: leftLine.id, point: .start)]
  )
  addLiveConstraint(
    to: appState,
    idHint: "right-start-fixed",
    kind: "fixed",
    targets: [.controlPoint(entityID: rightLine.id, point: .start)]
  )
  addLiveConstraint(
    to: appState,
    idHint: "arc-start-fixed",
    kind: "fixed",
    targets: [.controlPoint(entityID: arc.id, point: .start)]
  )
  addLiveConstraint(
    to: appState,
    idHint: "right-end-fixed",
    kind: "fixed",
    targets: [.controlPoint(entityID: rightLine.id, point: .end)]
  )
  addLiveConstraint(
    to: appState,
    idHint: "start-tangent",
    kind: "tangent",
    targets: [
      .controlPoint(entityID: arc.id, point: .start),
      .controlPoint(entityID: leftLine.id, point: .end),
    ]
  )

  let arcBeforeSecondCoincident = unwrap(
    appState.actions.document.entities.first { $0.id == arc.id })
  appState.actions.canvas.selectedTool = .coincident
  appState.actions.constraints.handleConstraintTargetSelection(
    unwrap(
      arcBeforeSecondCoincident.pointSelectionTargets.first { $0.target.controlPoint == .arcEnd }?
        .target)
  )
  appState.actions.constraints.handleConstraintTargetSelection(
    unwrap(rightLine.pointSelectionTargets.first { $0.target.controlPoint == .end }?.target)
  )

  let updatedArc = unwrap(appState.actions.document.entities.first { $0.id == arc.id })
  let updatedRightLine = unwrap(appState.actions.document.entities.first { $0.id == rightLine.id })
  #expect(appState.actions.document.constraints.filter { $0.rawKind == "coincident" }.count == 2)
  #expect(pointsAreClose(arcEnd(updatedArc), lineEnd(updatedRightLine)))
  #expect(pointsAreClose(arcStart(updatedArc), lineEnd(leftLine)))
  #expect(
    appState.actions.document.statusMessage.contains("追加")
      || appState.actions.document.statusMessage.contains("一致"))
}

@MainActor
@Test("Live Core E2E 接線3の未固定線分端点は選択ツールで伸縮できる")
func live_core_e2e_tangent_connected_free_line_endpoint_can_stretch_with_select_tool() {
  let appState = makeLiveCoreAppState(name: "Live E2E Tangent Free Endpoint Stretch")
  let scenario = addLiveTangentThreeScenario(to: appState, idSuffix: "endpoint")

  let target = unwrap(
    scenario.rightLine.pointSelectionTargets.first { $0.target.controlPoint == .start }?.target)
  appState.actions.document.moveControlPoint(target, to: ModelPoint(xMM: -15.0, yMM: 90.0))

  let updatedRightLine = unwrap(
    appState.actions.document.entities.first { $0.id == scenario.rightLine.id })
  let updatedArc = unwrap(appState.actions.document.entities.first { $0.id == scenario.arc.id })
  #expect(pointsAreClose(lineStart(updatedRightLine), ModelPoint(xMM: -15.0, yMM: 90.0)))
  #expect(pointsAreClose(lineEnd(updatedRightLine), lineEnd(scenario.rightLine)))
  #expect(pointsAreClose(arcEnd(updatedArc), lineEnd(updatedRightLine)))
  #expect(
    vectorsPointSameDirection(
      ModelPoint(
        xMM: lineStart(updatedRightLine).xMM - lineEnd(updatedRightLine).xMM,
        yMM: lineStart(updatedRightLine).yMM - lineEnd(updatedRightLine).yMM
      ),
      arcTangentDirection(updatedArc, endpoint: .arcEnd)
    ))
}

@MainActor
@Test("Live Core E2E 接線3の端点ドラッグは線分方向へ射影して伸縮できる")
func live_core_e2e_tangent_connected_line_endpoint_drag_projects_to_stretch_direction() {
  let appState = makeLiveCoreAppState(name: "Live E2E Tangent Endpoint Projected Stretch")
  let scenario = addLiveTangentThreeScenario(to: appState, idSuffix: "projected-endpoint")

  let target = unwrap(
    scenario.leftLine.pointSelectionTargets.first { $0.target.controlPoint == .start }?.target)
  appState.actions.document.moveControlPoint(target, to: ModelPoint(xMM: -30.0, yMM: 90.0))

  let updatedLeftLine = unwrap(
    appState.actions.document.entities.first { $0.id == scenario.leftLine.id })
  let updatedArc = unwrap(appState.actions.document.entities.first { $0.id == scenario.arc.id })
  #expect(pointsAreClose(lineStart(updatedLeftLine), ModelPoint(xMM: -21.0, yMM: 87.0)))
  #expect(pointsAreClose(lineEnd(updatedLeftLine), lineEnd(scenario.leftLine)))
  #expect(pointsAreClose(arcStart(updatedArc), lineEnd(updatedLeftLine)))
  #expect(
    vectorsPointSameDirection(
      ModelPoint(
        xMM: lineEnd(updatedLeftLine).xMM - lineStart(updatedLeftLine).xMM,
        yMM: lineEnd(updatedLeftLine).yMM - lineStart(updatedLeftLine).yMM
      ),
      arcTangentDirection(updatedArc, endpoint: .arcStart)
    ))
}

@MainActor
@Test("Live Core E2E 接線3の線分本体ドラッグは片端固定時に伸縮へフォールバックする")
func live_core_e2e_tangent_connected_line_body_drag_falls_back_to_stretch() {
  let appState = makeLiveCoreAppState(name: "Live E2E Tangent Line Body Stretch")
  let scenario = addLiveTangentThreeScenario(to: appState, idSuffix: "body")

  appState.actions.document.moveEntities(
    [scenario.rightLine.id],
    delta: ModelPoint(xMM: -5.0, yMM: 15.0),
    duplicating: false
  )

  let updatedRightLine = unwrap(
    appState.actions.document.entities.first { $0.id == scenario.rightLine.id })
  let updatedArc = unwrap(appState.actions.document.entities.first { $0.id == scenario.arc.id })
  #expect(pointsAreClose(lineStart(updatedRightLine), ModelPoint(xMM: -15.0, yMM: 90.0)))
  #expect(pointsAreClose(lineEnd(updatedRightLine), lineEnd(scenario.rightLine)))
  #expect(pointsAreClose(arcEnd(updatedArc), lineEnd(updatedRightLine)))
  #expect(
    vectorsPointSameDirection(
      ModelPoint(
        xMM: lineStart(updatedRightLine).xMM - lineEnd(updatedRightLine).xMM,
        yMM: lineStart(updatedRightLine).yMM - lineEnd(updatedRightLine).yMM
      ),
      arcTangentDirection(updatedArc, endpoint: .arcEnd)
    ))
}

@MainActor
@Test("Live Core 境界 moveEntities は通常移動をCore側で適用できる")
func live_core_move_entities_command_translates_existing_entities() {
  let appState = makeLiveCoreAppState(name: "Live Move Entities Command")
  let line = addLiveLine(
    appState,
    idHint: "move-line",
    start: .zero,
    end: ModelPoint(xMM: 20.0, yMM: 0.0)
  )

  let command = CoreDocumentCommand(
    kind: .moveEntities,
    payload: .object([
      "entityIds": .array([.string(line.id)]),
      "delta": CorePoint(xMm: 4.0, yMm: -3.0).jsonValue,
      "allowSingleLineStretch": .bool(false),
    ])
  )

  #expect(applyLiveCoreCommand(command, to: appState))

  let movedLine = unwrap(appState.actions.document.entities.first { $0.id == line.id })
  #expect(pointsAreClose(lineStart(movedLine), ModelPoint(xMM: 4.0, yMM: -3.0)))
  #expect(pointsAreClose(lineEnd(movedLine), ModelPoint(xMM: 24.0, yMM: -3.0)))
}

@MainActor
@Test("Live Core 境界 moveEntities は拘束で全体移動できない単線をCore側で伸縮へフォールバックできる")
func live_core_move_entities_command_falls_back_to_single_line_stretch() {
  let appState = makeLiveCoreAppState(name: "Live Move Entities Stretch Fallback")
  let scenario = addLiveTangentThreeScenario(to: appState, idSuffix: "core-move-body")
  let command = CoreDocumentCommand(
    kind: .moveEntities,
    payload: .object([
      "entityIds": .array([.string(scenario.rightLine.id)]),
      "delta": CorePoint(xMm: -5.0, yMm: 15.0).jsonValue,
      "allowSingleLineStretch": .bool(true),
    ])
  )

  #expect(applyLiveCoreCommand(command, to: appState))

  let updatedRightLine = unwrap(
    appState.actions.document.entities.first { $0.id == scenario.rightLine.id })
  let updatedArc = unwrap(appState.actions.document.entities.first { $0.id == scenario.arc.id })
  #expect(pointsAreClose(lineStart(updatedRightLine), ModelPoint(xMM: -15.0, yMM: 90.0)))
  #expect(pointsAreClose(lineEnd(updatedRightLine), lineEnd(scenario.rightLine)))
  #expect(pointsAreClose(arcEnd(updatedArc), lineEnd(updatedRightLine)))
}

@MainActor
@Test("Live Core 境界 moveControlPoint は線分端点を元方向へ射影してCore側で伸縮できる")
func live_core_move_control_point_command_projects_line_endpoint_to_stretch_direction() {
  let appState = makeLiveCoreAppState(name: "Live Move Control Point Projection")
  let scenario = addLiveTangentThreeScenario(to: appState, idSuffix: "core-control-point")
  let command = CoreDocumentCommand(
    kind: .moveControlPoint,
    payload: .object([
      "target":
        CoreConstraintTarget
        .controlPoint(entityID: scenario.leftLine.id, point: .start)
        .jsonValue,
      "position": CorePoint(xMm: -30.0, yMm: 90.0).jsonValue,
      "allowProjection": .bool(true),
    ])
  )

  #expect(applyLiveCoreCommand(command, to: appState))

  let updatedLeftLine = unwrap(
    appState.actions.document.entities.first { $0.id == scenario.leftLine.id })
  let updatedArc = unwrap(appState.actions.document.entities.first { $0.id == scenario.arc.id })
  #expect(pointsAreClose(lineStart(updatedLeftLine), ModelPoint(xMM: -21.0, yMM: 87.0)))
  #expect(pointsAreClose(lineEnd(updatedLeftLine), lineEnd(scenario.leftLine)))
  #expect(pointsAreClose(arcStart(updatedArc), lineEnd(updatedLeftLine)))
}

@MainActor
@Test("Live Core 境界 preflightConstraint は寸法拘束と計測表示の初期値をCore側で返す")
func live_core_preflight_constraint_returns_dimension_initial_values() {
  let appState = makeLiveCoreAppState(name: "Live Dimension Preflight")
  let point = addLivePoint(appState, idHint: "point", at: ModelPoint(xMM: 3.0, yMM: 4.0))
  let line = addLiveLine(
    appState,
    idHint: "line",
    start: .zero,
    end: ModelPoint(xMM: 20.0, yMM: 0.0)
  )
  let circle = addLiveCircle(
    appState,
    idHint: "circle",
    center: ModelPoint(xMM: 12.0, yMM: 4.0),
    edge: ModelPoint(xMM: 17.0, yMM: 4.0)
  )

  let pointLine = requireSuccess(
    appState.cadSession.preflightConstraint(
      kind: "distance",
      targets: [
        point.entitySelectionTarget.wireTarget,
        unwrap(line.lineSelectionTargets.first?.target.wireTarget),
      ]
    ),
    context: "preflight point-line distance"
  )
  #expect(pointLine.kind == "pointLineDistance")
  #expect(pointLine.value == CoreConstraintValue.fixedMm(4.0))

  let horizontal = requireSuccess(
    appState.cadSession.preflightConstraint(
      kind: "horizontalDistance",
      targets: [
        point.entitySelectionTarget.wireTarget,
        circle.entitySelectionTarget.wireTarget,
      ]
    ),
    context: "preflight horizontal distance"
  )
  #expect(horizontal.kind == "horizontalDistance")
  #expect(horizontal.value == CoreConstraintValue.fixedMm(9.0))
  #expect(
    horizontal.normalizedTargets == [
      .entity(point.id),
      .controlPoint(entityID: circle.id, point: .center),
    ])

  let segmentLength = requireSuccess(
    appState.cadSession.preflightConstraint(
      kind: "segmentLength",
      targets: [unwrap(line.lineSelectionTargets.first?.target.wireTarget)]
    ),
    context: "preflight segment length"
  )
  #expect(segmentLength.kind == "segmentLength")
  #expect(segmentLength.value == CoreConstraintValue.fixedMm(20.0))

  let diameter = requireSuccess(
    appState.cadSession.preflightConstraint(
      kind: "diameter",
      targets: [circle.entitySelectionTarget.wireTarget]
    ),
    context: "preflight diameter"
  )
  #expect(diameter.kind == "diameter")
  #expect(diameter.value == CoreConstraintValue.fixedMm(10.0))
}

@MainActor
@Test("Live Core #286 円弧掃引角のインスペクタ同値コミットは 180 度超の値を保持する")
func live_core_arc_sweep_inspector_commit_preserves_large_sweep_issue_286() {
  let appState = makeLiveCoreAppState(name: "Live Large Arc Sweep Inspector Commit")
  let arc = addLiveArc(
    to: appState,
    idHint: "large-sweep",
    center: ModelPoint(xMM: -20.0, yMM: 65.0),
    radiusMM: 44.72135954999579,
    startAngleRad: 2.677945044588987,
    sweepAngleRad: 5.695182703632019
  )
  appState.actions.canvas.selectEntity(arc.id)

  #expect(
    appState.actions.document.setSelectedArc(
      radiusMM: 44.72135954999579,
      startAngleRad: 2.677945044588987,
      sweepAngleRad: degreesToRadians(326.31)
    ))

  guard let updated = appState.actions.document.entities.first(where: { $0.id == arc.id }),
    case .arc(_, _, _, let sweepAngleRad) = updated.geometry
  else {
    Issue.record("expected updated large-sweep arc")
    return
  }
  #expect(abs(radiansToDegrees(sweepAngleRad) - 326.31) < 0.001)
}

@MainActor
@Test("Live Core E2E #281 対称拘束は通常線軸クリックでも追加できる")
func live_core_e2e_symmetric_accepts_normal_line_axis_issue_281() {
  let appState = makeLiveCoreAppState(name: "Live E2E Symmetric Normal Line Axis")
  let first = addLivePoint(appState, idHint: "first-point", at: ModelPoint(xMM: -6.0, yMM: 4.0))
  let second = addLivePoint(appState, idHint: "second-point", at: ModelPoint(xMM: 6.0, yMM: 4.0))
  let axis = addLiveLine(
    appState,
    idHint: "normal-axis-line",
    start: ModelPoint(xMM: 0.0, yMM: -10.0),
    end: ModelPoint(xMM: 0.0, yMM: 10.0)
  )
  let harness = makeLiveCoreCanvasHarness(appState: appState, selectedTool: .symmetric)

  harness.click(pointAt(first))
  harness.click(pointAt(second))
  harness.click(ModelPoint(xMM: 0.0, yMM: 0.0))

  #expect(appState.actions.document.constraints.contains { $0.rawKind == "symmetric" })
  #expect(axis.kind == .lineSegment)
}

@MainActor
@Test("Live Core 幾何拘束ツールマトリクスは代表UI操作フローを受理する")
func live_core_geometric_constraint_tool_matrix_accepts_representative_ui_flows() {
  assertLiveConstraint("coincident point-point") { appState in
    let first = addLivePoint(appState, idHint: "first-point", at: .zero)
    let second = addLivePoint(appState, idHint: "second-point", at: ModelPoint(xMM: 5.0, yMM: 5.0))

    appState.actions.canvas.selectedTool = .coincident
    appState.actions.constraints.handleConstraintTargetSelection(first.entitySelectionTarget)
    appState.actions.constraints.handleConstraintTargetSelection(second.entitySelectionTarget)

    assertLastLiveConstraint(appState, kind: "coincident")
  }

  assertLiveConstraint("horizontal line") { appState in
    let line = addLiveLine(
      appState, idHint: "line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 6.0))

    appState.actions.canvas.selectedTool = .horizontal
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(line.lineSelectionTargets.first?.target))

    assertLastLiveConstraint(appState, kind: "horizontal")
  }

  assertLiveConstraint("horizontal point-point") { appState in
    let first = addLivePoint(appState, idHint: "first-point", at: .zero)
    let second = addLivePoint(appState, idHint: "second-point", at: ModelPoint(xMM: 12.0, yMM: 6.0))

    appState.actions.canvas.selectedTool = .horizontal
    appState.actions.constraints.handleConstraintTargetSelection(first.entitySelectionTarget)
    appState.actions.constraints.handleConstraintTargetSelection(second.entitySelectionTarget)

    assertLastLiveConstraint(appState, kind: "horizontal")
  }

  assertLiveConstraint("vertical line") { appState in
    let line = addLiveLine(
      appState, idHint: "line", start: .zero, end: ModelPoint(xMM: 6.0, yMM: 20.0))

    appState.actions.canvas.selectedTool = .vertical
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(line.lineSelectionTargets.first?.target))

    assertLastLiveConstraint(appState, kind: "vertical")
  }

  assertLiveConstraint("vertical point-point") { appState in
    let first = addLivePoint(appState, idHint: "first-point", at: .zero)
    let second = addLivePoint(appState, idHint: "second-point", at: ModelPoint(xMM: 6.0, yMM: 12.0))

    appState.actions.canvas.selectedTool = .vertical
    appState.actions.constraints.handleConstraintTargetSelection(first.entitySelectionTarget)
    appState.actions.constraints.handleConstraintTargetSelection(second.entitySelectionTarget)

    assertLastLiveConstraint(appState, kind: "vertical")
  }

  assertLiveConstraint("parallel line-line") { appState in
    let first = addLiveLine(
      appState, idHint: "first-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
    let second = addLiveLine(
      appState, idHint: "second-line", start: ModelPoint(xMM: 0.0, yMM: 6.0),
      end: ModelPoint(xMM: 16.0, yMM: 12.0))

    appState.actions.canvas.selectedTool = .parallel
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(first.lineSelectionTargets.first?.target))
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(second.lineSelectionTargets.first?.target))

    assertLastLiveConstraint(appState, kind: "parallel")
  }

  assertLiveConstraint("perpendicular line-line") { appState in
    let first = addLiveLine(
      appState, idHint: "first-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
    let second = addLiveLine(
      appState, idHint: "second-line", start: .zero, end: ModelPoint(xMM: 8.0, yMM: 12.0))

    appState.actions.canvas.selectedTool = .perpendicular
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(first.lineSelectionTargets.first?.target))
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(second.lineSelectionTargets.first?.target))

    assertLastLiveConstraint(appState, kind: "perpendicular")
  }

  assertLiveConstraint("tangent line endpoint-arc start") { appState in
    let line = addLiveLine(
      appState,
      idHint: "line",
      start: ModelPoint(xMM: -10.0, yMM: 0.0),
      end: .zero
    )
    let arc = addLiveArc(
      to: appState,
      idHint: "arc",
      center: ModelPoint(xMM: 10.0, yMM: 0.0),
      radiusMM: 10.0,
      startAngleRad: .pi,
      sweepAngleRad: .pi / 2
    )

    appState.actions.canvas.selectedTool = .tangent
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(line.pointSelectionTargets.first { $0.target.controlPoint == .end }?.target))
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(arc.pointSelectionTargets.first { $0.target.controlPoint == .arcStart }?.target))

    assertLastLiveConstraint(appState, kind: "tangent")
  }

  assertLiveConstraint("equal length line-line") { appState in
    let first = addLiveLine(
      appState, idHint: "first-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
    let second = addLiveLine(
      appState, idHint: "second-line", start: ModelPoint(xMM: 0.0, yMM: 6.0),
      end: ModelPoint(xMM: 8.0, yMM: 12.0))

    appState.actions.canvas.selectedTool = .equalLength
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(first.lineSelectionTargets.first?.target))
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(second.lineSelectionTargets.first?.target))

    assertLastLiveConstraint(appState, kind: "equalSegmentLength")
  }

  assertLiveConstraint("angle shared-endpoint line-line") { appState in
    let first = addLiveLine(
      appState, idHint: "first-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
    let second = addLiveLine(
      appState, idHint: "second-line", start: .zero, end: ModelPoint(xMM: 10.0, yMM: 10.0))

    appState.actions.canvas.selectedTool = .angle
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(first.lineSelectionTargets.first?.target))
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(second.lineSelectionTargets.first?.target))

    assertLastLiveConstraint(appState, kind: "angle")
  }

  assertLiveConstraint("symmetric point-point-axis") { appState in
    let first = addLivePoint(appState, idHint: "first-point", at: ModelPoint(xMM: -6.0, yMM: 4.0))
    let second = addLivePoint(appState, idHint: "second-point", at: ModelPoint(xMM: 4.0, yMM: -6.0))
    let axis = addLiveCenterLine(
      appState, idHint: "axis-line", start: ModelPoint(xMM: -10.0, yMM: -10.0),
      end: ModelPoint(xMM: 10.0, yMM: 10.0))

    appState.actions.canvas.selectedTool = .symmetric
    appState.actions.constraints.handleConstraintTargetSelection(first.entitySelectionTarget)
    appState.actions.constraints.handleConstraintTargetSelection(second.entitySelectionTarget)
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(axis.lineSelectionTargets.first?.target))

    assertLastLiveConstraint(appState, kind: "symmetric")
  }

  assertLiveConstraint("fixed point") { appState in
    let point = addLivePoint(appState, idHint: "point", at: ModelPoint(xMM: 4.0, yMM: 4.0))

    appState.actions.canvas.selectedTool = .fixed
    appState.actions.constraints.handleConstraintTargetSelection(point.entitySelectionTarget)

    assertLastLiveConstraint(appState, kind: "fixed")
  }
}

@MainActor
@Test("Live Core 寸法拘束ツールマトリクスは代表UI操作フローを受理する")
func live_core_dimension_constraint_tool_matrix_accepts_representative_ui_flows() {
  assertLiveConstraint("distance point-point") { appState in
    let first = addLivePoint(appState, idHint: "first-point", at: .zero)
    let second = addLivePoint(appState, idHint: "second-point", at: ModelPoint(xMM: 10.0, yMM: 0.0))

    appState.actions.canvas.selectedTool = .distance
    appState.actions.constraints.handleConstraintTargetSelection(first.entitySelectionTarget)
    appState.actions.constraints.handleConstraintTargetSelection(second.entitySelectionTarget)
    appState.actions.constraints.updatePendingConstraintValueText("10.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    assertLastLiveConstraint(appState, kind: "distance")
  }

  assertLiveConstraint("distance point-line") { appState in
    let line = addLiveLine(
      appState, idHint: "line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
    let point = addLivePoint(appState, idHint: "point", at: ModelPoint(xMM: 4.0, yMM: 6.0))

    appState.actions.canvas.selectedTool = .distance
    appState.actions.constraints.handleConstraintTargetSelection(point.entitySelectionTarget)
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(line.lineSelectionTargets.first?.target))
    appState.actions.constraints.updatePendingConstraintValueText("6.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    assertLastLiveConstraint(appState, kind: "pointLineDistance")
  }

  assertLiveConstraint("line-line distance") { appState in
    let first = addLiveLine(
      appState, idHint: "first-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
    let second = addLiveLine(
      appState, idHint: "second-line", start: ModelPoint(xMM: 0.0, yMM: 6.0),
      end: ModelPoint(xMM: 20.0, yMM: 6.0))

    appState.actions.canvas.selectedTool = .lineLineDistance
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(first.lineSelectionTargets.first?.target))
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(second.lineSelectionTargets.first?.target))
    appState.actions.constraints.updatePendingConstraintValueText("6.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    assertLastLiveConstraint(appState, kind: "lineLineDistance")
  }

  assertLiveConstraint("segment length") { appState in
    let line = addLiveLine(
      appState, idHint: "line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))

    appState.actions.canvas.selectedTool = .segmentLength
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(line.lineSelectionTargets.first?.target))
    appState.actions.constraints.updatePendingConstraintValueText("20.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    assertLastLiveConstraint(appState, kind: "segmentLength")
  }

  assertLiveConstraint("diameter circle") { appState in
    let circle = addLiveCircle(
      appState, idHint: "circle", center: .zero, edge: ModelPoint(xMM: 5.0, yMM: 0.0))

    appState.actions.canvas.selectedTool = .diameter
    appState.actions.constraints.handleConstraintTargetSelection(circle.entitySelectionTarget)
    appState.actions.constraints.updatePendingConstraintValueText("10.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    assertLastLiveConstraint(appState, kind: "diameter")
  }

  assertLiveConstraint("radius circle") { appState in
    let circle = addLiveCircle(
      appState, idHint: "circle", center: .zero, edge: ModelPoint(xMM: 5.0, yMM: 0.0))

    appState.actions.canvas.selectedTool = .radius
    appState.actions.constraints.handleConstraintTargetSelection(circle.entitySelectionTarget)
    appState.actions.constraints.updatePendingConstraintValueText("5.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    assertLastLiveConstraint(appState, kind: "radius")
  }
}

@MainActor
@Test("Live Core UI/Core target互換マトリクスは選択仕様が許す派生target種別を受理する")
func live_core_ui_core_target_compatibility_matrix_accepts_allowed_target_variants() {
  assertLiveConstraint("horizontal centerLine") { appState in
    let centerLine = addLiveCenterLine(
      appState, idHint: "center-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 6.0))

    appState.actions.canvas.selectedTool = .horizontal
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(centerLine.lineSelectionTargets.first?.target))

    assertLastLiveConstraint(appState, kind: "horizontal")
  }

  assertLiveConstraint("vertical centerLine") { appState in
    let centerLine = addLiveCenterLine(
      appState, idHint: "center-line", start: .zero, end: ModelPoint(xMM: 6.0, yMM: 20.0))

    appState.actions.canvas.selectedTool = .vertical
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(centerLine.lineSelectionTargets.first?.target))

    assertLastLiveConstraint(appState, kind: "vertical")
  }

  assertLiveConstraint("pointOnLine point-centerLine") { appState in
    let point = addLivePoint(appState, idHint: "point", at: ModelPoint(xMM: 4.0, yMM: 6.0))
    let centerLine = addLiveCenterLine(
      appState, idHint: "center-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))

    appState.actions.canvas.selectedTool = .pointOnLine
    appState.actions.constraints.handleConstraintTargetSelection(point.entitySelectionTarget)
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(centerLine.lineSelectionTargets.first?.target))

    assertLastLiveConstraint(appState, kind: "pointOnLine")
  }

  assertLiveConstraint("distance point-centerLine") { appState in
    let point = addLivePoint(appState, idHint: "point", at: ModelPoint(xMM: 4.0, yMM: 6.0))
    let centerLine = addLiveCenterLine(
      appState, idHint: "center-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))

    appState.actions.canvas.selectedTool = .distance
    appState.actions.constraints.handleConstraintTargetSelection(point.entitySelectionTarget)
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(centerLine.lineSelectionTargets.first?.target))
    appState.actions.constraints.updatePendingConstraintValueText("6.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    assertLastLiveConstraint(appState, kind: "pointLineDistance")
  }

  assertLiveConstraint("lineLineDistance centerLine-centerLine") { appState in
    let first = addLiveCenterLine(
      appState, idHint: "first-center-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
    let second = addLiveCenterLine(
      appState, idHint: "second-center-line", start: ModelPoint(xMM: 0.0, yMM: 6.0),
      end: ModelPoint(xMM: 20.0, yMM: 6.0))

    appState.actions.canvas.selectedTool = .lineLineDistance
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(first.lineSelectionTargets.first?.target))
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(second.lineSelectionTargets.first?.target))
    appState.actions.constraints.updatePendingConstraintValueText("6.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    assertLastLiveConstraint(appState, kind: "lineLineDistance")
  }

  assertLiveConstraint("segmentLength centerLine") { appState in
    let centerLine = addLiveCenterLine(
      appState, idHint: "center-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))

    appState.actions.canvas.selectedTool = .segmentLength
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(centerLine.lineSelectionTargets.first?.target))
    appState.actions.constraints.updatePendingConstraintValueText("20.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    assertLastLiveConstraint(appState, kind: "segmentLength")
  }

  assertLiveConstraint("parallel centerLine-line") { appState in
    let first = addLiveCenterLine(
      appState, idHint: "center-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
    let second = addLiveLine(
      appState, idHint: "line", start: ModelPoint(xMM: 0.0, yMM: 6.0),
      end: ModelPoint(xMM: 16.0, yMM: 12.0))

    appState.actions.canvas.selectedTool = .parallel
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(first.lineSelectionTargets.first?.target))
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(second.lineSelectionTargets.first?.target))

    assertLastLiveConstraint(appState, kind: "parallel")
  }

  assertLiveConstraint("perpendicular centerLine-line") { appState in
    let first = addLiveCenterLine(
      appState, idHint: "center-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
    let second = addLiveLine(
      appState, idHint: "line", start: .zero, end: ModelPoint(xMM: 8.0, yMM: 12.0))

    appState.actions.canvas.selectedTool = .perpendicular
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(first.lineSelectionTargets.first?.target))
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(second.lineSelectionTargets.first?.target))

    assertLastLiveConstraint(appState, kind: "perpendicular")
  }

  assertLiveConstraint("equalLength centerLine-line") { appState in
    let first = addLiveCenterLine(
      appState, idHint: "center-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
    let second = addLiveLine(
      appState, idHint: "line", start: ModelPoint(xMM: 0.0, yMM: 6.0),
      end: ModelPoint(xMM: 8.0, yMM: 12.0))

    appState.actions.canvas.selectedTool = .equalLength
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(first.lineSelectionTargets.first?.target))
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(second.lineSelectionTargets.first?.target))

    assertLastLiveConstraint(appState, kind: "equalSegmentLength")
  }

  assertLiveConstraint("angle arc") { appState in
    let arc = addLiveArc(
      appState,
      idHint: "arc",
      center: .zero,
      start: ModelPoint(xMM: 8.0, yMM: 0.0),
      end: ModelPoint(xMM: 0.0, yMM: 8.0)
    )

    appState.actions.canvas.selectedTool = .angle
    appState.actions.constraints.handleConstraintTargetSelection(arc.entitySelectionTarget)
    appState.actions.constraints.updatePendingConstraintValueText("90.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    assertLastLiveConstraint(appState, kind: "angle")
  }

  assertLiveConstraint("radius arc") { appState in
    let arc = addLiveArc(
      appState,
      idHint: "arc",
      center: .zero,
      start: ModelPoint(xMM: 8.0, yMM: 0.0),
      end: ModelPoint(xMM: 0.0, yMM: 8.0)
    )

    appState.actions.canvas.selectedTool = .radius
    appState.actions.constraints.handleConstraintTargetSelection(arc.entitySelectionTarget)
    appState.actions.constraints.updatePendingConstraintValueText("8.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    assertLastLiveConstraint(appState, kind: "radius")
  }
}

@MainActor
@Test("Live Core オフセットツールマトリクスは単体と閉曲線の代表UI操作フローを受理する")
func live_core_offset_tool_matrix_accepts_single_and_closed_contour_ui_flows() {
  assertLiveDerivedElement("offset single line") { appState in
    let line = addLiveLine(
      appState, idHint: "line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 3.0))

    appState.actions.canvas.selectedTool = .offset
    appState.actions.constraints.handleConstraintTargetSelection(
      clickedLineTarget(line, at: ModelPoint(xMM: 8.0, yMM: 5.0)))
    appState.actions.constraints.updatePendingConstraintValueText("2.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    let offset = unwrap(appState.actions.document.derivedElements.last)
    #expect(offset.kind == .offsetCurve)
    #expect(offset.sourceEntityIDs == [line.id])
    #expect(offset.distanceMM == 2.0)
  }

  assertLiveDerivedElement("offset closed contour default") { appState in
    let contour = addLiveRectangleContour(appState)

    appState.actions.canvas.selectedTool = .offset
    appState.actions.constraints.handleConstraintTargetSelection(
      clickedLineTarget(contour.bottom, at: ModelPoint(xMM: 5.0, yMM: 1.0)))

    #expect(
      appState.actions.canvas.pendingConstraintValueDraft?.selectedOffsetSourceScope
        == .closedContour)
    #expect(
      appState.actions.canvas.pendingConstraintValueDraft?.offsetSourceEntityIDs
        == contour.sourceIDs)
    #expect(appState.actions.canvas.pendingConstraintValueDraft?.offsetDirection == "inward")

    appState.actions.constraints.updatePendingConstraintValueText("1.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    let offset = unwrap(appState.actions.document.derivedElements.last)
    #expect(offset.kind == .offsetCurve)
    #expect(offset.sourceEntityIDs == contour.sourceIDs)
    #expect(offset.direction == .inward)
    #expect(offset.distanceMM == 1.0)
  }

  assertLiveDerivedElement("offset closed contour switches to single element") { appState in
    let contour = addLiveRectangleContour(appState)

    appState.actions.canvas.selectedTool = .offset
    appState.actions.constraints.handleConstraintTargetSelection(
      clickedLineTarget(contour.bottom, at: ModelPoint(xMM: 5.0, yMM: -1.0)))
    appState.actions.constraints.updatePendingOffsetSourceScope(.singleElement)
    appState.actions.constraints.updatePendingConstraintValueText("1.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    let offset = unwrap(appState.actions.document.derivedElements.last)
    #expect(offset.kind == .offsetCurve)
    #expect(offset.sourceEntityIDs == [contour.bottom.id])
    #expect(offset.distanceMM == 1.0)
  }

  assertLiveDerivedElement("offset selected range") { appState in
    let contour = addLiveRectangleContour(appState)
    appState.actions.canvas.selectedEntityIDs = [contour.bottom.id, contour.right.id]

    appState.actions.canvas.selectedTool = .offset
    appState.actions.constraints.handleConstraintTargetSelection(
      clickedLineTarget(contour.bottom, at: ModelPoint(xMM: 5.0, yMM: 1.0))
    )

    #expect(
      appState.actions.canvas.pendingConstraintValueDraft?.selectedOffsetSourceScope
        == .selectedRange)
    #expect(
      Set(appState.actions.canvas.pendingConstraintValueDraft?.offsetSourceEntityIDs ?? [])
        == Set([
          contour.bottom.id,
          contour.right.id,
        ]))

    appState.actions.constraints.updatePendingConstraintValueText("1.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    let offset = unwrap(appState.actions.document.derivedElements.last)
    #expect(offset.kind == .offsetCurve)
    #expect(Set(offset.sourceEntityIDs) == Set([contour.bottom.id, contour.right.id]))
    #expect(!offset.sourceEntityIDs.contains(contour.top.id))
    #expect(!offset.sourceEntityIDs.contains(contour.left.id))
  }

  assertLiveDerivedElement("offset selected range on fillet") { appState in
    let bottom = addLiveLine(
      appState,
      idHint: "bottom",
      start: .zero,
      end: ModelPoint(xMM: 20.0, yMM: 0.0)
    )
    let right = addLiveLine(
      appState,
      idHint: "right",
      start: ModelPoint(xMM: 20.0, yMM: 0.0),
      end: ModelPoint(xMM: 20.0, yMM: 20.0)
    )
    let top = addLiveLine(
      appState,
      idHint: "top",
      start: ModelPoint(xMM: 20.0, yMM: 20.0),
      end: ModelPoint(xMM: 0.0, yMM: 20.0)
    )
    let leftExtension = addLiveLine(
      appState,
      idHint: "left-extension",
      start: ModelPoint(xMM: 0.0, yMM: 20.0),
      end: ModelPoint(xMM: 0.0, yMM: 30.0)
    )

    appState.actions.canvas.selectedEntityIDs = []
    appState.actions.canvas.selectedTool = .fillet
    appState.actions.constraints.handleConstraintTargetSelection(
      clickedLineTarget(bottom, at: ModelPoint(xMM: 10.0, yMM: 0.0)))
    appState.actions.constraints.handleConstraintTargetSelection(
      clickedLineTarget(right, at: ModelPoint(xMM: 20.0, yMM: 10.0)))
    appState.actions.constraints.handleConstraintTargetSelection(
      clickedLineTarget(top, at: ModelPoint(xMM: 10.0, yMM: 20.0)))
    appState.actions.constraints.handleConstraintTargetSelection(
      clickedLineTarget(leftExtension, at: ModelPoint(xMM: 0.0, yMM: 25.0)))
    appState.actions.constraints.updatePendingConstraintValueText("2.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    let fillet = unwrap(appState.actions.document.derivedElements.last)
    #expect(fillet.sourceEntityIDs.count == 4)
    let resolvedRight = unwrap(
      appState.actions.document.entities.first(where: {
        $0.id == "\(fillet.id):resolved:2"
      }))
    appState.actions.canvas.selectedEntityIDs = [right.id, top.id, leftExtension.id]
    appState.actions.canvas.selectedTool = .offset
    appState.actions.constraints.handleConstraintTargetSelection(
      clickedLineTarget(resolvedRight, at: ModelPoint(xMM: 19.0, yMM: 10.0))
    )

    #expect(
      appState.actions.canvas.pendingConstraintValueDraft?.selectedOffsetSourceScope
        == .selectedRange)
    #expect(
      appState.actions.canvas.pendingConstraintValueDraft?.offsetSourceEntityIDs == [fillet.id])
    let availableResolvedIDs = Set(
      appState.actions.document.entities
        .filter { $0.derivedElementID == fillet.id }
        .map(\.id))
    let resolvedIDs = unwrap(
      appState.actions.canvas.pendingConstraintValueDraft?.offsetSourceResolvedEntityIDs)
    #expect(resolvedIDs.count == 5)
    #expect(Set(resolvedIDs).isSubset(of: availableResolvedIDs))

    appState.actions.constraints.updatePendingConstraintValueText("1.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    let offset = unwrap(appState.actions.document.derivedElements.last)
    #expect(offset.kind == .offsetCurve)
    #expect(offset.sourceEntityIDs == [fillet.id])
    #expect(offset.sourceResolvedEntityIDs == resolvedIDs)
  }

  assertLiveDerivedElement("offset centerLine") { appState in
    let centerLine = addLiveCenterLine(
      appState, idHint: "center-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 3.0))

    appState.actions.canvas.selectedTool = .offset
    appState.actions.constraints.handleConstraintTargetSelection(
      clickedLineTarget(centerLine, at: ModelPoint(xMM: 8.0, yMM: 5.0)))
    appState.actions.constraints.updatePendingConstraintValueText("2.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    let offset = unwrap(appState.actions.document.derivedElements.last)
    #expect(offset.kind == .offsetCurve)
    #expect(offset.sourceEntityIDs == [centerLine.id])
    #expect(offset.distanceMM == 2.0)
  }

  assertLiveDerivedElement("offset circle") { appState in
    let circle = addLiveCircle(
      appState, idHint: "circle", center: .zero, edge: ModelPoint(xMM: 5.0, yMM: 0.0))

    appState.actions.canvas.selectedTool = .offset
    appState.actions.constraints.handleConstraintTargetSelection(circle.entitySelectionTarget)
    appState.actions.constraints.updatePendingConstraintValueText("2.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    let offset = unwrap(appState.actions.document.derivedElements.last)
    #expect(offset.kind == .offsetCurve)
    #expect(offset.sourceEntityIDs == [circle.id])
    #expect(offset.distanceMM == 2.0)
  }

  assertLiveDerivedElement("offset arc") { appState in
    let arc = addLiveArc(
      appState,
      idHint: "arc",
      center: .zero,
      start: ModelPoint(xMM: 8.0, yMM: 0.0),
      end: ModelPoint(xMM: 0.0, yMM: 8.0)
    )

    appState.actions.canvas.selectedTool = .offset
    appState.actions.constraints.handleConstraintTargetSelection(arc.entitySelectionTarget)
    appState.actions.constraints.updatePendingConstraintValueText("2.0")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    let offset = unwrap(appState.actions.document.derivedElements.last)
    #expect(offset.kind == .offsetCurve)
    #expect(offset.sourceEntityIDs == [arc.id])
    #expect(offset.distanceMM == 2.0)
  }
}

@MainActor
@Test("Live Core フィレットツールは代表UI操作フローを受理する")
func live_core_fillet_tool_accepts_representative_ui_flow() {
  assertLiveDerivedElement("fillet two connected lines") { appState in
    let first = addLiveLine(
      appState, idHint: "first-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
    let second = addLiveLine(
      appState, idHint: "second-line", start: .zero, end: ModelPoint(xMM: 0.0, yMM: 20.0))

    appState.actions.canvas.selectedTool = .fillet
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(first.lineSelectionTargets.first?.target))
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(second.lineSelectionTargets.first?.target))
    appState.actions.constraints.updatePendingConstraintValueText("2.5")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    let fillet = unwrap(appState.actions.document.derivedElements.last)
    #expect(fillet.kind == .fillet)
    #expect(Set(fillet.sourceEntityIDs) == Set([first.id, second.id]))
    #expect(fillet.radiusMM == 2.5)
  }

  assertLiveDerivedElement("fillet two connected centerLines") { appState in
    let first = addLiveCenterLine(
      appState, idHint: "first-center-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
    let second = addLiveCenterLine(
      appState, idHint: "second-center-line", start: .zero, end: ModelPoint(xMM: 0.0, yMM: 20.0))

    appState.actions.canvas.selectedTool = .fillet
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(first.lineSelectionTargets.first?.target))
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(second.lineSelectionTargets.first?.target))
    appState.actions.constraints.updatePendingConstraintValueText("2.5")
    appState.actions.constraints.commitPendingConstraintValueEntry()

    let fillet = unwrap(appState.actions.document.derivedElements.last)
    #expect(fillet.kind == .fillet)
    #expect(Set(fillet.sourceEntityIDs) == Set([first.id, second.id]))
    #expect(fillet.radiusMM == 2.5)
  }
}

@MainActor
@Test("Live Core ドラッグ編集はプレビューと確定でCore状態へ反映される")
func live_core_drag_editing_previews_and_commits_entity_move() {
  let appState = makeLiveCoreAppState(name: "Live Drag Editing")
  let line = addLiveLine(
    appState,
    idHint: "line",
    start: ModelPoint(xMM: 1.0, yMM: 2.0),
    end: ModelPoint(xMM: 12.0, yMM: 5.0)
  )
  let initialStart = lineStart(line)
  let initialEnd = lineEnd(line)
  let delta = ModelPoint(xMM: 5.0, yMM: 7.0)

  appState.actions.document.previewMoveEntity(line.id, delta: delta)

  let preview = unwrap(appState.actions.canvas.previewEntities?.first(where: { $0.id == line.id }))
  #expect(lineStart(preview) == translated(initialStart, by: delta))
  #expect(lineEnd(preview) == translated(initialEnd, by: delta))
  #expect(
    lineStart(unwrap(appState.actions.document.entities.first(where: { $0.id == line.id })))
      == initialStart)

  appState.actions.document.moveEntity(line.id, delta: delta)

  let moved = unwrap(appState.actions.document.entities.first(where: { $0.id == line.id }))
  #expect(appState.actions.canvas.previewEntities == nil)
  #expect(lineStart(moved) == translated(initialStart, by: delta))
  #expect(lineEnd(moved) == translated(initialEnd, by: delta))
}

@MainActor
@Test("Live Core 計測表示は実Core上で移動して拘束へ変換できる")
func live_core_measurement_annotations_move_and_convert_to_constraints() {
  assertLiveMeasurementConversion("distance measurement") { appState in
    let first = addLivePoint(appState, idHint: "first-point", at: .zero)
    let second = addLivePoint(appState, idHint: "second-point", at: ModelPoint(xMM: 10.0, yMM: 0.0))

    appState.actions.canvas.selectedTool = .measureDistance
    appState.actions.constraints.handleConstraintTargetSelection(first.entitySelectionTarget)
    appState.actions.constraints.handleConstraintTargetSelection(second.entitySelectionTarget)

    let constraint = convertLastMeasurementAnnotation(appState, expectedRawKind: "distance")
    #expect(constraint.rawKind == "distance")
    #expect(constraint.valueMM == 10.0)
  }

  assertLiveMeasurementConversion("segment length measurement") { appState in
    let line = addLiveLine(
      appState, idHint: "line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))

    appState.actions.canvas.selectedTool = .measureSegmentLength
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(line.lineSelectionTargets.first?.target))

    let constraint = convertLastMeasurementAnnotation(appState, expectedRawKind: "segmentLength")
    #expect(constraint.rawKind == "segmentLength")
    #expect(constraint.valueMM == 20.0)
  }

  assertLiveMeasurementConversion("radius measurement") { appState in
    let circle = addLiveCircle(
      appState, idHint: "circle", center: .zero, edge: ModelPoint(xMM: 5.0, yMM: 0.0))

    appState.actions.canvas.selectedTool = .measureRadius
    appState.actions.constraints.handleConstraintTargetSelection(circle.entitySelectionTarget)

    let constraint = convertLastMeasurementAnnotation(appState, expectedRawKind: "radius")
    #expect(constraint.rawKind == "radius")
    #expect(constraint.valueMM == 5.0)
  }

  assertLiveMeasurementConversion("diameter measurement") { appState in
    let circle = addLiveCircle(
      appState, idHint: "circle", center: .zero, edge: ModelPoint(xMM: 5.0, yMM: 0.0))

    appState.actions.canvas.selectedTool = .measureDiameter
    appState.actions.constraints.handleConstraintTargetSelection(circle.entitySelectionTarget)

    let constraint = convertLastMeasurementAnnotation(appState, expectedRawKind: "diameter")
    #expect(constraint.rawKind == "diameter")
    #expect(constraint.valueMM == 10.0)
  }

  assertLiveMeasurementConversion("angle measurement") { appState in
    let first = addLiveLine(
      appState, idHint: "first-line", start: .zero, end: ModelPoint(xMM: 10.0, yMM: 0.0))
    let second = addLiveLine(
      appState, idHint: "second-line", start: .zero, end: ModelPoint(xMM: 0.0, yMM: 10.0))

    appState.actions.canvas.selectedTool = .measureAngle
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(first.lineSelectionTargets.first?.target))
    appState.actions.constraints.handleConstraintTargetSelection(
      unwrap(second.lineSelectionTargets.first?.target))

    let constraint = convertLastMeasurementAnnotation(appState, expectedRawKind: "angle")
    #expect(constraint.rawKind == "angle")
    #expect(constraint.valueDegrees == 90.0)
  }

  assertLiveMeasurementConversion("arc sweep measurement") { appState in
    let arc = addLiveArc(
      appState,
      idHint: "arc",
      center: .zero,
      start: ModelPoint(xMM: 8.0, yMM: 0.0),
      end: ModelPoint(xMM: 0.0, yMM: 8.0)
    )

    appState.actions.canvas.selectedTool = .measureArcSweepAngle
    appState.actions.constraints.handleConstraintTargetSelection(arc.entitySelectionTarget)

    let constraint = convertLastMeasurementAnnotation(appState, expectedRawKind: "arcSweepAngle")
    #expect(constraint.rawKind == "angle")
    #expect(constraint.valueDegrees == 90.0)
  }
}

@MainActor
@Test("Live Core 直線上拘束は線から点のUI操作相当でも追加できる")
func live_core_point_on_line_accepts_line_then_point_ui_flow() {
  let appState = makeLiveCoreAppState(name: "Live Point On Line Line First")
  let point = addLivePoint(appState, idHint: "point", at: ModelPoint(xMM: 4.0, yMM: 6.0))
  let line = addLiveLine(
    appState, idHint: "line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))

  appState.actions.canvas.selectedTool = .pointOnLine
  appState.actions.constraints.handleConstraintTargetSelection(
    unwrap(line.lineSelectionTargets.first?.target))
  appState.actions.constraints.handleConstraintTargetSelection(point.entitySelectionTarget)

  let constraint = unwrap(
    appState.actions.document.constraints.first(where: { $0.rawKind == "pointOnLine" }))
  let targets = unwrap(CoreConstraintTarget.decodeList(from: constraint.targetsJSON))
  #expect(
    targets == [
      .entity(point.id),
      .entity(line.id),
    ])
}

@MainActor
@Test("Live Core 距離拘束は2点と点線距離をUI操作相当で追加できる")
func live_core_distance_constraints_accept_point_point_and_point_line_ui_flows() {
  let appState = makeLiveCoreAppState(name: "Live Distance Constraints")
  let firstPoint = addLivePoint(appState, idHint: "first-point", at: .zero)
  let secondPoint = addLivePoint(
    appState, idHint: "second-point", at: ModelPoint(xMM: 10.0, yMM: 0.0))
  let line = addLiveLine(
    appState, idHint: "line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
  let offLinePoint = addLivePoint(
    appState, idHint: "off-line-point", at: ModelPoint(xMM: 4.0, yMM: 6.0))

  appState.actions.canvas.selectedTool = .distance
  appState.actions.constraints.handleConstraintTargetSelection(firstPoint.entitySelectionTarget)
  appState.actions.constraints.handleConstraintTargetSelection(secondPoint.entitySelectionTarget)
  appState.actions.constraints.updatePendingConstraintValueText("10.0")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  appState.actions.canvas.selectedTool = .distance
  appState.actions.constraints.handleConstraintTargetSelection(offLinePoint.entitySelectionTarget)
  appState.actions.constraints.handleConstraintTargetSelection(
    unwrap(line.lineSelectionTargets.first?.target))
  appState.actions.constraints.updatePendingConstraintValueText("6.0")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  #expect(appState.actions.document.constraints.contains { $0.rawKind == "distance" })
  #expect(appState.actions.document.constraints.contains { $0.rawKind == "pointLineDistance" })
}

@MainActor
@Test("Live Core 線分間距離拘束は線2本のUI操作相当で追加できる")
func live_core_line_line_distance_accepts_line_line_ui_flow() {
  let appState = makeLiveCoreAppState(name: "Live Line Line Distance")
  let firstLine = addLiveLine(
    appState, idHint: "first-line", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
  let secondLine = addLiveLine(
    appState, idHint: "second-line", start: ModelPoint(xMM: 0.0, yMM: 6.0),
    end: ModelPoint(xMM: 20.0, yMM: 6.0))

  appState.actions.canvas.selectedTool = .lineLineDistance
  appState.actions.constraints.handleConstraintTargetSelection(
    unwrap(firstLine.lineSelectionTargets.first?.target))
  appState.actions.constraints.handleConstraintTargetSelection(
    unwrap(secondLine.lineSelectionTargets.first?.target))
  appState.actions.constraints.updatePendingConstraintValueText("6.0")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  #expect(appState.actions.document.constraints.contains { $0.rawKind == "lineLineDistance" })
}

@Test("Live Core は直線上拘束の点点targetを拒否しDocumentSessionAdapterの状態を壊さない")
func live_core_rejects_invalid_point_on_line_targets_without_store_state_mutation() {
  let store = DocumentSessionAdapter()
  let initialState = requireSuccess(
    store.createNewDocument(named: "Live Invalid Point On Line", viewMode: .editDisplay))
  let firstPointID = addLivePoint(to: store, at: .zero)
  let secondPointID = addLivePoint(to: store, at: ModelPoint(xMM: 8.0, yMM: 6.0))
  let beforeInvalidCommand = unwrap(store.lastAppliedState)

  let invalidCommand = CoreDocumentCommand(
    kind: .addConstraint,
    payload: .object([
      "id": .string("constraint:invalid-point-on-line"),
      "kind": .string("pointOnLine"),
      "targets": .array([
        CoreConstraintTarget.entity(firstPointID).jsonValue,
        CoreConstraintTarget.entity(secondPointID).jsonValue,
      ]),
      "value": .null,
      "status": .string("unknown"),
    ])
  )

  switch store.applyCommand(invalidCommand, viewMode: .editDisplay) {
  case .success:
    Issue.record("expected pointOnLine point/point targets to be rejected by live Core")
  case .failure(let failure):
    #expect(
      failure.message.contains("直線上")
        || failure.message.contains("pointOnLine")
        || failure.message.contains("target")
    )
  }

  #expect(initialState.constraints.isEmpty)
  #expect(store.lastAppliedState == beforeInvalidCommand)
  #expect(store.lastAppliedState?.constraints.isEmpty == true)
}

@MainActor
@Test("Live Core 未保存プロジェクトを破棄して新規作成しても RPC エラーにならない")
func live_core_discarding_unsaved_project_can_create_a_new_document() {
  let appState = makeLiveCoreAppState(name: "Live Unsaved Replacement")
  appState.actions.canvas.selectedTool = .point
  appState.actions.canvas.handleCanvasPlacement(ModelPoint(xMM: 10.0, yMM: 10.0))
  #expect(appState.actions.document.isDocumentDirty)

  appState.actions.document.createNewProject()
  #expect(appState.actions.document.documentSaveConfirmation != nil)
  appState.actions.document.discardDocumentChangesAndContinue()

  #expect(appState.actions.document.alertMessage == nil)
  if case .unavailable = appState.actions.document.coreStatus {
    Issue.record("discarding an unsaved project must not make the Core unavailable")
  }
  #expect(appState.actions.document.entities.isEmpty)
  #expect(!appState.actions.document.isDocumentDirty)
}

@MainActor
@Test("Live Core は保存したプロジェクトを別セッションで開き、再読込できる")
func live_core_document_session_save_open_and_reload_round_trip() {
  let source = makeLiveCoreAppState(name: "Live Persistence Source")
  let line = addLiveLine(
    source,
    idHint: "saved-line",
    start: ModelPoint(xMM: -12.0, yMM: 4.0),
    end: ModelPoint(xMM: 18.0, yMM: 4.0)
  )
  let url = uniqueTempURL("live-core-session-round-trip.kawa")
  requireSuccess(source.cadSession.saveDocument(to: url), context: "save live core document")

  let reopenedAdapter = DocumentSessionAdapter()
  let opened = requireSuccess(
    reopenedAdapter.openDocument(at: url, viewMode: .editDisplay),
    context: "open saved document in independent live core session"
  )
  #expect(opened.snapshot.name == "Live Persistence Source")
  #expect(opened.entities.contains { $0.id == line.id })
  #expect(!reopenedAdapter.isDocumentDirty)

  let addedPointID = addLivePoint(to: reopenedAdapter, at: ModelPoint(xMM: 3.0, yMM: -7.0))
  let reloaded = requireSuccess(
    reopenedAdapter.loadState(viewMode: .editDisplay),
    context: "reload independent live core session")
  #expect(reloaded.entities.contains { $0.id == line.id })
  #expect(reloaded.entities.contains { $0.id == addedPointID })
  #expect(reopenedAdapter.isDocumentDirty)
}

@MainActor
@Test("Live Core は未保存変更を破棄して既存プロジェクトへ置換できる")
func live_core_discarding_unsaved_changes_replaces_with_opened_project() {
  let savedProject = makeLiveCoreAppState(name: "Live Replacement Target")
  let savedLine = addLiveLine(
    savedProject,
    idHint: "saved-target-line",
    start: ModelPoint(xMM: 0.0, yMM: 0.0),
    end: ModelPoint(xMM: 24.0, yMM: 0.0)
  )
  let savedURL = uniqueTempURL("live-core-replacement-target.kawa")
  requireSuccess(
    savedProject.cadSession.saveDocument(to: savedURL), context: "save replacement target")

  let appState = makeLiveCoreAppState(name: "Live Dirty Replacement Source")
  _ = addLivePoint(appState, idHint: "dirty-before-open", at: ModelPoint(xMM: 2.0, yMM: 2.0))
  #expect(appState.actions.document.isDocumentDirty)

  appState.actions.document.openProject(at: savedURL)
  #expect(appState.actions.document.documentSaveConfirmation != nil)
  appState.actions.document.discardDocumentChangesAndContinue()

  #expect(appState.actions.document.alertMessage == nil)
  #expect(appState.actions.document.documentName == "Live Replacement Target")
  #expect(appState.actions.document.entities.contains { $0.id == savedLine.id })
  #expect(!appState.actions.document.isDocumentDirty)
}

@MainActor
private func makeLiveCoreAppState(name: String) -> AppCoordinator {
  let store = DocumentSessionAdapter()
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.document.applyDocumentState(
    requireSuccess(store.createNewDocument(named: name, viewMode: .editDisplay)))
  return appState
}

@MainActor
private func applyLiveCoreCommand(_ command: CoreDocumentCommand, to appState: AppCoordinator)
  -> Bool
{
  appState.actions.document.executeDocumentCommand(
    DocumentCommandRequest(payload: command, successMessage: "")
  )
}

@MainActor
private func liveSelectedInspectorPart(_ appState: AppCoordinator) -> ProjectPart? {
  WorkspaceViewStateFactory.selectedInspectorPart(
    selectedPartID: appState.actions.inspector.inspectorSelectedPartID,
    parts: appState.actions.document.parts
  )
}

private func liveCoreMultiPageOutputDocumentModel() -> OutputDocumentModel {
  let printableArea = OutputPrintableAreaMm(
    leftMm: -100.0,
    rightMm: 100.0,
    topMm: 143.5,
    bottomMm: -143.5
  )
  return OutputDocumentModel(
    paperSize: .a4,
    orientation: .portrait,
    scale: .actualSize,
    pageCount: 2,
    pages: [
      OutputPage(
        widthMm: 210.0,
        heightMm: 297.0,
        gridColumn: 0,
        gridRow: 0,
        rotationDeg: 0,
        printableAreaMm: printableArea,
        graphics: [
          OutputGraphic(
            entityId: "entity:page-1-crossing-line",
            kind: .lineSegment,
            geometry: .lineSegment(
              startMm: OutputPointMm(xMm: 80.0, yMm: 0.0),
              endMm: OutputPointMm(xMm: 220.0, yMm: 0.0)
            ),
            style: .default
          )
        ],
        texts: [],
        guide: nil
      ),
      OutputPage(
        widthMm: 210.0,
        heightMm: 297.0,
        gridColumn: 1,
        gridRow: 0,
        rotationDeg: 0,
        printableAreaMm: printableArea,
        graphics: [
          OutputGraphic(
            entityId: "entity:page-2-crossing-line",
            kind: .lineSegment,
            geometry: .lineSegment(
              startMm: OutputPointMm(xMm: -220.0, yMm: 0.0),
              endMm: OutputPointMm(xMm: -80.0, yMm: 0.0)
            ),
            style: .default
          )
        ],
        texts: [],
        guide: nil
      ),
    ]
  )
}

@MainActor
private func addLivePoint(_ appState: AppCoordinator, idHint: String, at point: ModelPoint)
  -> CanvasEntity
{
  let existingIDs = Set(appState.actions.document.entities.map(\.id))
  appState.actions.canvas.selectedTool = .point
  appState.actions.canvas.handleCanvasPlacement(point)
  return unwrap(
    appState.actions.document.entities.first { !existingIDs.contains($0.id) && $0.kind == .point },
    context: "expected new point for \(idHint)")
}

@MainActor
private func addLiveLine(
  _ appState: AppCoordinator, idHint: String, start: ModelPoint, end: ModelPoint
) -> CanvasEntity {
  let existingIDs = Set(appState.actions.document.entities.map(\.id))
  appState.actions.canvas.selectedTool = .line
  appState.actions.canvas.handleCanvasPlacement(start)
  appState.actions.canvas.handleCanvasPlacement(end)
  return unwrap(
    appState.actions.document.entities.first {
      !existingIDs.contains($0.id) && $0.kind == .lineSegment
    }, context: "expected new line for \(idHint)")
}

@MainActor
private func addLiveCenterLine(
  _ appState: AppCoordinator, idHint: String, start: ModelPoint, end: ModelPoint
) -> CanvasEntity {
  let existingIDs = Set(appState.actions.document.entities.map(\.id))
  appState.actions.canvas.selectedTool = .centerLine
  appState.actions.canvas.handleCanvasPlacement(start)
  appState.actions.canvas.handleCanvasPlacement(end)
  return unwrap(
    appState.actions.document.entities.first {
      !existingIDs.contains($0.id) && $0.kind == .centerLine
    }, context: "expected new center line for \(idHint)")
}

private func addLivePoint(to store: DocumentSessionAdapter, at point: ModelPoint) -> String {
  let id = "entity:live-point-\(UUID().uuidString)"
  let command = CoreDocumentCommand(
    kind: .addEntity,
    payload: .object([
      "id": .string(id),
      "layerId": .string("layer:cut-line"),
      "kind": .object([
        "point": CorePoint(xMm: point.xMM, yMm: point.yMM).jsonValue
      ]),
    ])
  )
  _ = requireSuccess(store.applyCommand(command, viewMode: .editDisplay))
  return id
}

@MainActor
private func addLiveArc(
  to appState: AppCoordinator,
  idHint: String,
  center: ModelPoint,
  radiusMM: Double,
  startAngleRad: Double,
  sweepAngleRad: Double
) -> CanvasEntity {
  let id = "entity:live-arc-\(idHint)-\(UUID().uuidString)"
  let command = CoreDocumentCommand(
    kind: .addEntity,
    payload: .object([
      "id": .string(id),
      "layerId": .string("layer:cut-line"),
      "kind": .object([
        "arc": .object([
          "center": CorePoint(xMm: center.xMM, yMm: center.yMM).jsonValue,
          "radiusMm": .number(radiusMM),
          "startAngleRad": .number(startAngleRad),
          "sweepAngleRad": .number(sweepAngleRad),
        ])
      ]),
    ])
  )
  #expect(applyLiveCoreCommand(command, to: appState))
  return unwrap(
    appState.actions.document.entities.first { $0.id == id },
    context: "expected live arc for \(idHint)")
}

@MainActor
private func addLiveConstraint(
  to appState: AppCoordinator,
  idHint: String,
  kind: String,
  targets: [CoreConstraintTarget]
) {
  let command = CoreDocumentCommand(
    kind: .addConstraint,
    payload: .object([
      "id": .string("constraint:live-\(kind)-\(idHint)-\(UUID().uuidString)"),
      "kind": .string(kind),
      "targets": .array(targets.map(\.jsonValue)),
      "value": .null,
      "status": .string("unknown"),
    ])
  )
  #expect(applyLiveCoreCommand(command, to: appState))
}

@MainActor
private func addLiveTangentThreeScenario(
  to appState: AppCoordinator,
  idSuffix: String
) -> (leftLine: CanvasEntity, rightLine: CanvasEntity, arc: CanvasEntity) {
  let leftLine = addLiveLine(
    appState,
    idHint: "left-line-\(idSuffix)",
    start: ModelPoint(xMM: -25.0, yMM: 75.0),
    end: ModelPoint(xMM: -50.00000000000001, yMM: 3.552713678800501e-15)
  )
  let rightLine = addLiveLine(
    appState,
    idHint: "right-line-\(idSuffix)",
    start: ModelPoint(xMM: -10.0, yMM: 75.0),
    end: ModelPoint(xMM: 14.999999999999991, yMM: 7.105427357601002e-15)
  )
  let arc = addLiveArc(
    to: appState,
    idHint: "sample-arc-3-\(idSuffix)",
    center: ModelPoint(xMM: -17.500000000000014, yMM: -10.833333333333327),
    radiusMM: 34.25800798515745,
    startAngleRad: 2.819842099193151,
    sweepAngleRad: 3.7850937623830774
  )
  addLiveConstraint(
    to: appState,
    idHint: "start-coincident-\(idSuffix)",
    kind: "coincident",
    targets: [
      .controlPoint(entityID: leftLine.id, point: .end),
      .controlPoint(entityID: arc.id, point: .start),
    ]
  )
  addLiveConstraint(
    to: appState,
    idHint: "arc-start-fixed-\(idSuffix)",
    kind: "fixed",
    targets: [.controlPoint(entityID: arc.id, point: .start)]
  )
  addLiveConstraint(
    to: appState,
    idHint: "right-end-fixed-\(idSuffix)",
    kind: "fixed",
    targets: [.controlPoint(entityID: rightLine.id, point: .end)]
  )
  addLiveConstraint(
    to: appState,
    idHint: "start-tangent-\(idSuffix)",
    kind: "tangent",
    targets: [
      .controlPoint(entityID: arc.id, point: .start),
      .controlPoint(entityID: leftLine.id, point: .end),
    ]
  )
  addLiveConstraint(
    to: appState,
    idHint: "end-coincident-\(idSuffix)",
    kind: "coincident",
    targets: [
      .controlPoint(entityID: rightLine.id, point: .end),
      .controlPoint(entityID: arc.id, point: .end),
    ]
  )
  addLiveConstraint(
    to: appState,
    idHint: "end-tangent-\(idSuffix)",
    kind: "tangent",
    targets: [
      .controlPoint(entityID: arc.id, point: .end),
      .controlPoint(entityID: rightLine.id, point: .end),
    ]
  )
  return (leftLine, rightLine, arc)
}

@MainActor
private func addLiveArc(
  _ appState: AppCoordinator,
  idHint: String,
  center: ModelPoint,
  start: ModelPoint,
  end: ModelPoint
) -> CanvasEntity {
  let existingIDs = Set(appState.actions.document.entities.map(\.id))
  appState.actions.canvas.selectedTool = .arc
  appState.actions.canvas.handleCanvasPlacement(center)
  appState.actions.canvas.handleCanvasPlacement(start)
  appState.actions.canvas.handleCanvasPlacement(end)
  return unwrap(
    appState.actions.document.entities.first { !existingIDs.contains($0.id) && $0.kind == .arc },
    context: "expected new arc for \(idHint)")
}

@MainActor
private func assertLiveConstraint(
  _ name: String,
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  _ run: (AppCoordinator) -> Void
) {
  let appState = makeLiveCoreAppState(name: "Live Constraint Matrix - \(name)")
  run(appState)
  if appState.actions.document.constraints.isEmpty {
    Issue.record(
      "expected \(name) to add a constraint",
      sourceLocation: SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
    )
  }
}

@MainActor
private func assertLiveDerivedElement(
  _ name: String,
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  _ run: (AppCoordinator) -> Void
) {
  let appState = makeLiveCoreAppState(name: "Live Derived Matrix - \(name)")
  run(appState)
  if appState.actions.document.derivedElements.isEmpty {
    Issue.record(
      "expected \(name) to add a derived element",
      sourceLocation: SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
    )
  }
}

@MainActor
private func assertLiveMeasurementConversion(
  _ name: String,
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column,
  _ run: (AppCoordinator) -> Void
) {
  let appState = makeLiveCoreAppState(name: "Live Measurement Conversion - \(name)")
  run(appState)
  if !appState.actions.document.measurementAnnotations.isEmpty {
    Issue.record(
      "expected \(name) to convert and remove the measurement annotation",
      sourceLocation: SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
    )
  }
  if appState.actions.document.constraints.isEmpty {
    Issue.record(
      "expected \(name) to add a constraint",
      sourceLocation: SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
    )
  }
}

@MainActor
private func convertLastMeasurementAnnotation(
  _ appState: AppCoordinator,
  expectedRawKind: String,
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column
) -> ProjectConstraint {
  let annotation = unwrap(
    appState.actions.document.measurementAnnotations.last,
    context: "expected \(expectedRawKind) measurement annotation")
  #expect(
    annotation.rawKind == expectedRawKind,
    sourceLocation: SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
  )

  appState.actions.canvas.selectMeasurementAnnotation(annotation.id)
  #expect(appState.actions.canvas.selectedMeasurementAnnotationID == annotation.id)
  appState.actions.canvas.moveMeasurementAnnotation(
    id: annotation.id, delta: ModelPoint(xMM: 1.5, yMM: -2.0), labelOnly: true)

  let movedAnnotation = unwrap(
    appState.actions.document.measurementAnnotations.first(where: { $0.id == annotation.id }))
  #expect(movedAnnotation.labelOffsetMM == ModelPoint(xMM: 1.5, yMM: -2.0))
  #expect(movedAnnotation.overallOffsetMM == .zero)

  appState.actions.canvas.convertMeasurementAnnotationToConstraint(id: annotation.id)
  #expect(appState.actions.canvas.selectedMeasurementAnnotationID == nil)
  #expect(appState.actions.document.measurementAnnotations.allSatisfy { $0.id != annotation.id })

  return unwrap(
    appState.actions.document.constraints.last,
    context: "expected converted constraint for \(expectedRawKind)")
}

@MainActor
private func assertLastLiveConstraint(
  _ appState: AppCoordinator,
  kind: String,
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column
) {
  let constraint = appState.actions.document.constraints.last
  #expect(
    constraint?.rawKind == kind,
    sourceLocation: SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
  )
}

private struct LiveRectangleContour {
  let bottom: CanvasEntity
  let right: CanvasEntity
  let top: CanvasEntity
  let left: CanvasEntity

  var sourceIDs: [String] {
    [bottom.id, right.id, top.id, left.id]
  }
}

@MainActor
private func addLiveRectangleContour(_ appState: AppCoordinator) -> LiveRectangleContour {
  let bottom = addLiveLine(
    appState,
    idHint: "bottom",
    start: .zero,
    end: ModelPoint(xMM: 10.0, yMM: 0.0)
  )
  let right = addLiveLine(
    appState,
    idHint: "right",
    start: ModelPoint(xMM: 10.0, yMM: 0.0),
    end: ModelPoint(xMM: 10.0, yMM: 10.0)
  )
  let top = addLiveLine(
    appState,
    idHint: "top",
    start: ModelPoint(xMM: 10.0, yMM: 10.0),
    end: ModelPoint(xMM: 0.0, yMM: 10.0)
  )
  let left = addLiveLine(
    appState,
    idHint: "left",
    start: ModelPoint(xMM: 0.0, yMM: 10.0),
    end: .zero
  )
  return LiveRectangleContour(bottom: bottom, right: right, top: top, left: left)
}

private func clickedLineTarget(_ entity: CanvasEntity, at point: ModelPoint)
  -> CanvasSelectionTarget
{
  CanvasSelectionTarget(
    entityID: entity.id,
    entityLabel: entity.label,
    entityKind: entity.kind,
    controlPoint: nil,
    point: point
  )
}

private func lineStart(_ entity: CanvasEntity) -> ModelPoint {
  switch entity.geometry {
  case .line(let start, _, _):
    return start
  default:
    Issue.record("expected line entity \(entity.id)")
    return .zero
  }
}

private func pointAt(_ entity: CanvasEntity) -> ModelPoint {
  switch entity.geometry {
  case .point(let point):
    return point
  default:
    Issue.record("expected point entity \(entity.id)")
    return .zero
  }
}

private func circleCenter(_ entity: CanvasEntity) -> ModelPoint {
  switch entity.geometry {
  case .circle(let center, _):
    return center
  default:
    Issue.record("expected circle entity \(entity.id)")
    return .zero
  }
}

private func lineEnd(_ entity: CanvasEntity) -> ModelPoint {
  switch entity.geometry {
  case .line(_, let end, _):
    return end
  default:
    Issue.record("expected line entity \(entity.id)")
    return .zero
  }
}

private func arcStart(_ entity: CanvasEntity) -> ModelPoint {
  switch entity.geometry {
  case .arc(let center, let radiusMM, let startAngleRad, _):
    return ModelPoint(
      xMM: center.xMM + radiusMM * cos(startAngleRad),
      yMM: center.yMM + radiusMM * sin(startAngleRad)
    )
  default:
    Issue.record("expected arc entity \(entity.id)")
    return .zero
  }
}

private func arcEnd(_ entity: CanvasEntity) -> ModelPoint {
  switch entity.geometry {
  case .arc(let center, let radiusMM, let startAngleRad, let sweepAngleRad):
    let endAngleRad = startAngleRad + sweepAngleRad
    return ModelPoint(
      xMM: center.xMM + radiusMM * cos(endAngleRad),
      yMM: center.yMM + radiusMM * sin(endAngleRad)
    )
  default:
    Issue.record("expected arc entity \(entity.id)")
    return .zero
  }
}

private func arcTangentDirection(_ entity: CanvasEntity, endpoint: CanvasControlPoint) -> ModelPoint
{
  switch entity.geometry {
  case .arc(_, _, let startAngleRad, let sweepAngleRad):
    let radiusAngle: Double
    switch endpoint {
    case .arcStart:
      radiusAngle = startAngleRad
    case .arcEnd:
      radiusAngle = startAngleRad + sweepAngleRad
    default:
      Issue.record("expected arc endpoint for tangent direction")
      return .zero
    }
    let sweepSign = sweepAngleRad < 0.0 ? -1.0 : 1.0
    return ModelPoint(
      xMM: cos(radiusAngle + sweepSign * .pi / 2.0),
      yMM: sin(radiusAngle + sweepSign * .pi / 2.0)
    )
  default:
    Issue.record("expected arc entity \(entity.id)")
    return .zero
  }
}

private func lineDirection(from start: ModelPoint, to end: ModelPoint) -> ModelPoint {
  let length = hypot(end.xMM - start.xMM, end.yMM - start.yMM)
  guard length > 0.0001 else {
    Issue.record("expected non-zero line direction")
    return .zero
  }
  return ModelPoint(
    xMM: (end.xMM - start.xMM) / length,
    yMM: (end.yMM - start.yMM) / length
  )
}

private func pointsAreClose(_ first: ModelPoint, _ second: ModelPoint) -> Bool {
  hypot(first.xMM - second.xMM, first.yMM - second.yMM) <= 0.0001
}

private func vectorsPointSameDirection(_ first: ModelPoint, _ second: ModelPoint) -> Bool {
  abs(first.xMM * second.yMM - first.yMM * second.xMM) <= 0.0001
    && (first.xMM * second.xMM + first.yMM * second.yMM) > 0.0
}

private func translated(_ point: ModelPoint, by delta: ModelPoint) -> ModelPoint {
  ModelPoint(xMM: point.xMM + delta.xMM, yMM: point.yMM + delta.yMM)
}

@MainActor
private final class LiveCoreCanvasHarness {
  private let appState: AppCoordinator
  private let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
  private let coordinateSpace: CanvasCoordinateSpace
  let view: LeatherCanvasView
  private(set) var selectedTargets: [CanvasSelectionTarget] = []

  init(appState: AppCoordinator, selectedTool: CanvasTool) {
    _ = NSApplication.shared
    self.appState = appState
    self.coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect)
    self.view = LeatherCanvasView(frame: pageRect)
    appState.actions.canvas.selectedTool = selectedTool
    view.onSelectEntity = { [weak appState, weak view] entityID in
      guard let appState else {
        return
      }
      appState.actions.canvas.selectEntity(entityID)
      if let view {
        syncLiveCoreCanvasView(view, appState: appState)
      }
    }
    view.onPreviewMoveEntities = { [weak appState, weak view] entityIDs, delta, duplicating in
      guard let appState else {
        return
      }
      appState.actions.document.previewMoveEntities(
        entityIDs, delta: delta, duplicating: duplicating)
      if let view {
        syncLiveCoreCanvasView(view, appState: appState)
      }
    }
    view.onMoveEntities = { [weak appState, weak view] entityIDs, delta, duplicating in
      guard let appState else {
        return
      }
      appState.actions.document.moveEntities(entityIDs, delta: delta, duplicating: duplicating)
      if let view {
        syncLiveCoreCanvasView(view, appState: appState)
      }
    }
    view.onPreviewMoveControlPoint = { [weak appState, weak view] target, point in
      guard let appState else {
        return
      }
      appState.actions.document.previewMoveControlPoint(target, to: point)
      if let view {
        syncLiveCoreCanvasView(view, appState: appState)
      }
    }
    view.onMoveControlPoint = { [weak appState, weak view] target, point in
      guard let appState else {
        return
      }
      appState.actions.document.moveControlPoint(target, to: point)
      if let view {
        syncLiveCoreCanvasView(view, appState: appState)
      }
    }
    view.onCancelMovePreview = { [weak appState, weak view] in
      guard let appState else {
        return
      }
      appState.actions.document.cancelMovePreview()
      if let view {
        syncLiveCoreCanvasView(view, appState: appState)
      }
    }
    view.onSelectTarget = { [weak appState, weak view] target in
      guard let appState else {
        return
      }
      if let target {
        self.selectedTargets.append(target)
      }
      appState.actions.constraints.handleConstraintTargetSelection(target)
      if let view {
        syncLiveCoreCanvasView(view, appState: appState)
      }
    }
    syncLiveCoreCanvasView(view, appState: appState)
  }

  func click(_ modelPoint: ModelPoint) {
    let canvasPoint = coordinateSpace.canvasPoint(for: modelPoint)
    let eventPoint = CGPoint(x: canvasPoint.x, y: view.bounds.height - canvasPoint.y)
    guard let event = liveCoreMouseDownEvent(at: eventPoint) else {
      Issue.record("expected AppKit mouse event for \(modelPoint)")
      return
    }
    view.mouseDown(with: event)
  }

  func drag(from start: ModelPoint, to end: ModelPoint) {
    let startPoint = eventPoint(for: start)
    let endPoint = eventPoint(for: end)
    guard let down = liveCoreMouseEvent(kind: .leftMouseDown, at: startPoint),
      let dragged = liveCoreMouseEvent(kind: .leftMouseDragged, at: endPoint),
      let up = liveCoreMouseEvent(kind: .leftMouseUp, at: endPoint)
    else {
      Issue.record("expected AppKit mouse events for drag from \(start) to \(end)")
      return
    }
    view.mouseDown(with: down)
    view.mouseDragged(with: dragged)
    view.mouseUp(with: up)
  }

  private func eventPoint(for modelPoint: ModelPoint) -> CGPoint {
    let canvasPoint = coordinateSpace.canvasPoint(for: modelPoint)
    return CGPoint(x: canvasPoint.x, y: view.bounds.height - canvasPoint.y)
  }
}

@MainActor
private func makeLiveCoreCanvasHarness(appState: AppCoordinator, selectedTool: CanvasTool)
  -> LiveCoreCanvasHarness
{
  LiveCoreCanvasHarness(appState: appState, selectedTool: selectedTool)
}

@MainActor
private func syncLiveCoreCanvasView(_ view: LeatherCanvasView, appState: AppCoordinator) {
  view.entities = appState.actions.document.entities
  view.documentConstraints = appState.actions.document.constraints
  view.measurementAnnotations = appState.actions.document.measurementAnnotations
  view.parameters = appState.actions.document.parameters
  view.derivedElements = appState.actions.document.derivedElements
  view.layers = appState.actions.document.layers
  view.coincidentPointGroups = appState.actions.document.coincidentPointGroups
  view.selectedEntityID = appState.actions.canvas.selectedEntityID
  view.selectedEntityIDs = appState.actions.canvas.selectedEntityIDs
  view.selectedConstraintID = appState.actions.canvas.selectedConstraintID
  view.selectedMeasurementAnnotationID = appState.actions.canvas.selectedMeasurementAnnotationID
  view.stitchStartPoints = appState.actions.document.stitchStartPoints
  view.selectedStitchStartPointID = appState.actions.canvas.selectedStitchStartPointID
  view.pendingConstraintTargets = appState.actions.canvas.pendingConstraintTargets
  view.selectedTool = appState.actions.canvas.selectedTool
  view.gridSnapEnabled = false
  view.pointSnapEnabled = true
}

private func liveCoreMouseDownEvent(at point: CGPoint) -> NSEvent? {
  liveCoreMouseEvent(kind: .leftMouseDown, at: point)
}

private func liveCoreMouseEvent(kind: NSEvent.EventType, at point: CGPoint) -> NSEvent? {
  NSEvent.mouseEvent(
    with: kind,
    location: point,
    modifierFlags: [],
    timestamp: 0,
    windowNumber: 0,
    context: nil,
    eventNumber: 0,
    clickCount: 1,
    pressure: 1.0
  )
}

@MainActor
private func addLiveCircle(
  _ appState: AppCoordinator, idHint: String, center: ModelPoint, edge: ModelPoint
) -> CanvasEntity {
  let existingIDs = Set(appState.actions.document.entities.map(\.id))
  appState.actions.canvas.selectedTool = .circle
  appState.actions.canvas.handleCanvasPlacement(center)
  appState.actions.canvas.handleCanvasPlacement(edge)
  return unwrap(
    appState.actions.document.entities.first { !existingIDs.contains($0.id) && $0.kind == .circle },
    context: "expected new circle for \(idHint)")
}
