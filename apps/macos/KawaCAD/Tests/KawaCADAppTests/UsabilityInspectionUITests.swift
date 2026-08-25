import Foundation
import KawaCADOutput
import Testing

@testable import KawaCADApp

// The checks in the expanded usability inspection are intentionally kept in one
// suite.  This makes both remediated findings and the checks that were OK at
// inspection time visible in the regular UI regression run.

@Test("点検 UI UXE-01: 復旧候補を後で確認しても候補と作業画面を維持する")
@MainActor
func inspection_uxe_01_postponing_recovery_keeps_candidate_and_work_ui() {
  let recoveryRoot = uniqueTempURL("inspection-recovery")
  let configuration = DocumentRecoveryConfiguration(
    baseDirectoryURL: recoveryRoot,
    saveDelay: 60,
    maxDirtyDelay: 120,
    retentionInterval: 30 * 24 * 60 * 60,
    maxDocuments: 10
  )
  let recoveryAdapter = DocumentRecoveryAdapter(configuration: configuration)
  _ = recoveryAdapter.commitSnapshot(
    recoveryID: "candidate",
    documentID: "document:recovered",
    displayName: "復旧候補",
    originalDocumentURL: nil,
    contentFingerprint: Data("inspection".utf8),
    versionInfo: .init(fileFormatMajor: 1, schemaMajor: 2),
    appVersion: "test"
  ) { url in
    let snapshot = """
      {
        "fileFormatVersion": "0.1.0",
        "schemaVersion": "0.1.0",
        "document": { "id": "document:recovered", "unit": "mm" }
      }
      """
    do {
      try Data(snapshot.utf8).write(to: url, options: .atomic)
      return .success(())
    } catch {
      return .failure(error.localizedDescription)
    }
  }

  let store = StubDocumentSessionAdapter(createNewDocumentState: makeDocumentState(name: "作業中"))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) },
    documentRecoveryConfiguration: configuration,
    documentRecoveryAdapter: recoveryAdapter
  )

  appState.actions.recovery.handleApplicationLaunch()
  #expect(appState.actions.recovery.recoveryChooser?.candidates.map(\.recoveryID) == ["candidate"])

  appState.actions.recovery.postponeRecoveryChooser()

  #expect(appState.actions.recovery.recoveryChooser == nil)
  #expect(recoveryAdapter.loadCandidates().map(\.recoveryID) == ["candidate"])
  #expect(appState.actions.document.documentName == "無題プロジェクト")
  #expect(store.hasDocument)
}
@Test("点検 UI UXE-02: 新規文書を作成できる")
@MainActor
func inspection_uxe_02_new_document_flow() {
  let emptyState = makeDocumentState(name: "新規文書", entities: [])
  let store = StubDocumentSessionAdapter(createNewDocumentState: emptyState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  #expect(appState.actions.document.documentName == "無題プロジェクト")
  #expect(appState.actions.document.entities.isEmpty)
}

@Test("点検 UI UXE-03: 基本・詳細ツールの各カテゴリを選択できる")
@MainActor
func inspection_uxe_03_basic_and_detailed_tool_palette_reaches_all_categories() {
  let categoryNames = Set(CanvasTool.allCases.map(\.groupName))
  #expect(
    categoryNames
      == Set([
        AppStrings.tr("tool.group.drawing"),
        AppStrings.tr("tool.group.constraint"),
        AppStrings.tr("tool.group.measurement"),
      ]))
  #expect(!CanvasTool.allCases.filter(\.isBasicTool).isEmpty)
  #expect(!CanvasTool.allCases.filter(\.isDetailedTool).isEmpty)

  let store = StubDocumentSessionAdapter(createNewDocumentState: makeDocumentState())
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )
  for tool in [CanvasTool.line, .horizontal, .measureDistance] {
    appState.actions.uiBindings.menu.activateTool(tool)
    #expect(appState.actions.canvas.selectedTool == tool)
    #expect(appState.actions.document.statusMessage == tool.idleMessage)
  }
}

