import CoreGraphics
import Foundation
import KawaCADOutput
import Testing

@testable import KawaCADApp

@Test("UC1 AppCoordinator は新規作成直後のドキュメント状態を反映する")
@MainActor
func uc1_app_state_initial_project_is_reflected_in_the_ui_model() {
  let initialState = makeDocumentState(
    name: "UI Project",
    entities: [
      pointEntity(id: "entity:point-a", point: .zero),
      lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0)),
    ],
    constraints: [
      ProjectConstraint(
        id: "constraint:line-a-horizontal",
        rawKind: "horizontal",
        kind: "水平",
        targets: ["entity:line-a"],
        targetsJSON: #"["entity:line-a"]"#,
        valueMM: nil,
        valueDegrees: nil,
        valueParameterID: nil,
        status: .underConstrained
      )
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)

  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(LeatherCoreVersionInfo(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  #expect(appState.actions.document.documentName == "UI Project")
  #expect(appState.actions.canvas.selectedTool == .select)
  #expect(appState.actions.document.documentURL == nil)
  #expect(appState.actions.document.canEditLayers)
  #expect(appState.actions.document.canRenameDocument)
  #expect(appState.actions.document.canSaveProject)
  #expect(appState.actions.document.canUndo == store.canUndo)
  #expect(appState.actions.document.canRedo == store.canRedo)
  #expect(appState.actions.document.entities.map(\.id) == ["entity:point-a", "entity:line-a"])
  #expect(appState.actions.document.constraints.map(\.id) == ["constraint:line-a-horizontal"])
  #expect(appState.actions.canvas.aggregatedConstraintStatus == .underConstrained)
  #expect(
    appState.actions.document.coreStatus
      == .connected(LeatherCoreVersionInfo(fileFormatMajor: 0, schemaMajor: 0)))
  #expect(appState.actions.document.statusMessage == "新規プロジェクトを作成しました。")
}

@Test("UC1 AppCoordinator はプロジェクト名変更を境界へ送る")
@MainActor
func uc1_app_state_document_name_rename_is_sent_through_the_boundary() {
  let initialState = makeDocumentState(name: "無題プロジェクト")
  let renamedState = makeDocumentState(name: "Pattern A")
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = renamedState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(LeatherCoreVersionInfo(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.document.renameDocument(to: " Pattern A ")

  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "renameDocument")
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["name"] as? String) == "Pattern A")
  #expect(appState.actions.document.documentName == "Pattern A")
  #expect(appState.actions.document.statusMessage == "Pattern A に変更しました")
}

@Test("範囲選択の修飾操作は選択集合だけをトグルし履歴とDirty状態を変更しない")
@MainActor
func marquee_selection_modifier_toggles_without_document_mutation() {
  let first = pointEntity(id: "entity:first", point: .zero)
  let second = pointEntity(id: "entity:second", point: .init(xMM: 10, yMM: 0))
  let state = makeDocumentState(
    history: LeatherHistoryState(canUndo: true, canRedo: false),
    entities: [first, second]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: state)
  let appState = AppCoordinator(documentAdapter: store)
  store.isDocumentDirty = true
  appState.actions.canvas.selectEntities([first.id])

  appState.actions.canvas.selectEntities([first.id, second.id], extendingSelection: true)

  #expect(appState.actions.canvas.selectedEntityIDs == [second.id])
  #expect(store.appliedPayloads.isEmpty)
  #expect(store.isDocumentDirty)
  #expect(appState.actions.document.canUndo)
  #expect(!appState.actions.document.canRedo)
}

@Test("プロジェクト名の未確定ドラフトは保存前にCoreへ確定する")
@MainActor
func pending_document_name_draft_is_committed_before_save() {
  let initialState = makeDocumentState(name: "旧名称")
  let renamedState = makeDocumentState(name: "保存する名称")
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = renamedState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(LeatherCoreVersionInfo(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  let saveURL = uniqueTempURL("pending-name-save.kawa")
  store.documentURL = saveURL

  appState.actions.document.updatePendingDocumentNameDraft(" 保存する名称 ")
  appState.actions.document.saveProject()

  #expect((store.appliedPayloads.first?["kind"] as? String) == "renameDocument")
  let payload = unwrap(store.appliedPayloads.first?["payload"] as? [String: Any])
  #expect((payload["name"] as? String) == "保存する名称")
  #expect(store.saveDocumentCalls == [saveURL])
  #expect(appState.actions.document.documentName == "保存する名称")
  #expect(appState.actions.document.pendingDocumentNameDraft == nil)
}

@Test("無効なプロジェクト名ドラフトは保存と新規作成を開始しない")
@MainActor
func invalid_pending_document_name_draft_blocks_save_and_new_project() {
  let initialState = makeDocumentState(name: "既存名称")
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(LeatherCoreVersionInfo(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  let saveURL = uniqueTempURL("invalid-pending-name-save.kawa")
  store.documentURL = saveURL
  let createCallsBefore = store.createNewDocumentCalls.count

  appState.actions.document.updatePendingDocumentNameDraft("   ")
  appState.actions.document.saveProject()
  appState.actions.document.createNewProject()

  #expect(store.appliedPayloads.isEmpty)
  #expect(store.saveDocumentCalls.isEmpty)
  #expect(store.createNewDocumentCalls.count == createCallsBefore)
  #expect(appState.actions.document.documentName == "既存名称")
  #expect(appState.actions.document.pendingDocumentNameDraft == "   ")
}

@Test("未確定の有効名称で新規作成に失敗しても元文書と入力を変更しない")
@MainActor
func pending_document_name_draft_is_not_committed_when_new_project_fails() {
  let initialState = makeDocumentState(
    name: "既存名称",
    history: LeatherHistoryState(canUndo: true, canRedo: true),
    entities: [pointEntity(id: "entity:existing", point: .zero)]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(LeatherCoreVersionInfo(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  store.createNewDocumentFailure = "create failed"
  let originalURL = uniqueTempURL("existing.kawa")
  store.documentURL = originalURL
  store.isDocumentDirty = true
  appState.actions.canvas.selectedEntityID = "entity:existing"
  appState.actions.document.updatePendingDocumentNameDraft("入力中の名称")

  appState.actions.document.createNewProject()
  appState.actions.document.discardDocumentChangesAndContinue()

  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.document.documentName == "既存名称")
  #expect(appState.actions.document.pendingDocumentNameDraft == "入力中の名称")
  #expect(appState.actions.document.documentURL == originalURL)
  #expect(appState.actions.document.entities.map(\.id) == ["entity:existing"])
  #expect(appState.actions.document.canUndo)
  #expect(appState.actions.document.canRedo)
  #expect(appState.actions.canvas.selectedEntityID == "entity:existing")
}

@Test("未確定の有効名称で新規作成に成功すると新規文書だけを初期状態へ置き換える")
@MainActor
func pending_document_name_draft_does_not_leak_into_new_project() {
  let initialState = makeDocumentState(name: "既存名称")
  let newState = makeDocumentState(name: "無題プロジェクト")
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.createNewDocumentState = newState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(LeatherCoreVersionInfo(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.document.updatePendingDocumentNameDraft("入力中の名称")
  appState.actions.canvas.selectedEntityID = "entity:stale"

  appState.actions.document.createNewProject()

  #expect(store.appliedPayloads.isEmpty)
  #expect(store.createNewDocumentCalls.last?.name == "無題プロジェクト")
  #expect(appState.actions.document.documentName == "無題プロジェクト")
  #expect(appState.actions.document.documentURL == nil)
  #expect(appState.actions.document.pendingDocumentNameDraft == nil)
  #expect(appState.actions.canvas.selectedEntityID == nil)
  #expect(!appState.actions.document.canUndo)
  #expect(!appState.actions.document.canRedo)
}

@Test("別名保存のキャンセル後も確定した入力名称と元文書を保持する")
@MainActor
func save_as_cancellation_keeps_document_and_committed_name() {
  let initialState = makeDocumentState(name: "既存名称")
  let renamedState = makeDocumentState(name: "入力中の名称")
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = renamedState
  let savePanel = StubDesktopEnvironmentAdapter()
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(LeatherCoreVersionInfo(fileFormatMajor: 0, schemaMajor: 0)) },
    desktopEnvironment: savePanel
  )
  appState.actions.document.updatePendingDocumentNameDraft("入力中の名称")

  #expect(!appState.actions.document.saveProjectAsPanel())

  #expect(savePanel.promptedDocumentNames == ["入力中の名称"])
  #expect(store.saveDocumentCalls.isEmpty)
  #expect(appState.actions.document.documentName == "入力中の名称")
  #expect(appState.actions.document.pendingDocumentNameDraft == nil)
  #expect(appState.actions.document.documentURL == nil)
}

@Test("円弧追加に失敗しても既存の図形、選択、Dirty状態、履歴を変更しない")
@MainActor
func arc_creation_failure_does_not_replace_existing_selection_or_state() {
  let existingArc = arcEntity(
    id: "entity:existing-arc",
    center: .zero,
    radiusMM: 10,
    startAngleRad: 0,
    sweepAngleRad: .pi / 2
  )
  let initialState = makeDocumentState(
    history: LeatherHistoryState(canUndo: true, canRedo: true),
    entities: [existingArc]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(LeatherCoreVersionInfo(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "failed-arc" })
  )
  store.applyCommandFailure = "円弧を追加できません"
  store.isDocumentDirty = true
  appState.actions.canvas.selectedEntityID = existingArc.id
  appState.actions.canvas.selectedEntityIDs = [existingArc.id]

  appState.actions.canvas.applyArcEntityCommand(
    center: .init(xMM: 20, yMM: 20),
    start: .init(xMM: 30, yMM: 20),
    end: .init(xMM: 20, yMM: 30),
    sweepReferenceRad: .pi / 2
  )

  #expect(store.appliedPayloads.count == 1)
  #expect(appState.actions.document.entities == [existingArc])
  #expect(appState.actions.canvas.selectedEntityID == existingArc.id)
  #expect(appState.actions.canvas.selectedEntityIDs == [existingArc.id])
  #expect(store.isDocumentDirty)
  #expect(appState.actions.document.canUndo)
  #expect(appState.actions.document.canRedo)
  #expect(appState.actions.document.statusMessage == "円弧を追加できません")
}

@Test("UC2 AppCoordinator のパラメータ値更新は境界に setParameterValue を送る")
@MainActor
func uc2_app_state_parameter_update_is_sent_through_the_boundary() {
  let parameter = ProjectParameter(
    id: "parameter:width",
    name: "width",
    valueMM: 20.0,
    unit: "millimeter",
    memo: "line width",
    usageCount: 1,
    usedConstraintIDs: ["constraint:line-a-length"]
  )
  let initialState = makeDocumentState(
    name: "Parameter Project",
    parameters: [parameter],
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: .init(xMM: 20.0, yMM: 0.0))
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.document.setParameterValue(
    appState.actions.document.parameters[0], valueMM: 32.0)

  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "setParameterValue")
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["parameterId"] as? String) == "parameter:width")
  #expect((payload["valueMm"] as? Double) == 32.0)
  #expect(appState.actions.document.parameters[0].valueMM == 20.0)
  #expect(appState.actions.document.statusMessage == "width を更新しました")
}

@Test("UXE-C02 AppCoordinator は同名パラメータへの変更を境界へ送らずに拒否する")
@MainActor
func uxe_c02_app_state_rejects_duplicate_parameter_name() {
  let width = ProjectParameter(
    id: "parameter:width", name: "width", valueMM: 20, unit: "millimeter", memo: "",
    usageCount: 0, usedConstraintIDs: []
  )
  let height = ProjectParameter(
    id: "parameter:height", name: "height", valueMM: 30, unit: "millimeter", memo: "",
    usageCount: 0, usedConstraintIDs: []
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(parameters: [width, height])
  )
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  let result = appState.actions.document.updateParameter(
    ProjectParameter(
      id: height.id, name: " width ", valueMM: height.valueMM, unit: height.unit, memo: height.memo,
      usageCount: height.usageCount, usedConstraintIDs: height.usedConstraintIDs
    ))

  #expect(!result)
  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.document.statusMessage == "パラメータ名は重複できません")
}

@Test("UXE-C05 AppCoordinator は同名レイヤーへの変更を境界へ送らずに拒否する")
@MainActor
func uxe_c05_app_state_rejects_duplicate_layer_name() {
  let layers = [
    ProjectLayer(
      id: "layer:cut", name: "Cut Line", kind: .cutLine, visible: true, printable: true,
      colorHex: "#1f2937"
    ),
    ProjectLayer(
      id: "layer:pattern", name: "Pattern", kind: .dimension, visible: true, printable: true,
      colorHex: "#1f2937"
    ),
  ]
  let store = StubDocumentSessionAdapter(createNewDocumentState: makeDocumentState(layers: layers))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  let result = appState.actions.document.renameLayer(layers[1], name: " Cut Line ")

  #expect(!result)
  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.document.statusMessage == "レイヤー名は重複できません")
}

@Test("試作の両端接線化は接続済み円弧を線分へ接する形に更新する", .disabled("接線形状計算は Core 結合テストへ移管"))
@MainActor
func prototype_smooth_arc_tangencies_updates_connected_arc_and_lines() throws {
  let rightLine = lineEntity(
    id: "entity:right-line",
    start: ModelPoint(xMM: 5.0, yMM: 65.0),
    end: ModelPoint(xMM: 15.215188501565995, yMM: 19.0430377003132)
  )
  let leftLine = lineEntity(
    id: "entity:left-line",
    start: ModelPoint(xMM: -15.0, yMM: 65.0),
    end: ModelPoint(xMM: -25.0, yMM: 20.0)
  )
  let arc = arcEntity(
    id: "entity:arc",
    center: ModelPoint(xMM: -5.0, yMM: 15.0),
    radiusMM: 20.615528128088304,
    startAngleRad: 0.19739555984988075,
    sweepAngleRad: -3.5839668765665382
  )
  let state = makeDocumentState(
    entities: [rightLine, leftLine, arc],
    constraints: [
      projectConstraint(
        id: "constraint:start-coincident",
        rawKind: "coincident",
        targets: [
          .controlPoint(entityID: rightLine.id, point: .end),
          .controlPoint(entityID: arc.id, point: .start),
        ]
      ),
      projectConstraint(
        id: "constraint:end-coincident",
        rawKind: "coincident",
        targets: [
          .controlPoint(entityID: leftLine.id, point: .end),
          .controlPoint(entityID: arc.id, point: .end),
        ]
      ),
      projectConstraint(
        id: "constraint:arc-start-fixed",
        rawKind: "fixed",
        targets: [.controlPoint(entityID: arc.id, point: .start)]
      ),
      projectConstraint(
        id: "constraint:arc-end-fixed",
        rawKind: "fixed",
        targets: [.controlPoint(entityID: arc.id, point: .end)]
      ),
    ]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: state)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(LeatherCoreVersionInfo(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedEntityID = arc.id
  appState.actions.canvas.selectedEntityIDs = [arc.id]

  #expect(appState.actions.canvas.canSmoothSelectedArcTangenciesPrototype)

  appState.actions.constraints.smoothSelectedArcTangenciesPrototype()

  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "compound")
  let commands = try #require(store.appliedPayloads[0]["payload"] as? [[String: Any]])
  #expect(commands.filter { ($0["kind"] as? String) == "deleteConstraint" }.count == 2)
  #expect(commands.filter { ($0["kind"] as? String) == "updateEntity" }.count == 3)
  #expect(commands.filter { ($0["kind"] as? String) == "addConstraint" }.count == 2)
  let updatedEntities =
    commands
    .filter { ($0["kind"] as? String) == "updateEntity" }
    .compactMap { ($0["payload"] as? [String: Any])?["id"] as? String }
  #expect(Set(updatedEntities) == [arc.id, rightLine.id, leftLine.id])

  let updatedArcPayload = try #require(
    commands.compactMap { command -> [String: Any]? in
      guard let payload = command["payload"] as? [String: Any],
        payload["id"] as? String == arc.id
      else {
        return nil
      }
      return payload
    }.first)
  let geometry = try #require(updatedArcPayload["kind"] as? [String: Any])
  let updatedArcGeometry = try #require(geometry["arc"] as? [String: Any])
  #expect((updatedArcGeometry["radiusMm"] as? Double ?? 0.0) > 0.0)
  #expect(abs(updatedArcGeometry["sweepAngleRad"] as? Double ?? 0.0) > 0.001)
}

@Test("UC3 AppCoordinator の失敗した更新は状態を壊さない")
@MainActor
func uc3_app_state_rejected_update_keeps_state_unchanged() {
  let initialState = makeDocumentState(
    name: "Conflict Project",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: .init(xMM: 20.0, yMM: 0.0))
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandFailure = "線分長拘束は既存の拘束と矛盾するため追加できません。"

  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedEntityID = "entity:line-a"

  let before = appState.actions.document.entities
  appState.actions.document.setSelectedLineLength(40.0)

  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "setEntityMetric")
  #expect(appState.actions.document.entities == before)
  #expect(appState.actions.canvas.selectedEntityID == "entity:line-a")
  #expect(appState.actions.document.statusMessage == "線分長拘束は既存の拘束と矛盾するため追加できません。")
  #expect(appState.actions.document.alertMessage == nil)
  #expect(appState.actions.workspace.errorPresentation?.identity.category == .operationFailure)
  #expect(appState.actions.workspace.errorPresentation?.message == "線分長拘束は既存の拘束と矛盾するため追加できません。")
}

@Test("UC15 AppCoordinator はドラッグ中に非破壊プレビューを表示し、確定時だけ正式更新する")
@MainActor
func uc15_app_state_drag_preview_uses_preview_command_until_commit() {
  let initialLine = lineEntity(
    id: "entity:line-a",
    start: .zero,
    end: ModelPoint(xMM: 100.0, yMM: 0.0)
  )
  let previewLine = lineEntity(
    id: "entity:line-a",
    start: .zero,
    end: ModelPoint(xMM: 150.0, yMM: 0.0)
  )
  let initialState = makeDocumentState(
    name: "Drag Preview",
    entities: [initialLine],
    constraintStatus: .underConstrained
  )
  let previewState = makeDocumentState(
    name: "Drag Preview",
    entities: [previewLine],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.previewCommandState = previewState
  store.applyCommandState = previewState

  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.document.previewMoveEntity(
    "entity:line-a", delta: ModelPoint(xMM: 50.0, yMM: 50.0))

  #expect(store.previewedPayloads.count == 1)
  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.document.entities == [initialLine])
  #expect(appState.actions.canvas.previewEntities == [previewLine])

  appState.actions.document.moveEntity("entity:line-a", delta: ModelPoint(xMM: 50.0, yMM: 50.0))

  #expect(store.appliedPayloads.count == 1)
  #expect(appState.actions.document.entities == [previewLine])
  #expect(appState.actions.canvas.previewEntities == nil)
}

@Test("UC15 AppCoordinator は複数選択のドラッグ移動を1つの compound コマンドで確定する")
@MainActor
func uc15_app_state_moves_selected_entities_as_one_compound_command() {
  let initialPoint = pointEntity(id: "entity:point-a", point: .zero)
  let initialLine = lineEntity(
    id: "entity:line-a",
    start: ModelPoint(xMM: 0, yMM: 0),
    end: ModelPoint(xMM: 10, yMM: 0)
  )
  let movedPoint = pointEntity(id: "entity:point-a", point: ModelPoint(xMM: 5, yMM: 7))
  let movedLine = lineEntity(
    id: "entity:line-a",
    start: ModelPoint(xMM: 5, yMM: 7),
    end: ModelPoint(xMM: 15, yMM: 7)
  )
  let initialState = makeDocumentState(
    name: "Multi Move",
    entities: [initialPoint, initialLine],
    constraintStatus: .underConstrained
  )
  let movedState = makeDocumentState(
    name: "Multi Move",
    entities: [movedPoint, movedLine],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.previewCommandState = movedState
  store.applyCommandState = movedState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.document.previewMoveEntities(
    ["entity:point-a", "entity:line-a"], delta: ModelPoint(xMM: 5, yMM: 7), duplicating: false)

  #expect((store.previewedPayloads[0]["kind"] as? String) == "moveEntities")
  let previewPayload = unwrap(store.previewedPayloads[0]["payload"] as? [String: Any])
  #expect(
    Set(unwrap(previewPayload["entityIds"] as? [String])) == ["entity:point-a", "entity:line-a"])
  #expect((previewPayload["delta"] as? [String: Double])?["xMm"] == 5.0)
  #expect((previewPayload["delta"] as? [String: Double])?["yMm"] == 7.0)
  #expect(appState.actions.canvas.previewEntities == [movedPoint, movedLine])
  #expect(appState.actions.document.statusMessage == "移動プレビュー中")

  appState.actions.document.moveEntities(
    ["entity:point-a", "entity:line-a"], delta: ModelPoint(xMM: 5, yMM: 7), duplicating: false)

  #expect((store.appliedPayloads[0]["kind"] as? String) == "moveEntities")
  let appliedPayload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect(
    Set(unwrap(appliedPayload["entityIds"] as? [String])) == ["entity:point-a", "entity:line-a"])
  #expect((appliedPayload["delta"] as? [String: Double])?["xMm"] == 5.0)
  #expect((appliedPayload["delta"] as? [String: Double])?["yMm"] == 7.0)
  #expect(appState.actions.document.entities == [movedPoint, movedLine])
  #expect(appState.actions.canvas.selectedEntityIDs == ["entity:point-a", "entity:line-a"])
  #expect(appState.actions.document.statusMessage == "2 個のエンティティを移動しました")
}

@Test("UC15 パーツ内の単一図形ドラッグはパーツ移動として確定する")
@MainActor
func uc15_app_state_moves_part_when_dragging_one_member_entity() {
  let part = ProjectPart(
    id: "part:wallet",
    name: "Wallet",
    originMM: .zero,
    outlineEntityIDs: ["entity:line"],
    holeEntityIDGroups: [],
    entityIDs: ["entity:line"],
    derivedElementIDs: [],
    freeTextIDs: [],
    measurementAnnotationIDs: []
  )
  let initialState = makeDocumentState(
    name: "Part Drag",
    parts: [part],
    entities: [lineEntity(id: "entity:line", start: .zero, end: ModelPoint(xMM: 10, yMM: 0))]
  )
  let movedPart = part.withMetadata(name: part.name, originMM: ModelPoint(xMM: 5, yMM: 7))
  let movedState = makeDocumentState(
    name: "Part Drag",
    parts: [movedPart],
    entities: [
      lineEntity(
        id: "entity:line", start: ModelPoint(xMM: 5, yMM: 7), end: ModelPoint(xMM: 15, yMM: 7))
    ]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.previewCommandState = movedState
  store.applyCommandState = movedState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.document.previewMoveEntities(
    ["entity:line"], delta: ModelPoint(xMM: 5, yMM: 7), duplicating: false)
  #expect((store.previewedPayloads.first?["kind"] as? String) == "movePart")

  appState.actions.document.moveEntities(
    ["entity:line"], delta: ModelPoint(xMM: 5, yMM: 7), duplicating: false)
  #expect((store.appliedPayloads.first?["kind"] as? String) == "movePart")
  #expect(appState.actions.document.parts.first?.originMM == movedPart.originMM)
}

@Test("UC15 AppCoordinator は Option+Drag 相当の複製後に新規複製を選択する")
@MainActor
func uc15_app_state_option_drag_duplicates_and_selects_new_entities() {
  let initialPoint = pointEntity(id: "entity:point-a", point: .zero)
  let initialState = makeDocumentState(
    name: "Option Drag",
    entities: [initialPoint],
    constraintStatus: .underConstrained
  )
  let duplicatedPoint = pointEntity(
    id: "entity:copy-fixed:entity:point-a",
    point: ModelPoint(xMM: 12, yMM: -4)
  )
  let duplicatedState = makeDocumentState(
    name: "Option Drag",
    entities: [initialPoint, duplicatedPoint],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = duplicatedState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "fixed" })
  )

  appState.actions.document.moveEntities(
    ["entity:point-a"], delta: ModelPoint(xMM: 12, yMM: -4), duplicating: true)

  #expect((store.appliedPayloads[0]["kind"] as? String) == "duplicateSelection")
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  let selection = unwrap(payload["selection"] as? [String: Any])
  #expect(selection["entityIds"] as? [String] == ["entity:point-a"])
  #expect(appState.actions.document.entities == [initialPoint, duplicatedPoint])
  #expect(appState.actions.canvas.selectedEntityIDs == ["entity:copy-fixed:entity:point-a"])
  #expect(appState.actions.canvas.selectedEntityID == "entity:copy-fixed:entity:point-a")
  #expect(appState.actions.document.statusMessage == "1 件の選択内容を複製しました")
}

@Test("UC8 AppCoordinator の線分長編集は入力値を反映する")
@MainActor
func uc8_app_state_line_length_edit_updates_selected_entity() {
  let initialState = makeDocumentState(
    name: "Line Edit Project",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 10.0, yMM: 0.0))
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedEntityID = "entity:line-a"

  appState.actions.document.setSelectedLineLength(25.0)

  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "setEntityMetric")
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["entityId"] as? String) == "entity:line-a")
  let metric = unwrap(payload["metric"] as? [String: Any])
  #expect((metric["kind"] as? String) == "segmentLength")
  #expect((metric["valueMm"] as? Double) == 25.0)
}

@Test("UC3 AppCoordinator の距離ツールは点と線分から点線距離拘束の入力待ち後に追加する")
@MainActor
func uc3_app_state_distance_tool_waits_for_point_line_distance_value_entry() {
  let initialState = makeDocumentState(
    name: "Point Line Distance",
    entities: [
      lineEntity(
        id: "entity:line-a",
        start: .zero,
        end: ModelPoint(xMM: 20.0, yMM: 0.0)
      ),
      pointEntity(
        id: "entity:point-a",
        point: ModelPoint(xMM: 4.0, yMM: 6.0)
      ),
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedTool = .distance

  let line = appState.actions.document.entities[0]
  let target = CanvasSelectionTarget(
    entityID: line.id,
    entityLabel: line.label,
    entityKind: line.kind,
    controlPoint: nil,
    point: ModelPoint(xMM: 10.0, yMM: 0.0)
  )
  appState.actions.constraints.handleConstraintTargetSelection(target)

  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintTargets.count == 1)
  #expect(appState.actions.document.statusMessage == "距離拘束: 1/2 対象を選択済み。次は点/制御点、または線分/中心線を選択してください")

  let pointTarget = appState.actions.document.entities[1].entitySelectionTarget
  appState.actions.constraints.handleConstraintTargetSelection(pointTarget)

  #expect(appState.actions.canvas.pendingConstraintTargets.isEmpty)
  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "pointLineDistance")
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.valueText == "6.00")
  #expect(appState.actions.document.statusMessage == "距離の値を入力してください")

  appState.actions.constraints.updatePendingConstraintValueText("8.5")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  #expect(appState.actions.canvas.pendingConstraintValueDraft == nil)
  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "addConstraint")
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["kind"] as? String) == "pointLineDistance")
  let value = unwrap(payload["value"] as? [String: Double])
  #expect(value["fixedMm"] == 8.5)
}

@Test("UC3 AppCoordinator の距離ツールはクリック位置付き線分と円中心から点線距離を作成する")
@MainActor
func uc3_app_state_distance_tool_accepts_clicked_line_and_circle_center() {
  let line = lineEntity(
    id: "entity:line-a",
    start: .zero,
    end: ModelPoint(xMM: 20.0, yMM: 0.0)
  )
  let circle = CanvasEntity(
    id: "entity:circle-a",
    label: "Circle A",
    kind: .circle,
    layerID: "layer:cut-line",
    geometry: .circle(center: ModelPoint(xMM: 4.0, yMM: 6.0), radiusMM: 2.0)
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(
      name: "Circle Center Line Distance",
      entities: [line, circle],
      constraintStatus: .underConstrained
    )
  )
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedTool = .distance

  appState.actions.constraints.handleConstraintTargetSelection(
    CanvasSelectionTarget(
      entityID: line.id,
      entityLabel: line.label,
      entityKind: line.kind,
      controlPoint: nil,
      point: ModelPoint(xMM: 10.0, yMM: 0.0)
    )
  )
  appState.actions.constraints.handleConstraintTargetSelection(
    unwrap(circle.defaultPointSelectionTarget)
  )

  #expect(appState.actions.canvas.pendingConstraintTargets.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "pointLineDistance")
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.valueText == "6.00")
}

@Test("UC3 AppCoordinator の距離ツールは2点間距離拘束の入力待ち後に追加する")
@MainActor
func uc3_app_state_distance_tool_waits_for_point_distance_value_entry() {
  let initialState = makeDocumentState(
    name: "Point Distance",
    entities: [
      pointEntity(id: "entity:point-a", point: .zero),
      pointEntity(id: "entity:point-b", point: ModelPoint(xMM: 3.0, yMM: 4.0)),
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedTool = .distance

  appState.actions.constraints.handleConstraintTargetSelection(
    appState.actions.document.entities[0].entitySelectionTarget)
  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintTargets.count == 1)
  #expect(appState.actions.document.statusMessage == "距離拘束: 1/2 対象を選択済み。次は点/制御点、または線分/中心線を選択してください")

  appState.actions.constraints.handleConstraintTargetSelection(
    appState.actions.document.entities[1].entitySelectionTarget)
  #expect(appState.actions.canvas.pendingConstraintTargets.isEmpty)
  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "distance")
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.valueText == "5.00")

  appState.actions.constraints.updatePendingConstraintValueText("7.25")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  #expect(appState.actions.canvas.pendingConstraintValueDraft == nil)
  #expect(store.appliedPayloads.count == 1)
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["kind"] as? String) == "distance")
  let value = unwrap(payload["value"] as? [String: Double])
  #expect(value["fixedMm"] == 7.25)
}

