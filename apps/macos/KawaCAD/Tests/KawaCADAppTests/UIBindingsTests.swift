import CoreGraphics
import Foundation
import KawaCADOutput
import Testing

@testable import KawaCADApp

@Test("UI統合回帰 UC1 menu callback で新規作成と図形配置ができる")
@MainActor
func ui_bindings_uc1_menu_and_canvas_callbacks_place_entities() {
  let initialState = makeDocumentState(
    name: "Bindings Project",
    entities: [],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = makeDocumentState(
    name: "Bindings Project",
    history: LeatherHistoryState(canUndo: true, canRedo: false),
    entities: [
      pointEntity(id: "entity:placed-point", point: .init(xMM: 12.0, yMM: 34.0))
    ],
    constraintStatus: .underConstrained
  )

  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.uiBindings.menu.createNewProject()
  appState.actions.canvas.selectedTool = .point
  appState.actions.uiBindings.canvas.handleCanvasPlacement(
    .init(xMM: 12.0, yMM: 34.0), CanvasPlacementModifiers())

  #expect(store.createNewDocumentCalls.count >= 1)
  #expect(store.appliedPayloads.last?["kind"] as? String == "createEntityFromGesture")
  #expect(appState.actions.document.canUndo)
  #expect(!appState.actions.document.canRedo)
  #expect(appState.actions.document.entities.map(\.id) == ["entity:placed-point"])
}
@Test("UI統合回帰 UC4 menu callback で Undo/Redo が状態を戻す")
@MainActor
func ui_bindings_uc4_menu_callbacks_restore_history_state() {
  let undoState = makeDocumentState(
    name: "Undo Project",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 10.0, yMM: 0.0))
    ],
    constraintStatus: .underConstrained
  )
  let redoState = makeDocumentState(
    name: "Redo Project",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 20.0, yMM: 0.0))
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: undoState)
  store.undoState = undoState
  store.redoState = redoState
  store.canUndo = true
  store.canRedo = true

  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.pendingConstraintTargets = [
    CanvasSelectionTarget(
      entityID: "entity:line-a",
      entityLabel: "line-a",
      entityKind: .lineSegment,
      controlPoint: nil,
      point: nil
    )
  ]

  appState.actions.uiBindings.menu.undo()
  #expect(store.undoCalls == [.editDisplay])
  #expect(appState.actions.document.documentName == "無題プロジェクト")
  #expect(appState.actions.canvas.pendingConstraintTargets.isEmpty)

  appState.actions.uiBindings.menu.redo()
  #expect(store.redoCalls == [.editDisplay])
  #expect(appState.actions.document.documentName == "無題プロジェクト")
}

@Test("UI統合回帰 UC5 menu callback で保存と再読込ができる")
@MainActor
func ui_bindings_uc5_menu_callbacks_save_and_reload_document() {
  let savedState = makeDocumentState(
    name: "Save Project",
    entities: [
      pointEntity(id: "entity:point-a", point: .zero)
    ],
    constraintStatus: .underConstrained
  )
  let reloadedState = makeDocumentState(
    name: "Reloaded Project",
    entities: [
      pointEntity(id: "entity:point-b", point: .init(xMM: 8.0, yMM: 9.0))
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: savedState)
  store.loadStateValue = reloadedState
  store.hasDocument = true

  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  let saveURL = uniqueTempURL("bindings-save.kawa")
  store.documentURL = saveURL

  appState.actions.uiBindings.menu.saveProject()
  #expect(store.saveDocumentCalls == [saveURL])

  appState.actions.uiBindings.menu.reloadFromDocument()
  #expect(store.loadStateCalls == [.editDisplay])
  #expect(
    appState.actions.document.documentName
      == saveURL.deletingPathExtension().lastPathComponent)
  #expect(appState.actions.document.entities.map(\.id) == ["entity:point-b"])
}

@Test("UI統合回帰 UC6 toolbar callback で表示と選択が更新される")
@MainActor
func ui_bindings_uc6_toolbar_callbacks_update_display_state() {
  let initialState = makeDocumentState(
    name: "Toolbar Project",
    entities: [
      pointEntity(id: "entity:point-a", point: .zero)
    ],
    constraintStatus: .underConstrained
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.uiBindings.toolbar.zoomIn()
  #expect(appState.actions.canvas.canvasZoomScale > 1.0)
  appState.actions.uiBindings.canvas.panCanvas(CGSize(width: 9, height: -6))
  #expect(appState.actions.canvas.canvasPanOffset == CGSize(width: 9, height: -6))
  appState.actions.uiBindings.canvas.setCanvasViewport(
    1.5, CGSize(width: -12, height: 18), "拡大率を変更しました")
  #expect(appState.actions.canvas.canvasZoomScale == 1.5)
  #expect(appState.actions.canvas.canvasPanOffset == CGSize(width: -12, height: 18))

  appState.actions.uiBindings.toolbar.setGridVisible(false)
  appState.actions.uiBindings.toolbar.setA4ReferenceVisible(false)
  appState.actions.uiBindings.toolbar.setA4ReferenceOrientation(.landscape)
  appState.actions.uiBindings.toolbar.setGridSnapEnabled(false)
  appState.actions.uiBindings.toolbar.setPointSnapEnabled(false)
  appState.actions.uiBindings.toolbar.setInspectorPanelVisible(false)
  appState.actions.uiBindings.toolbar.setLayerPanelVisible(false)
  appState.actions.uiBindings.toolbar.setParameterPanelVisible(false)
  appState.actions.uiBindings.toolbar.setBottomWorkbenchVisible(false)

  #expect(!appState.actions.workspace.gridVisible)
  #expect(!appState.actions.workspace.a4ReferenceVisible)
  #expect(appState.actions.workspace.a4ReferenceOrientation == .landscape)
  #expect(!appState.actions.workspace.gridSnapEnabled)
  #expect(!appState.actions.workspace.pointSnapEnabled)
  #expect(!appState.actions.workspace.inspectorPanelVisible)
  #expect(!appState.actions.canvas.layerPanelVisible)
  #expect(!appState.actions.canvas.parameterPanelVisible)
  #expect(!appState.actions.workspace.bottomWorkbenchVisible)

  appState.actions.uiBindings.toolbar.setActiveLayer("layer:construction")
  #expect(appState.actions.canvas.activeLayerID == "layer:construction")
}