@Test("点検 UI UXE-04: レイヤーの追加・選択・表示・名称変更を確認できる")
@MainActor
func inspection_uxe_04_layer_controls_cover_add_select_visibility_and_rename() {
  let cut = ProjectLayer(
    id: "layer:cut", name: "Cut", kind: .cutLine, visible: true, printable: true,
    colorHex: "#111111")
  let pattern = ProjectLayer(
    id: "layer:pattern", name: "Pattern", kind: .dimension, visible: true, printable: true,
    colorHex: "#222222")
  let hiddenPattern = ProjectLayer(
    id: pattern.id, name: pattern.name, kind: pattern.kind, visible: false, printable: true,
    colorHex: pattern.colorHex)
  let renamedPattern = ProjectLayer(
    id: pattern.id, name: "Stitch", kind: pattern.kind, visible: false, printable: true,
    colorHex: pattern.colorHex)
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(layers: [cut, pattern]))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  appState.actions.document.addLayer()
  appState.actions.uiBindings.toolbar.setActiveLayer(pattern.id)
  store.applyCommandState = makeDocumentState(layers: [cut, hiddenPattern])
  appState.actions.document.setLayerVisibility(pattern, visible: false)
  store.applyCommandState = makeDocumentState(layers: [cut, renamedPattern])
  #expect(appState.actions.document.renameLayer(hiddenPattern, name: "Stitch"))

  #expect(appState.actions.canvas.activeLayerID == pattern.id)
  #expect(appState.actions.document.layers.first(where: { $0.id == pattern.id })?.visible == false)
  #expect(appState.actions.document.layers.first(where: { $0.id == pattern.id })?.name == "Stitch")
  #expect(
    store.appliedPayloads.compactMap { $0["kind"] as? String } == [
      "addLayer", "setLayerVisibility", "renameLayer",
    ])
}

@Test("点検 UI UXE-05: 共有スタイルをインスペクタで選択・編集できる")
@MainActor
func inspection_uxe_05_shared_style_inspector_selection_and_editing() {
  let initialStyle = ProjectSharedStyle(
    id: "style:cut", name: "Cut", colorHex: "#111111", strokeWidthMM: 0.2, linePattern: .solid)
  let updatedStyle = initialStyle.withStyle(
    colorHex: "#ff0000", strokeWidthMM: 0.4, linePattern: .dotted)
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(sharedStyles: [initialStyle]))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  appState.actions.inspector.setInspectorTab(.sharedStyles)
  appState.actions.inspector.inspectorSelectedSharedStyleID = initialStyle.id
  store.applyCommandState = makeDocumentState(sharedStyles: [updatedStyle])
  #expect(appState.actions.document.updateSharedStyle(updatedStyle))
  appState.actions.document.addSharedStyle()

  #expect(appState.actions.inspector.inspectorTab == .sharedStyles)
  #expect(appState.actions.inspector.inspectorSelectedSharedStyleID == initialStyle.id)
  #expect(appState.actions.document.sharedStyles == [updatedStyle])
  #expect(
    store.appliedPayloads.compactMap { $0["kind"] as? String } == [
      "updateSharedStyle", "addSharedStyle",
    ])
}

@Test("点検 UI UXE-06: パラメータ参照を選べ、同名への変更は拒否される")
@MainActor
func inspection_uxe_06_parameter_reference_and_duplicate_name_feedback() {
  let width = ProjectParameter(
    id: "parameter:width", name: "width", valueMM: 20, unit: "millimeter", memo: "", usageCount: 0,
    usedConstraintIDs: [])
  let height = ProjectParameter(
    id: "parameter:height", name: "height", valueMM: 30, unit: "millimeter", memo: "",
    usageCount: 0, usedConstraintIDs: [])
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(parameters: [width, height]))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  appState.actions.canvas.pendingConstraintValueDraft = PendingConstraintValueDraft(
    kind: "distance",
    title: "距離",
    prompt: "値を入力",
    targets: [],
    valueText: "20",
    unit: "mm",
    allowsParameterReference: true,
    entryMode: .parameterReference,
    selectedParameterID: width.id,
    anchorCanvasPoint: nil
  )
  let duplicate = ProjectParameter(
    id: height.id, name: " width ", valueMM: height.valueMM, unit: height.unit, memo: height.memo,
    usageCount: 0, usedConstraintIDs: [])

  #expect(appState.actions.canvas.pendingConstraintValueDraft?.allowsParameterReference == true)
  #expect(appState.actions.canvas.pendingConstraintValueDraft?.selectedParameterID == width.id)
  #expect(!appState.actions.document.updateParameter(duplicate))
  #expect(store.appliedPayloads.isEmpty)
  #expect(appState.actions.document.statusMessage == "パラメータ名は重複できません")
}