@Test("UC249 AppCoordinator の線分間距離ツールは線分2本から入力待ち後に追加する")
@MainActor
func uc249_app_state_line_line_distance_tool_waits_for_value_entry() {
  let initialState = makeDocumentState(
    name: "Line Line Distance",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0)),
      centerLineEntity(
        id: "entity:fold-line",
        start: ModelPoint(xMM: 4.0, yMM: 6.0),
        end: ModelPoint(xMM: 4.0, yMM: 18.0)
      ),
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedTool = .lineLineDistance

  let firstTarget = unwrap(appState.actions.document.entities[0].lineSelectionTargets.first?.target)
  appState.actions.constraints.handleConstraintTargetSelection(firstTarget)
  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintTargets.count == 1)

  let secondTarget = unwrap(
    appState.actions.document.entities[1].lineSelectionTargets.first?.target)
  appState.actions.constraints.handleConstraintTargetSelection(secondTarget)
  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "lineLineDistance")
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.valueText == "6.00")

  appState.actions.constraints.updatePendingConstraintValueText("12.5")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  #expect(appState.actions.canvas.pendingConstraintValueDraft == nil)
  #expect(store.appliedPayloads.count == 1)
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["kind"] as? String) == "lineLineDistance")
  let value = unwrap(payload["value"] as? [String: Double])
  #expect(value["fixedMm"] == 12.5)
}

@Test("UC249 AppCoordinator の直線上拘束ツールは点と線分から値なし拘束を追加する")
@MainActor
func uc249_app_state_point_on_line_tool_adds_geometric_constraint() {
  let initialState = makeDocumentState(
    name: "Point On Line",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0)),
      pointEntity(id: "entity:point-a", point: ModelPoint(xMM: 4.0, yMM: 6.0)),
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedTool = .pointOnLine

  let lineTarget = unwrap(appState.actions.document.entities[0].lineSelectionTargets.first?.target)
  appState.actions.constraints.handleConstraintTargetSelection(lineTarget)
  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintTargets.count == 1)

  appState.actions.constraints.handleConstraintTargetSelection(
    appState.actions.document.entities[1].entitySelectionTarget)
  #expect(appState.actions.canvas.pendingConstraintTargets.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintValueDraft == nil)
  #expect(store.appliedPayloads.count == 1)
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["kind"] as? String) == "pointOnLine")
  let targets = unwrap(payload["targets"] as? [[String: Any]])
  #expect(targets.count == 2)
  #expect(targets[0]["entity"] as? String == "entity:point-a")
  #expect(targets[1]["entity"] as? String == "entity:line-a")
  #expect(payload["value"] is NSNull)
}

@Test("UC249 AppCoordinator の直線上拘束ツールは点を先に選んでも距離拘束メッセージを出さない")
@MainActor
func uc249_app_state_point_on_line_tool_keeps_point_on_line_messages_after_first_point() {
  let initialState = makeDocumentState(
    name: "Point On Line Message",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0)),
      pointEntity(id: "entity:point-a", point: ModelPoint(xMM: 4.0, yMM: 6.0)),
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedTool = .pointOnLine

  #expect(
    CanvasInteractionFeature.initialConstraintSelectionMessage(for: .pointOnLine)
      == "直線上拘束: 点または線分を選択してください")

  appState.actions.constraints.handleConstraintTargetSelection(
    appState.actions.document.entities[1].entitySelectionTarget)

  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintTargets.count == 1)
  #expect(appState.actions.document.statusMessage == "直線上拘束: 1/2 対象を選択済み。次は点または線分を選択してください")
}

@Test("UC249 AppCoordinator の直線上拘束ツールは点同士の選択を直線上拘束エラーとして扱う")
@MainActor
func uc249_app_state_point_on_line_tool_rejects_two_points_with_point_on_line_message() {
  let initialState = makeDocumentState(
    name: "Point On Line Invalid Targets",
    entities: [
      pointEntity(id: "entity:point-a", point: ModelPoint(xMM: 4.0, yMM: 6.0)),
      pointEntity(id: "entity:point-b", point: ModelPoint(xMM: 8.0, yMM: 6.0)),
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedTool = .pointOnLine

  appState.actions.constraints.handleConstraintTargetSelection(
    appState.actions.document.entities[0].entitySelectionTarget)
  appState.actions.constraints.handleConstraintTargetSelection(
    appState.actions.document.entities[1].entitySelectionTarget)

  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintTargets.isEmpty)
  #expect(appState.actions.document.statusMessage == "直線上拘束には点と線分が必要です")
}

@Test("UC3 AppCoordinator の線分長ツールは線分長拘束の入力待ち後に追加する")
@MainActor
func uc3_app_state_segment_length_tool_waits_for_value_entry() {
  let initialState = makeDocumentState(
    name: "Segment Length Draft",
    entities: [
      lineEntity(
        id: "entity:line-a",
        start: .zero,
        end: ModelPoint(xMM: 20.0, yMM: 0.0)
      )
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedTool = .segmentLength

  let target = unwrap(appState.actions.document.entities[0].lineSelectionTargets.first?.target)
  appState.actions.constraints.handleConstraintTargetSelection(target)

  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "segmentLength")
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.valueText == "20.00")

  appState.actions.constraints.updatePendingConstraintValueText("32.5")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  #expect(appState.actions.canvas.pendingConstraintValueDraft == nil)
  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "addConstraint")
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["kind"] as? String) == "segmentLength")
  let value = unwrap(payload["value"] as? [String: Double])
  #expect(value["fixedMm"] == 32.5)
}

@Test("UC3 AppCoordinator の線分長ツールはクリック位置付き線分 target でも入力待ちになる")
@MainActor
func uc3_app_state_segment_length_tool_accepts_click_point_line_target() {
  let initialState = makeDocumentState(
    name: "Segment Length Click Target",
    entities: [
      lineEntity(
        id: "entity:line-a",
        start: .zero,
        end: ModelPoint(xMM: 20.0, yMM: 0.0)
      )
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedTool = .segmentLength
  let baseTarget = unwrap(appState.actions.document.entities[0].lineSelectionTargets.first?.target)
  let clickedTarget = CanvasSelectionTarget(
    entityID: baseTarget.entityID,
    entityLabel: baseTarget.entityLabel,
    entityKind: baseTarget.entityKind,
    controlPoint: baseTarget.controlPoint,
    point: ModelPoint(xMM: 8.0, yMM: 0.0)
  )

  appState.actions.constraints.handleConstraintTargetSelection(clickedTarget)

  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "segmentLength")
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.valueText == "20.00")
}

@Test("計測表示の線分長ツールはフィレット解決済み線分を元線分として保存する")
@MainActor
func measurement_segment_length_tool_maps_fillet_resolved_line_to_source_entity() {
  let bottom = lineEntity(
    id: "entity:bottom",
    start: .zero,
    end: ModelPoint(xMM: 20.0, yMM: 0.0)
  ).withFilletSuppressedStyle()
  let right = lineEntity(
    id: "entity:right",
    start: ModelPoint(xMM: 20.0, yMM: 0.0),
    end: ModelPoint(xMM: 20.0, yMM: 10.0)
  ).withFilletSuppressedStyle()
  let resolvedBottom = lineEntity(
    id: "derived:fillet-a:resolved:0",
    start: ModelPoint(xMM: 2.0, yMM: 0.0),
    end: ModelPoint(xMM: 18.0, yMM: 0.0)
  ).withCoreMetadata(
    derivedElementID: "derived:fillet-a",
    derivedResolvedIndex: 0,
    sourceEntityID: "entity:bottom",
    isSuppressedByFillet: false
  )
  let resolvedCorner = arcEntity(
    id: "derived:fillet-a:resolved:1",
    center: ModelPoint(xMM: 18.0, yMM: 2.0),
    radiusMM: 2.0,
    startAngleRad: -.pi / 2.0,
    sweepAngleRad: .pi / 2.0
  )
  let fillet = ProjectDerivedElement(
    id: "derived:fillet-a",
    layerID: "layer:cut-line",
    kind: .fillet,
    sourceEntityIDs: ["entity:bottom", "entity:right"],
    distanceMM: nil,
    distanceParameterID: nil,
    radiusMM: 2.0,
    radiusParameterID: nil,
    filletClosed: false
  )
  let initialState = makeDocumentState(
    name: "Measurement Fillet Target",
    entities: [bottom, right, resolvedBottom, resolvedCorner],
    derivedElements: [fillet],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedTool = .measureSegmentLength

  appState.actions.constraints.handleConstraintTargetSelection(resolvedBottom.entitySelectionTarget)

  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "addMeasurementAnnotation")
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["kind"] as? String) == "segmentLength")
  let targets = unwrap(payload["targets"] as? [[String: Any]])
  #expect((targets.first?["entity"] as? String) == "entity:bottom")
  #expect(appState.actions.document.statusMessage != "派生要素には拘束を追加できません。")
}

@Test("計測表示の直径ツールは円弧にも直径表示を追加できる")
@MainActor
func measurement_diameter_tool_accepts_arc_targets() {
  let arc = arcEntity(
    id: "entity:arc-a",
    center: .zero,
    radiusMM: 12.0,
    startAngleRad: 0.0,
    sweepAngleRad: .pi / 2.0
  )
  let initialState = makeDocumentState(
    name: "Arc Diameter Measurement",
    entities: [arc],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedTool = .measureDiameter

  appState.actions.constraints.handleConstraintTargetSelection(arc.entitySelectionTarget)

  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "addMeasurementAnnotation")
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["kind"] as? String) == "diameter")
  let targets = unwrap(payload["targets"] as? [[String: Any]])
  #expect((targets.first?["entity"] as? String) == "entity:arc-a")
}

@Test("寸法拘束表示の初回移動は表示注釈追加コマンドを送る")
@MainActor
func dimension_constraint_annotation_first_move_sends_add_command() {
  let line = lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 10.0, yMM: 0.0))
  let constraint = projectConstraint(
    id: "constraint:length-a",
    rawKind: "segmentLength",
    targets: [.entity("entity:line-a")],
    valueMM: 10.0
  )
  let initialState = makeDocumentState(
    entities: [line],
    constraints: [constraint],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.canvas.moveDimensionConstraintAnnotation(
    constraintID: "constraint:length-a",
    delta: ModelPoint(xMM: 2.0, yMM: -1.0),
    labelOnly: true
  )

  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "moveDimensionConstraintAnnotation")
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["constraintId"] as? String) == "constraint:length-a")
  let delta = unwrap(payload["delta"] as? [String: Any])
  #expect((delta["xMm"] as? Double) == 2.0)
  #expect((delta["yMm"] as? Double) == -1.0)
  #expect((payload["labelOnly"] as? Bool) == true)
}

@Test("寸法拘束表示の移動は既存表示注釈を更新する")
@MainActor
func dimension_constraint_annotation_move_sends_update_command() {
  let line = lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 10.0, yMM: 0.0))
  let constraint = projectConstraint(
    id: "constraint:length-a",
    rawKind: "segmentLength",
    targets: [.entity("entity:line-a")],
    valueMM: 10.0
  )
  let initialState = makeDocumentState(
    entities: [line],
    constraints: [constraint],
    dimensionConstraintAnnotations: [
      ProjectDimensionConstraintAnnotation(
        constraintID: "constraint:length-a",
        labelOffsetMM: ModelPoint(xMM: 1.0, yMM: 1.0),
        overallOffsetMM: ModelPoint(xMM: 0.5, yMM: 0.0),
        visible: true
      )
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.canvas.moveDimensionConstraintAnnotation(
    constraintID: "constraint:length-a",
    delta: ModelPoint(xMM: 2.0, yMM: -1.0),
    labelOnly: false
  )

  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "moveDimensionConstraintAnnotation")
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  let delta = unwrap(payload["delta"] as? [String: Any])
  #expect((delta["xMm"] as? Double) == 2.0)
  #expect((delta["yMm"] as? Double) == -1.0)
  #expect((payload["labelOnly"] as? Bool) == false)
}

@Test("計測表示の角度ツールは円弧角表示を扱わない")
@MainActor
func measurement_angle_tool_rejects_arc_targets() {
  let arc = arcEntity(
    id: "entity:arc-a",
    center: .zero,
    radiusMM: 12.0,
    startAngleRad: 0.0,
    sweepAngleRad: .pi / 2.0
  )
  let initialState = makeDocumentState(
    name: "Arc Angle Measurement",
    entities: [arc],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedTool = .measureAngle

  appState.actions.constraints.handleConstraintTargetSelection(arc.entitySelectionTarget)

  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.document.statusMessage == "entity:arc-a は線分拘束の対象にできません")
}

@Test("UC3 AppCoordinator の線分長ツールは固定値とパラメータ参照を同じ導線で選べる")
@MainActor
func uc3_app_state_segment_length_tool_supports_parameter_reference_in_same_entry_flow() {
  let parameter = ProjectParameter(
    id: "parameter:width",
    name: "width",
    valueMM: 24.0,
    unit: "millimeter",
    memo: "",
    usageCount: 0,
    usedConstraintIDs: []
  )
  let initialState = makeDocumentState(
    name: "Segment Length Parameter Draft",
    parameters: [parameter],
    entities: [
      lineEntity(
        id: "entity:line-a",
        start: .zero,
        end: ModelPoint(xMM: 20.0, yMM: 0.0)
      )
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedTool = .segmentLength

  let target = unwrap(appState.actions.document.entities[0].lineSelectionTargets.first?.target)
  appState.actions.constraints.handleConstraintTargetSelection(target)

  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "segmentLength")
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.allowsParameterReference == true)
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.entryMode == .fixedValue)
  #expect(appState.actions.document.statusMessage == "線分長の固定値を入力するか、参照するパラメータを選択してください")

  appState.actions.constraints.updatePendingConstraintEntryMode(.parameterReference)

  #expect(appState.actions.canvas.pendingConstraintValueDraft?.entryMode == .parameterReference)
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.selectedParameterID == "parameter:width")
  #expect(appState.actions.document.statusMessage == "線分長で使うパラメータを選択してください")

  appState.actions.constraints.commitPendingConstraintValueEntry()

  #expect(appState.actions.canvas.pendingConstraintValueDraft == nil)
  #expect(store.appliedPayloads.count == 1)
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["kind"] as? String) == "segmentLength")
  #expect((payload["value"] as? [String: String])?["parameter"] == "parameter:width")
}

@Test("UC8 AppCoordinator の半径拘束は円弧選択後に入力待ちになる")
@MainActor
func uc8_app_state_radius_constraint_on_arc_waits_for_value_entry() {
  let arc = CanvasEntity(
    id: "entity:arc-a",
    label: "Arc A",
    kind: .arc,
    layerID: "layer:cut-line",
    geometry: .arc(
      center: .init(xMM: 20.0, yMM: 10.0),
      radiusMM: 12.0,
      startAngleRad: 0.0,
      sweepAngleRad: .pi / 2.0
    )
  )
  let initialState = makeDocumentState(
    name: "Radius Constraint Project",
    entities: [arc],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.canvas.activateTool(.radius)
  appState.actions.canvas.selectTarget(
    unwrap(appState.actions.document.entities.first?.entitySelectionTarget))

  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "radius")
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.valueText == "12.00")

  appState.actions.constraints.updatePendingConstraintValueText("15.5")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  #expect(appState.actions.canvas.pendingConstraintValueDraft == nil)
  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "addConstraint")
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["kind"] as? String) == "radius")
  #expect((payload["value"] as? [String: Any])?["fixedMm"] as? Double == 15.5)
  let targets = unwrap(payload["targets"] as? [[String: Any]])
  #expect(targets.count == 1)
  #expect((targets[0]["entity"] as? String) == "entity:arc-a")
}

@Test("UC8 AppCoordinator の角度拘束は円弧選択後に度数法の入力待ちになる")
@MainActor
func uc8_app_state_angle_constraint_on_arc_waits_for_degree_value_entry() {
  let arc = CanvasEntity(
    id: "entity:arc-a",
    label: "Arc A",
    kind: .arc,
    layerID: "layer:cut-line",
    geometry: .arc(
      center: .init(xMM: 20.0, yMM: 10.0),
      radiusMM: 12.0,
      startAngleRad: 0.0,
      sweepAngleRad: .pi / 2.0
    )
  )
  let initialState = makeDocumentState(
    name: "Arc Angle Constraint Project",
    entities: [arc],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.canvas.activateTool(.angle)
  appState.actions.canvas.selectTarget(
    unwrap(appState.actions.document.entities.first?.entitySelectionTarget))

  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "angle")
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.valueText == "90.00")
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.unit == "°")

  appState.actions.constraints.updatePendingConstraintValueText("120")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  #expect(appState.actions.canvas.pendingConstraintValueDraft == nil)
  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "addConstraint")
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["kind"] as? String) == "angle")
  #expect((payload["value"] as? [String: Any])?["fixedDegrees"] as? Double == 120.0)
  let targets = unwrap(payload["targets"] as? [[String: Any]])
  #expect(targets.count == 1)
  #expect((targets[0]["entity"] as? String) == "entity:arc-a")
}

@Test("UC8 AppCoordinator の角度拘束は共有端点の初期角度を Core preflight から取得する")
@MainActor
func uc8_app_state_angle_constraint_uses_core_preflight_for_shared_endpoint_initial_value() {
  let first = lineEntity(
    id: "entity:first",
    start: ModelPoint(xMM: 10.0, yMM: 0.0),
    end: .zero
  )
  let second = lineEntity(
    id: "entity:second",
    start: .zero,
    end: ModelPoint(xMM: 0.0, yMM: 5.0)
  )
  let initialState = makeDocumentState(
    name: "Shared Endpoint Angle Project",
    entities: [first, second],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.preflightConstraintResult = .success(
    ConstraintPreflightResult(kind: "angle", value: .fixedDegrees(90.0))
  )
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.canvas.activateTool(.angle)
  appState.actions.canvas.selectTarget(first.entitySelectionTarget)
  appState.actions.canvas.selectTarget(second.entitySelectionTarget)

  #expect(store.preflightConstraintCalls.count == 1)
  #expect(store.preflightConstraintCalls[0].kind == "angle")
  #expect((store.preflightConstraintCalls[0].targets[0]["entity"] as? String) == "entity:first")
  #expect((store.preflightConstraintCalls[0].targets[1]["entity"] as? String) == "entity:second")
  #expect(store.appliedPayloads.count == 1)
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["kind"] as? String) == "angle")
  #expect((payload["value"] as? [String: Any])?["fixedDegrees"] as? Double == 90.0)
}

@Test("接線拘束は線分端点と円弧端点を Core preflight 後に追加する")
@MainActor
func tangent_constraint_uses_core_preflight_before_add_constraint() {
  let line = lineEntity(
    id: "entity:line",
    start: ModelPoint(xMM: -10.0, yMM: 0.0),
    end: .zero
  )
  let arc = arcEntity(
    id: "entity:arc",
    center: ModelPoint(xMM: 10.0, yMM: 0.0),
    radiusMM: 10.0,
    startAngleRad: .pi,
    sweepAngleRad: .pi / 2
  )
  let initialState = makeDocumentState(
    name: "Tangent Constraint Project",
    entities: [line, arc],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.preflightConstraintResult = .success(
    ConstraintPreflightResult(kind: "tangent", value: nil)
  )
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.canvas.activateTool(.tangent)
  appState.actions.canvas.selectTarget(
    unwrap(line.pointSelectionTargets.first { $0.target.controlPoint == .end }?.target))
  appState.actions.canvas.selectTarget(
    unwrap(arc.pointSelectionTargets.first { $0.target.controlPoint == .arcStart }?.target))

  #expect(store.preflightConstraintCalls.count == 1)
  #expect(store.preflightConstraintCalls[0].kind == "tangent")
  #expect(store.appliedPayloads.count == 1)
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["kind"] as? String) == "tangent")
  let targets = unwrap(payload["targets"] as? [[String: Any]])
  #expect((targets[0]["controlPoint"] as? [String: Any])?["entity_id"] as? String == "entity:line")
  #expect((targets[1]["controlPoint"] as? [String: Any])?["entity_id"] as? String == "entity:arc")
}

@Test("接線拘束は未接続ターゲットを Core preflight 失敗として案内する")
@MainActor
func tangent_constraint_reports_preflight_failure_for_disconnected_targets() {
  let line = lineEntity(
    id: "entity:line",
    start: ModelPoint(xMM: -10.0, yMM: 0.0),
    end: .zero
  )
  let arc = arcEntity(
    id: "entity:arc",
    center: ModelPoint(xMM: 30.0, yMM: 0.0),
    radiusMM: 10.0,
    startAngleRad: .pi,
    sweepAngleRad: .pi / 2
  )
  let initialState = makeDocumentState(
    name: "Disconnected Tangent Constraint Project",
    entities: [line, arc],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.preflightConstraintResult = .failure("invalid tangent targets")
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.canvas.activateTool(.tangent)
  appState.actions.canvas.selectTarget(
    unwrap(line.pointSelectionTargets.first { $0.target.controlPoint == .end }?.target))
  appState.actions.canvas.selectTarget(
    unwrap(arc.pointSelectionTargets.first { $0.target.controlPoint == .arcStart }?.target))

  #expect(store.preflightConstraintCalls.count == 1)
  #expect(store.appliedPayloads.isEmpty)
  #expect(
    appState.actions.document.statusMessage
      == AppStrings.tr("status.tangent_requires_connected_line_arc"))
}

@Test("UC8 AppCoordinator の直径拘束は円選択後に入力待ちになる")
@MainActor
func uc8_app_state_diameter_constraint_on_circle_waits_for_value_entry() {
  let circle = CanvasEntity(
    id: "entity:circle-a",
    label: "Circle A",
    kind: .circle,
    layerID: "layer:cut-line",
    geometry: .circle(
      center: .init(xMM: 10.0, yMM: 10.0),
      radiusMM: 8.0
    )
  )
  let initialState = makeDocumentState(
    name: "Diameter Constraint Project",
    entities: [circle],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.canvas.activateTool(.diameter)
  appState.actions.canvas.selectTarget(
    unwrap(appState.actions.document.entities.first?.entitySelectionTarget))

  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "diameter")
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.valueText == "16.00")

  appState.actions.constraints.updatePendingConstraintValueText("18")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  #expect(appState.actions.canvas.pendingConstraintValueDraft == nil)
  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "addConstraint")
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["kind"] as? String) == "diameter")
  #expect((payload["value"] as? [String: Any])?["fixedMm"] as? Double == 18.0)
  let targets = unwrap(payload["targets"] as? [[String: Any]])
  #expect(targets.count == 1)
  #expect((targets[0]["entity"] as? String) == "entity:circle-a")
}

@Test("UC4 AppCoordinator の Undo/Redo は一時状態を消して状態を戻す")
@MainActor
func uc4_app_state_undo_and_redo_restore_state_and_clear_transients() {
  let currentState = makeDocumentState(
    name: "Current State",
    printOrientation: .landscape,
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 15.0, yMM: 0.0))
    ],
    constraintStatus: .underConstrained
  )
  let undoState = makeDocumentState(
    name: "Undo State",
    printOrientation: .portrait,
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 10.0, yMM: 0.0))
    ],
    constraintStatus: .underConstrained
  )
  let redoState = makeDocumentState(
    name: "Redo State",
    printOrientation: .landscape,
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: currentState)
  store.undoState = undoState
  store.redoState = redoState
  store.canUndo = true

  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) })
  appState.actions.output.outputRequestDraft = OutputRequestDraft(
    destination: .pdf,
    options: OutputPresentationOptions(
      orientation: .landscape,
      includeDimensionLabels: true,
      includeScaleGuide: false,
      rotationDeg: 0
    ),
    directPrintSession: nil
  )
  #expect(appState.actions.workspace.a4ReferenceOrientation == .landscape)
  appState.actions.canvas.selectedEntityID = "entity:point-a"
  appState.actions.canvas.pendingConstraintTargets = [
    CanvasSelectionTarget(
      entityID: "entity:line-a",
      entityLabel: "line-a",
      entityKind: .lineSegment,
      controlPoint: nil,
      point: nil
    )
  ]
  appState.actions.canvas.draftStartPoint = ModelPoint(xMM: 1.0, yMM: 2.0)
  appState.actions.canvas.draftCurrentPoint = ModelPoint(xMM: 3.0, yMM: 4.0)

  appState.actions.document.undo()

  #expect(store.undoCalls == [.editDisplay])
  #expect(appState.actions.canvas.selectedEntityID == nil)
  #expect(appState.actions.canvas.pendingConstraintTargets.isEmpty)
  #expect(appState.actions.canvas.draftStartPoint == nil)
  #expect(appState.actions.canvas.draftCurrentPoint == nil)
  #expect(appState.actions.document.documentName == "Undo State")
  #expect(appState.actions.document.entities.map(\.id) == ["entity:line-a"])
  #expect(appState.actions.workspace.a4ReferenceOrientation == .portrait)
  #expect(appState.actions.output.outputRequestDraft?.options.orientation == .portrait)
  #expect(appState.actions.document.statusMessage == "元に戻しました。")

  appState.actions.document.redo()

  #expect(store.redoCalls == [.editDisplay])
  #expect(appState.actions.document.documentName == "Redo State")
  #expect(
    appState.actions.document.entities.map(\.geometry)
      == [
        lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0)).geometry
      ]
  )
  #expect(appState.actions.workspace.a4ReferenceOrientation == .landscape)
  #expect(appState.actions.output.outputRequestDraft?.options.orientation == .landscape)
  #expect(appState.actions.document.statusMessage == "やり直しました。")
}

@Test("UC1 復旧した文書の印刷向きをワークスペースへ反映する")
@MainActor
func uc1_recovery_restores_print_orientation() {
  let initialState = makeDocumentState(name: "Initial", printOrientation: .portrait)
  let recoveredState = makeDocumentState(name: "Recovered", printOrientation: .landscape)
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.recoveredDocumentState = recoveredState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  let snapshotURL = uniqueTempURL("orientation-recovery.lcraft")
  let candidate = DocumentRecoveryCandidate(
    recoveryID: "recovery:orientation",
    generationID: "generation:orientation",
    displayName: "Recovered",
    originalDocumentURL: nil,
    updatedAt: Date(),
    containerURL: snapshotURL.deletingLastPathComponent(),
    metadataURL: nil,
    status: .recoverable(snapshotURL: snapshotURL)
  )

  appState.actions.recovery.recoverRecoveryCandidate(candidate)

  #expect(store.recoverDocumentCalls.count == 1)
  #expect(appState.actions.workspace.a4ReferenceOrientation == .landscape)
}

@Test("UC4 AppCoordinator の空履歴 Undo/Redo は状態を壊さず拒否される")
@MainActor
func uc4_app_state_empty_history_undo_redo_are_rejected_without_state_changes() {
  let initialState = makeDocumentState(
    name: "Empty History",
    entities: [
      pointEntity(id: "entity:point-a", point: .zero)
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.undoFailure = "元に戻す操作はありません"
  store.redoFailure = "やり直す操作はありません"
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) })
  appState.actions.canvas.selectedEntityID = "entity:point-a"
  appState.actions.canvas.pendingConstraintTargets = [
    CanvasSelectionTarget(
      entityID: "entity:point-a",
      entityLabel: "Point A",
      entityKind: .point,
      controlPoint: nil,
      point: .zero
    )
  ]
  appState.actions.canvas.draftStartPoint = .init(xMM: 1.0, yMM: 2.0)
  appState.actions.canvas.draftCurrentPoint = .init(xMM: 3.0, yMM: 4.0)

  let before = (
    selectedEntityID: appState.actions.canvas.selectedEntityID,
    pendingConstraintTargets: appState.actions.canvas.pendingConstraintTargets,
    draftStartPoint: appState.actions.canvas.draftStartPoint,
    draftCurrentPoint: appState.actions.canvas.draftCurrentPoint,
    statusMessage: appState.actions.document.statusMessage
  )

  appState.actions.document.undo()
  #expect(appState.actions.canvas.selectedEntityID == before.selectedEntityID)
  #expect(appState.actions.canvas.pendingConstraintTargets == before.pendingConstraintTargets)
  #expect(appState.actions.canvas.draftStartPoint == before.draftStartPoint)
  #expect(appState.actions.canvas.draftCurrentPoint == before.draftCurrentPoint)
  #expect(appState.actions.document.statusMessage == "元に戻す操作はありません")
  #expect(appState.actions.document.coreStatus == .unavailable("元に戻す操作はありません"))
  #expect(appState.actions.workspace.errorPresentation?.message == "元に戻す操作はありません")

  appState.actions.document.redo()
  #expect(appState.actions.canvas.selectedEntityID == before.selectedEntityID)
  #expect(appState.actions.canvas.pendingConstraintTargets == before.pendingConstraintTargets)
  #expect(appState.actions.canvas.draftStartPoint == before.draftStartPoint)
  #expect(appState.actions.canvas.draftCurrentPoint == before.draftCurrentPoint)
  #expect(appState.actions.document.statusMessage == "やり直す操作はありません")
  #expect(appState.actions.document.coreStatus == .unavailable("やり直す操作はありません"))
  #expect(appState.actions.workspace.errorPresentation?.message == "やり直す操作はありません")
}