@Test("点検 UI UXE-07: 表示補助と A4 縦横トグルをツールバーから切り替えられる")
@MainActor
func inspection_uxe_07_view_aids_and_a4_orientation_toggle() {
  let store = StubDocumentSessionAdapter(createNewDocumentState: makeDocumentState())
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  appState.actions.uiBindings.toolbar.setGridVisible(false)
  appState.actions.uiBindings.toolbar.setA4ReferenceVisible(false)
  appState.actions.uiBindings.toolbar.setA4ReferenceOrientation(.landscape)
  appState.actions.uiBindings.toolbar.setA4ReferenceOrientation(.portrait)

  #expect(!appState.actions.workspace.gridVisible)
  #expect(!appState.actions.workspace.a4ReferenceVisible)
  #expect(appState.actions.workspace.a4ReferenceOrientation == .portrait)
}

@Test("点検 UI UXE-08: 出力プレビューから作図・拘束・計測ツールを選ぶと編集へ戻る")
@MainActor
func inspection_uxe_08_output_preview_returns_to_edit_for_every_tool_family() {
  let store = StubDocumentSessionAdapter(createNewDocumentState: makeDocumentState())
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  for tool in [CanvasTool.line, .horizontal, .measureDistance] {
    appState.actions.canvas.viewMode = .outputPreview
    appState.actions.uiBindings.menu.activateTool(tool)
    #expect(appState.actions.canvas.viewMode == .editDisplay)
    #expect(appState.actions.canvas.selectedTool == tool)
  }
}

@Test("点検 UI UXE-09: 空の文書では PDF 出力設定を開いた時点で 0 ページ警告を出す")
@MainActor
func inspection_uxe_09_empty_document_pdf_request_has_immediate_zero_page_warning() {
  let emptyOutput = OutputDocumentModel(
    paperSize: .a4, orientation: .portrait, scale: .actualSize, pageCount: 0, pages: [])
  let store = StubDocumentSessionAdapter(createNewDocumentState: makeDocumentState(name: "空の文書"))
  store.outputBuildResult = sampleOutputBuildResult(
    model: emptyOutput,
    warnings: [.init(kind: .emptyDocument, message: "出力対象がありません。")]
  )
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  appState.actions.uiBindings.menu.exportPDFPanel()
  let draft = unwrap(appState.actions.output.outputRequestDraft)

  guard case .ready(let prepared) = draft.buildState else {
    Issue.record("PDF request must be prepared before its sheet is presented")
    return
  }
  #expect(prepared.buildResult.outputDocumentModel.pageCount == 0)
  #expect(
    appState.actions.output.outputExecutionDisabledReason(for: draft)?.contains("出力ページがありません")
      == true)
}

@Test("点検 UI UXE-10: A4ガイドの向きで1ページ出力を開き、キャンセルできる")
@MainActor
func inspection_uxe_10_single_page_output_uses_a4_orientation_and_cancel() {
  let store = StubDocumentSessionAdapter(createNewDocumentState: makeDocumentState(name: "レザータグ"))
  store.outputBuildResult = sampleOutputBuildResult(
    model: sampleOutputDocumentModel(orientation: .portrait))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  appState.actions.workspace.setA4ReferenceOrientation(.landscape)
  appState.actions.output.exportPDFPanel()
  let draft = unwrap(appState.actions.output.outputRequestDraft)
  guard case .ready(let prepared) = draft.buildState else {
    Issue.record("single-page output should be ready")
    return
  }
  #expect(prepared.buildResult.outputDocumentModel.pageCount == 1)

  #expect(appState.actions.output.outputRequestDraft?.options.orientation == .landscape)
  #expect(appState.actions.workspace.a4ReferenceOrientation == .landscape)

  appState.actions.output.cancelOutputRequest()
  #expect(appState.actions.output.outputRequestDraft == nil)
}

@Test("点検 UI UXE-11: 保存前にパラメータ・レイヤーの同名を拒否し、保存できる")
@MainActor
func inspection_uxe_11_duplicate_names_are_rejected_before_save() {
  let width = ProjectParameter(
    id: "parameter:width", name: "width", valueMM: 20, unit: "millimeter", memo: "", usageCount: 0,
    usedConstraintIDs: [])
  let height = ProjectParameter(
    id: "parameter:height", name: "height", valueMM: 30, unit: "millimeter", memo: "",
    usageCount: 0, usedConstraintIDs: [])
  let cut = ProjectLayer(
    id: "layer:cut", name: "Cut", kind: .cutLine, visible: true, printable: true,
    colorHex: "#111111")
  let pattern = ProjectLayer(
    id: "layer:pattern", name: "Pattern", kind: .dimension, visible: true, printable: true,
    colorHex: "#222222")
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(layers: [cut, pattern], parameters: [width, height]))
  let saveURL = uniqueTempURL("inspection-save.kawa")
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )
  store.documentURL = saveURL

  #expect(
    !appState.actions.document.updateParameter(
      ProjectParameter(
        id: height.id, name: "width", valueMM: height.valueMM, unit: height.unit, memo: height.memo,
        usageCount: 0, usedConstraintIDs: [])))
  #expect(!appState.actions.document.renameLayer(pattern, name: "Cut"))
  appState.actions.uiBindings.menu.saveProject()

  #expect(store.appliedPayloads.isEmpty)
  #expect(store.saveDocumentCalls == [saveURL])
}