@Test("UC1/UC6 AppCoordinator の表示・ズーム・選択・キャンバス操作は状態を更新する")
@MainActor
func uc1_uc6_app_state_view_and_canvas_controls_update_state() {
  let initialState = makeDocumentState(
    name: "Canvas Project",
    entities: [
      pointEntity(id: "entity:point-a", label: "Point A", point: .zero),
      lineEntity(
        id: "entity:line-a", label: "Line A", start: .zero, end: .init(xMM: 10.0, yMM: 0.0)),
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.workspace.setGridSnapEnabled(false)
  appState.actions.workspace.setGridVisible(false)
  appState.actions.workspace.setA4ReferenceVisible(false)
  appState.actions.workspace.setLayerPanelVisible(false)
  appState.actions.workspace.setParameterPanelVisible(false)
  appState.actions.workspace.setInspectorPanelVisible(false)
  appState.actions.workspace.setBottomWorkbenchVisible(false)
  appState.actions.canvas.setPointSnapEnabled(false)

  #expect(!appState.actions.workspace.gridSnapEnabled)
  #expect(!appState.actions.workspace.gridVisible)
  #expect(!appState.actions.workspace.a4ReferenceVisible)
  #expect(!appState.actions.canvas.layerPanelVisible)
  #expect(!appState.actions.canvas.parameterPanelVisible)
  #expect(!appState.actions.workspace.inspectorPanelVisible)
  #expect(!appState.actions.workspace.bottomWorkbenchVisible)
  #expect(!appState.actions.workspace.pointSnapEnabled)

  appState.actions.canvas.canvasZoomScale = 2.0
  appState.actions.canvas.canvasPanOffset = CGSize(width: 40, height: -20)
  appState.actions.canvas.zoomIn()
  #expect(appState.actions.canvas.canvasZoomScale == 2.5)
  appState.actions.canvas.zoomOut()
  #expect(appState.actions.canvas.canvasZoomScale == 2.0)
  appState.actions.canvas.panCanvas(by: CGSize(width: 12, height: -8))
  #expect(appState.actions.canvas.canvasPanOffset == CGSize(width: 52, height: -28))
  appState.actions.canvas.setCanvasViewport(
    scale: 1.75,
    panOffset: CGSize(width: -15, height: 24),
    message: "拡大率を変更しました"
  )
  #expect(appState.actions.canvas.canvasZoomScale == 1.75)
  #expect(appState.actions.canvas.canvasPanOffset == CGSize(width: -15, height: 24))
  #expect(appState.actions.document.statusMessage == "拡大率を変更しました 175%")
  appState.actions.canvas.zoomToFit()
  #expect(appState.actions.canvas.canvasZoomScale == 1.0)
  #expect(appState.actions.canvas.canvasPanOffset == .zero)

  appState.actions.canvas.draftStartPoint = .init(xMM: 99.0, yMM: 99.0)
  appState.actions.canvas.draftCurrentPoint = .init(xMM: 88.0, yMM: 88.0)
  appState.actions.canvas.pendingConstraintTargets = [
    CanvasSelectionTarget(
      entityID: "entity:line-a",
      entityLabel: "Line A",
      entityKind: .lineSegment,
      controlPoint: nil,
      point: .zero
    )
  ]
  appState.actions.canvas.activateTool(.line)
  #expect(appState.actions.canvas.selectedTool == .line)
  #expect(appState.actions.canvas.draftStartPoint == nil)
  #expect(appState.actions.canvas.draftCurrentPoint == nil)
  #expect(appState.actions.canvas.pendingConstraintTargets.isEmpty)
  #expect(appState.actions.document.statusMessage == CanvasTool.line.idleMessage)

  appState.actions.canvas.selectEntity("entity:line-a")
  #expect(appState.actions.canvas.selectedEntityID == "entity:line-a")
  #expect(appState.actions.canvas.selectedEntityIDs == ["entity:line-a"])
  #expect(appState.actions.document.statusMessage == "Line A を選択中")

  appState.actions.canvas.toggleEntitySelection("entity:point-a")
  #expect(appState.actions.canvas.selectedEntityIDs == ["entity:line-a", "entity:point-a"])
  #expect(appState.actions.canvas.selectedEntityID == "entity:point-a")
  #expect(appState.actions.document.statusMessage == "2 個のエンティティを選択中")

  appState.actions.canvas.selectEntities(["entity:point-a", "missing-entity"])
  #expect(appState.actions.canvas.selectedEntityIDs == ["entity:point-a"])
  #expect(appState.actions.canvas.selectedEntityID == "entity:point-a")
  #expect(appState.actions.document.statusMessage == "Point A を選択中")

  appState.actions.canvas.selectAllEntities()
  #expect(appState.actions.canvas.selectedEntityIDs == ["entity:point-a", "entity:line-a"])
  #expect(appState.actions.document.statusMessage == "2 個のエンティティを選択中")

  appState.actions.canvas.selectTarget(
    unwrap(
      appState.actions.document.entities.first(where: { $0.id == "entity:point-a" })?
        .entitySelectionTarget))
  #expect(appState.actions.canvas.selectedEntityID == "entity:point-a")
  #expect(appState.actions.document.statusMessage == "Point A を選択中")

  appState.actions.canvas.handleCanvasCursor(
    .init(xMM: 12.0, yMM: 13.0), canvasPoint: CGPoint(x: 240.0, y: 320.0))
  #expect(appState.actions.canvas.cursorModelPoint == .init(xMM: 12.0, yMM: 13.0))
  #expect(appState.actions.canvas.cursorCanvasPoint == CGPoint(x: 240.0, y: 320.0))

  appState.actions.canvas.selectedTool = .line
  appState.actions.canvas.handleCanvasPlacement(.init(xMM: 1.0, yMM: 2.0))
  #expect(appState.actions.canvas.draftStartPoint == .init(xMM: 1.0, yMM: 2.0))
  #expect(appState.actions.canvas.draftCurrentPoint == .init(xMM: 1.0, yMM: 2.0))
  #expect(appState.actions.document.statusMessage == CanvasTool.line.placementContinuationMessage)

  appState.actions.canvas.handleCanvasHover(.init(xMM: 3.0, yMM: 4.0))
  #expect(appState.actions.canvas.draftCurrentPoint == .init(xMM: 3.0, yMM: 4.0))

  appState.actions.canvas.handleCanvasPlacement(.init(xMM: 5.0, yMM: 6.0))
  #expect(appState.actions.canvas.draftStartPoint == nil)
  #expect(appState.actions.canvas.draftCurrentPoint == nil)
  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "createEntityFromGesture")
  #expect(appState.actions.document.statusMessage == "\(CanvasTool.line.displayName)を追加しました")

  appState.actions.canvas.selectedTool = .point
  appState.actions.canvas.handleCanvasPlacement(.init(xMM: 7.0, yMM: 8.0))
  #expect(store.appliedPayloads.count == 2)
  #expect((store.appliedPayloads[1]["kind"] as? String) == "createEntityFromGesture")
  #expect(appState.actions.document.statusMessage == "\(CanvasTool.point.displayName)を追加しました")
}

@Test("UC1 AppCoordinator は管理タブ滞在中の選択変更を inspector badge で検出する")
@MainActor
func uc1_app_state_tracks_pending_inspector_selection_changes() {
  let initialState = makeDocumentState(
    entities: [
      pointEntity(id: "entity:point-a", point: .zero),
      lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 10, yMM: 0)),
    ]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.inspector.setInspectorTab(.layers)
  #expect(!appState.actions.inspector.inspectorHasPendingSelectionChange)

  appState.actions.canvas.selectEntity("entity:point-a")
  #expect(appState.actions.inspector.inspectorHasPendingSelectionChange)

  appState.actions.inspector.revealInspectorSelectionTab()
  #expect(appState.actions.inspector.inspectorTab == .selection)
  #expect(!appState.actions.inspector.inspectorHasPendingSelectionChange)

  appState.actions.canvas.selectEntity("entity:line-a")
  appState.actions.inspector.setInspectorTab(.layers)
  #expect(!appState.actions.inspector.inspectorHasPendingSelectionChange)
}

@Test("UC1 AppCoordinator は管理タブごとの検索表示と query を保持する")
@MainActor
func uc1_app_state_manages_inspector_search_visibility_and_queries() {
  let initialState = makeDocumentState(
    parameters: (0..<8).map {
      ProjectParameter(
        id: "parameter:\($0)",
        name: "Param \($0)",
        valueMM: Double($0),
        unit: "millimeter",
        memo: "memo \($0)",
        usageCount: 0,
        usedConstraintIDs: []
      )
    }
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.inspector.setInspectorTab(.layers)
  #expect(!appState.actions.inspector.shouldShowLayerInspectorSearch)
  appState.actions.inspector.revealInspectorSearchForCurrentTab()
  #expect(appState.actions.inspector.shouldShowLayerInspectorSearch)
  appState.actions.inspector.inspectorLayerSearchQuery = "cut"
  #expect(appState.actions.inspector.filteredInspectorLayers.map(\.id) == ["layer:cut-line"])
  appState.actions.inspector.inspectorLayerSearchVisible = false
  #expect(appState.actions.inspector.shouldShowLayerInspectorSearch)

  appState.actions.inspector.setInspectorTab(.parameters)
  #expect(appState.actions.inspector.shouldShowParameterInspectorSearch)
  appState.actions.inspector.inspectorParameterSearchQuery = "param 3"
  #expect(appState.actions.inspector.filteredInspectorParameters.map(\.id) == ["parameter:3"])
  appState.actions.inspector.inspectorParameterSearchVisible = false
  #expect(appState.actions.inspector.shouldShowParameterInspectorSearch)

  appState.actions.inspector.setInspectorTab(.layers)
  #expect(appState.actions.inspector.inspectorLayerSearchQuery == "cut")
}

@Test("UC1 AppCoordinator は document 置換時に inspector tab と検索状態をリセットする")
@MainActor
func uc1_app_state_resets_inspector_presentation_on_document_replace() {
  let initialState = makeDocumentState(name: "Initial")
  let reopenedState = makeDocumentState(name: "Reopened")
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.openDocumentState = reopenedState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.inspector.setInspectorTab(.sharedStyles)
  appState.actions.inspector.inspectorSelectedLayerID = "layer:cut-line"
  appState.actions.inspector.inspectorLayerSearchQuery = "cut"
  appState.actions.inspector.inspectorLayerSearchVisible = true

  appState.actions.document.openProject(at: uniqueTempURL("reopened.kawa"))

  #expect(appState.actions.inspector.inspectorTab == .selection)
  #expect(appState.actions.inspector.inspectorSelectedLayerID == nil)
  #expect(appState.actions.inspector.inspectorLayerSearchQuery.isEmpty)
  #expect(!appState.actions.inspector.inspectorLayerSearchVisible)
}

@Test("UC1 AppCoordinator の円弧ツールは中心・開始点・終点の順に作図する")
@MainActor
func uc1_app_state_arc_tool_uses_center_start_end_flow() {
  let createdArc = CanvasEntity(
    id: "entity:arc-fixed-id",
    label: "Arc A",
    kind: .arc,
    layerID: "layer:cut-line",
    geometry: .arc(
      center: .init(xMM: 10.0, yMM: 10.0),
      radiusMM: 5.0,
      startAngleRad: 0.0,
      sweepAngleRad: .pi / 2.0
    )
  )
  let initialState = makeDocumentState(name: "Arc Placement")
  let appliedState = makeDocumentState(
    name: "Arc Placement",
    entities: [createdArc],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = appliedState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "fixed-id" })
  )

  appState.actions.canvas.activateTool(.arc)
  appState.actions.canvas.handleCanvasPlacement(.init(xMM: 10.0, yMM: 10.0))

  #expect(appState.actions.canvas.draftStartPoint == .init(xMM: 10.0, yMM: 10.0))
  #expect(appState.actions.canvas.draftArcStartPoint == nil)
  #expect(appState.actions.document.statusMessage == "円弧の開始点をクリックします。")

  appState.actions.canvas.handleCanvasHover(.init(xMM: 15.0, yMM: 10.0))
  #expect(appState.actions.canvas.draftCurrentPoint == .init(xMM: 15.0, yMM: 10.0))

  appState.actions.canvas.handleCanvasPlacement(.init(xMM: 15.0, yMM: 10.0))
  #expect(appState.actions.canvas.draftArcStartPoint == .init(xMM: 15.0, yMM: 10.0))
  #expect(appState.actions.document.statusMessage == "円弧の終点をクリックします。")

  appState.actions.canvas.handleCanvasHover(.init(xMM: 10.0, yMM: 15.0))
  #expect(appState.actions.canvas.draftCurrentPoint == .init(xMM: 10.0, yMM: 15.0))

  appState.actions.canvas.handleCanvasPlacement(.init(xMM: 10.0, yMM: 15.0))

  #expect(appState.actions.canvas.draftStartPoint == nil)
  #expect(appState.actions.canvas.draftArcStartPoint == nil)
  #expect(appState.actions.canvas.draftCurrentPoint == nil)
  #expect(appState.actions.canvas.draftArcSweepAngleRad == nil)
  #expect(store.appliedPayloads.count == 1)
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["id"] as? String) == "entity:arc-fixed-id")
  let gesture = unwrap(payload["gesture"] as? [String: Any])
  #expect((gesture["start"] as? [String: Double])?["xMm"] == 15.0)
  #expect(abs(((gesture["sweepReferenceRad"] as? Double) ?? 0.0) - (.pi / 2.0)) < 0.0001)
  #expect(appState.actions.canvas.selectedEntityID == "entity:arc-fixed-id")
  #expect(appState.actions.canvas.selectedEntityIDs == ["entity:arc-fixed-id"])
  #expect(appState.actions.document.statusMessage == "円弧を追加しました。開始角と掃引角を続けて編集できます")
}

@Test("UC286 AppCoordinator の円弧ツールは 180 度超の掃引角を保持する")
@MainActor
func uc286_app_state_arc_tool_preserves_sweep_angles_over_180_degrees() {
  let initialState = makeDocumentState(name: "Large Arc")
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = initialState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "large-arc-id" })
  )
  appState.actions.workspace.gridSnapEnabled = false

  appState.actions.canvas.activateTool(.arc)
  appState.actions.canvas.handleCanvasPlacement(.zero)
  appState.actions.canvas.handleCanvasPlacement(.init(xMM: 10.0, yMM: 0.0))
  appState.actions.canvas.handleCanvasHover(.init(xMM: 0.0, yMM: 10.0))
  appState.actions.canvas.handleCanvasHover(.init(xMM: -10.0, yMM: 0.0))
  appState.actions.canvas.handleCanvasHover(
    .init(xMM: -9.396926207859085, yMM: -3.4202014332566866))

  #expect(
    abs((appState.actions.canvas.draftArcSweepAngleRad ?? 0.0) - degreesToRadians(200.0)) < 0.0001)
  appState.actions.canvas.handleCanvasPlacement(
    .init(xMM: -9.396926207859085, yMM: -3.4202014332566866))

  #expect(store.appliedPayloads.count == 1)
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  let gesture = unwrap(payload["gesture"] as? [String: Any])
  #expect(
    abs(((gesture["sweepReferenceRad"] as? Double) ?? 0.0) - degreesToRadians(200.0)) < 0.0001)
}

@Test("UC286 AppCoordinator の円弧ツールは負方向の 180 度超掃引角を保持する")
@MainActor
func uc286_app_state_arc_tool_preserves_negative_sweep_angles_over_180_degrees() {
  let initialState = makeDocumentState(name: "Large Negative Arc")
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = initialState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "large-negative-arc-id" })
  )
  appState.actions.workspace.gridSnapEnabled = false

  appState.actions.canvas.activateTool(.arc)
  appState.actions.canvas.handleCanvasPlacement(.zero)
  appState.actions.canvas.handleCanvasPlacement(.init(xMM: 10.0, yMM: 0.0))
  appState.actions.canvas.handleCanvasHover(.init(xMM: 0.0, yMM: -10.0))
  appState.actions.canvas.handleCanvasHover(.init(xMM: -10.0, yMM: 0.0))
  appState.actions.canvas.handleCanvasHover(.init(xMM: -9.396926207859085, yMM: 3.4202014332566866))
  appState.actions.canvas.handleCanvasPlacement(
    .init(xMM: -9.396926207859085, yMM: 3.4202014332566866))

  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  let gesture = unwrap(payload["gesture"] as? [String: Any])
  #expect(
    abs(((gesture["sweepReferenceRad"] as? Double) ?? 0.0) - degreesToRadians(-200.0)) < 0.0001)
}

@Test("UC1 AppCoordinator の円弧ツールは Shift 押下中に掃引角をスナップする")
@MainActor
func uc1_app_state_arc_tool_snaps_sweep_angle_with_shift() {
  let initialState = makeDocumentState(name: "Arc Snap")
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = initialState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "snap-id" })
  )

  appState.actions.canvas.activateTool(.arc)
  appState.actions.canvas.handleCanvasPlacement(.zero)
  appState.actions.canvas.handleCanvasPlacement(.init(xMM: 10.0, yMM: 0.0))
  appState.actions.canvas.handleCanvasHover(
    .init(xMM: 7.0, yMM: 7.0), modifiers: .init(forceAxis: true))

  let previewPoint = unwrap(appState.actions.canvas.draftCurrentPoint)
  #expect(abs(previewPoint.xMM - 7.0710678118654755) < 0.01)
  #expect(abs(previewPoint.yMM - 7.0710678118654755) < 0.01)

  appState.actions.canvas.handleCanvasPlacement(
    .init(xMM: 7.0, yMM: 7.0), modifiers: .init(forceAxis: true))

  #expect(store.appliedPayloads.count == 1)
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  let gesture = unwrap(payload["gesture"] as? [String: Any])
  #expect(abs(((gesture["sweepReferenceRad"] as? Double) ?? 0.0) - (.pi / 4.0)) < 0.0001)
}

@Test("UC286 AppCoordinator の円弧ツールは Shift 補正後も 180 度超を維持する")
@MainActor
func uc286_app_state_arc_tool_keeps_large_shift_snapped_sweep_angle() {
  let initialState = makeDocumentState(name: "Large Snapped Arc")
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = initialState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "large-snapped-arc-id" })
  )

  appState.actions.canvas.activateTool(.arc)
  appState.actions.canvas.handleCanvasPlacement(.zero)
  appState.actions.canvas.handleCanvasPlacement(.init(xMM: 10.0, yMM: 0.0))
  appState.actions.canvas.handleCanvasHover(
    .init(xMM: 0.0, yMM: 10.0), modifiers: .init(forceAxis: true))
  appState.actions.canvas.handleCanvasHover(
    .init(xMM: -10.0, yMM: 0.0), modifiers: .init(forceAxis: true))
  appState.actions.canvas.handleCanvasHover(
    .init(xMM: -8.660254037844386, yMM: -5.0), modifiers: .init(forceAxis: true))
  appState.actions.canvas.handleCanvasPlacement(
    .init(xMM: -8.660254037844386, yMM: -5.0), modifiers: .init(forceAxis: true))

  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  let gesture = unwrap(payload["gesture"] as? [String: Any])
  #expect(
    abs(((gesture["sweepReferenceRad"] as? Double) ?? 0.0) - degreesToRadians(210.0)) < 0.0001)
}

@Test("UC14a AppCoordinator のキャンセルは入力、プレビュー、ドラフト、拘束選択、選択の順に解除する")
@MainActor
func uc14a_app_state_cancel_current_interaction_uses_consistent_priority() {
  let initialState = makeDocumentState(
    name: "Cancel Priority",
    parameters: [
      ProjectParameter(
        id: "param:width",
        name: "width",
        valueMM: 25.0,
        unit: "millimeter",
        memo: "",
        usageCount: 0,
        usedConstraintIDs: []
      )
    ],
    parts: [
      ProjectPart(
        id: "part:cancel",
        name: "Cancel Part",
        originMM: .zero,
        outlineEntityIDs: ["entity:point-a"],
        holeEntityIDGroups: [],
        entityIDs: ["entity:point-a"],
        derivedElementIDs: [],
        freeTextIDs: [],
        measurementAnnotationIDs: []
      )
    ],
    entities: [
      pointEntity(id: "entity:point-a", label: "Point A", point: .zero)
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedEntityID = "entity:point-a"
  appState.actions.canvas.selectedEntityIDs = ["entity:point-a"]
  appState.actions.inspector.inspectorSelectedPartID = "part:cancel"
  appState.actions.canvas.pendingConstraintTargets = [
    CanvasSelectionTarget(
      entityID: "entity:point-a",
      entityLabel: "Point A",
      entityKind: .point,
      controlPoint: .center,
      point: .zero
    )
  ]
  appState.actions.canvas.draftStartPoint = .init(xMM: 10.0, yMM: 10.0)
  appState.actions.canvas.draftCurrentPoint = .init(xMM: 20.0, yMM: 20.0)
  appState.actions.canvas.previewEntities = [
    pointEntity(id: "entity:point-a", label: "Point A", point: .init(xMM: 5.0, yMM: 5.0))
  ]
  appState.actions.canvas.pendingConstraintValueDraft = PendingConstraintValueDraft(
    kind: "distance",
    title: "距離",
    prompt: "距離を指定してください",
    targets: [],
    valueText: "12",
    unit: "mm",
    allowsParameterReference: true,
    entryMode: .fixedValue,
    selectedParameterID: nil,
    anchorCanvasPoint: nil
  )

  appState.actions.canvas.cancelCurrentInteraction()
  #expect(appState.actions.canvas.pendingConstraintValueDraft == nil)
  #expect(appState.actions.canvas.previewEntities != nil)
  #expect(appState.actions.canvas.draftStartPoint != nil)
  #expect(!appState.actions.canvas.pendingConstraintTargets.isEmpty)
  #expect(appState.actions.canvas.selectedEntityID == "entity:point-a")

  appState.actions.canvas.cancelCurrentInteraction()
  #expect(appState.actions.canvas.previewEntities == nil)
  #expect(appState.actions.canvas.draftStartPoint != nil)

  appState.actions.canvas.cancelCurrentInteraction()
  #expect(appState.actions.canvas.draftStartPoint == nil)
  #expect(appState.actions.canvas.draftCurrentPoint == nil)
  #expect(!appState.actions.canvas.pendingConstraintTargets.isEmpty)

  appState.actions.canvas.cancelCurrentInteraction()
  #expect(appState.actions.canvas.pendingConstraintTargets.isEmpty)
  #expect(appState.actions.canvas.selectedEntityID == "entity:point-a")

  appState.actions.canvas.cancelCurrentInteraction()
  #expect(appState.actions.canvas.selectedEntityID == nil)
  #expect(appState.actions.canvas.selectedEntityIDs.isEmpty)
  #expect(appState.actions.inspector.inspectorSelectedPartID == "part:cancel")

  appState.actions.canvas.cancelCurrentInteraction()
  #expect(appState.actions.inspector.inspectorSelectedPartID == nil)
}

@Test("UC14a AppCoordinator の拘束ツールで空白クリックすると対象選択を解除する")
@MainActor
func uc14a_app_state_constraint_background_click_clears_pending_targets() {
  let initialState = makeDocumentState(
    name: "Constraint Reset",
    entities: [
      pointEntity(id: "entity:point-a", label: "Point A", point: .zero)
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedTool = .distance
  appState.actions.canvas.selectedEntityID = "entity:point-a"
  appState.actions.canvas.selectedEntityIDs = ["entity:point-a"]
  appState.actions.canvas.pendingConstraintTargets = [
    CanvasSelectionTarget(
      entityID: "entity:point-a",
      entityLabel: "Point A",
      entityKind: .point,
      controlPoint: .center,
      point: .zero
    )
  ]

  appState.actions.constraints.handleConstraintTargetSelection(nil)

  #expect(appState.actions.canvas.pendingConstraintTargets.isEmpty)
  #expect(appState.actions.canvas.selectedEntityID == nil)
  #expect(appState.actions.canvas.selectedEntityIDs.isEmpty)
  #expect(appState.actions.document.statusMessage == "距離拘束: 点/制御点、または線分/中心線を選択してください")
}

@Test("UC14 AppCoordinator は選択中の拘束マークを Delete 操作で削除する")
@MainActor
func uc14_app_state_deletes_selected_constraint_marker() {
  let constraint = ProjectConstraint(
    id: "constraint:horizontal",
    rawKind: "horizontal",
    kind: "horizontal",
    targets: [],
    targetsJSON: #"[{"entity":"entity:line-a"}]"#,
    valueMM: nil,
    valueDegrees: nil,
    valueParameterID: nil,
    status: .underConstrained
  )
  let initialState = makeDocumentState(
    name: "Delete Constraint Marker",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 20, yMM: 0))
    ],
    constraints: [constraint],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = makeDocumentState(
    name: "Delete Constraint Marker",
    entities: initialState.entities,
    constraints: [],
    constraintStatus: .underConstrained
  )
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectConstraint("constraint:horizontal")

  appState.actions.canvas.deleteSelectedEntity()

  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "deleteConstraint")
  #expect((store.appliedPayloads[0]["payload"] as? String) == "constraint:horizontal")
  #expect(appState.actions.canvas.selectedConstraintID == nil)
}

@Test("UC14 AppCoordinator は複数選択エンティティを compound delete で削除する")
@MainActor
func uc14_app_state_deletes_multiple_selected_entities_as_compound_command() {
  let first = lineEntity(id: "entity:first", start: .zero, end: ModelPoint(xMM: 10, yMM: 0))
  let second = lineEntity(
    id: "entity:second", start: ModelPoint(xMM: 10, yMM: 0), end: ModelPoint(xMM: 10, yMM: 10))
  let initialState = makeDocumentState(
    name: "Delete Multiple",
    entities: [first, second],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = makeDocumentState(name: "Delete Multiple")
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedEntityIDs = ["entity:first", "entity:second"]
  appState.actions.canvas.selectedEntityID = "entity:first"

  appState.actions.canvas.deleteSelectedEntity()

  #expect(store.appliedPayloads.count == 1)
  let command = store.appliedPayloads[0]
  #expect((command["kind"] as? String) == "compound")
  let payloads = unwrap(command["payload"] as? [[String: Any]])
  #expect(payloads.count == 2)
  #expect(
    Set(payloads.compactMap { $0["payload"] as? String }) == ["entity:first", "entity:second"])
  #expect(appState.actions.canvas.selectedEntityID == nil)
  #expect(appState.actions.canvas.selectedEntityIDs.isEmpty)
}

@Test("UC13 AppCoordinator は線分作図時にスナップ結果を意味コマンドで送る")
@MainActor
func uc13_app_state_line_placement_sends_auto_constraints_as_compound_command() {
  let initialState = makeDocumentState(
    name: "Line Assist",
    entities: [
      pointEntity(id: "entity:point-a", point: .zero)
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "fixed-id" })
  )

  appState.actions.canvas.activateTool(.line)
  appState.actions.canvas.handleCanvasPlacement(.init(xMM: 0.8, yMM: 0.7))
  appState.actions.canvas.handleCanvasPlacement(.init(xMM: 21.0, yMM: 0.2))

  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "createEntityFromGesture")
  let entityPayload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  let entityID = unwrap(entityPayload["id"] as? String)
  let gesture = unwrap(entityPayload["gesture"] as? [String: Any])
  let start = unwrap(gesture["start"] as? [String: Double])
  let end = unwrap(gesture["end"] as? [String: Double])
  #expect(start["xMm"] == 0.0)
  #expect(start["yMm"] == 0.0)
  #expect(end["xMm"] == 20.0)
  #expect(end["yMm"] == 0.0)

  let startSnap = unwrap(entityPayload["startSnap"] as? [String: Any])
  #expect((startSnap["target"] as? [String: Any])?["entity"] as? String == "entity:point-a")
  #expect((gesture["axis"] as? String) == "horizontal")
  #expect(entityPayload["axisConstraintId"] as? String != nil)
  #expect(entityID == "entity:line-fixed-id")
}

@Test("UC13 AppCoordinator はShift押下中に線分を水平または垂直へ強制補正する")
@MainActor
func uc13_app_state_shift_forces_line_axis_constraint() {
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(name: "Shift Line Assist"))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "fixed-id" })
  )

  appState.actions.canvas.activateTool(.line)
  appState.actions.workspace.gridSnapEnabled = false
  appState.actions.canvas.handleCanvasPlacement(.init(xMM: 12.3, yMM: 8.7))
  appState.actions.workspace.gridSnapEnabled = true
  appState.actions.canvas.handleCanvasPlacement(
    .init(xMM: 12.8, yMM: 51.2),
    modifiers: CanvasPlacementModifiers(forceAxis: true)
  )

  let entityPayload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  let gesture = unwrap(entityPayload["gesture"] as? [String: Any])
  let start = unwrap(gesture["start"] as? [String: Double])
  let end = unwrap(gesture["end"] as? [String: Double])
  #expect(start["xMm"] == 12.3)
  #expect(start["yMm"] == 8.7)
  #expect(end["xMm"] == 12.3)
  #expect(end["yMm"] == 50.0)
  #expect((gesture["axis"] as? String) == "vertical")
  #expect(entityPayload["axisConstraintId"] as? String != nil)
}

@Test("UC14 AppCoordinator はControl押下中の線分配置でスナップを一時無効化する")
@MainActor
func uc14_app_state_control_temporarily_suppresses_line_snap() {
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(
      name: "Temporary Snap Suppression",
      entities: [
        pointEntity(id: "entity:point-a", point: .zero)
      ]
    ))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "fixed-id" })
  )

  appState.actions.canvas.activateTool(.line)
  appState.actions.workspace.gridSnapEnabled = true
  appState.actions.workspace.pointSnapEnabled = true
  appState.actions.canvas.handleCanvasPlacement(
    .init(xMM: 0.4, yMM: 0.3),
    modifiers: CanvasPlacementModifiers(suppressesSnap: true)
  )
  appState.actions.canvas.handleCanvasPlacement(
    .init(xMM: 12.8, yMM: 9.2),
    modifiers: CanvasPlacementModifiers(suppressesSnap: true)
  )

  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  let gesture = unwrap(payload["gesture"] as? [String: Any])
  let start = unwrap(gesture["start"] as? [String: Double])
  let end = unwrap(gesture["end"] as? [String: Double])
  #expect(start["xMm"] == 0.4)
  #expect(start["yMm"] == 0.3)
  #expect(end["xMm"] == 12.8)
  #expect(end["yMm"] == 9.2)
}

@Test("UC14 AppCoordinator は位置指定ペーストでコピー対象の代表点を指定位置へ合わせる", .disabled("依存解決と座標変換は Core 結合テストへ移管"))
@MainActor
func uc14_app_state_pastes_copied_entities_at_requested_position() {
  let initialState = makeDocumentState(
    name: "Paste At Cursor",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 20, yMM: 0))
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "fixed-id" })
  )
  appState.actions.canvas.selectEntity("entity:line-a")
  appState.actions.document.copySelection()
  appState.actions.canvas.selectedConstraintID = "constraint:previous-selection"

  appState.actions.document.pasteCopiedEntity(at: ModelPoint(xMM: 100, yMM: 50))

  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "compound")
  let commands = unwrap(store.appliedPayloads[0]["payload"] as? [[String: Any]])
  #expect(commands.count == 1)
  let payload = unwrap(commands[0]["payload"] as? [String: Any])
  let kind = unwrap(payload["kind"] as? [String: Any])
  let line = unwrap(kind["lineSegment"] as? [String: Any])
  let start = unwrap(line["start"] as? [String: Double])
  let end = unwrap(line["end"] as? [String: Double])
  #expect(start["xMm"] == 90)
  #expect(start["yMm"] == 50)
  #expect(end["xMm"] == 110)
  #expect(end["yMm"] == 50)
  #expect(appState.actions.canvas.selectedEntityIDs == ["entity:paste-fixed-id"])
  #expect(appState.actions.canvas.selectedEntityID == "entity:paste-fixed-id")
  #expect(appState.actions.canvas.selectedConstraintID == nil)
}

@Test("#369 AppCoordinator は外接矩形中心をカーソルへ配置し、方式変更で同じIDを貼り直す")
@MainActor
func issue369_app_state_replaces_paste_placement_without_new_ids() {
  let initialState = makeDocumentState(
    name: "Paste placement",
    entities: [lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 20, yMM: 0))]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.selectionExportResult = .success(
    SelectionClipboardExport(
      clipboardJson: "{\"selection\":true}",
      rootCount: 1,
      anchorPoint: CorePoint(xMm: 10, yMm: 0),
      bounds: CoreBounds(
        minPoint: CorePoint(xMm: 0, yMm: 0),
        maxPoint: CorePoint(xMm: 20, yMm: 0)
      )
    ))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectEntity("entity:line-a")
  appState.actions.document.copySelection()

  appState.actions.document.pasteCopiedEntity(at: ModelPoint(xMM: 100, yMM: 50))
  appState.actions.document.selectPastePlacement(.nearSource)

  #expect(store.appliedPayloads.count == 2)
  let firstPayload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  let secondPayload = unwrap(store.appliedPayloads[1]["payload"] as? [String: Any])
  #expect(firstPayload["idNamespace"] as? String == secondPayload["idNamespace"] as? String)
  let firstDelta = unwrap(firstPayload["delta"] as? [String: Double])
  let secondDelta = unwrap(secondPayload["delta"] as? [String: Double])
  #expect(firstDelta["xMm"] == 90)
  #expect(firstDelta["yMm"] == 50)
  #expect(secondDelta["xMm"] == 5)
  #expect(secondDelta["yMm"] == 5)
  #expect(store.undoCalls.count == 1)
}

@Test("UC14 AppCoordinator は通常ペーストを元bundleからの連続オフセットで維持する", .disabled("貼り付け内容は Core 結合テストへ移管"))
@MainActor
func uc14_app_state_keeps_clipboard_bundle_immutable_across_repeated_paste() {
  let initialState = makeDocumentState(
    name: "Repeated Paste",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 20, yMM: 0))
    ],
    freeTexts: [
      ProjectFreeText(
        id: "free-text:note",
        content: "note",
        positionMM: ModelPoint(xMM: 10, yMM: 5),
        fontSizeMM: 4
      )
    ]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "fixed-id" })
  )
  appState.actions.canvas.selectEntity("entity:line-a")
  appState.actions.document.copySelection()
  let originalClipboard = appState.actions.document.clipboardBundle

  appState.actions.document.pasteCopiedEntity()
  appState.actions.document.pasteCopiedEntity()

  #expect(appState.actions.document.clipboardBundle == originalClipboard)
  #expect(appState.documentPresentation.clipboardPasteSequence == 2)
  #expect(store.appliedPayloads.count == 2)

  let firstCommands = unwrap(store.appliedPayloads[0]["payload"] as? [[String: Any]])
  let firstLinePayload = unwrap(firstCommands.first?["payload"] as? [String: Any])
  let firstLine = unwrap(
    (firstLinePayload["kind"] as? [String: Any])?["lineSegment"] as? [String: Any])
  let firstStart = unwrap(firstLine["start"] as? [String: Double])
  let firstEnd = unwrap(firstLine["end"] as? [String: Double])
  #expect(firstStart["xMm"] == 5)
  #expect(firstStart["yMm"] == 5)
  #expect(firstEnd["xMm"] == 25)
  #expect(firstEnd["yMm"] == 5)

  let secondCommands = unwrap(store.appliedPayloads[1]["payload"] as? [[String: Any]])
  let secondLinePayload = unwrap(secondCommands.first?["payload"] as? [String: Any])
  let secondLine = unwrap(
    (secondLinePayload["kind"] as? [String: Any])?["lineSegment"] as? [String: Any])
  let secondStart = unwrap(secondLine["start"] as? [String: Double])
  let secondEnd = unwrap(secondLine["end"] as? [String: Double])
  #expect(secondStart["xMm"] == 10)
  #expect(secondStart["yMm"] == 10)
  #expect(secondEnd["xMm"] == 30)
  #expect(secondEnd["yMm"] == 10)
}

@Test("UC14 AppCoordinator は丸穴メタデータを compound paste に含める", .disabled("依存閉包は Core 結合テストへ移管"))
@MainActor
func uc14_app_state_paste_preserves_round_hole_metadata() {
  let holeEntity = CanvasEntity(
    id: "entity:hole",
    label: "Hole",
    kind: .circle,
    layerID: "layer:cut-line",
    styleID: nil,
    geometry: .circle(center: ModelPoint(xMM: 8, yMM: 8), radiusMM: 2)
  )
  let roundHole = ProjectRoundHole(
    id: "round-hole:hole", entityID: holeEntity.id, kind: .snapFastener)
  let initialState = makeDocumentState(
    name: "Round Hole Paste",
    entities: [holeEntity],
    roundHoles: [roundHole]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "fixed-id" })
  )
  appState.actions.canvas.selectEntity(holeEntity.id)
  appState.actions.document.copySelection()

  appState.actions.document.pasteCopiedEntity()

  let commands = unwrap(store.appliedPayloads.first?["payload"] as? [[String: Any]])
  #expect(commands.count == 2)
  let addRoundHole = unwrap(
    commands.first(where: { ($0["kind"] as? String) == "addRoundHole" }),
    context: "missing addRoundHole command"
  )
  let payload = unwrap(addRoundHole["payload"] as? [String: Any])
  #expect((payload["id"] as? String) == "round-hole:fixed-id")
  #expect((payload["entityId"] as? String) == "entity:paste-fixed-id")
  #expect((payload["kind"] as? String) == "snapFastener")
}

@Test("UC14 AppCoordinator の位置指定ペーストは単独 Arc の代表点を維持する", .disabled("代表点計算は Core 結合テストへ移管"))
@MainActor
func uc14_app_state_paste_at_position_uses_arc_representative_point() {
  let arc = arcEntity(
    id: "entity:arc-a",
    center: ModelPoint(xMM: 50, yMM: 50),
    radiusMM: 20,
    startAngleRad: 0,
    sweepAngleRad: .pi / 2
  )
  let initialState = makeDocumentState(
    name: "Arc Paste Anchor",
    entities: [arc]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "fixed-id" })
  )
  appState.actions.canvas.selectEntity(arc.id)
  appState.actions.document.copySelection()

  appState.actions.document.pasteCopiedEntity(at: ModelPoint(xMM: 100, yMM: 100))

  let commands = unwrap(store.appliedPayloads.first?["payload"] as? [[String: Any]])
  let payload = unwrap(commands.first?["payload"] as? [String: Any])
  let kind = unwrap(payload["kind"] as? [String: Any])
  let pastedArc = unwrap(kind["arc"] as? [String: Any])
  let center = unwrap(pastedArc["center"] as? [String: Double])
  #expect(center["xMm"] == 100)
  #expect(center["yMm"] == 100)
}

@Test("UC14 AppCoordinator の複製は clipboard sequence を進めず bundle を置き換えない")
@MainActor
func uc14_app_state_duplicate_keeps_clipboard_sequence_stable() {
  let initialState = makeDocumentState(
    name: "Duplicate Stable",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 20, yMM: 0))
    ]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "fixed-id" })
  )
  appState.actions.canvas.selectEntity("entity:line-a")
  appState.actions.document.copySelection()
  let originalClipboard = appState.actions.document.clipboardBundle

  appState.actions.document.pasteCopiedEntity()
  appState.actions.canvas.selectEntity("entity:line-a")
  appState.actions.document.duplicateSelection()

  #expect(appState.actions.document.clipboardBundle == originalClipboard)
  #expect(appState.documentPresentation.clipboardPasteSequence == 1)
  #expect(store.appliedPayloads.count == 2)
}

@Test("UC14 AppCoordinator は選択外参照の拘束と計測表示をコピー対象から除外する", .disabled("依存閉包は Core 結合テストへ移管"))
@MainActor
func uc14_app_state_copy_omits_external_relations() {
  let lineA = lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 20, yMM: 0))
  let lineB = lineEntity(
    id: "entity:line-b", start: ModelPoint(xMM: 30, yMM: 0), end: ModelPoint(xMM: 50, yMM: 0))
  let constraint = ProjectConstraint(
    id: "constraint:length-a",
    rawKind: "distance",
    kind: "距離",
    targets: ["entity:line-a", "entity:line-b"],
    targetsJSON: #"[{"entity":"entity:line-a"},{"entity":"entity:line-b"}]"#,
    valueMM: 30,
    valueDegrees: nil,
    valueParameterID: nil,
    status: .fullyConstrained
  )
  let annotation = ProjectMeasurementAnnotation(
    id: "measurement:distance-a",
    rawKind: "distance",
    kind: "距離",
    targets: ["entity:line-a", "entity:line-b"],
    targetsJSON: #"[{"entity":"entity:line-a"},{"entity":"entity:line-b"}]"#,
    labelOffsetMM: .zero,
    overallOffsetMM: .zero,
    visible: true
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(
      name: "Omit Relations",
      entities: [lineA, lineB],
      constraints: [constraint],
      measurementAnnotations: [annotation]
    ))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectEntity("entity:line-a")

  appState.actions.document.copySelection()

  #expect(appState.actions.document.clipboardBundle?.clipboardJSON.isEmpty == false)
  #expect(appState.actions.document.alertMessage == nil)
}

@Test(
  "UC14 AppCoordinator は source 未選択の拘束単体コピーを失敗させ既存 clipboard を維持する",
  .disabled("参照検証は Core 結合テストへ移管"))
@MainActor
func uc14_app_state_rejects_constraint_only_copy_without_sources() {
  let line = lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 20, yMM: 0))
  let constraint = ProjectConstraint(
    id: "constraint:length-a",
    rawKind: "distance",
    kind: "距離",
    targets: ["entity:line-a"],
    targetsJSON: #"[{"entity":"entity:line-a"}]"#,
    valueMM: 20,
    valueDegrees: nil,
    valueParameterID: nil,
    status: .fullyConstrained
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(
      name: "Constraint Copy Failure",
      entities: [line],
      constraints: [constraint]
    ))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectEntity("entity:line-a")
  appState.actions.document.copySelection()
  let previousClipboard = appState.actions.document.clipboardBundle

  appState.actions.canvas.selectConstraint("constraint:length-a")
  appState.actions.document.copySelection()

  #expect(appState.actions.document.alertMessage != nil)
  #expect(appState.actions.document.clipboardBundle == previousClipboard)
}

@Test("UC14 AppCoordinator は閉じた拘束と寸法注釈を paste bundle に含める", .disabled("依存閉包は Core 結合テストへ移管"))
@MainActor
func uc14_app_state_paste_includes_closed_constraints_and_dimension_annotations() {
  let line = lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 20, yMM: 0))
  let constraint = ProjectConstraint(
    id: "constraint:length-a",
    rawKind: "segmentLength",
    kind: "線分長",
    targets: ["entity:line-a"],
    targetsJSON: #"[{"entity":"entity:line-a"}]"#,
    valueMM: 20,
    valueDegrees: nil,
    valueParameterID: nil,
    status: .fullyConstrained
  )
  let dimensionAnnotation = ProjectDimensionConstraintAnnotation(
    constraintID: "constraint:length-a",
    labelOffsetMM: ModelPoint(xMM: 3, yMM: 4),
    overallOffsetMM: .zero,
    visible: true
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(
      name: "Constraint Copy",
      entities: [line],
      constraints: [constraint],
      dimensionConstraintAnnotations: [dimensionAnnotation]
    ))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "fixed-id" })
  )
  appState.actions.canvas.selectEntity("entity:line-a")
  appState.actions.document.copySelection()

  appState.actions.document.pasteCopiedEntity()

  let commands = unwrap(store.appliedPayloads.first?["payload"] as? [[String: Any]])
  #expect(commands.contains { ($0["kind"] as? String) == "addConstraint" })
  #expect(commands.contains { ($0["kind"] as? String) == "addDimensionConstraintAnnotation" })
}

@Test("UC14 AppCoordinator は paste 前に外部 parameter 参照の消失を検出する", .disabled("参照検証は Core 結合テストへ移管"))
@MainActor
func uc14_app_state_rejects_paste_when_parameter_reference_is_missing() {
  let parameter = ProjectParameter(
    id: "parameter:offset",
    name: "offset",
    valueMM: 5,
    unit: "millimeter",
    memo: "",
    usageCount: 1,
    usedConstraintIDs: []
  )
  let line = lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 20, yMM: 0))
  let derived = ProjectDerivedElement(
    id: "derived:offset-a",
    layerID: "layer:cut-line",
    styleID: nil,
    kind: .offsetCurve,
    sourceEntityIDs: ["entity:line-a"],
    distanceMM: nil,
    distanceParameterID: "parameter:offset",
    direction: .left
  )
  let initialState = makeDocumentState(
    name: "Missing Parameter",
    parameters: [parameter],
    entities: [line],
    derivedElements: [derived]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectEntity("entity:line-a")
  appState.actions.document.copySelection()
  store.recordAppliedState(
    makeDocumentState(name: "Missing Parameter", entities: [line], derivedElements: [derived]))

  appState.actions.document.pasteCopiedEntity()

  #expect(store.appliedPayloads.isEmpty)
  #expect(
    appState.actions.document.alertMessage?.message
      == AppStrings.tr("status.clipboard_missing_parameter", "parameter:offset"))
}

@Test("UC14 AppCoordinator は派生要素どうしの依存連鎖を含む選択をコピーできる", .disabled("依存閉包は Core 結合テストへ移管"))
@MainActor
func uc14_app_state_copies_chained_derived_dependencies() {
  let first = lineEntity(id: "entity:first", start: .zero, end: ModelPoint(xMM: 20, yMM: 0))
  let second = lineEntity(
    id: "entity:second", start: ModelPoint(xMM: 20, yMM: 0), end: ModelPoint(xMM: 20, yMM: 20))
  let filletResolved = arcEntity(
    id: "derived:fillet-a:resolved:0",
    center: ModelPoint(xMM: 18, yMM: 2),
    radiusMM: 2,
    startAngleRad: 0,
    sweepAngleRad: .pi / 2
  )
  let offsetResolved = arcEntity(
    id: "derived:offset-a:resolved:0",
    center: ModelPoint(xMM: 15, yMM: 5),
    radiusMM: 2,
    startAngleRad: 0,
    sweepAngleRad: .pi / 2
  )
  let fillet = ProjectDerivedElement(
    id: "derived:fillet-a",
    layerID: "layer:cut-line",
    styleID: nil,
    kind: .fillet,
    sourceEntityIDs: [first.id, second.id],
    distanceMM: nil,
    distanceParameterID: nil,
    direction: .left,
    radiusMM: 2.0
  )
  let offset = ProjectDerivedElement(
    id: "derived:offset-a",
    layerID: "layer:cut-line",
    styleID: nil,
    kind: .offsetCurve,
    sourceEntityIDs: [fillet.id],
    distanceMM: 3.0,
    distanceParameterID: nil,
    direction: .left
  )
  let initialState = makeDocumentState(
    name: "Chained Derived Copy",
    entities: [first, second, filletResolved, offsetResolved],
    derivedElements: [fillet, offset]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedEntityIDs = [
    first.id, second.id, filletResolved.id, offsetResolved.id,
  ]

  appState.actions.document.copySelection()

  #expect(appState.actions.document.alertMessage == nil)
  #expect(appState.actions.document.clipboardBundle?.clipboardJSON.isEmpty == false)
}

@Test("UC1/UC5 AppCoordinator の保存・開く・再読込は store を経由して状態を反映する")
@MainActor
func uc1_uc5_app_state_open_save_reload_routes_through_the_store() {
  let initialState = makeDocumentState(
    name: "Initial",
    entities: [
      pointEntity(id: "entity:point-a", point: .zero)
    ],
    constraintStatus: .underConstrained
  )
  let reopenedState = makeDocumentState(
    name: "Reopened",
    entities: [
      lineEntity(id: "entity:line-b", start: .zero, end: .init(xMM: 25.0, yMM: 0.0))
    ],
    constraintStatus: .fullyConstrained
  )
  let reloadedState = makeDocumentState(
    name: "Reloaded",
    entities: [
      pointEntity(id: "entity:point-c", point: .init(xMM: 5.0, yMM: 6.0))
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.openDocumentState = reopenedState
  store.loadStateValue = reloadedState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  let saveURL = uniqueTempURL("saved-project.kawa")
  store.documentURL = saveURL
  appState.actions.document.saveProject()
  #expect(store.saveDocumentCalls == [saveURL])
  #expect(appState.actions.document.documentURL == saveURL)
  #expect(appState.actions.document.statusMessage == "「\(saveURL.lastPathComponent)」に保存しました。")

  let openURL = uniqueTempURL("opened-project.kawa")
  appState.actions.canvas.selectedEntityID = "entity:point-a"
  appState.actions.canvas.selectedEntityIDs = ["entity:point-a"]
  appState.actions.canvas.pendingConstraintTargets = [
    CanvasSelectionTarget(
      entityID: "entity:point-a",
      entityLabel: "Point A",
      entityKind: .point,
      controlPoint: nil,
      point: .zero
    )
  ]
  appState.actions.canvas.draftStartPoint = .init(xMM: 9.0, yMM: 9.0)
  appState.actions.canvas.draftCurrentPoint = .init(xMM: 10.0, yMM: 10.0)
  appState.actions.document.openProject(at: openURL)
  #expect(store.openDocumentCalls.map(\.url) == [openURL])
  #expect(appState.actions.document.documentURL == openURL)
  #expect(appState.actions.canvas.selectedTool == .select)
  #expect(appState.actions.canvas.selectedEntityID == nil)
  #expect(appState.actions.canvas.selectedEntityIDs.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintTargets.isEmpty)
  #expect(appState.actions.canvas.draftStartPoint == nil)
  #expect(appState.actions.canvas.draftCurrentPoint == nil)
  #expect(appState.actions.document.documentName == "Reopened")
  #expect(appState.actions.document.entities.map(\.id) == ["entity:line-b"])
  #expect(appState.actions.document.statusMessage == "「\(openURL.lastPathComponent)」を開きました。")

  appState.actions.canvas.selectedEntityID = "entity:missing"
  appState.actions.canvas.selectedEntityIDs = ["entity:missing"]
  appState.actions.canvas.selectedConstraintID = "constraint:missing"
  appState.actions.canvas.selectedMeasurementAnnotationID = "measurement:missing"
  appState.actions.canvas.pendingConstraintTargets = [
    pointEntity(id: "entity:pending", point: .zero).entitySelectionTarget
  ]
  appState.actions.canvas.draftStartPoint = .zero
  appState.actions.canvas.draftCurrentPoint = ModelPoint(xMM: 1.0, yMM: 1.0)
  appState.actions.canvas.previewEntities = [
    pointEntity(id: "entity:preview", point: .zero)
  ]
  appState.actions.canvas.setViewMode(.outputPreview)
  #expect(store.loadStateCalls == [.outputPreview])
  #expect(appState.actions.canvas.viewMode == .outputPreview)
  #expect(appState.actions.document.statusMessage == AppStrings.tr("status.output_preview_mode"))
  #expect(appState.actions.document.documentName == "Reloaded")
  #expect(appState.actions.document.entities.map(\.id) == ["entity:point-c"])
  #expect(appState.actions.canvas.selectedEntityID == nil)
  #expect(appState.actions.canvas.selectedEntityIDs.isEmpty)
  #expect(appState.actions.canvas.selectedConstraintID == nil)
  #expect(appState.actions.canvas.selectedMeasurementAnnotationID == nil)
  #expect(appState.actions.canvas.pendingConstraintTargets.isEmpty)
  #expect(appState.actions.canvas.draftStartPoint == nil)
  #expect(appState.actions.canvas.draftCurrentPoint == nil)
  #expect(appState.actions.canvas.previewEntities == nil)
  #expect(appState.actions.canvas.selectedTool == .select)
  #expect(store.loadStateCalls == [.outputPreview])
  #expect(store.undoCalls.isEmpty)
  #expect(store.redoCalls.isEmpty)
  #expect(!appState.actions.canvas.canDeleteSelection)
  #expect(!appState.actions.canvas.canCopySelection)
  #expect(!appState.actions.canvas.canSelectAllEntities)

  appState.actions.canvas.setViewMode(.outputPreview)
  #expect(store.loadStateCalls == [.outputPreview])

  store.hasDocument = false
  store.recordAppliedState(
    makeDocumentState(
      layers: defaultLayers(),
      parameters: [
        ProjectParameter(
          id: "parameter:temp",
          name: "temp",
          valueMM: 1.0,
          unit: "millimeter",
          memo: "",
          usageCount: 0,
          usedConstraintIDs: []
        )
      ],
      entities: [
        pointEntity(id: "entity:temp", point: .zero)
      ]
    ))
  appState.actions.document.reloadFromDocument()
  #expect(appState.actions.document.layers.isEmpty)
  #expect(appState.actions.document.parameters.isEmpty)
  #expect(appState.actions.document.entities.isEmpty)
  #expect(store.loadStateCalls == [.outputPreview])
}

@Test("表示モードは編集表示と出力プレビューとして表示する")
@MainActor
func canvas_view_mode_display_names_use_edit_and_output_preview_terms() {
  #expect(CanvasViewMode.editDisplay.displayName == "編集表示")
  #expect(CanvasViewMode.outputPreview.displayName == "出力プレビュー")
  #expect(AppStrings.tr("menu.edit_display_mode") == "編集表示モード")
  #expect(AppStrings.tr("menu.output_preview_mode") == "出力プレビューモード")
}

@Test("出力プレビュー切替時に Core の出力分割結果と警告を保持する")
@MainActor
func output_preview_mode_keeps_core_output_pages_and_warning_summary() {
  let initialState = makeDocumentState(
    name: "Preview",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: .init(xMM: 220.0, yMM: 0.0))
    ]
  )
  let previewModel = OutputDocumentModel(
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
        printableAreaMm: OutputPaperDefaults.pdfPrintableAreaMm(for: .portrait),
        graphics: [],
        texts: [],
        guide: nil
      ),
      OutputPage(
        widthMm: 210.0,
        heightMm: 297.0,
        gridColumn: 1,
        gridRow: 0,
        rotationDeg: 0,
        printableAreaMm: OutputPaperDefaults.pdfPrintableAreaMm(for: .portrait),
        graphics: [],
        texts: [],
        guide: nil
      ),
    ]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.outputBuildResult = sampleOutputBuildResult(
    model: previewModel,
    warnings: [.init(kind: .pageBoundaryCrossing, message: "A4ページ境界をまたぐ図形があります。")]
  )
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  appState.actions.workspace.setA4ReferenceOrientation(.landscape)
  appState.actions.canvas.setViewMode(.outputPreview)

  #expect(store.loadStateCalls == [.outputPreview])
  #expect(store.outputBuildOptions.count == 1)
  #expect(store.outputBuildOptions.first?.orientation == .landscape)
  #expect(
    appState.actions.output.outputPreviewBuildResult?.outputDocumentModel.pages.map(\.gridColumn)
      == [0, 1])
  #expect(appState.actions.output.outputPreviewSummaryText == "出力警告: A4ページ境界をまたぐ図形があります。")
  #expect(!appState.actions.canvas.canDeleteSelection)

  appState.actions.canvas.setViewMode(.editDisplay)

  #expect(appState.actions.output.outputPreviewBuildResult == nil)
  #expect(appState.actions.output.outputPreviewSummaryText == nil)
}

@Test("選択ドラッグのプレビュー失敗時は修正可能エラーとして banner を表示する")
@MainActor
func app_state_presents_user_correctable_error_when_select_drag_preview_fails() {
  let initialState = makeDocumentState(
    name: "Drag Failure",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: .init(xMM: 10.0, yMM: 0.0))
    ]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.previewCommandFailure = "ドラッグプレビューを解けません"
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  appState.actions.document.previewMoveEntities(
    ["entity:line-a"], delta: .init(xMM: 3.0, yMM: 0.0), duplicating: false)

  #expect(appState.actions.document.statusMessage == "ドラッグプレビューを解けません")
  #expect(appState.actions.workspace.errorPresentation?.identity.category == .userCorrectable)
  #expect(appState.actions.workspace.errorPresentation?.message == "ドラッグプレビューを解けません")
}

@Test("派生要素への拘束警告時は修正可能エラーとして保持する")
@MainActor
func app_state_presents_user_correctable_error_when_derived_constraint_warning_is_presented() {
  let derivedLine = lineEntity(
    id: "derived:fillet-a:resolved:line-a",
    start: .zero,
    end: .init(xMM: 10.0, yMM: 0.0)
  ).withCoreMetadata(
    derivedElementID: "derived:fillet-a",
    derivedResolvedIndex: 0,
    sourceEntityID: "entity:line-a",
    isSuppressedByFillet: false
  )
  let initialState = makeDocumentState(
    name: "Derived Constraint Warning",
    entities: [derivedLine]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )
  appState.actions.canvas.selectedTool = .horizontal

  appState.actions.constraints.handleConstraintTargetSelection(derivedLine.entitySelectionTarget)

  #expect(appState.actions.document.statusMessage == "派生要素には拘束を追加できません。")
  #expect(appState.actions.document.alertMessage == nil)
  #expect(appState.actions.workspace.errorPresentation?.identity.category == .userCorrectable)
  #expect(appState.actions.workspace.errorPresentation?.message == "派生要素には拘束を追加できません。")
}

@Test("Output AppCoordinator は output model を構築して PDF を保存する")
@MainActor
func output_app_state_exports_pdf_via_output_model_and_renderer() throws {
  let initialState = makeDocumentState(
    name: "Export",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: .init(xMM: 20.0, yMM: 0.0))
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.outputBuildResult = sampleOutputBuildResult()
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )
  let outputURL = uniqueTempURL("output-export.pdf")
  let options = OutputBuildOptions(
    orientation: .landscape,
    includeDimensionLabels: false,
    includeScaleGuide: true,
    rotationDeg: 90,
    printableAreaMm: OutputPrintableAreaMm(
      leftMm: -95.0,
      rightMm: 95.0,
      topMm: 138.0,
      bottomMm: -138.0
    )
  )

  appState.actions.output.exportPDF(to: outputURL, options: options)

  #expect(store.outputBuildOptions == [options])
  #expect(store.renderedOutputModels.count == 1)
  #expect(store.renderedOutputModels[0].paperSize == .a4)
  let writtenData = try Data(contentsOf: outputURL)
  #expect(String(data: writtenData, encoding: .utf8) == "%PDF-1.4\n")
  #expect(appState.actions.document.statusMessage == "\(outputURL.lastPathComponent) に PDF を出力しました")
  #expect(appState.actions.document.alertMessage == nil)
}

@Test("Output AppCoordinator は PDF 出力設定シートを既定値で開く")
@MainActor
func output_app_state_opens_pdf_request_sheet_with_defaults() {
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(name: "Export", entities: []))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  appState.actions.workspace.setA4ReferenceOrientation(.landscape)
  appState.actions.output.exportPDFPanel()

  let draft = unwrap(appState.actions.output.outputRequestDraft)
  #expect(draft.destination == .pdf)
  #expect(draft.options.orientation == .landscape)
  #expect(draft.options.includeDimensionLabels)
  #expect(draft.options.includeScaleGuide)
  #expect(draft.options.rotationDeg == 0)
}

@Test("Output AppCoordinator は同じ出力設定シートで PDF と直接印刷を切り替える")
@MainActor
func output_app_state_switches_output_request_destination() {
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(name: "Export", entities: []))
  let printController = StubPrintController()
  printController.printerNames = ["Test Printer"]
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) },
    outputService: OutputService(printController: printController)
  )

  appState.actions.output.exportPDFPanel()
  appState.actions.output.setOutputRequestDestination(.directPrint)

  var draft = unwrap(appState.actions.output.outputRequestDraft)
  #expect(draft.destination == .directPrint)
  #expect(draft.selectedDirectPrinterName == "Test Printer")
  #expect(draft.directPrintSession != nil)

  appState.actions.output.setOutputRequestDestination(.pdf)

  draft = unwrap(appState.actions.output.outputRequestDraft)
  #expect(draft.destination == .pdf)
  #expect(draft.selectedDirectPrinterName == nil)
  #expect(draft.directPrintSession == nil)
}