@Test("点検 UI UXE-12: wide・regular・compact と画面幅制約でパネルを到達可能に保つ")
@MainActor
func inspection_uxe_12_responsive_layout_keeps_inspector_reachable() {
  let store = StubDocumentSessionAdapter(createNewDocumentState: makeDocumentState())
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )
  appState.actions.workspace.inspectorPanelVisible = true

  appState.actions.workspace.updateWindowLayoutMode(.wide)
  #expect(appState.actions.workspace.windowLayoutMode == .wide)
  #expect(appState.actions.workspace.inspectorPanelVisible)

  appState.actions.workspace.updateWindowLayoutMode(.regular)
  #expect(appState.actions.workspace.windowLayoutMode == .regular)
  appState.actions.workspace.showCompactDrawer(.inspector)
  appState.actions.workspace.updateWindowLayoutMode(.compact)
  #expect(appState.actions.workspace.windowLayoutMode == .compact)
  #expect(appState.actions.workspace.compactDrawer == nil)
  #expect(WindowLayoutPolicy.constrainedWindowWidth(1_700, visibleScreenWidth: 1_440) == 1_440)
}

@Test("点検 UI UP-01: 新規文書で既定レイヤーとキャンバスへ到達できる")
@MainActor
func inspection_up_01_new_project_and_default_layers() {
  let initial = makeDocumentState(name: "名称未設定")
  let store = StubDocumentSessionAdapter(createNewDocumentState: initial)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  #expect(appState.actions.document.documentName == "無題プロジェクト")
  #expect(appState.actions.document.layers.map(\.name) == ["カット線", "補助線", "寸法"])
  #expect(store.appliedPayloads.isEmpty)
}

@Test("点検 UI UP-02: 線分を作図でき、途中の作図を Esc 相当で取り消せる")
@MainActor
func inspection_up_02_line_drawing_and_escape_cancel() {
  let empty = makeDocumentState(name: "作図", entities: [])
  let line = lineEntity(id: "entity:line", start: .zero, end: .init(xMM: 40, yMM: 0))
  let drawn = makeDocumentState(name: "作図", entities: [line])
  let store = StubDocumentSessionAdapter(createNewDocumentState: empty)
  store.applyCommandState = drawn
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  appState.actions.uiBindings.menu.activateTool(.line)
  appState.actions.uiBindings.canvas.handleCanvasPlacement(.zero, CanvasPlacementModifiers())
  appState.actions.uiBindings.canvas.handleCanvasPlacement(
    .init(xMM: 40, yMM: 0), CanvasPlacementModifiers())
  #expect(appState.actions.document.entities.map(\.id) == [line.id])

  appState.actions.uiBindings.canvas.handleCanvasPlacement(
    .init(xMM: 10, yMM: 10), CanvasPlacementModifiers())
  #expect(appState.actions.canvas.draftStartPoint != nil)
  appState.actions.canvas.cancelCurrentInteraction()
  #expect(appState.actions.canvas.draftStartPoint == nil)
  #expect(appState.actions.document.statusMessage == CanvasTool.line.idleMessage)
}

@Test("点検 UI UP-03: 選択で compact inspector を開き、Esc を段階的に処理する")
@MainActor
func inspection_up_03_selection_and_inspector_escape_progression() {
  let line = lineEntity(id: "entity:line", label: "線分", start: .zero, end: .init(xMM: 40, yMM: 0))
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [line]))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  appState.actions.workspace.inspectorPanelVisible = true
  appState.actions.workspace.updateWindowLayoutMode(.compact)
  appState.actions.canvas.selectEntity(line.id)
  #expect(appState.actions.canvas.selectedEntityID == line.id)
  #expect(appState.actions.workspace.compactDrawer == .inspector)

  appState.actions.canvas.cancelCurrentInteraction()
  #expect(appState.actions.workspace.compactDrawer == nil)
  #expect(appState.actions.canvas.selectedEntityID == line.id)
  appState.actions.canvas.cancelCurrentInteraction()
  #expect(appState.actions.canvas.selectedEntityID == nil)
}