@Test("UXE-C04 PDF出力設定は空の出力を開いた時点で0ページの警告として表示する")
@MainActor
func uxe_c04_pdf_request_sheet_immediately_prepares_empty_output() {
  let emptyModel = OutputDocumentModel(
    paperSize: .a4,
    orientation: .portrait,
    scale: .actualSize,
    pageCount: 0,
    pages: []
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(name: "Empty", entities: []))
  store.outputBuildResult = sampleOutputBuildResult(
    model: emptyModel,
    warnings: [.init(kind: .emptyDocument, message: "出力対象がありません。")]
  )
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  appState.actions.output.exportPDFPanel()

  let draft = unwrap(appState.actions.output.outputRequestDraft)
  guard case .ready(let prepared) = draft.buildState else {
    Issue.record("PDF request should be prepared before the sheet is displayed")
    return
  }
  #expect(prepared.buildResult.outputDocumentModel.pageCount == 0)
  #expect(
    appState.actions.output.outputExecutionDisabledReason(for: draft)?.contains("出力ページがありません")
      == true)
}

@Test("UXE-C03 出力プレビュー中に編集ツールを選ぶと編集表示へ戻る")
@MainActor
func uxe_c03_activating_tools_from_output_preview_returns_to_edit_display() {
  let store = StubDocumentSessionAdapter(createNewDocumentState: makeDocumentState())
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  for tool in [CanvasTool.line, .horizontal, .measureDistance] {
    appState.actions.canvas.viewMode = .outputPreview
    appState.actions.canvas.activateTool(tool)

    #expect(appState.actions.canvas.viewMode == .editDisplay)
    #expect(appState.actions.canvas.selectedTool == tool)
    #expect(appState.actions.document.statusMessage == tool.idleMessage)
  }
}

@Test("Output AppCoordinator は A4 ガイド向きを PDF 出力オプションとして Core へ渡す")
@MainActor
func output_app_state_uses_a4_reference_orientation_for_pdf_request_options() throws {
  let initialState = makeDocumentState(name: "Export", entities: [])
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )
  let outputURL = uniqueTempURL("output-configured-export.pdf")
  let preparedBuildResult = sampleOutputBuildResult(
    model: sampleOutputDocumentModel(orientation: .portrait, rotationDeg: 90)
  )

  appState.actions.workspace.setA4ReferenceOrientation(.landscape)
  appState.actions.output.outputRequestDraft = OutputRequestDraft(
    destination: .pdf,
    options: OutputPresentationOptions(
      orientation: .portrait,
      includeDimensionLabels: false,
      includeScaleGuide: false,
      rotationDeg: 90
    ),
    directPrintSession: nil,
    buildState: .ready(
      OutputRequestPreparedState(
        buildResult: preparedBuildResult,
        buildOptions: OutputBuildOptions(
          orientation: .portrait,
          includeDimensionLabels: false,
          includeScaleGuide: false,
          rotationDeg: 90,
          printableAreaMm: OutputPrintableAreaMm(
            leftMm: -100.0,
            rightMm: 100.0,
            topMm: 143.5,
            bottomMm: -143.5
          )
        ),
        directPrintSession: nil
      ))
  )

  appState.actions.output.confirmOutputRequest(saveURL: outputURL)

  #expect(store.outputBuildOptions.isEmpty)
  #expect(store.renderedOutputModels.map(\.orientation) == [.portrait])
  #expect(appState.actions.output.outputRequestDraft == nil)
}

@Test("Output AppCoordinator は PDF 出力時の警告を成功メッセージへ含める")
@MainActor
func output_app_state_pdf_export_success_message_includes_warnings() {
  let initialState = makeDocumentState(name: "Export Warning", entities: [])
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.outputBuildResult = sampleOutputBuildResult(
    warnings: [.init(kind: .emptyDocument, message: "出力対象がありません。")]
  )
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  appState.actions.output.exportPDF(
    to: uniqueTempURL("output-warning.pdf"),
    options: OutputBuildOptions(
      orientation: .portrait,
      includeDimensionLabels: true,
      includeScaleGuide: true,
      rotationDeg: 0,
      printableAreaMm: OutputPrintableAreaMm(
        leftMm: -100.0,
        rightMm: 100.0,
        topMm: 143.5,
        bottomMm: -143.5
      )
    )
  )

  #expect(appState.actions.document.statusMessage.contains("警告: 出力対象がありません。"))
}

@Test("Output AppCoordinator は renderPDF 失敗時に保存せず警告する")
@MainActor
func output_app_state_pdf_export_failure_keeps_file_unwritten() {
  let initialState = makeDocumentState(name: "Export Failure", entities: [])
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.renderPDFResult = .failure(OutputError("render pdf failed"))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )
  let outputURL = uniqueTempURL("output-render-failure.pdf")

  appState.actions.output.exportPDF(
    to: outputURL,
    options: OutputBuildOptions(
      orientation: .portrait,
      includeDimensionLabels: true,
      includeScaleGuide: true,
      rotationDeg: 0,
      printableAreaMm: OutputPrintableAreaMm(
        leftMm: -100.0,
        rightMm: 100.0,
        topMm: 143.5,
        bottomMm: -143.5
      )
    )
  )

  #expect(appState.actions.document.coreStatus == .unavailable("render pdf failed"))
  #expect(appState.actions.document.alertMessage?.message == "render pdf failed")
  #expect(!FileManager.default.fileExists(atPath: outputURL.path))
}

@Test("Output AppCoordinator は output model を構築して直接印刷へ渡す")
@MainActor
func output_app_state_routes_direct_print_through_render_print_and_controller() {
  let initialState = makeDocumentState(name: "Direct Print", entities: [])
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.outputBuildResult = sampleOutputBuildResult(
    model: sampleOutputDocumentModel(orientation: .landscape, rotationDeg: 90)
  )
  store.renderPrintResult = .success(
    samplePrintRenderData(orientation: .landscape, rotationDeg: 90))
  let printController = StubPrintController()
  printController.outputBuildOptions = OutputBuildOptions(
    orientation: .landscape,
    includeDimensionLabels: false,
    includeScaleGuide: true,
    rotationDeg: 90,
    printableAreaMm: OutputPrintableAreaMm(
      leftMm: -95.0,
      rightMm: 95.0,
      topMm: 138.0,
      bottomMm: -138.0
    )
  )
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) },
    outputService: OutputService(printController: printController)
  )

  let selectedOptions = OutputPresentationOptions(
    orientation: .landscape,
    includeDimensionLabels: false,
    includeScaleGuide: true,
    rotationDeg: 90
  )

  appState.actions.output.printDirect(presentation: selectedOptions)

  #expect(store.outputBuildOptions == [printController.outputBuildOptions!])
  #expect(printController.requestedPresentations == [selectedOptions])
  #expect(store.printedOutputModels.count == 1)
  #expect(printController.printedRenderData.count == 1)
  #expect(printController.printedOrientations == [.landscape])
  #expect(printController.printedDocumentNames == ["Direct Print"])
  #expect(appState.actions.document.statusMessage == "直接印刷を開始しました")
}

@Test("Output AppCoordinator は renderPrint 失敗時に直接印刷を開始しない")
@MainActor
func output_app_state_direct_print_failure_keeps_controller_idle() {
  let initialState = makeDocumentState(name: "Direct Print Failure", entities: [])
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.renderPrintResult = .failure(OutputError("render print failed"))
  let printController = StubPrintController()
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) },
    outputService: OutputService(printController: printController)
  )

  appState.actions.output.printDirect(
    presentation: OutputPresentationOptions(
      orientation: .portrait,
      includeDimensionLabels: true,
      includeScaleGuide: true,
      rotationDeg: 0
    ))

  #expect(appState.actions.document.coreStatus == .unavailable("render print failed"))
  #expect(appState.actions.document.alertMessage?.message == "render print failed")
  #expect(printController.printedRenderData.isEmpty)
}

@Test("Output AppCoordinator は非対応の既定候補を飛ばして直接印刷シートを開く")
@MainActor
func output_app_state_direct_print_panel_selects_a_compatible_printer() {
  let store = StubDocumentSessionAdapter(createNewDocumentState: makeDocumentState())
  let printController = StubPrintController()
  printController.printerNames = ["Default Printer", "Compatible Printer"]
  printController.directPrintSessionResults = [
    "Default Printer": .failure(OutputError("A4、100%実寸、片面を設定できません。"))
  ]
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) },
    outputService: OutputService(printController: printController)
  )

  appState.actions.output.printDirectPanel()

  let draft = unwrap(appState.actions.output.outputRequestDraft)
  #expect(draft.selectedDirectPrinterName == "Compatible Printer")
  #expect(draft.directPrintSession != nil)
  #expect(printController.requestedPrinterNames == ["Default Printer", "Compatible Printer"])
  #expect(appState.actions.document.alertMessage == nil)
  appState.actions.output.cancelOutputRequest()
}

@Test("Output AppCoordinator は非対応プリンタの選択を保持して直接印刷を無効化する")
@MainActor
func output_app_state_direct_print_selection_failure_disables_printing() {
  let store = StubDocumentSessionAdapter(createNewDocumentState: makeDocumentState())
  let printController = StubPrintController()
  printController.directPrintSessionResults = [
    "Unsupported Printer": .failure(OutputError("A4、100%実寸、片面を設定できません。"))
  ]
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) },
    outputService: OutputService(printController: printController)
  )
  let directPrintSession = OutputDirectPrintSession(
    printInfo: LivePrintController.makePrintInfo(for: .portrait)
  )
  let buildOptions = OutputBuildOptions(
    orientation: .portrait,
    includeDimensionLabels: true,
    includeScaleGuide: true,
    rotationDeg: 0,
    printableAreaMm: directPrintSession.printableAreaMm
  )
  appState.actions.output.outputRequestDraft = OutputRequestDraft(
    destination: .directPrint,
    options: OutputPresentationOptions(
      orientation: .portrait,
      includeDimensionLabels: true,
      includeScaleGuide: true,
      rotationDeg: 0
    ),
    directPrinterNames: ["Compatible Printer", "Unsupported Printer"],
    selectedDirectPrinterName: "Compatible Printer",
    directPrintSession: directPrintSession,
    buildState: .ready(
      OutputRequestPreparedState(
        buildResult: sampleOutputBuildResult(),
        buildOptions: buildOptions,
        directPrintSession: directPrintSession
      ))
  )

  appState.actions.output.selectDirectPrintPrinter("Unsupported Printer")

  let draft = unwrap(appState.actions.output.outputRequestDraft)
  #expect(draft.selectedDirectPrinterName == "Unsupported Printer")
  #expect(draft.directPrintSession == nil)
  #expect(
    appState.actions.output.outputExecutionDisabledReason(for: draft)
      == "A4、100%実寸、片面を設定できません。")
  appState.actions.output.confirmOutputRequest()
  #expect(printController.printedRenderData.isEmpty)
}

@Test("Output AppCoordinator は警告付きの直接印刷主操作で続行できる")
@MainActor
func output_app_state_direct_print_sheet_allows_warning_confirmation() {
  let initialState = makeDocumentState(name: "Direct Print Warning", entities: [])
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.outputBuildResult = sampleOutputBuildResult(
    model: sampleOutputDocumentModel(orientation: .landscape, rotationDeg: 90),
    warnings: [.init(kind: .outOfPrintableBounds, message: "印刷可能領域からはみ出しています。")]
  )
  store.renderPrintResult = .success(
    samplePrintRenderData(orientation: .landscape, rotationDeg: 90))
  let printController = StubPrintController()
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) },
    outputService: OutputService(printController: printController)
  )
  let directPrintSession = OutputDirectPrintSession(
    printInfo: LivePrintController.makePrintInfo(for: .landscape)
  )

  appState.actions.output.outputRequestDraft = OutputRequestDraft(
    destination: .directPrint,
    options: OutputPresentationOptions(
      orientation: .landscape,
      includeDimensionLabels: false,
      includeScaleGuide: true,
      rotationDeg: 90
    ),
    directPrintSession: directPrintSession,
    buildState: .ready(
      OutputRequestPreparedState(
        buildResult: store.outputBuildResult,
        buildOptions: OutputBuildOptions(
          orientation: .landscape,
          includeDimensionLabels: false,
          includeScaleGuide: true,
          rotationDeg: 90,
          printableAreaMm: directPrintSession.printableAreaMm
        ),
        directPrintSession: directPrintSession
      ))
  )

  #expect(
    appState.actions.output.outputRequestDraft?.confirmationTitle == "警告を確認して印刷へ進む")
  appState.actions.output.confirmOutputRequest()

  #expect(appState.actions.output.outputRequestDraft == nil)
  #expect(printController.printedRenderData.count == 1)
  #expect(printController.printedOrientations == [.landscape])
  #expect(printController.printedDocumentNames == ["Direct Print Warning"])
}

@Test("UC1 AppCoordinator の失敗した再作成・開く・再読込は状態を壊さない")
@MainActor
func uc1_app_state_failed_session_operations_keep_state_safe() {
  let initialState = makeDocumentState(
    name: "Stable",
    entities: [
      pointEntity(id: "entity:point-a", point: .zero)
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )
  store.createNewDocumentFailure = "create failed"
  store.openDocumentFailure = "open failed"
  store.loadStateFailure = "reload failed"

  appState.actions.canvas.selectedEntityID = "entity:point-a"
  appState.actions.canvas.draftStartPoint = .init(xMM: 1.0, yMM: 1.0)
  appState.actions.canvas.draftCurrentPoint = .init(xMM: 2.0, yMM: 2.0)
  appState.actions.canvas.selectedTool = .line

  appState.actions.document.createNewProject()
  #expect(store.createNewDocumentCalls.map(\.name).count == 2)
  #expect(appState.actions.document.coreStatus == .unavailable("create failed"))
  #expect(appState.actions.workspace.errorPresentation?.message == "create failed")
  #expect(appState.actions.document.documentName == "Stable")
  #expect(appState.actions.canvas.selectedEntityID == "entity:point-a")
  #expect(appState.actions.canvas.draftStartPoint == .init(xMM: 1.0, yMM: 1.0))

  appState.actions.canvas.selectedEntityID = "entity:point-a"
  appState.actions.canvas.draftStartPoint = .init(xMM: 1.0, yMM: 1.0)
  appState.actions.canvas.draftCurrentPoint = .init(xMM: 2.0, yMM: 2.0)
  appState.actions.document.openProject(at: uniqueTempURL("failed-open.kawa"))
  #expect(appState.actions.document.coreStatus == .unavailable("open failed"))
  #expect(appState.actions.workspace.errorPresentation?.message == "open failed")
  #expect(appState.actions.canvas.selectedEntityID == "entity:point-a")
  #expect(appState.actions.canvas.draftStartPoint == .init(xMM: 1.0, yMM: 1.0))

  store.hasDocument = true
  appState.actions.document.applyDocumentState(
    makeDocumentState(
      layers: defaultLayers(),
      parameters: [
        ProjectParameter(
          id: "parameter:width",
          name: "width",
          valueMM: 10.0,
          unit: "millimeter",
          memo: "",
          usageCount: 0,
          usedConstraintIDs: []
        )
      ],
      entities: [
        pointEntity(id: "entity:point-a", point: .zero)
      ],
      constraints: []
    ))
  appState.actions.document.reloadFromDocument()

  #expect(store.loadStateCalls == [.editDisplay])
  #expect(appState.actions.document.coreStatus == .unavailable("reload failed"))
  #expect(appState.actions.workspace.errorPresentation?.message == "reload failed")
  #expect(appState.actions.document.layers == defaultLayers())
  #expect(appState.actions.document.parameters.map(\.name) == ["width"])
  #expect(appState.actions.document.entities.map(\.id) == ["entity:point-a"])
  #expect(appState.actions.document.constraints.isEmpty)
}

@Test("UC1 AppCoordinator は dirty な新規作成要求で保存確認を出す")
@MainActor
func uc1_app_state_prompts_before_creating_new_dirty_document() {
  let initialState = makeDocumentState(
    name: "Dirty", entities: [pointEntity(id: "entity:point-a", point: .zero)])
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )
  store.isDocumentDirty = true

  appState.actions.document.createNewProject()

  #expect(store.createNewDocumentCalls.count == 1)
  #expect(appState.actions.document.documentSaveConfirmation?.documentName == "Dirty")

  appState.actions.document.discardDocumentChangesAndContinue()

  #expect(store.createNewDocumentCalls.count == 2)
  #expect(appState.actions.document.documentSaveConfirmation == nil)
}

@Test("UC1 AppCoordinator は dirty な open 要求で保存後に続行する")
@MainActor
func uc1_app_state_saves_before_opening_another_project() {
  let initialState = makeDocumentState(
    name: "Dirty", entities: [pointEntity(id: "entity:point-a", point: .zero)])
  let openedState = makeDocumentState(name: "Opened", entities: [])
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.openDocumentState = openedState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )
  let saveURL = uniqueTempURL("dirty-document.kawa")
  store.documentURL = saveURL
  store.isDocumentDirty = true
  let openURL = uniqueTempURL("opened-document.kawa")

  appState.actions.document.openProject(at: openURL)
  appState.actions.document.confirmDocumentSaveAndContinue()

  #expect(store.saveDocumentCalls == [saveURL])
  #expect(store.openDocumentCalls.map(\.url) == [openURL])
  #expect(appState.actions.document.documentSaveConfirmation == nil)
  #expect(appState.actions.document.documentName == "Opened")
}

@Test("UC1 AppCoordinator は未保存 dirty 文書で保存パネルをキャンセルすると破壊的操作を中止する")
@MainActor
func uc1_app_state_cancels_destructive_action_when_save_panel_is_cancelled() {
  let initialState = makeDocumentState(
    name: "Unsaved Dirty", entities: [pointEntity(id: "entity:point-a", point: .zero)])
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let savePanelPresenter = StubDesktopEnvironmentAdapter()
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) },
    desktopEnvironment: savePanelPresenter
  )
  store.isDocumentDirty = true

  appState.actions.document.createNewProject()
  appState.actions.document.confirmDocumentSaveAndContinue()

  #expect(savePanelPresenter.promptedDocumentNames == ["Unsaved Dirty"])
  #expect(store.createNewDocumentCalls.count == 1)
  #expect(appState.actions.document.documentSaveConfirmation == nil)
  #expect(appState.actions.document.documentName == "Unsaved Dirty")
}

@Test("UC1 AppCoordinator は dirty なウィンドウクローズ要求で保存確認を経由する")
@MainActor
func uc1_app_state_routes_window_close_through_save_confirmation() {
  let initialState = makeDocumentState(
    name: "Dirty", entities: [pointEntity(id: "entity:point-a", point: .zero)])
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let lifecycleController = StubDocumentLifecycleController()
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )
  appState.documentLifecycleController = lifecycleController
  store.isDocumentDirty = true

  #expect(appState.actions.document.requestWindowClose() == false)
  #expect(appState.actions.document.documentSaveConfirmation?.documentName == "Dirty")

  appState.actions.document.discardDocumentChangesAndContinue()

  #expect(lifecycleController.closeWindowCount == 1)
}

@Test("UC1 破棄して閉じた最後のウィンドウは保存確認を繰り返さず終了できる")
@MainActor
func uc1_app_state_terminates_after_discarded_window_close_without_a_second_confirmation() {
  let initialState = makeDocumentState(
    name: "Dirty", entities: [pointEntity(id: "entity:point-a", point: .zero)])
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let lifecycleController = StubDocumentLifecycleController()
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )
  appState.documentLifecycleController = lifecycleController
  store.isDocumentDirty = true

  #expect(appState.actions.document.requestWindowClose() == false)
  appState.actions.document.discardDocumentChangesAndContinue()

  #expect(lifecycleController.closeWindowCount == 1)
  #expect(appState.actions.document.requestApplicationQuit())
  #expect(appState.actions.document.documentSaveConfirmation == nil)
}

@Test("UC1 AppCoordinator は dirty な終了要求で保存確認を経由する")
@MainActor
func uc1_app_state_routes_quit_through_save_confirmation() {
  let initialState = makeDocumentState(
    name: "Dirty", entities: [pointEntity(id: "entity:point-a", point: .zero)])
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let lifecycleController = StubDocumentLifecycleController()
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )
  appState.documentLifecycleController = lifecycleController
  store.isDocumentDirty = true

  #expect(appState.actions.document.requestApplicationQuit() == false)
  #expect(appState.actions.document.documentSaveConfirmation?.documentName == "Dirty")

  appState.actions.document.cancelDocumentSaveConfirmation()
  #expect(lifecycleController.terminationReplies == [false])

  #expect(appState.actions.document.requestApplicationQuit() == false)
  appState.actions.document.discardDocumentChangesAndContinue()
  #expect(lifecycleController.terminationReplies == [false, true])
}

@Test("UC1 AppCoordinator は保存確認中の追加終了要求を即時拒否する")
@MainActor
func uc1_app_state_rejects_reentrant_quit_while_save_confirmation_is_visible() {
  let initialState = makeDocumentState(
    name: "Dirty", entities: [pointEntity(id: "entity:point-a", point: .zero)])
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let lifecycleController = StubDocumentLifecycleController()
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )
  appState.documentLifecycleController = lifecycleController
  store.isDocumentDirty = true

  #expect(appState.actions.document.requestWindowClose() == false)
  #expect(appState.actions.document.documentSaveConfirmation?.documentName == "Dirty")

  #expect(appState.actions.document.requestApplicationQuit() == false)
  #expect(lifecycleController.terminationReplies == [false])

  appState.actions.document.discardDocumentChangesAndContinue()
  #expect(lifecycleController.closeWindowCount == 1)
  #expect(lifecycleController.terminationReplies == [false])
}

@Test("UC6 AppCoordinator のレイヤー表示切り替えは store を経由して反映される")
@MainActor
func uc6_app_state_layer_visibility_routes_through_the_store() {
  let visibleState = makeDocumentState(
    name: "Layer Visibility",
    layers: defaultLayers(),
    entities: [
      pointEntity(id: "entity:anchor", label: "Anchor", point: .zero)
    ],
    constraintStatus: .fullyConstrained
  )
  let hiddenLayers = [
    ProjectLayer(
      id: "layer:cut-line",
      name: "カット線",
      kind: .cutLine,
      visible: false,
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
  let hiddenState = makeDocumentState(
    name: "Layer Visibility",
    layers: hiddenLayers,
    entities: [],
    constraintStatus: .fullyConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: visibleState)
  store.applyCommandState = hiddenState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) })

  let layer = unwrap(appState.actions.document.layers.first(where: { $0.id == "layer:cut-line" }))
  appState.actions.document.setLayerVisibility(layer, visible: false)

  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "setLayerVisibility")
  #expect(
    appState.actions.document.layers.first(where: { $0.id == "layer:cut-line" })?.visible == false)
  #expect(appState.actions.document.entities.isEmpty)
  #expect(appState.actions.document.statusMessage == "カット線 の表示を無効にしました")
}

@Test("UC6 AppCoordinator のレイヤースタイル変更は store を経由して反映される")
@MainActor
func uc6_app_state_layer_style_routes_through_the_store() {
  let initialLayers = defaultLayers()
  let updatedLayers = [
    ProjectLayer(
      id: "layer:cut-line",
      name: "カット線",
      kind: .cutLine,
      visible: true,
      printable: true,
      colorHex: "#336699",
      strokeWidthMM: 0.45,
      linePattern: .dotted
    ),
    initialLayers[1],
    initialLayers[2],
  ]
  let initialState = makeDocumentState(name: "Layer Style", layers: initialLayers)
  let updatedState = makeDocumentState(name: "Layer Style", layers: updatedLayers)
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = updatedState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) })

  let updatedLayer = updatedLayers[0]
  let didApply = appState.actions.document.setLayerStyle(updatedLayer)

  #expect(didApply)
  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "setLayerStyle")
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  let style = unwrap(payload["style"] as? [String: Any])
  #expect((payload["layerId"] as? String) == "layer:cut-line")
  #expect((style["pattern"] as? String) == "dotted")
  #expect((style["strokeWidthMm"] as? Double) == 0.45)
  #expect(
    appState.actions.document.layers.first(where: { $0.id == "layer:cut-line" })?.linePattern
      == .dotted)
  #expect(
    appState.actions.document.layers.first(where: { $0.id == "layer:cut-line" })?.strokeWidthMM
      == 0.45)
  #expect(appState.actions.document.statusMessage == "カット線 の線スタイルを更新しました")
}

@Test("AppCoordinator の共有スタイル更新と選択図形への適用は store を経由して反映される")
@MainActor
func app_state_shared_style_routes_through_the_store() {
  let initialStyle = ProjectSharedStyle(
    id: "style:stitch",
    name: "縫い線",
    colorHex: "#336699",
    strokeWidthMM: 0.35,
    linePattern: .dashed
  )
  let updatedStyle = initialStyle.withStyle(
    colorHex: "#DC2626", strokeWidthMM: 0.5, linePattern: .dotted)
  let line = lineEntity(
    id: "entity:line",
    start: ModelPoint(xMM: 0, yMM: 0),
    end: ModelPoint(xMM: 20, yMM: 0)
  )
  let initialState = makeDocumentState(
    name: "Shared Style",
    sharedStyles: [initialStyle],
    entities: [line]
  )
  let styleUpdatedState = makeDocumentState(
    name: "Shared Style",
    sharedStyles: [updatedStyle],
    entities: [line]
  )
  let appliedState = makeDocumentState(
    name: "Shared Style",
    sharedStyles: [updatedStyle],
    entities: [line.withSharedStyle("style:stitch")]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandStates = [styleUpdatedState, appliedState]
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) })

  let didUpdate = appState.actions.document.updateSharedStyle(updatedStyle)
  appState.actions.canvas.selectedEntityID = "entity:line"
  appState.actions.canvas.selectedEntityIDs = ["entity:line"]
  let didApply = appState.actions.document.setSelectedEntitiesSharedStyle("style:stitch")

  #expect(didUpdate)
  #expect(didApply)
  #expect(store.appliedPayloads.count == 2)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "updateSharedStyle")
  let updatePayload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((updatePayload["id"] as? String) == "style:stitch")
  let stylePayload = unwrap(updatePayload["style"] as? [String: Any])
  #expect((stylePayload["pattern"] as? String) == "dotted")
  #expect((stylePayload["strokeWidthMm"] as? Double) == 0.5)

  #expect((store.appliedPayloads[1]["kind"] as? String) == "setEntitySharedStyle")
  let applyPayload = unwrap(store.appliedPayloads[1]["payload"] as? [String: Any])
  #expect((applyPayload["entityId"] as? String) == "entity:line")
  #expect((applyPayload["styleId"] as? String) == "style:stitch")
  #expect(appState.actions.document.sharedStyles[0].linePattern == .dotted)
  #expect(appState.actions.canvas.selectedEntity?.styleID == "style:stitch")
}

@Test("AppCoordinator は複数選択図形へ共有スタイルを compound command で適用する")
@MainActor
func app_state_applies_shared_style_to_multiple_selected_entities() {
  let style = ProjectSharedStyle(
    id: "style:fold",
    name: "折り線",
    colorHex: "#16A34A",
    strokeWidthMM: 0.25,
    linePattern: .dashed
  )
  let lineA = lineEntity(
    id: "entity:a", start: ModelPoint(xMM: 0, yMM: 0), end: ModelPoint(xMM: 10, yMM: 0))
  let lineB = lineEntity(
    id: "entity:b", start: ModelPoint(xMM: 0, yMM: 5), end: ModelPoint(xMM: 10, yMM: 5))
  let initialState = makeDocumentState(
    name: "Shared Style Multi", sharedStyles: [style], entities: [lineA, lineB])
  let updatedState = makeDocumentState(
    name: "Shared Style Multi",
    sharedStyles: [style],
    entities: [lineA.withSharedStyle("style:fold"), lineB.withSharedStyle("style:fold")]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = updatedState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) })
  appState.actions.canvas.selectedEntityIDs = ["entity:a", "entity:b"]

  let didApply = appState.actions.document.setSelectedEntitiesSharedStyle("style:fold")

  #expect(didApply)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "compound")
  let commands = unwrap(store.appliedPayloads[0]["payload"] as? [[String: Any]])
  #expect(commands.count == 2)
  #expect(commands.allSatisfy { ($0["kind"] as? String) == "setEntitySharedStyle" })
  #expect(Set(appState.actions.canvas.selectedEntities.compactMap(\.styleID)) == ["style:fold"])
}

@Test("AppCoordinator は派生要素選択時に共有スタイルを派生要素へ適用する")
@MainActor
func app_state_applies_shared_style_to_selected_derived_element() {
  let style = ProjectSharedStyle(
    id: "style:stitch",
    name: "縫い線",
    colorHex: "#DC2626",
    strokeWidthMM: 0.25,
    linePattern: .dashed
  )
  let resolved = lineEntity(
    id: "derived:offset:resolved:0",
    start: ModelPoint(xMM: 0, yMM: 3),
    end: ModelPoint(xMM: 10, yMM: 3)
  )
  let derived = ProjectDerivedElement(
    id: "derived:offset",
    layerID: "layer:cut-line",
    sourceEntityIDs: ["entity:line"],
    distanceMM: 3.0,
    distanceParameterID: nil,
    direction: .left
  )
  let initialState = makeDocumentState(
    name: "Derived Shared Style",
    sharedStyles: [style],
    entities: [resolved],
    derivedElements: [derived]
  )
  let updatedState = makeDocumentState(
    name: "Derived Shared Style",
    sharedStyles: [style],
    entities: [resolved.withSharedStyle("style:stitch")],
    derivedElements: [derived.withSharedStyle("style:stitch")]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = updatedState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) })
  appState.actions.canvas.selectedEntityID = "derived:offset:resolved:0"
  appState.actions.canvas.selectedEntityIDs = ["derived:offset:resolved:0"]

  let didApply = appState.actions.document.setSelectedEntitiesSharedStyle("style:stitch")

  #expect(didApply)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "setDerivedSharedStyle")
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["derivedElementId"] as? String) == "derived:offset")
  #expect((payload["styleId"] as? String) == "style:stitch")
  #expect(appState.actions.canvas.selectedDerivedElement?.styleID == "style:stitch")
  #expect(appState.actions.canvas.selectedEntity?.styleID == "style:stitch")
}