@Test("点検 UI UP-04: パラメータを追加し、名前と値を編集できる")
@MainActor
func inspection_up_04_parameter_add_and_edit() {
  let added = ProjectParameter(
    id: "parameter:width", name: "param_1", valueMM: 0, unit: "millimeter", memo: "", usageCount: 0,
    usedConstraintIDs: [])
  let edited = ProjectParameter(
    id: added.id, name: "width", valueMM: 120, unit: added.unit, memo: "", usageCount: 0,
    usedConstraintIDs: [])
  let store = StubDocumentSessionAdapter(createNewDocumentState: makeDocumentState(parameters: []))
  store.applyCommandStates = [
    makeDocumentState(parameters: [added]),
    makeDocumentState(parameters: [edited]),
  ]
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) },
    commandFactory: DocumentCommandFactory(uuidProvider: { "width" })
  )

  appState.actions.document.addParameter()
  #expect(appState.actions.document.parameters == [added])
  #expect(appState.actions.document.updateParameter(edited))

  #expect(appState.actions.document.parameters == [edited])
  #expect(appState.actions.document.parameters[0].isUnused)
  #expect(
    store.appliedPayloads.compactMap { $0["kind"] as? String } == [
      "addParameter", "updateParameter",
    ])
}

@Test("点検 UI UP-05: Undo / Redo で図形数を往復できる")
@MainActor
func inspection_up_05_undo_redo_restores_entities() {
  let empty = makeDocumentState(name: "履歴", entities: [])
  let line = lineEntity(id: "entity:line", start: .zero, end: .init(xMM: 40, yMM: 0))
  let withLine = makeDocumentState(
    name: "履歴",
    history: LeatherHistoryState(canUndo: true, canRedo: false),
    entities: [line]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: empty)
  store.applyCommandState = withLine
  store.undoState = empty
  store.redoState = withLine
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  appState.actions.canvas.activateTool(.line)
  appState.actions.canvas.handleCanvasPlacement(.zero)
  appState.actions.canvas.handleCanvasPlacement(.init(xMM: 40, yMM: 0))
  #expect(appState.actions.document.entities.map(\.id) == [line.id])

  appState.actions.uiBindings.menu.undo()
  #expect(appState.actions.document.entities.isEmpty)
  appState.actions.uiBindings.menu.redo()
  #expect(appState.actions.document.entities.map(\.id) == [line.id])
}

@Test("点検 UI UP-06: 保存後の再読込で図形とパラメータを復元できる")
@MainActor
func inspection_up_06_save_and_reload_restores_document_contents() {
  let parameter = ProjectParameter(
    id: "parameter:width", name: "width", valueMM: 120, unit: "millimeter", memo: "", usageCount: 0,
    usedConstraintIDs: [])
  let line = lineEntity(id: "entity:line", start: .zero, end: .init(xMM: 40, yMM: 0))
  let document = makeDocumentState(name: "保存点検", parameters: [parameter], entities: [line])
  let store = StubDocumentSessionAdapter(createNewDocumentState: document)
  let saveURL = uniqueTempURL("inspection-round-trip.kawa")
  store.loadStateValue = document
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )
  store.documentURL = saveURL

  appState.actions.uiBindings.menu.saveProject()
  appState.actions.uiBindings.menu.reloadFromDocument()

  #expect(store.saveDocumentCalls == [saveURL])
  #expect(store.loadStateCalls == [.editDisplay])
  #expect(appState.actions.document.entities.map(\.id) == [line.id])
  #expect(appState.actions.document.parameters.map(\.id) == [parameter.id])
}

@Test("点検 UI UP-07: 3レイアウトで出力導線を開き、キャンセルして編集表示へ戻れる")
@MainActor
func inspection_up_07_layouts_and_output_entry_can_be_cancelled() {
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(entities: [
      lineEntity(id: "entity:line", start: .zero, end: .init(xMM: 20, yMM: 0))
    ]))
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )

  for mode in [WindowLayoutMode.compact, .regular, .wide] {
    appState.actions.workspace.updateWindowLayoutMode(mode)
    #expect(appState.actions.workspace.windowLayoutMode == mode)
  }
  appState.actions.uiBindings.menu.exportPDFPanel()
  #expect(appState.actions.output.outputRequestDraft != nil)
  appState.actions.output.cancelOutputRequest()
  #expect(appState.actions.output.outputRequestDraft == nil)

  appState.actions.uiBindings.menu.setViewMode(.outputPreview)
  #expect(appState.actions.canvas.viewMode == .outputPreview)
  appState.actions.uiBindings.menu.setViewMode(.editDisplay)
  #expect(appState.actions.canvas.viewMode == .editDisplay)
}