@Test(
  "AppCoordinator は選択した型紙線種を作図コマンドへ付与する",
  arguments: [
    (CanvasTool.line, "style:outer-cut-line", "line"),
    (CanvasTool.line, "style:stitch-line", "line"),
    (CanvasTool.centerLine, "style:center-line", "line"),
    (CanvasTool.horizontalCenterLine, "style:construction-line", "line"),
    (CanvasTool.verticalCenterLine, "style:dimension-line", "line"),
  ]
)
@MainActor
func app_state_applies_active_pattern_line_style_to_drawing_commands(
  tool: CanvasTool,
  styleID: String,
  expectedKind: String
) {
  let initialState = makeDocumentState(
    name: "Pattern Line Drawing",
    sharedStyles: patternLineSharedStyles()
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) })
  appState.actions.document.setActivePatternLineStyle(styleID)

  appState.actions.canvas.applyEntityCommand(
    for: tool,
    start: .zero,
    end: ModelPoint(xMM: 20.0, yMM: 5.0)
  )

  let payload = unwrap(store.appliedPayloads.last?["payload"] as? [String: Any])
  #expect((payload["styleId"] as? String) == styleID)
  let gesture = unwrap(payload["gesture"] as? [String: Any])
  #expect((gesture["kind"] as? String) == expectedKind)
}

@Test("AppCoordinator は選択した型紙線種を三点円弧コマンドへ付与する")
@MainActor
func app_state_applies_active_pattern_line_style_to_arc_command() {
  let initialState = makeDocumentState(
    name: "Pattern Arc Drawing",
    sharedStyles: patternLineSharedStyles()
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) })
  appState.actions.document.setActivePatternLineStyle("style:fold-line")

  appState.actions.canvas.applyArcEntityCommand(
    center: .zero,
    start: ModelPoint(xMM: 10.0, yMM: 0.0),
    end: ModelPoint(xMM: 0.0, yMM: 10.0),
    sweepReferenceRad: Double.pi / 2
  )

  let payload = unwrap(store.appliedPayloads.last?["payload"] as? [String: Any])
  #expect((payload["styleId"] as? String) == "style:fold-line")
  let gesture = unwrap(payload["gesture"] as? [String: Any])
  #expect((gesture["kind"] as? String) == "arc")
}

@Test(
  "AppCoordinator は選択した型紙線種を固定値・パラメータ参照のオフセット派生要素へ付与する",
  arguments: [
    ("fixed", ConstraintValueEntryMode.fixedValue),
    ("parameter", ConstraintValueEntryMode.parameterReference),
  ]
)
@MainActor
func app_state_applies_active_pattern_line_style_to_offset_derived_element(
  label: String,
  entryMode: ConstraintValueEntryMode
) {
  let parameter = ProjectParameter(
    id: "parameter:offset",
    name: "offset",
    valueMM: 3.0,
    unit: "millimeter",
    memo: "",
    usageCount: 0,
    usedConstraintIDs: []
  )
  let initialState = makeDocumentState(
    name: "Pattern Offset \(label)",
    sharedStyles: patternLineSharedStyles(),
    parameters: [parameter]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) })
  appState.actions.document.setActivePatternLineStyle("style:stitch-line")
  appState.actions.constraints.beginOffsetValueEntry(
    sourceEntityIDs: ["entity:line-a"], direction: "left")
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.valueText == "3.00")
  appState.actions.constraints.updatePendingConstraintValueText("3.0")
  appState.actions.constraints.updatePendingConstraintEntryMode(entryMode)
  appState.actions.constraints.updatePendingConstraintParameterID("parameter:offset")

  appState.actions.constraints.commitPendingConstraintValueEntry()

  let payload = unwrap(store.appliedPayloads.last?["payload"] as? [String: Any])
  #expect((payload["styleId"] as? String) == "style:stitch-line")
  let kind = unwrap(payload["kind"] as? [String: Any])
  let offset = unwrap(kind["offsetCurve"] as? [String: Any])
  #expect((offset["sourceEntityIds"] as? [String]) == ["entity:line-a"])
  if entryMode == .fixedValue {
    #expect((offset["distance"] as? [String: Double])?["fixedMm"] == 3.0)
  } else {
    #expect((offset["distance"] as? [String: String])?["parameter"] == "parameter:offset")
  }
}

@Test("AppCoordinator は型紙線種セレクタから通常図形と派生要素へ一括適用できる")
@MainActor
func app_state_applies_active_pattern_line_style_to_mixed_selection() {
  let line = lineEntity(id: "entity:line", start: .zero, end: ModelPoint(xMM: 10.0, yMM: 0.0))
  let resolved = lineEntity(
    id: "derived:offset:resolved:0",
    start: ModelPoint(xMM: 0.0, yMM: 3.0),
    end: ModelPoint(xMM: 10.0, yMM: 3.0)
  )
  let derived = ProjectDerivedElement(
    id: "derived:offset",
    layerID: "layer:cut-line",
    sourceEntityIDs: ["entity:source"],
    distanceMM: 3.0,
    distanceParameterID: nil,
    direction: .left
  )
  let initialState = makeDocumentState(
    name: "Pattern Bulk Apply",
    sharedStyles: patternLineSharedStyles(),
    entities: [line, resolved],
    derivedElements: [derived]
  )
  let updatedState = makeDocumentState(
    name: "Pattern Bulk Apply",
    sharedStyles: patternLineSharedStyles(),
    entities: [
      line.withSharedStyle("style:fold-line"),
      resolved.withSharedStyle("style:fold-line"),
    ],
    derivedElements: [derived.withSharedStyle("style:fold-line")]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = updatedState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) })
  appState.actions.canvas.selectedEntityIDs = ["entity:line", "derived:offset:resolved:0"]
  appState.actions.document.setActivePatternLineStyle("style:fold-line")

  #expect(appState.actions.document.applyActivePatternLineStyleToSelection())

  #expect((store.appliedPayloads.last?["kind"] as? String) == "compound")
  let commands = unwrap(store.appliedPayloads.last?["payload"] as? [[String: Any]])
  #expect(commands.count == 2)
  #expect(commands.contains { ($0["kind"] as? String) == "setEntitySharedStyle" })
  #expect(commands.contains { ($0["kind"] as? String) == "setDerivedSharedStyle" })
  #expect(
    Set(appState.actions.canvas.selectedEntities.compactMap(\.styleID)) == ["style:fold-line"])
}

@Test("UC6 AppCoordinator の不正なレイヤースタイル変更は境界へ送らない")
@MainActor
func uc6_app_state_invalid_layer_style_is_rejected_before_boundary() {
  let initialLayers = defaultLayers()
  let initialState = makeDocumentState(name: "Invalid Layer Style", layers: initialLayers)
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) })

  let invalidLayer = ProjectLayer(
    id: "layer:cut-line",
    name: "カット線",
    kind: .cutLine,
    visible: true,
    printable: true,
    colorHex: "336699",
    strokeWidthMM: 0.45,
    linePattern: .dashed
  )

  let didApply = appState.actions.document.setLayerStyle(invalidLayer)

  #expect(!didApply)
  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.document.layers == initialLayers)
  #expect(appState.actions.document.statusMessage == "線色は #RRGGBB 形式で入力してください")
}

@Test("UC6 AppCoordinator のレイヤー追加・名称変更・削除は store を経由して反映される")
@MainActor
func uc6_app_state_layer_management_routes_through_the_store() {
  let initialLayers = [
    ProjectLayer(
      id: "layer:cut-line",
      name: "カット線",
      kind: .cutLine,
      visible: true,
      printable: true,
      colorHex: "#1f2937"
    ),
    ProjectLayer(
      id: "layer:user-a",
      name: "Layer A",
      kind: .cutLine,
      visible: true,
      printable: true,
      colorHex: "#1f2937"
    ),
  ]
  let initialState = makeDocumentState(
    name: "Layer Management",
    layers: initialLayers,
    entities: [
      lineEntity(
        id: "entity:line-a",
        layerID: "layer:user-a",
        start: .zero,
        end: .init(xMM: 10.0, yMM: 0.0)
      )
    ],
    constraintStatus: .underConstrained
  )
  let addedLayerID = "layer:user-added"
  let addedState = makeDocumentState(
    name: "Layer Management",
    layers: initialLayers + [
      ProjectLayer(
        id: addedLayerID,
        name: "レイヤー 3",
        kind: .cutLine,
        visible: true,
        printable: true,
        colorHex: "#000000"
      )
    ],
    entities: [
      lineEntity(
        id: "entity:line-a",
        layerID: "layer:user-a",
        start: .zero,
        end: .init(xMM: 10.0, yMM: 0.0)
      )
    ],
    constraintStatus: .underConstrained
  )
  let renamedState = makeDocumentState(
    name: "Layer Management",
    layers: [
      initialLayers[0],
      ProjectLayer(
        id: "layer:user-a",
        name: "Pattern",
        kind: .cutLine,
        visible: true,
        printable: true,
        colorHex: "#1f2937"
      ),
    ],
    entities: [
      lineEntity(
        id: "entity:line-a",
        layerID: "layer:user-a",
        start: .zero,
        end: .init(xMM: 10.0, yMM: 0.0)
      )
    ],
    constraintStatus: .underConstrained
  )
  let deletedState = makeDocumentState(
    name: "Layer Management",
    layers: [initialLayers[0]],
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: .init(xMM: 10.0, yMM: 0.0))
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) })

  store.applyCommandState = addedState
  appState.actions.document.addLayer()
  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "addLayer")
  let addPayload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((addPayload["kind"] as? String) == "cutLine")
  #expect((addPayload["printable"] as? Bool) == true)
  let newLayerID = unwrap(addPayload["id"] as? String)
  #expect(appState.actions.canvas.activeLayerID == newLayerID)

  store.applyCommandState = renamedState
  let layerToRename: ProjectLayer = unwrap(
    appState.actions.document.layers.first(where: { $0.id == "layer:user-a" }))
  appState.actions.document.renameLayer(layerToRename, name: "Pattern")
  #expect(store.appliedPayloads.count == 2)
  #expect((store.appliedPayloads[1]["kind"] as? String) == "renameLayer")
  let renamePayload = unwrap(store.appliedPayloads[1]["payload"] as? [String: Any])
  #expect((renamePayload["layerId"] as? String) == "layer:user-a")
  #expect((renamePayload["name"] as? String) == "Pattern")
  #expect(
    appState.actions.document.layers.first(where: { $0.id == "layer:user-a" })?.name == "Pattern")

  store.applyCommandState = deletedState
  appState.actions.canvas.activeLayerID = "layer:user-a"
  let layerToDelete: ProjectLayer = unwrap(
    appState.actions.document.layers.first(where: { $0.id == "layer:user-a" }))
  appState.actions.document.deleteLayer(layerToDelete)
  #expect(store.appliedPayloads.count == 2)
  #expect(appState.actions.document.layerDeletionConfirmation?.layer.id == "layer:user-a")
  #expect(appState.actions.document.layerDeletionConfirmation?.entityCount == 1)
  #expect(appState.actions.document.statusMessage == "Pattern の削除確認が必要です")

  appState.actions.document.confirmLayerDeletion()

  #expect(store.appliedPayloads.count == 3)
  #expect((store.appliedPayloads[2]["kind"] as? String) == "deleteLayer")
  #expect((store.appliedPayloads[2]["payload"] as? String) == "layer:user-a")
  #expect(appState.actions.document.layerDeletionConfirmation == nil)
  #expect(appState.actions.document.layers.map { $0.id } == ["layer:cut-line"])
  #expect(appState.actions.canvas.activeLayerID == "layer:cut-line")
}

@Test("UC6 AppCoordinator の参照付きレイヤー削除はキャンセルできる")
@MainActor
func uc6_app_state_layer_delete_confirmation_can_be_cancelled() {
  let userLayer = ProjectLayer(
    id: "layer:user-a",
    name: "Layer A",
    kind: .cutLine,
    visible: true,
    printable: true,
    colorHex: "#1f2937"
  )
  let initialState = makeDocumentState(
    name: "Layer Delete Cancel",
    layers: [defaultLayers()[0], userLayer],
    entities: [
      lineEntity(
        id: "entity:line-a",
        layerID: "layer:user-a",
        start: .zero,
        end: .init(xMM: 10.0, yMM: 0.0)
      )
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) })

  appState.actions.document.deleteLayer(userLayer)
  appState.actions.document.cancelLayerDeletion()

  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.document.layerDeletionConfirmation == nil)
  #expect(appState.actions.document.layers.map(\.id) == ["layer:cut-line", "layer:user-a"])
  #expect(appState.actions.document.statusMessage == "「Layer A」の削除を取り消しました。")
}

@Test("UC203 AppCoordinator はオフセット線を再オフセットするとき派生要素IDを参照元にする", .disabled("派生参照の正規化は Core 結合テストへ移管"))
@MainActor
func uc203_app_state_offset_tool_uses_derived_element_id_for_offset_source() {
  let offsetLine = lineEntity(
    id: "derived:offset-a:resolved:0",
    start: .zero,
    end: .init(xMM: 10.0, yMM: 0.0)
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [offsetLine]))
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .offset

  appState.actions.constraints.handleConstraintTargetSelection(offsetLine.entitySelectionTarget)

  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.offsetSourceEntityIDs == [
      "derived:offset-a"
    ])
}

@Test("UC203 AppCoordinator は複数選択を部分オフセットの参照元として維持する")
@MainActor
func uc203_app_state_offset_tool_preserves_multi_selection_sources() {
  let first = lineEntity(
    id: "entity:first",
    start: .zero,
    end: .init(xMM: 10.0, yMM: 0.0)
  )
  let second = lineEntity(
    id: "entity:second",
    start: .init(xMM: 10.0, yMM: 0.0),
    end: .init(xMM: 10.0, yMM: 10.0)
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [first, second]))
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .offset
  appState.actions.canvas.selectedEntityIDs = ["entity:first", "entity:second"]

  appState.actions.constraints.handleConstraintTargetSelection(first.entitySelectionTarget)

  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.offsetSourceEntityIDs == [
      "entity:first", "entity:second",
    ])
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.selectedOffsetSourceScope == .selectedRange
  )
}

@Test("UC203 AppCoordinator は閉じた輪郭を既定のオフセット元にする", .disabled("閉輪郭判定は Core 結合テストへ移管"))
@MainActor
func uc203_app_state_offset_tool_defaults_to_closed_contour_scope() {
  let bottom = lineEntity(
    id: "entity:bottom",
    start: .zero,
    end: .init(xMM: 10.0, yMM: 0.0)
  )
  let right = lineEntity(
    id: "entity:right",
    start: .init(xMM: 10.0, yMM: 0.0),
    end: .init(xMM: 10.0, yMM: 10.0)
  )
  let top = lineEntity(
    id: "entity:top",
    start: .init(xMM: 10.0, yMM: 10.0),
    end: .init(xMM: 0.0, yMM: 10.0)
  )
  let left = lineEntity(
    id: "entity:left",
    start: .init(xMM: 0.0, yMM: 10.0),
    end: .zero
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [bottom, right, top, left]))
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .offset
  let target = CanvasSelectionTarget(
    entityID: bottom.id,
    entityLabel: bottom.label,
    entityKind: bottom.kind,
    controlPoint: nil,
    point: .init(xMM: 5.0, yMM: 1.0)
  )

  appState.actions.constraints.handleConstraintTargetSelection(target)

  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.selectedOffsetSourceScope == .closedContour
  )
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.offsetSourceScopeOptions.map(\.scope) == [
      .closedContour, .singleElement,
    ])
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.offsetSourceEntityIDs == [
      "entity:bottom", "entity:right", "entity:top", "entity:left",
    ])
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.offsetDirection == "inward")
}

@Test("UC203 AppCoordinator は閉じた輪郭候補から単独要素へ切り替えられる", .disabled("オフセット候補生成は Core 結合テストへ移管"))
@MainActor
func uc203_app_state_offset_tool_can_switch_closed_contour_to_single_element() {
  let bottom = lineEntity(
    id: "entity:bottom",
    start: .zero,
    end: .init(xMM: 10.0, yMM: 0.0)
  )
  let right = lineEntity(
    id: "entity:right",
    start: .init(xMM: 10.0, yMM: 0.0),
    end: .init(xMM: 10.0, yMM: 10.0)
  )
  let top = lineEntity(
    id: "entity:top",
    start: .init(xMM: 10.0, yMM: 10.0),
    end: .init(xMM: 0.0, yMM: 10.0)
  )
  let left = lineEntity(
    id: "entity:left",
    start: .init(xMM: 0.0, yMM: 10.0),
    end: .zero
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [bottom, right, top, left]))
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .offset
  let target = CanvasSelectionTarget(
    entityID: bottom.id,
    entityLabel: bottom.label,
    entityKind: bottom.kind,
    controlPoint: nil,
    point: .init(xMM: 5.0, yMM: -1.0)
  )

  appState.actions.constraints.handleConstraintTargetSelection(target)
  appState.actions.constraints.updatePendingOffsetSourceScope(.singleElement)

  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.selectedOffsetSourceScope == .singleElement
  )
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.offsetSourceEntityIDs == ["entity:bottom"])
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.offsetDirection == "right")
}

@Test("UC203 AppCoordinator は線分と円弧の閉じた輪郭をオフセット元にできる", .disabled("閉輪郭判定は Core 結合テストへ移管"))
@MainActor
func uc203_app_state_offset_tool_detects_line_arc_closed_contour() {
  let bottom = lineEntity(
    id: "entity:bottom",
    start: .init(xMM: -5.0, yMM: 0.0),
    end: .init(xMM: 5.0, yMM: 0.0)
  )
  let arc = arcEntity(
    id: "entity:arc",
    center: .zero,
    radiusMM: 5.0,
    startAngleRad: 0.0,
    sweepAngleRad: .pi
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [bottom, arc]))
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .offset
  let target = CanvasSelectionTarget(
    entityID: bottom.id,
    entityLabel: bottom.label,
    entityKind: bottom.kind,
    controlPoint: nil,
    point: .init(xMM: 0.0, yMM: 1.0)
  )

  appState.actions.constraints.handleConstraintTargetSelection(target)

  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.offsetSourceEntityIDs == [
      "entity:bottom", "entity:arc",
    ])
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.offsetDirection == "inward")
}

@Test("UC203 AppCoordinator は円弧境界に近い閉じた輪郭クリックも内側として扱う", .disabled("内外判定は Core 結合テストへ移管"))
@MainActor
func uc203_app_state_offset_tool_classifies_clicks_near_arc_boundary() {
  let bottom = lineEntity(
    id: "entity:bottom",
    start: .init(xMM: -5.0, yMM: 0.0),
    end: .init(xMM: 5.0, yMM: 0.0)
  )
  let arc = arcEntity(
    id: "entity:arc",
    center: .zero,
    radiusMM: 5.0,
    startAngleRad: 0.0,
    sweepAngleRad: .pi
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [bottom, arc]))
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .offset
  let target = CanvasSelectionTarget(
    entityID: bottom.id,
    entityLabel: bottom.label,
    entityKind: bottom.kind,
    controlPoint: nil,
    point: .init(xMM: 4.7, yMM: 1.0)
  )

  appState.actions.constraints.handleConstraintTargetSelection(target)

  #expect(appState.actions.canvas.pendingConstraintValueDraft?.offsetDirection == "inward")
}

@Test("UC203 AppCoordinator は閉じたフィレット解決済み形状をオフセット元にできる", .disabled("派生輪郭解決は Core 結合テストへ移管"))
@MainActor
func uc203_app_state_offset_tool_uses_closed_fillet_derived_element_as_source() {
  let bottom = lineEntity(
    id: "entity:bottom",
    start: .zero,
    end: .init(xMM: 20.0, yMM: 0.0)
  ).withFilletSuppressedStyle()
  let right = lineEntity(
    id: "entity:right",
    start: .init(xMM: 20.0, yMM: 0.0),
    end: .init(xMM: 20.0, yMM: 10.0)
  ).withFilletSuppressedStyle()
  let top = lineEntity(
    id: "entity:top",
    start: .init(xMM: 20.0, yMM: 10.0),
    end: .init(xMM: 0.0, yMM: 10.0)
  ).withFilletSuppressedStyle()
  let left = lineEntity(
    id: "entity:left",
    start: .init(xMM: 0.0, yMM: 10.0),
    end: .zero
  ).withFilletSuppressedStyle()
  let resolvedBottom = lineEntity(
    id: "derived:fillet-a:resolved:0",
    start: .init(xMM: 2.0, yMM: 0.0),
    end: .init(xMM: 18.0, yMM: 0.0)
  )
  let resolvedBottomRight = arcEntity(
    id: "derived:fillet-a:resolved:1",
    center: .init(xMM: 18.0, yMM: 2.0),
    radiusMM: 2.0,
    startAngleRad: -.pi / 2.0,
    sweepAngleRad: .pi / 2.0
  )
  let resolvedRight = lineEntity(
    id: "derived:fillet-a:resolved:2",
    start: .init(xMM: 20.0, yMM: 2.0),
    end: .init(xMM: 20.0, yMM: 8.0)
  )
  let resolvedTopRight = arcEntity(
    id: "derived:fillet-a:resolved:3",
    center: .init(xMM: 18.0, yMM: 8.0),
    radiusMM: 2.0,
    startAngleRad: 0.0,
    sweepAngleRad: .pi / 2.0
  )
  let resolvedTop = lineEntity(
    id: "derived:fillet-a:resolved:4",
    start: .init(xMM: 18.0, yMM: 10.0),
    end: .init(xMM: 2.0, yMM: 10.0)
  )
  let resolvedTopLeft = arcEntity(
    id: "derived:fillet-a:resolved:5",
    center: .init(xMM: 2.0, yMM: 8.0),
    radiusMM: 2.0,
    startAngleRad: .pi / 2.0,
    sweepAngleRad: .pi / 2.0
  )
  let resolvedLeft = lineEntity(
    id: "derived:fillet-a:resolved:6",
    start: .init(xMM: 0.0, yMM: 8.0),
    end: .init(xMM: 0.0, yMM: 2.0)
  )
  let resolvedBottomLeft = arcEntity(
    id: "derived:fillet-a:resolved:7",
    center: .init(xMM: 2.0, yMM: 2.0),
    radiusMM: 2.0,
    startAngleRad: .pi,
    sweepAngleRad: .pi / 2.0
  )
  let fillet = ProjectDerivedElement(
    id: "derived:fillet-a",
    layerID: "layer:cut-line",
    kind: .fillet,
    sourceEntityIDs: ["entity:bottom", "entity:right", "entity:top", "entity:left"],
    distanceMM: nil,
    distanceParameterID: nil,
    radiusMM: 2.0,
    radiusParameterID: nil,
    filletClosed: true
  )
  let state = makeDocumentState(
    entities: [
      bottom,
      right,
      top,
      left,
      resolvedBottom,
      resolvedBottomRight,
      resolvedRight,
      resolvedTopRight,
      resolvedTop,
      resolvedTopLeft,
      resolvedLeft,
      resolvedBottomLeft,
    ],
    derivedElements: [fillet]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: state)
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .offset
  let target = CanvasSelectionTarget(
    entityID: resolvedBottom.id,
    entityLabel: resolvedBottom.label,
    entityKind: resolvedBottom.kind,
    controlPoint: nil,
    point: .init(xMM: 10.0, yMM: 1.0)
  )

  appState.actions.constraints.handleConstraintTargetSelection(target)

  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.selectedOffsetSourceScope == .closedContour
  )
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.offsetSourceEntityIDs == [
      "derived:fillet-a"
    ])
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.offsetDirection == "inward")

  appState.actions.constraints.updatePendingConstraintValueText("1.0")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  let command = store.appliedPayloads.last
  #expect((command?["kind"] as? String) == "addDerivedElement")
  let payload = unwrap(command?["payload"] as? [String: Any])
  let kind = unwrap(payload["kind"] as? [String: Any])
  let offset = unwrap(kind["offsetCurve"] as? [String: Any])
  #expect((offset["sourceEntityIds"] as? [String]) == ["derived:fillet-a"])
  #expect((offset["direction"] as? String) == "inward")
}

@Test("UC204 AppCoordinator はフィレットツールで2本の線分から半径入力後に派生要素を追加する")
@MainActor
func uc204_app_state_fillet_tool_adds_derived_element() {
  let first = lineEntity(
    id: "entity:first",
    start: .zero,
    end: .init(xMM: 10.0, yMM: 0.0)
  )
  let second = lineEntity(
    id: "entity:second",
    start: .zero,
    end: .init(xMM: 0.0, yMM: 10.0)
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [first, second]))
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .fillet

  appState.actions.constraints.handleConstraintTargetSelection(first.entitySelectionTarget)
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "fillet")
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.valueText == "5.00")
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletSourceEntityIDs == ["entity:first"])

  appState.actions.constraints.handleConstraintTargetSelection(second.entitySelectionTarget)
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "fillet")
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletSourceEntityIDs == [
      "entity:first", "entity:second",
    ])

  appState.actions.constraints.updatePendingConstraintValueText("2.5")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  let command = store.appliedPayloads.last
  #expect((command?["kind"] as? String) == "addDerivedElement")
  let payload = unwrap(command?["payload"] as? [String: Any])
  let kind = unwrap(payload["kind"] as? [String: Any])
  let fillet = unwrap(kind["fillet"] as? [String: Any])
  #expect((fillet["sourceEntityIds"] as? [String]) == ["entity:first", "entity:second"])
  #expect((fillet["radius"] as? [String: Double])?["fixedMm"] == 2.5)
}

@Test("UC204 AppCoordinator はフィレットツールで線分と円弧を半径入力へ進める")
@MainActor
func uc204_app_state_fillet_tool_accepts_connected_line_and_arc() {
  let line = lineEntity(
    id: "entity:line",
    start: .zero,
    end: .init(xMM: 10.0, yMM: 0.0)
  )
  let arc = arcEntity(
    id: "entity:arc",
    center: .init(xMM: 20.0, yMM: 0.0),
    radiusMM: 10.0,
    startAngleRad: .pi,
    sweepAngleRad: -.pi / 2.0
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [line, arc]))
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .fillet

  appState.actions.constraints.handleConstraintTargetSelection(line.entitySelectionTarget)
  appState.actions.constraints.handleConstraintTargetSelection(arc.entitySelectionTarget)

  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "fillet")
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletSourceEntityIDs == [line.id, arc.id])
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.filletIsReadyForValueEntry == true)

  appState.actions.constraints.updatePendingConstraintValueText("2.0")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  let command = store.appliedPayloads.last
  let payload = unwrap(command?["payload"] as? [String: Any])
  let kind = unwrap(payload["kind"] as? [String: Any])
  let fillet = unwrap(kind["fillet"] as? [String: Any])
  #expect((fillet["sourceEntityIds"] as? [String]) == [line.id, arc.id])
  #expect((fillet["radius"] as? [String: Double])?["fixedMm"] == 2.0)
}

@Test("UC204 AppCoordinator は複数選択済みの線分をフィレット対象として優先する")
@MainActor
func uc204_app_state_fillet_tool_uses_selected_sources_for_bulk_fillet() {
  let first = lineEntity(
    id: "entity:first",
    start: .zero,
    end: .init(xMM: 10.0, yMM: 0.0)
  )
  let second = lineEntity(
    id: "entity:second",
    start: .init(xMM: 10.0, yMM: 0.0),
    end: .init(xMM: 10.0, yMM: 10.0)
  )
  let third = lineEntity(
    id: "entity:third",
    start: .init(xMM: 10.0, yMM: 10.0),
    end: .init(xMM: 20.0, yMM: 10.0)
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [first, second, third]))
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .fillet
  appState.actions.canvas.selectedEntityIDs = ["entity:first", "entity:second", "entity:third"]
  appState.actions.canvas.selectedEntityID = "entity:first"

  appState.actions.constraints.handleConstraintTargetSelection(second.entitySelectionTarget)

  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "fillet")
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletSourceEntityIDs == [
      "entity:first",
      "entity:second",
      "entity:third",
    ])

  appState.actions.constraints.updatePendingConstraintValueText("2.5")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  let command = store.appliedPayloads.last
  #expect((command?["kind"] as? String) == "addDerivedElement")
  let payload = unwrap(command?["payload"] as? [String: Any])
  let kind = unwrap(payload["kind"] as? [String: Any])
  let fillet = unwrap(kind["fillet"] as? [String: Any])
  #expect(
    (fillet["sourceEntityIds"] as? [String]) == [
      "entity:first",
      "entity:second",
      "entity:third",
    ])
}

@Test("UC204 フィレットツールは事前選択を再クリックなしで単一ドラフトへ引き継ぐ")
@MainActor
func uc204_fillet_tool_activation_uses_preselected_sources() {
  let first = lineEntity(id: "entity:first", start: .zero, end: .init(xMM: 10, yMM: 0))
  let second = lineEntity(
    id: "entity:second", start: .init(xMM: 10, yMM: 0), end: .init(xMM: 10, yMM: 10))
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [first, second]))
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedEntityIDs = [first.id, second.id]
  appState.actions.canvas.selectedEntityID = first.id

  appState.actions.canvas.activateTool(.fillet)

  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "fillet")
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletSourceEntityIDs == [
      first.id, second.id,
    ])
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.filletIsReadyForValueEntry == true)
}

@Test("UC204 フィレットドラフトは半径入力後も参照線追加とEsc取消を維持する")
@MainActor
func uc204_fillet_draft_preserves_value_while_sources_change() {
  let first = lineEntity(id: "entity:first", start: .zero, end: .init(xMM: 10, yMM: 0))
  let second = lineEntity(
    id: "entity:second", start: .init(xMM: 10, yMM: 0), end: .init(xMM: 10, yMM: 10))
  let third = lineEntity(
    id: "entity:third", start: .init(xMM: 10, yMM: 10), end: .init(xMM: 20, yMM: 10))
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [first, second, third]))
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .fillet

  appState.actions.constraints.handleConstraintTargetSelection(first.entitySelectionTarget)
  appState.actions.constraints.handleConstraintTargetSelection(second.entitySelectionTarget)
  appState.actions.constraints.updatePendingConstraintValueText("2.5")
  appState.actions.constraints.handleConstraintTargetSelection(third.entitySelectionTarget)

  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletSourceEntityIDs == [
      first.id, second.id, third.id,
    ])
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.valueText == "2.5")

  appState.actions.canvas.cancelCurrentInteraction()

  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletSourceEntityIDs == [
      first.id, second.id,
    ])
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.valueText == "2.5")
}

@Test("UC289 AppCoordinator はフィレットツール中に矩形4辺をクリックして一括フィレットできる")
@MainActor
func uc289_app_state_fillet_tool_collects_rectangle_after_tool_activation() {
  let bottom = lineEntity(id: "entity:bottom", start: .zero, end: .init(xMM: 20.0, yMM: 0.0))
  let right = lineEntity(
    id: "entity:right", start: .init(xMM: 20.0, yMM: 0.0), end: .init(xMM: 20.0, yMM: 10.0))
  let top = lineEntity(
    id: "entity:top", start: .init(xMM: 20.0, yMM: 10.0), end: .init(xMM: 0.0, yMM: 10.0))
  let left = lineEntity(id: "entity:left", start: .init(xMM: 0.0, yMM: 10.0), end: .zero)
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [bottom, right, top, left]))
  store.preflightDerivedElementHandler = { kind, _, selectedEntityIDs, _ in
    .success(
      DerivedElementPreflightResult(
        kind: kind,
        offsetOptions: [],
        sourceEntityIds: selectedEntityIDs,
        updateDerivedElementId: nil,
        closed: selectedEntityIDs.count == 4
      ))
  }
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .fillet

  appState.actions.constraints.handleConstraintTargetSelection(bottom.entitySelectionTarget)
  appState.actions.constraints.handleConstraintTargetSelection(right.entitySelectionTarget)
  #expect(appState.actions.canvas.pendingConstraintTargets.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "fillet")
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletSourceEntityIDs == [
      "entity:bottom", "entity:right",
    ])

  appState.actions.constraints.handleConstraintTargetSelection(top.entitySelectionTarget)
  #expect(appState.actions.canvas.pendingConstraintTargets.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "fillet")
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletSourceEntityIDs == [
      "entity:bottom", "entity:right", "entity:top",
    ])

  appState.actions.constraints.handleConstraintTargetSelection(left.entitySelectionTarget)
  #expect(appState.actions.canvas.pendingConstraintTargets.isEmpty)
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "fillet")
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletSourceEntityIDs == [
      "entity:bottom",
      "entity:right",
      "entity:top",
      "entity:left",
    ])
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.filletClosed == true)

  appState.actions.constraints.updatePendingConstraintValueText("3.0")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  let command = store.appliedPayloads.last
  let payload = unwrap(command?["payload"] as? [String: Any])
  let kind = unwrap(payload["kind"] as? [String: Any])
  let fillet = unwrap(kind["fillet"] as? [String: Any])
  #expect(
    (fillet["sourceEntityIds"] as? [String]) == [
      "entity:bottom",
      "entity:right",
      "entity:top",
      "entity:left",
    ])
  #expect(fillet["closed"] == nil)
}

@Test("UC289 AppCoordinator はフィレット収集中の Esc で最後の対象だけを戻す")
@MainActor
func uc289_app_state_fillet_tool_escape_removes_last_collected_source() {
  let bottom = lineEntity(id: "entity:bottom", start: .zero, end: .init(xMM: 20.0, yMM: 0.0))
  let right = lineEntity(
    id: "entity:right", start: .init(xMM: 20.0, yMM: 0.0), end: .init(xMM: 20.0, yMM: 10.0))
  let top = lineEntity(
    id: "entity:top", start: .init(xMM: 20.0, yMM: 10.0), end: .init(xMM: 0.0, yMM: 10.0))
  let left = lineEntity(id: "entity:left", start: .init(xMM: 0.0, yMM: 10.0), end: .zero)
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [bottom, right, top, left]))
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .fillet

  appState.actions.constraints.handleConstraintTargetSelection(bottom.entitySelectionTarget)
  appState.actions.constraints.handleConstraintTargetSelection(right.entitySelectionTarget)
  appState.actions.constraints.handleConstraintTargetSelection(top.entitySelectionTarget)
  appState.actions.canvas.cancelCurrentInteraction()

  #expect(appState.actions.canvas.pendingConstraintTargets.isEmpty)
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletSourceEntityIDs == [
      "entity:bottom", "entity:right",
    ])
}

@Test("UC289 AppCoordinator は接続していないフィレット元を半径入力前に拒否する")
@MainActor
func uc289_app_state_fillet_tool_rejects_disconnected_sources_before_radius_entry() {
  let first = lineEntity(id: "entity:first", start: .zero, end: .init(xMM: 10.0, yMM: 0.0))
  let disconnected = lineEntity(
    id: "entity:disconnected", start: .init(xMM: 20.0, yMM: 0.0), end: .init(xMM: 30.0, yMM: 0.0))
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [first, disconnected]))
  store.preflightDerivedElementResult = .failure(
    "fillet source entities must form one connected path")
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .fillet

  appState.actions.constraints.handleConstraintTargetSelection(first.entitySelectionTarget)
  appState.actions.constraints.handleConstraintTargetSelection(disconnected.entitySelectionTarget)

  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletSourceEntityIDs == ["entity:first"])
  #expect(store.appliedPayloads.isEmpty)
}

@Test("UC204 AppCoordinator は既存フィレットに隣接する角の追加を派生要素更新にする", .disabled("フィレット統合は Core 結合テストへ移管"))
@MainActor
func uc204_app_state_fillet_tool_extends_existing_fillet_for_adjacent_corner() {
  let first = lineEntity(
    id: "entity:first",
    start: .zero,
    end: .init(xMM: 10.0, yMM: 0.0)
  )
  let second = lineEntity(
    id: "entity:second",
    start: .init(xMM: 10.0, yMM: 0.0),
    end: .init(xMM: 10.0, yMM: 10.0)
  )
  let third = lineEntity(
    id: "entity:third",
    start: .init(xMM: 10.0, yMM: 10.0),
    end: .init(xMM: 20.0, yMM: 10.0)
  )
  let resolvedSecond = lineEntity(
    id: "derived:fillet-a:resolved:2",
    start: .init(xMM: 10.0, yMM: 2.0),
    end: .init(xMM: 10.0, yMM: 10.0)
  )
  let fillet = ProjectDerivedElement(
    id: "derived:fillet-a",
    layerID: "layer:cut-line",
    kind: .fillet,
    sourceEntityIDs: ["entity:first", "entity:second"],
    distanceMM: nil,
    distanceParameterID: nil,
    radiusMM: 2.0,
    radiusParameterID: nil
  )
  let state = makeDocumentState(
    entities: [first, second, third, resolvedSecond],
    derivedElements: [fillet]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: state)
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .fillet

  appState.actions.constraints.handleConstraintTargetSelection(resolvedSecond.entitySelectionTarget)
  appState.actions.constraints.handleConstraintTargetSelection(third.entitySelectionTarget)

  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "fillet")
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletSourceEntityIDs == [
      "entity:first",
      "entity:second",
      "entity:third",
    ])
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletUpdateDerivedElementID
      == "derived:fillet-a")

  appState.actions.constraints.updatePendingConstraintValueText("2.5")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  let command = store.appliedPayloads.last
  #expect((command?["kind"] as? String) == "updateDerivedElement")
  let payload = unwrap(command?["payload"] as? [String: Any])
  #expect((payload["id"] as? String) == "derived:fillet-a")
  let kind = unwrap(payload["kind"] as? [String: Any])
  let updatedFillet = unwrap(kind["fillet"] as? [String: Any])
  #expect(
    (updatedFillet["sourceEntityIds"] as? [String]) == [
      "entity:first",
      "entity:second",
      "entity:third",
    ])
  #expect((updatedFillet["radius"] as? [String: Double])?["fixedMm"] == 2.5)
}

@Test("UC204 AppCoordinator は既存フィレットを伸ばしても閉じた輪郭扱いにしない", .disabled("フィレット統合は Core 結合テストへ移管"))
@MainActor
func uc204_app_state_extending_existing_fillet_keeps_open_path() {
  let top = lineEntity(
    id: "entity:top",
    start: .init(xMM: 20.0, yMM: 10.0),
    end: .init(xMM: 0.0, yMM: 10.0)
  )
  let left = lineEntity(
    id: "entity:left",
    start: .init(xMM: 0.0, yMM: 10.0),
    end: .zero
  )
  let bottom = lineEntity(
    id: "entity:bottom",
    start: .zero,
    end: .init(xMM: 20.0, yMM: 0.0)
  )
  let right = lineEntity(
    id: "entity:right",
    start: .init(xMM: 20.0, yMM: 0.0),
    end: .init(xMM: 20.0, yMM: 10.0)
  )
  let resolvedBottom = lineEntity(
    id: "derived:fillet-a:resolved:4",
    start: .init(xMM: 2.0, yMM: 0.0),
    end: .init(xMM: 20.0, yMM: 0.0)
  )
  let fillet = ProjectDerivedElement(
    id: "derived:fillet-a",
    layerID: "layer:cut-line",
    kind: .fillet,
    sourceEntityIDs: ["entity:top", "entity:left", "entity:bottom"],
    distanceMM: nil,
    distanceParameterID: nil,
    radiusMM: 2.0,
    radiusParameterID: nil,
    filletClosed: false
  )
  let state = makeDocumentState(
    entities: [top, left, bottom, right, resolvedBottom],
    derivedElements: [fillet]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: state)
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .fillet

  appState.actions.constraints.handleConstraintTargetSelection(resolvedBottom.entitySelectionTarget)
  appState.actions.constraints.handleConstraintTargetSelection(right.entitySelectionTarget)

  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletSourceEntityIDs == [
      "entity:top",
      "entity:left",
      "entity:bottom",
      "entity:right",
    ])
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.filletClosed == false)

  appState.actions.constraints.updatePendingConstraintValueText("2.5")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  let command = store.appliedPayloads.last
  #expect((command?["kind"] as? String) == "updateDerivedElement")
  let payload = unwrap(command?["payload"] as? [String: Any])
  let kind = unwrap(payload["kind"] as? [String: Any])
  let updatedFillet = unwrap(kind["fillet"] as? [String: Any])
  #expect(
    (updatedFillet["sourceEntityIds"] as? [String]) == [
      "entity:top",
      "entity:left",
      "entity:bottom",
      "entity:right",
    ])
  #expect((updatedFillet["closed"] as? Bool) == false)
}

@Test("UC204 AppCoordinator は矩形フィレットを一角ずつ追加した4角目で閉じたフィレットに昇格する", .disabled("閉輪郭統合は Core 結合テストへ移管"))
@MainActor
func uc204_app_state_closes_rectangle_fillet_on_fourth_incremental_corner() {
  let top = lineEntity(
    id: "entity:top",
    start: .init(xMM: 20.0, yMM: 10.0),
    end: .init(xMM: 0.0, yMM: 10.0)
  )
  let left = lineEntity(
    id: "entity:left",
    start: .init(xMM: 0.0, yMM: 10.0),
    end: .zero
  )
  let bottom = lineEntity(
    id: "entity:bottom",
    start: .zero,
    end: .init(xMM: 20.0, yMM: 0.0)
  )
  let right = lineEntity(
    id: "entity:right",
    start: .init(xMM: 20.0, yMM: 0.0),
    end: .init(xMM: 20.0, yMM: 10.0)
  )
  let resolvedRight = lineEntity(
    id: "derived:fillet-a:resolved:6",
    start: .init(xMM: 20.0, yMM: 2.0),
    end: .init(xMM: 20.0, yMM: 10.0)
  )
  let fillet = ProjectDerivedElement(
    id: "derived:fillet-a",
    layerID: "layer:cut-line",
    kind: .fillet,
    sourceEntityIDs: ["entity:top", "entity:left", "entity:bottom", "entity:right"],
    distanceMM: nil,
    distanceParameterID: nil,
    radiusMM: 2.0,
    radiusParameterID: nil,
    filletClosed: false
  )
  let state = makeDocumentState(
    entities: [top, left, bottom, right, resolvedRight],
    derivedElements: [fillet]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: state)
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .fillet

  appState.actions.constraints.handleConstraintTargetSelection(resolvedRight.entitySelectionTarget)
  appState.actions.constraints.handleConstraintTargetSelection(top.entitySelectionTarget)

  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletSourceEntityIDs == [
      "entity:top",
      "entity:left",
      "entity:bottom",
      "entity:right",
    ])
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.filletClosed == true)

  appState.actions.constraints.updatePendingConstraintValueText("2.5")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  let command = store.appliedPayloads.last
  #expect((command?["kind"] as? String) == "updateDerivedElement")
  let payload = unwrap(command?["payload"] as? [String: Any])
  let kind = unwrap(payload["kind"] as? [String: Any])
  let updatedFillet = unwrap(kind["fillet"] as? [String: Any])
  #expect(
    (updatedFillet["sourceEntityIds"] as? [String]) == [
      "entity:top",
      "entity:left",
      "entity:bottom",
      "entity:right",
    ])
  #expect(updatedFillet["closed"] == nil)
}

@Test("UC204 AppCoordinator はフィレット円弧の半径操作を派生要素更新にする")
@MainActor
func uc204_app_state_edits_fillet_radius_from_resolved_arc() {
  let resolvedArc = arcEntity(
    id: "derived:fillet-a:resolved:1",
    center: .init(xMM: 8.0, yMM: 2.0),
    radiusMM: 2.0,
    startAngleRad: -.pi / 2.0,
    sweepAngleRad: .pi / 2.0
  )
  let fillet = ProjectDerivedElement(
    id: "derived:fillet-a",
    layerID: "layer:cut-line",
    kind: .fillet,
    sourceEntityIDs: ["entity:first", "entity:second"],
    distanceMM: nil,
    distanceParameterID: nil,
    radiusMM: 2.0,
    radiusParameterID: nil,
    filletClosed: false
  )
  let state = makeDocumentState(entities: [resolvedArc], derivedElements: [fillet])
  let store = StubDocumentSessionAdapter(createNewDocumentState: state)
  let appState = AppCoordinator(documentAdapter: store)
  appState.actions.canvas.selectedTool = .radius

  appState.actions.constraints.handleConstraintTargetSelection(resolvedArc.entitySelectionTarget)

  #expect(appState.actions.canvas.pendingConstraintValueDraft?.kind == "fillet")
  #expect(
    appState.actions.canvas.pendingConstraintValueDraft?.filletUpdateDerivedElementID
      == "derived:fillet-a")
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.valueText == "2.00")

  appState.actions.constraints.updatePendingConstraintValueText("3.5")
  appState.actions.constraints.commitPendingConstraintValueEntry()

  let command = store.appliedPayloads.last
  #expect((command?["kind"] as? String) == "setDerivedRadius")
  let payload = unwrap(command?["payload"] as? [String: Any])
  #expect((payload["derivedElementId"] as? String) == "derived:fillet-a")
  #expect((payload["value"] as? [String: Double])?["fixedMm"] == 3.5)
}

@Test("UC204 AppCoordinator はフィレット円弧の半径ハンドルドラッグを派生要素更新にする")
@MainActor
func uc204_app_state_dragging_fillet_arc_radius_updates_derived_element() {
  let resolvedArc = arcEntity(
    id: "derived:fillet-a:resolved:1",
    center: .zero,
    radiusMM: 2.0,
    startAngleRad: 0.0,
    sweepAngleRad: .pi / 2.0
  )
  let fillet = ProjectDerivedElement(
    id: "derived:fillet-a",
    layerID: "layer:cut-line",
    kind: .fillet,
    sourceEntityIDs: ["entity:first", "entity:second"],
    distanceMM: nil,
    distanceParameterID: nil,
    radiusMM: 2.0,
    radiusParameterID: nil,
    filletClosed: false
  )
  let state = makeDocumentState(entities: [resolvedArc], derivedElements: [fillet])
  let store = StubDocumentSessionAdapter(createNewDocumentState: state)
  let appState = AppCoordinator(documentAdapter: store)
  let target = CanvasSelectionTarget(
    entityID: resolvedArc.id,
    entityLabel: resolvedArc.label,
    entityKind: resolvedArc.kind,
    controlPoint: .radius,
    point: .init(xMM: 2.0, yMM: 0.0)
  )

  appState.actions.document.moveControlPoint(target, to: .init(xMM: 4.0, yMM: 0.0))

  let command = store.appliedPayloads.last
  #expect((command?["kind"] as? String) == "setDerivedRadiusFromPoint")
  let payload = unwrap(command?["payload"] as? [String: Any])
  #expect((payload["derivedElementId"] as? String) == "derived:fillet-a")
  #expect((payload["resolvedIndex"] as? Double) == 1)
  #expect((payload["position"] as? [String: Double])?["xMm"] == 4.0)
}

@Test("UC204 AppCoordinator はフィレット元線分の移動展開を Core へ委譲する")
@MainActor
func uc204_app_state_moves_fillet_sources_together() {
  let first = lineEntity(
    id: "entity:first",
    start: .zero,
    end: .init(xMM: 10.0, yMM: 0.0)
  ).withFilletSuppressedStyle()
  let second = lineEntity(
    id: "entity:second",
    start: .zero,
    end: .init(xMM: 0.0, yMM: 10.0)
  ).withFilletSuppressedStyle()
  let fillet = ProjectDerivedElement(
    id: "derived:fillet-a",
    layerID: "layer:cut-line",
    kind: .fillet,
    sourceEntityIDs: ["entity:first", "entity:second"],
    distanceMM: nil,
    distanceParameterID: nil,
    radiusMM: 2.0,
    radiusParameterID: nil
  )
  let state = makeDocumentState(
    entities: [first, second],
    derivedElements: [fillet]
  )
  let movedState = makeDocumentState(
    entities: [
      first.translatedBy(dxMM: 5.0, dyMM: 7.0),
      second.translatedBy(dxMM: 5.0, dyMM: 7.0),
    ],
    derivedElements: [fillet]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: state)
  store.applyCommandState = movedState
  let appState = AppCoordinator(documentAdapter: store)

  appState.actions.document.moveEntity("entity:first", delta: ModelPoint(xMM: 5.0, yMM: 7.0))

  let command = unwrap(store.appliedPayloads.first)
  #expect((command["kind"] as? String) == "moveEntities")
  let payload = unwrap(command["payload"] as? [String: Any])
  #expect(payload["entityIds"] as? [String] == ["entity:first"])
  #expect((payload["allowSingleLineStretch"] as? Bool) == true)
  #expect(appState.actions.canvas.selectedEntityIDs == ["entity:first"])
}

@Test("UC204 AppCoordinator は複数ソースフィレットの元線分ドラッグを単辺更新にする")
@MainActor
func uc204_app_state_moves_single_source_for_bulk_fillet() {
  let first = lineEntity(
    id: "entity:first",
    start: .zero,
    end: .init(xMM: 10.0, yMM: 0.0)
  ).withFilletSuppressedStyle()
  let second = lineEntity(
    id: "entity:second",
    start: .init(xMM: 10.0, yMM: 0.0),
    end: .init(xMM: 10.0, yMM: 10.0)
  ).withFilletSuppressedStyle()
  let third = lineEntity(
    id: "entity:third",
    start: .init(xMM: 10.0, yMM: 10.0),
    end: .init(xMM: 0.0, yMM: 10.0)
  ).withFilletSuppressedStyle()
  let fillet = ProjectDerivedElement(
    id: "derived:fillet-a",
    layerID: "layer:cut-line",
    kind: .fillet,
    sourceEntityIDs: ["entity:first", "entity:second", "entity:third"],
    distanceMM: nil,
    distanceParameterID: nil,
    radiusMM: 2.0,
    radiusParameterID: nil
  )
  let movedSecond = second.translatedBy(dxMM: 5.0, dyMM: 0.0)
  let state = makeDocumentState(
    entities: [first, second, third],
    derivedElements: [fillet]
  )
  let movedState = makeDocumentState(
    entities: [first, movedSecond, third],
    derivedElements: [fillet]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: state)
  store.applyCommandState = movedState
  let appState = AppCoordinator(documentAdapter: store)

  appState.actions.document.moveEntity("entity:second", delta: ModelPoint(xMM: 5.0, yMM: 0.0))

  let command = unwrap(store.appliedPayloads.first)
  #expect((command["kind"] as? String) == "moveEntities")
  let payload = unwrap(command["payload"] as? [String: Any])
  #expect(payload["entityIds"] as? [String] == ["entity:second"])
  #expect((payload["allowSingleLineStretch"] as? Bool) == true)
  #expect(appState.actions.canvas.selectedEntityIDs == ["entity:second"])
}

@Test("AppCoordinator は自由テキストを追加・更新・削除できる")
@MainActor
func app_state_adds_updates_and_deletes_free_text() {
  let initialState = makeDocumentState(name: "Free Text")
  let addedText = ProjectFreeText(
    id: "free-text:fixed-id",
    content: "注記",
    positionMM: ModelPoint(xMM: 12.0, yMM: -8.0),
    fontSizeMM: 4.0
  )
  let addedState = makeDocumentState(name: "Free Text", freeTexts: [addedText])
  let updatedText =
    addedText
    .withContent("Skive edge")
    .withPosition(ModelPoint(xMM: 18.0, yMM: -4.0))
    .withFontSize(5.0)
  let updatedState = makeDocumentState(name: "Free Text", freeTexts: [updatedText])
  let deletedState = makeDocumentState(name: "Free Text", freeTexts: [])
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(LeatherCoreVersionInfo(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "fixed-id" })
  )

  store.applyCommandState = addedState
  appState.actions.canvas.addFreeText(at: ModelPoint(xMM: 12.0, yMM: -8.0))

  #expect(appState.actions.document.freeTexts == [addedText])
  #expect(appState.actions.canvas.selectedFreeTextID == "free-text:fixed-id")
  #expect(appState.actions.canvas.freeTextInlineEditRequestID == "free-text:fixed-id")
  #expect((store.appliedPayloads.last?["kind"] as? String) == "addFreeText")

  appState.actions.canvas.selectFreeText("free-text:fixed-id")
  #expect(appState.actions.canvas.selectedFreeTextID == "free-text:fixed-id")
  #expect(appState.actions.canvas.freeTextInlineEditRequestID == nil)
  #expect(appState.actions.canvas.canCancelCurrentInteraction)

  appState.actions.canvas.cancelCurrentInteraction()
  #expect(appState.actions.canvas.selectedFreeTextID == nil)
  #expect(appState.actions.canvas.freeTextInlineEditRequestID == nil)

  appState.actions.canvas.freeTextInlineEditRequestID = "free-text:fixed-id"
  appState.actions.canvas.selectedFreeTextID = "free-text:fixed-id"
  store.applyCommandState = updatedState
  #expect(appState.actions.canvas.updateFreeText(updatedText))

  #expect(appState.actions.document.freeTexts == [updatedText])
  #expect(appState.actions.canvas.freeTextInlineEditRequestID == "free-text:fixed-id")
  #expect((store.appliedPayloads.last?["kind"] as? String) == "updateFreeText")

  store.applyCommandState = deletedState
  appState.actions.canvas.deleteSelectedFreeText()

  #expect(appState.actions.document.freeTexts.isEmpty)
  #expect(appState.actions.canvas.selectedFreeTextID == nil)
  #expect(appState.actions.canvas.freeTextInlineEditRequestID == nil)
  #expect((store.appliedPayloads.last?["kind"] as? String) == "deleteFreeText")
}

@Test("AppCoordinator は丸穴を配置し、種類と直径を編集できる")
@MainActor
func app_state_round_hole_actions_add_update_kind_and_diameter() {
  let style = ProjectSharedStyle(
    id: "style:stitch-line",
    name: "縫い線",
    colorHex: "#2563EB",
    strokeWidthMM: 0.18,
    linePattern: .dashed
  )
  let initialState = makeDocumentState(name: "Round Hole", sharedStyles: [style])
  let placedEntity = CanvasEntity(
    id: "entity:round-hole-fixed-id",
    label: "Round Hole",
    kind: .circle,
    layerID: "layer:cut-line",
    styleID: style.id,
    geometry: .circle(center: ModelPoint(xMM: 10.0, yMM: 15.0), radiusMM: 3.0)
  )
  let placedHole = ProjectRoundHole(
    id: "round-hole:fixed-id",
    entityID: placedEntity.id,
    kind: .rivet
  )
  let placedState = makeDocumentState(
    name: "Round Hole",
    sharedStyles: [style],
    entities: [placedEntity],
    roundHoles: [placedHole]
  )
  let kindUpdatedState = makeDocumentState(
    name: "Round Hole",
    sharedStyles: [style],
    entities: [placedEntity],
    roundHoles: [placedHole.withKind(.decorative)]
  )
  let diameterUpdatedEntity = placedEntity.withGeometry(
    .circle(center: ModelPoint(xMM: 10.0, yMM: 15.0), radiusMM: 4.0)
  )
  let diameterUpdatedState = makeDocumentState(
    name: "Round Hole",
    sharedStyles: [style],
    entities: [diameterUpdatedEntity],
    roundHoles: [placedHole.withKind(.decorative)]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandStates = [placedState, kindUpdatedState, diameterUpdatedState]
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "fixed-id" })
  )
  appState.actions.document.setActivePatternLineStyle(style.id)
  appState.actions.document.setActiveRoundHoleKind(.rivet)
  #expect(appState.actions.document.setActiveRoundHoleDiameter(6.0))

  appState.actions.canvas.selectedTool = .roundHole
  appState.actions.canvas.handleCanvasPlacement(ModelPoint(xMM: 10.0, yMM: 15.0))

  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "createRoundHole")
  let placementPayload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((placementPayload["styleId"] as? String) == style.id)
  #expect((placementPayload["roundHoleKind"] as? String) == "rivet")
  #expect(appState.actions.canvas.selectedEntityID == placedEntity.id)
  #expect(appState.actions.canvas.selectedRoundHole == placedHole)

  #expect(appState.actions.document.setSelectedRoundHoleKind(.decorative))
  #expect(store.appliedPayloads.count == 2)
  #expect((store.appliedPayloads[1]["kind"] as? String) == "setRoundHoleKind")
  let kindPayload = unwrap(store.appliedPayloads[1]["payload"] as? [String: Any])
  #expect((kindPayload["kind"] as? String) == "decorative")
  #expect(appState.actions.canvas.selectedRoundHole?.kind == .decorative)

  #expect(appState.actions.document.setSelectedRoundHoleDiameter(8.0))
  #expect(store.appliedPayloads.count == 3)
  #expect((store.appliedPayloads[2]["kind"] as? String) == "setRoundHoleDiameter")
  let diameterPayload = unwrap(store.appliedPayloads[2]["payload"] as? [String: Any])
  #expect((diameterPayload["roundHoleId"] as? String) == placedHole.id)
  #expect((diameterPayload["diameterMm"] as? Double) == 8.0)
  #expect(appState.actions.canvas.selectedRoundHole?.kind == .decorative)
}

@Test(
  "AppCoordinator は丸穴の不正な直径では境界へ送らない",
  arguments: [0.0, -2.0, Double.infinity]
)
@MainActor
func app_state_round_hole_rejects_invalid_diameter(diameterMM: Double) {
  let initialState = makeDocumentState(name: "Round Hole Invalid")
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "fixed-id" })
  )

  #expect(appState.actions.document.setActiveRoundHoleDiameter(6.0))
  #expect(!appState.actions.document.setActiveRoundHoleDiameter(diameterMM))
  appState.actions.canvas.selectedTool = .roundHole
  appState.actions.canvas.handleCanvasPlacement(ModelPoint(xMM: 0.0, yMM: 0.0))

  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.document.statusMessage == "丸穴の直径には正の値を入力してください")
}

@Test(
  "AppCoordinator は図形種別ごとに縫い始め点を配置する",
  arguments: ["line", "arc", "derived"]
)
@MainActor
func app_state_places_stitch_start_point_on_stitch_line(targetKind: String) {
  let style = ProjectSharedStyle(
    id: "style:stitch-line",
    name: "縫い線",
    colorHex: "#2563EB",
    strokeWidthMM: 0.18,
    linePattern: .dashed
  )
  let entity: CanvasEntity
  let placementPoint: ModelPoint
  let expectedTargetID: String
  switch targetKind {
  case "line":
    entity = CanvasEntity(
      id: "entity:line",
      label: "Line",
      kind: .lineSegment,
      layerID: "layer:cut-line",
      styleID: style.id,
      geometry: .line(start: .zero, end: ModelPoint(xMM: 100.0, yMM: 0.0), centerLine: false)
    )
    placementPoint = ModelPoint(xMM: 40.0, yMM: 0.0)
    expectedTargetID = entity.id
  case "arc":
    entity = CanvasEntity(
      id: "entity:arc",
      label: "Arc",
      kind: .arc,
      layerID: "layer:cut-line",
      styleID: style.id,
      geometry: .arc(center: .zero, radiusMM: 10.0, startAngleRad: 0.0, sweepAngleRad: .pi)
    )
    placementPoint = ModelPoint(xMM: 0.0, yMM: 10.0)
    expectedTargetID = entity.id
  default:
    entity = CanvasEntity(
      id: "derived:offset:resolved:1",
      label: "Offset",
      kind: .lineSegment,
      layerID: "layer:cut-line",
      styleID: style.id,
      geometry: .line(
        start: ModelPoint(xMM: 0.0, yMM: 10.0), end: ModelPoint(xMM: 100.0, yMM: 10.0),
        centerLine: false)
    )
    placementPoint = ModelPoint(xMM: 50.0, yMM: 10.0)
    expectedTargetID = "derived:offset"
  }
  let placed = ProjectStitchStartPoint(
    id: "stitch-start:fixed-id",
    targetID: expectedTargetID,
    resolvedIndex: targetKind == "derived" ? 1 : nil,
    positionRatio: targetKind == "line" ? 0.4 : 0.5
  )
  let initialState = makeDocumentState(
    name: "Stitch Start", sharedStyles: [style], entities: [entity])
  let placedState = makeDocumentState(
    name: "Stitch Start",
    sharedStyles: [style],
    entities: [entity],
    stitchStartPoints: [placed]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = placedState
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "fixed-id" })
  )

  appState.actions.canvas.selectedTool = .stitchStartPoint
  appState.actions.canvas.handleCanvasPlacement(placementPoint)

  #expect(store.appliedPayloads.count == 1)
  #expect((store.appliedPayloads[0]["kind"] as? String) == "placeStitchStartPoint")
  let payload = unwrap(store.appliedPayloads[0]["payload"] as? [String: Any])
  #expect((payload["id"] as? String) == "stitch-start:fixed-id")
  #expect((payload["candidateTargetIds"] as? [String]) == [])
  let position = unwrap(payload["position"] as? [String: Double])
  #expect(position["xMm"] == placementPoint.xMM)
  #expect(position["yMm"] == placementPoint.yMM)
  #expect(appState.actions.canvas.selectedStitchStartPointID == "stitch-start:fixed-id")
}

@Test("AppCoordinator は縫い始め点の意味判定を Core へ委譲する")
@MainActor
func app_state_rejects_stitch_start_point_on_non_stitch_geometry() {
  let line = CanvasEntity(
    id: "entity:line",
    label: "Line",
    kind: .lineSegment,
    layerID: "layer:cut-line",
    styleID: "style:cut-line",
    geometry: .line(start: .zero, end: ModelPoint(xMM: 100.0, yMM: 0.0), centerLine: false)
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [line]))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "fixed-id" })
  )

  appState.actions.canvas.selectedTool = .stitchStartPoint
  appState.actions.canvas.handleCanvasPlacement(ModelPoint(xMM: 50.0, yMM: 0.0))

  #expect((store.appliedPayloads.first?["kind"] as? String) == "placeStitchStartPoint")
  let payload = unwrap(store.appliedPayloads.first?["payload"] as? [String: Any])
  #expect((payload["candidateTargetIds"] as? [String]) == [])
}

@Test("UC1 破棄後の新規作成失敗では元の recovery snapshot を保持する")
@MainActor
func uc1_discarded_replacement_keeps_recovery_when_creation_fails() {
  let originalState = makeDocumentState(
    name: "Dirty original",
    entities: [pointEntity(id: "entity:original", point: .zero)]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: originalState)
  let recoveryConfiguration = DocumentRecoveryConfiguration(
    baseDirectoryURL: uniqueTempURL("discard-recovery"),
    saveDelay: 0,
    maxDirtyDelay: 0,
    retentionInterval: 30 * 24 * 60 * 60,
    maxDocuments: 10
  )
  let recoveryAdapter = DocumentRecoveryAdapter(configuration: recoveryConfiguration)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    documentRecoveryConfiguration: recoveryConfiguration,
    documentRecoveryAdapter: recoveryAdapter
  )
  store.isDocumentDirty = true
  #expect(appState.actions.document.requestWindowClose() == false)
  #expect(recoveryAdapter.loadCandidates().count == 1)
  appState.actions.document.cancelDocumentSaveConfirmation()

  store.createNewDocumentFailure = "create failed"
  appState.actions.document.createNewProject()
  appState.actions.document.discardDocumentChangesAndContinue()

  #expect(appState.actions.document.documentName == "Dirty original")
  #expect(store.isDocumentDirty)
  #expect(recoveryAdapter.loadCandidates().count == 1)
}

@Test("UC1 破棄後の新規作成成功では元の recovery snapshot を削除する")
@MainActor
func uc1_discarded_replacement_removes_recovery_when_creation_succeeds() {
  let originalState = makeDocumentState(
    name: "Dirty original",
    entities: [pointEntity(id: "entity:original", point: .zero)]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: originalState)
  let recoveryConfiguration = DocumentRecoveryConfiguration(
    baseDirectoryURL: uniqueTempURL("discard-success-recovery"),
    saveDelay: 0,
    maxDirtyDelay: 0,
    retentionInterval: 30 * 24 * 60 * 60,
    maxDocuments: 10
  )
  let recoveryAdapter = DocumentRecoveryAdapter(configuration: recoveryConfiguration)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    documentRecoveryConfiguration: recoveryConfiguration,
    documentRecoveryAdapter: recoveryAdapter
  )
  store.createNewDocumentState = makeDocumentState(name: AppStrings.tr("app.document.untitled"))
  store.isDocumentDirty = true
  #expect(appState.actions.document.requestWindowClose() == false)
  #expect(recoveryAdapter.loadCandidates().count == 1)
  appState.actions.document.cancelDocumentSaveConfirmation()

  appState.actions.document.createNewProject()
  appState.actions.document.discardDocumentChangesAndContinue()

  #expect(appState.actions.document.documentName == AppStrings.tr("app.document.untitled"))
  #expect(!store.isDocumentDirty)
  #expect(recoveryAdapter.loadCandidates().isEmpty)
}

@Test("UC1 破棄後に開く操作が失敗しても元の recovery snapshot を保持する")
@MainActor
func uc1_discarded_replacement_keeps_recovery_when_opening_fails() {
  let originalState = makeDocumentState(
    name: "Dirty original",
    entities: [pointEntity(id: "entity:original", point: .zero)]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: originalState)
  let recoveryConfiguration = DocumentRecoveryConfiguration(
    baseDirectoryURL: uniqueTempURL("discard-open-recovery"),
    saveDelay: 0,
    maxDirtyDelay: 0,
    retentionInterval: 30 * 24 * 60 * 60,
    maxDocuments: 10
  )
  let recoveryAdapter = DocumentRecoveryAdapter(configuration: recoveryConfiguration)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) },
    documentRecoveryConfiguration: recoveryConfiguration,
    documentRecoveryAdapter: recoveryAdapter
  )
  store.isDocumentDirty = true
  #expect(appState.actions.document.requestWindowClose() == false)
  #expect(recoveryAdapter.loadCandidates().count == 1)
  appState.actions.document.cancelDocumentSaveConfirmation()

  store.openDocumentFailure = "open failed"
  appState.actions.document.openProject(at: uniqueTempURL("replacement-failed.kawa"))
  appState.actions.document.discardDocumentChangesAndContinue()

  #expect(appState.actions.document.documentName == "Dirty original")
  #expect(store.isDocumentDirty)
  #expect(recoveryAdapter.loadCandidates().count == 1)

}

final class StubDocumentSessionAdapter: DocumentSessionAdapting {
  var hasDocument: Bool = false
  var canUndo: Bool = false
  var canRedo: Bool = false
  var isDocumentDirty: Bool = false
  var documentURL: URL?
  var lastAppliedState: LeatherDocumentState?

  var createNewDocumentState: LeatherDocumentState
  var openDocumentState: LeatherDocumentState
  var recoveredDocumentState: LeatherDocumentState?
  var loadStateValue: LeatherDocumentState
  var saveDocumentResult: LeatherCoreResult<Void> = .success(())
  var writeSnapshotResult: LeatherCoreResult<Void> = .success(())
  var renderPDFResult: OutputResult<Data> = .success(Data("%PDF-1.4\n".utf8))
  var renderPrintResult: OutputResult<OutputPrintRenderData> = .success(samplePrintRenderData())
  var buildOutputDocumentModelResult: OutputResult<OutputBuildResult>?
  var outputBuildResult: OutputBuildResult = sampleOutputBuildResult()
  var previewCommandState: LeatherDocumentState
  var previewCommandFailure: String?
  var preflightConstraintResult: LeatherCoreResult<ConstraintPreflightResult>?
  var preflightDerivedElementResult: LeatherCoreResult<DerivedElementPreflightResult>?
  var preflightDerivedElementHandler:
    (
      (DerivedElementPreflightKind, String?, [String], ModelPoint?) -> LeatherCoreResult<
        DerivedElementPreflightResult
      >
    )?
  var selectionExportResult: LeatherCoreResult<SelectionClipboardExport>?
  var layerDeletionImpactResult: LeatherCoreResult<LayerDeletionImpact>?
  var applyCommandState: LeatherDocumentState
  var applyCommandStates: [LeatherDocumentState] = []
  var applyCommandFailure: String?
  var undoState: LeatherDocumentState
  var redoState: LeatherDocumentState
  var undoFailure: String?
  var redoFailure: String?
  var createNewDocumentFailure: String?
  var openDocumentFailure: String?
  var loadStateFailure: String?

  private(set) var createNewDocumentCalls: [(name: String, viewMode: CanvasViewMode)] = []
  private(set) var openDocumentCalls: [(url: URL, viewMode: CanvasViewMode)] = []
  private(set) var recoverDocumentCalls:
    [(url: URL, suggestedDocumentURL: URL?, viewMode: CanvasViewMode)] = []
  private(set) var loadStateCalls: [CanvasViewMode] = []
  private(set) var saveDocumentCalls: [URL] = []
  private(set) var writeSnapshotCalls: [URL] = []
  private(set) var previewedPayloads: [[String: Any]] = []
  private(set) var preflightConstraintCalls: [(kind: String, targets: [[String: Any]])] = []
  private(set) var appliedPayloads: [[String: Any]] = []
  private(set) var outputBuildOptions: [OutputBuildOptions] = []
  private(set) var renderedOutputModels: [OutputDocumentModel] = []
  private(set) var printedOutputModels: [OutputDocumentModel] = []
  private(set) var undoCalls: [CanvasViewMode] = []
  private(set) var redoCalls: [CanvasViewMode] = []

  init(createNewDocumentState: LeatherDocumentState) {
    self.createNewDocumentState = createNewDocumentState
    self.openDocumentState = createNewDocumentState
    self.loadStateValue = createNewDocumentState
    self.previewCommandState = createNewDocumentState
    self.applyCommandState = createNewDocumentState
    self.undoState = createNewDocumentState
    self.redoState = createNewDocumentState
  }

  func recordAppliedState(_ state: LeatherDocumentState?) {
    lastAppliedState = state
    canUndo = state?.history.canUndo ?? false
    canRedo = state?.history.canRedo ?? false
    if state == nil {
      isDocumentDirty = false
    }
  }

  func createNewDocument(named name: String, viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  > {
    createNewDocumentCalls.append((name, viewMode))
    if let createNewDocumentFailure {
      return .failure(createNewDocumentFailure)
    }
    hasDocument = true
    documentURL = nil
    canUndo = false
    canRedo = false
    lastAppliedState = createNewDocumentState
    isDocumentDirty = false
    return .success(createNewDocumentState)
  }

  func openDocument(at url: URL, viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  > {
    openDocumentCalls.append((url, viewMode))
    if let openDocumentFailure {
      return .failure(openDocumentFailure)
    }
    hasDocument = true
    documentURL = url
    canUndo = false
    canRedo = false
    lastAppliedState = openDocumentState
    isDocumentDirty = false
    return .success(openDocumentState)
  }

  func recoverDocument(
    from recoverySnapshotURL: URL,
    suggestedDocumentURL: URL?,
    viewMode: CanvasViewMode
  ) -> LeatherCoreResult<LeatherDocumentState> {
    recoverDocumentCalls.append((recoverySnapshotURL, suggestedDocumentURL, viewMode))
    if let openDocumentFailure {
      return .failure(openDocumentFailure)
    }
    let state = recoveredDocumentState ?? openDocumentState
    hasDocument = true
    documentURL = suggestedDocumentURL
    canUndo = false
    canRedo = false
    lastAppliedState = state
    isDocumentDirty = true
    return .success(state)
  }

  func loadState(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    loadStateCalls.append(viewMode)
    if let loadStateFailure {
      return .failure(loadStateFailure)
    }
    return .success(loadStateValue)
  }

  func saveDocument(to url: URL) -> LeatherCoreResult<Void> {
    saveDocumentCalls.append(url)
    switch saveDocumentResult {
    case .success:
      documentURL = url
      isDocumentDirty = false
      return .success(())
    case .failure(let message):
      return .failure(message)
    }
  }

  func writeSnapshot(to url: URL) -> LeatherCoreResult<Void> {
    writeSnapshotCalls.append(url)
    switch writeSnapshotResult {
    case .success:
      try? Data(
        "{\"fileFormatVersion\":\"0.1.0\",\"schemaVersion\":\"0.1.0\",\"document\":{\"name\":\"Recovery\"}}\n"
          .utf8
      ).write(to: url)
    case .failure:
      break
    }
    return writeSnapshotResult
  }

  func previewCommand(_ payload: CoreDocumentCommand, viewMode: CanvasViewMode)
    -> LeatherCoreResult<LeatherDocumentState>
  {
    previewedPayloads.append(payload.legacyObject)
    if let previewCommandFailure {
      return .failure(previewCommandFailure)
    }
    return .success(previewCommandState)
  }

  func preflightConstraint(kind: String, targets: [CoreConstraintTarget]) -> LeatherCoreResult<
    ConstraintPreflightResult
  > {
    let targetObjects = targets.map(\.jsonObject)
    preflightConstraintCalls.append((kind, targetObjects))
    if let preflightConstraintResult {
      return preflightConstraintResult
    }
    if let result = defaultPreflightConstraintResult(kind: kind, targets: targetObjects) {
      return .success(result)
    }
    switch kind {
    case "angle":
      return .success(ConstraintPreflightResult(kind: kind, value: .fixedDegrees(90.0)))
    case "tangent":
      return .success(ConstraintPreflightResult(kind: kind, value: nil))
    default:
      return .failure("unsupported preflight kind")
    }
  }

  func layerDeletionImpact(layerID: String) -> LeatherCoreResult<LayerDeletionImpact> {
    if let layerDeletionImpactResult { return layerDeletionImpactResult }
    let state = lastAppliedState ?? loadStateValue
    return .success(
      LayerDeletionImpact(
        layerID: layerID,
        entityCount: state.entities.filter { $0.layerID == layerID }.count,
        derivedElementCount: state.derivedElements.filter { $0.layerID == layerID }.count
      ))
  }

  private func defaultPreflightConstraintResult(
    kind: String,
    targets: [[String: Any]]
  ) -> ConstraintPreflightResult? {
    let decodedTargets = targets.compactMap(decodeConstraintTarget)
    guard decodedTargets.count == targets.count else {
      return nil
    }
    switch kind {
    case "distance":
      guard decodedTargets.count == 2 else { return nil }
      if let first = point(for: decodedTargets[0]),
        let second = point(for: decodedTargets[1])
      {
        return .init(kind: "distance", value: .fixedMm(distance(first, second)))
      }
      guard let pointTarget = decodedTargets.first(where: { point(for: $0) != nil }),
        let point = point(for: pointTarget),
        let lineTarget = decodedTargets.first(where: { line(for: $0) != nil }),
        let line = line(for: lineTarget)
      else {
        return nil
      }
      return .init(kind: "pointLineDistance", value: .fixedMm(pointLineDistance(point, line)))
    case "horizontalDistance":
      guard decodedTargets.count == 2,
        let first = point(for: decodedTargets[0]),
        let second = point(for: decodedTargets[1])
      else {
        return nil
      }
      return .init(kind: kind, value: .fixedMm(abs(second.xMM - first.xMM)))
    case "verticalDistance":
      guard decodedTargets.count == 2,
        let first = point(for: decodedTargets[0]),
        let second = point(for: decodedTargets[1])
      else {
        return nil
      }
      return .init(kind: kind, value: .fixedMm(abs(second.yMM - first.yMM)))
    case "lineLineDistance":
      guard decodedTargets.count == 2,
        let first = line(for: decodedTargets[0]),
        let second = line(for: decodedTargets[1])
      else {
        return nil
      }
      return .init(kind: kind, value: .fixedMm(pointLineDistance(second.start, first)))
    case "segmentLength":
      guard decodedTargets.count == 1,
        let line = line(for: decodedTargets[0])
      else {
        return nil
      }
      return .init(kind: kind, value: .fixedMm(distance(line.start, line.end)))
    case "diameter":
      guard decodedTargets.count == 1,
        let radius = radius(for: decodedTargets[0])
      else {
        return nil
      }
      return .init(kind: kind, value: .fixedMm(radius * 2.0))
    case "radius":
      guard decodedTargets.count == 1,
        let radius = radius(for: decodedTargets[0])
      else {
        return nil
      }
      return .init(kind: kind, value: .fixedMm(radius))
    case "pointOnLine":
      guard decodedTargets.count == 2,
        let pointTarget = decodedTargets.first(where: { point(for: $0) != nil }),
        let lineTarget = decodedTargets.first(where: { line(for: $0) != nil })
      else {
        return nil
      }
      return .init(
        kind: kind,
        value: nil,
        normalizedTargets: [pointTarget, lineTarget]
      )
    default:
      return nil
    }
  }

  private func decodeConstraintTarget(_ payload: [String: Any]) -> CoreConstraintTarget? {
    guard JSONSerialization.isValidJSONObject(payload),
      let data = try? JSONSerialization.data(withJSONObject: payload)
    else {
      return nil
    }
    return try? JSONDecoder().decode(CoreConstraintTarget.self, from: data)
  }

  private func entity(for target: CoreConstraintTarget) -> CanvasEntity? {
    (lastAppliedState ?? createNewDocumentState).entities.first { $0.id == target.entityID }
  }

  private func point(for target: CoreConstraintTarget) -> ModelPoint? {
    guard let entity = entity(for: target) else {
      return nil
    }
    switch (target, entity.geometry) {
    case (.entity, .point(let point)):
      return point
    case (.entity, .circle(let center, _)), (.entity, .arc(let center, _, _, _)):
      return center
    case (.controlPoint(_, .start), .line(let start, _, _)):
      return start
    case (.controlPoint(_, .end), .line(_, let end, _)):
      return end
    case (.controlPoint(_, .center), .circle(let center, _)):
      return center
    case (.controlPoint(_, .center), .arc(let center, _, _, _)):
      return center
    default:
      return nil
    }
  }

  private func line(for target: CoreConstraintTarget) -> (start: ModelPoint, end: ModelPoint)? {
    guard case .entity = target,
      let entity = entity(for: target),
      case .line(let start, let end, _) = entity.geometry
    else {
      return nil
    }
    return (start, end)
  }

  private func radius(for target: CoreConstraintTarget) -> Double? {
    guard case .entity = target,
      let entity = entity(for: target)
    else {
      return nil
    }
    switch entity.geometry {
    case .circle(_, let radius), .arc(_, let radius, _, _):
      return radius
    default:
      return nil
    }
  }

  private func distance(_ first: ModelPoint, _ second: ModelPoint) -> Double {
    hypot(second.xMM - first.xMM, second.yMM - first.yMM)
  }

  private func pointLineDistance(
    _ point: ModelPoint,
    _ line: (start: ModelPoint, end: ModelPoint)
  ) -> Double {
    let dx = line.end.xMM - line.start.xMM
    let dy = line.end.yMM - line.start.yMM
    let length = hypot(dx, dy)
    guard length > 0 else {
      return 0
    }
    let relativeX = point.xMM - line.start.xMM
    let relativeY = point.yMM - line.start.yMM
    return abs(relativeX * (-dy / length) + relativeY * (dx / length))
  }

  func preflightDerivedElement(
    kind: DerivedElementPreflightKind,
    hitEntityID: String?,
    selectedEntityIDs: [String],
    clickPoint: ModelPoint?
  ) -> LeatherCoreResult<DerivedElementPreflightResult> {
    if let preflightDerivedElementHandler {
      return preflightDerivedElementHandler(kind, hitEntityID, selectedEntityIDs, clickPoint)
    }
    if let preflightDerivedElementResult {
      return preflightDerivedElementResult
    }
    switch kind {
    case .offsetCurve:
      guard let source = hitEntityID ?? selectedEntityIDs.first else {
        return .failure("missing source")
      }
      let usesSelectedRange = selectedEntityIDs.count > 1
      let sourceEntityIDs = usesSelectedRange ? selectedEntityIDs : [source]
      return .success(
        DerivedElementPreflightResult(
          kind: kind,
          offsetOptions: [
            .init(
              scope: usesSelectedRange ? "selectedRange" : "singleElement",
              sourceEntityIds: sourceEntityIDs,
              direction: "left"
            )
          ],
          sourceEntityIds: [],
          updateDerivedElementId: nil,
          closed: false
        ))
    case .fillet:
      return .success(
        DerivedElementPreflightResult(
          kind: kind,
          offsetOptions: [],
          sourceEntityIds: selectedEntityIDs,
          updateDerivedElementId: nil,
          closed: false
        ))
    }
  }

  func evaluateMeasurement(annotationID: String) -> LeatherCoreResult<MeasurementEvaluation> {
    .failure("unused measurement evaluation")
  }

  func exportSelection(_ selection: CoreSelectionReference) -> LeatherCoreResult<
    SelectionClipboardExport
  > {
    if let selectionExportResult {
      return selectionExportResult
    }
    return .success(
      SelectionClipboardExport(
        clipboardJson: "{\"selection\":true}",
        rootCount: selection.rootCount,
        anchorPoint: nil,
        bounds: nil
      ))
  }

  func applyCommand(_ payload: CoreDocumentCommand, viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  > {
    appliedPayloads.append(payload.legacyObject)
    if let applyCommandFailure {
      return .failure(applyCommandFailure)
    }
    canUndo = true
    canRedo = false
    isDocumentDirty = true
    let nextState =
      !applyCommandStates.isEmpty ? applyCommandStates.removeFirst() : applyCommandState
    var state = nextState
    let command = payload.legacyObject
    if command["kind"] as? String == "setPrintOrientation",
      let commandPayload = command["payload"] as? [String: Any],
      let rawOrientation = commandPayload["orientation"] as? String,
      let orientation = OutputPrintOrientation(rawValue: rawOrientation)
    {
      state.printOrientation = orientation
      applyCommandState.printOrientation = orientation
      loadStateValue.printOrientation = orientation
    }
    state.mutation = mutation(from: lastAppliedState, to: nextState)
    state.persistence = LeatherPersistenceState(
      isDirty: true, revision: "stub-\(appliedPayloads.count)")
    lastAppliedState = state
    return .success(state)
  }

  private func mutation(
    from previous: LeatherDocumentState?,
    to next: LeatherDocumentState
  ) -> LeatherMutationResult {
    func createdIDs<T>(
      _ previousItems: [T],
      _ nextItems: [T],
      id: (T) -> String
    ) -> [String] {
      let previousIDs = Set(previousItems.map(id))
      return nextItems.map(id).filter { !previousIDs.contains($0) }
    }
    let previous = previous ?? makeDocumentState()
    return LeatherMutationResult(
      created: LeatherMutationIDs(
        partIDs: createdIDs(previous.parts, next.parts, id: \.id),
        entityIDs: createdIDs(previous.entities, next.entities, id: \.id),
        derivedElementIDs: createdIDs(previous.derivedElements, next.derivedElements, id: \.id),
        freeTextIDs: createdIDs(previous.freeTexts, next.freeTexts, id: \.id),
        roundHoleIDs: createdIDs(previous.roundHoles, next.roundHoles, id: \.id),
        stitchStartPointIDs: createdIDs(
          previous.stitchStartPoints, next.stitchStartPoints, id: \.id)
      ),
      updated: LeatherMutationIDs(),
      deleted: LeatherMutationIDs()
    )
  }

  func undo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    undoCalls.append(viewMode)
    if let undoFailure {
      return .failure(undoFailure)
    }
    canUndo = false
    canRedo = true
    lastAppliedState = undoState
    isDocumentDirty = true
    return .success(undoState)
  }

  func redo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    redoCalls.append(viewMode)
    if let redoFailure {
      return .failure(redoFailure)
    }
    canUndo = true
    canRedo = false
    lastAppliedState = redoState
    isDocumentDirty = true
    return .success(redoState)
  }

  func buildOutputDocumentModel(options: OutputBuildOptions) -> OutputResult<OutputBuildResult> {
    outputBuildOptions.append(options)
    return buildOutputDocumentModelResult ?? .success(outputBuildResult)
  }

  func renderPDF(outputDocumentModel: OutputDocumentModel) -> OutputResult<Data> {
    renderedOutputModels.append(outputDocumentModel)
    return renderPDFResult
  }

  func renderPrint(outputDocumentModel: OutputDocumentModel) -> OutputResult<OutputPrintRenderData>
  {
    printedOutputModels.append(outputDocumentModel)
    return renderPrintResult
  }
}

final class StubDesktopEnvironmentAdapter: DesktopEnvironmentAdapting {
  var appVersion = "test"
  var openProjectURL: URL?
  var nextURL: URL?
  var pdfURL: URL?
  private(set) var promptedDocumentNames: [String] = []

  func promptForOpenProjectURL() -> URL? {
    openProjectURL
  }

  func promptForSaveProjectURL(documentName: String) -> URL? {
    promptedDocumentNames.append(documentName)
    return nextURL
  }

  func promptForSavePDFURL(documentName: String) -> URL? {
    pdfURL
  }

  func revealInFinder(_ url: URL) {}
}

final class StubDocumentLifecycleController: DocumentLifecycleControlling {
  private(set) var closeWindowCount = 0
  private(set) var terminationReplies: [Bool] = []

  func continueClosingWindow() {
    closeWindowCount += 1
  }

  func replyToApplicationTermination(_ shouldTerminate: Bool) {
    terminationReplies.append(shouldTerminate)
  }
}

private func patternLineSharedStyles() -> [ProjectSharedStyle] {
  [
    ProjectSharedStyle(
      id: "style:outer-cut-line",
      name: "外形カット線",
      colorHex: "#111827",
      strokeWidthMM: 0.30,
      linePattern: .solid
    ),
    ProjectSharedStyle(
      id: "style:stitch-line",
      name: "縫い線",
      colorHex: "#DC2626",
      strokeWidthMM: 0.20,
      linePattern: .dashed
    ),
    ProjectSharedStyle(
      id: "style:fold-line",
      name: "折り線",
      colorHex: "#2563EB",
      strokeWidthMM: 0.18,
      linePattern: .dotted
    ),
    ProjectSharedStyle(
      id: "style:center-line",
      name: "中心線",
      colorHex: "#7C3AED",
      strokeWidthMM: 0.16,
      linePattern: .construction
    ),
    ProjectSharedStyle(
      id: "style:construction-line",
      name: "補助線",
      colorHex: "#64748B",
      strokeWidthMM: 0.12,
      linePattern: .dotted
    ),
    ProjectSharedStyle(
      id: "style:dimension-line",
      name: "寸法線",
      colorHex: "#059669",
      strokeWidthMM: 0.16,
      linePattern: .solid
    ),
  ]
}

final class StubPrintController: PrintControlling {
  var outputBuildOptions: OutputBuildOptions?
  var directPrintSessionResult: OutputResult<OutputDirectPrintSession>?
  var directPrintSessionResults: [String: OutputResult<OutputDirectPrintSession>] = [:]
  var preparedSessionResult: OutputResult<OutputPreparedDirectPrintSession>?
  var runPrintResult: OutputResult<Void> = .success(())
  var printerNames = ["Test Printer"]

  private(set) var requestedPresentations: [OutputPresentationOptions] = []
  private(set) var requestedPrinterNames: [String?] = []
  private(set) var preparedSessions:
    [(presentation: OutputPresentationOptions, session: OutputDirectPrintSession)] = []
  private(set) var printedRenderData: [OutputPrintRenderData] = []
  private(set) var printedSessions: [OutputDirectPrintSession] = []
  private(set) var printedOrientations: [OutputPrintOrientation] = []
  private(set) var printedDocumentNames: [String] = []

  func availablePrinterNames() -> [String] {
    printerNames
  }

  func makeDirectPrintSession(
    presentation: OutputPresentationOptions,
    printerName: String?
  ) -> OutputResult<OutputDirectPrintSession> {
    requestedPresentations.append(presentation)
    requestedPrinterNames.append(printerName)
    if let printerName, let result = directPrintSessionResults[printerName] {
      return result
    }
    if let directPrintSessionResult {
      return directPrintSessionResult
    }
    return .success(
      OutputDirectPrintSession(
        printInfo: LivePrintController.makePrintInfo(for: presentation.orientation)
      ))
  }

  func prepareDirectPrintSession(
    presentation: OutputPresentationOptions,
    session: OutputDirectPrintSession
  ) -> OutputResult<OutputPreparedDirectPrintSession> {
    preparedSessions.append((presentation, session))
    if let preparedSessionResult {
      return preparedSessionResult
    }
    return .success(
      OutputPreparedDirectPrintSession(
        session: session,
        buildOptions: outputBuildOptions
          ?? OutputBuildOptions(
            orientation: presentation.orientation,
            includeDimensionLabels: presentation.includeDimensionLabels,
            includeScaleGuide: presentation.includeScaleGuide,
            rotationDeg: presentation.rotationDeg,
            printableAreaMm: session.printableAreaMm
          )
      )
    )
  }

  func runDirectPrint(
    renderData: OutputPrintRenderData,
    session: OutputDirectPrintSession,
    documentName: String
  ) -> OutputResult<Void> {
    printedRenderData.append(renderData)
    printedSessions.append(session)
    printedOrientations.append(renderData.orientation)
    printedDocumentNames.append(documentName)
    return runPrintResult
  }
}
