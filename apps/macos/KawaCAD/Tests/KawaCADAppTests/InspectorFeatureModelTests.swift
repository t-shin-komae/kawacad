import Testing

@testable import KawaCADApp

@Test("インスペクタのタブは表示順とアクセシビリティ名を維持する")
func inspector_tabs_keep_order_and_accessibility_label() {
  #expect(
    InspectorTab.allCases.map(\.title) == [
      "選択", "レイヤー", "共有スタイル", "パラメータ", "パーツ",
    ])
  #expect(AppStrings.tr("accessibility.inspector_tabs") == "インスペクタ項目")
}

@Test("Inspector feature model は表示スナップショットと操作を AppCoordinator 境界で分離する")
@MainActor
func inspector_feature_model_keeps_presentation_state_and_actions_separate() {
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(name: "Inspector Props")
  )
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  let model = InspectorFeatureModelFactory.make(
    actionHandlers: appState.actions,
    inspectorPresentation: appState.inspectorPresentation,
    canvasPresentation: appState.canvasPresentation
  )

  #expect(model.inspectorTab == .selection)
  #expect(model.layers == appState.actions.document.layers)

  model.setInspectorLayerSearchQuery("outline")
  #expect(appState.actions.inspector.inspectorLayerSearchQuery == "outline")

  model.setInspectorTab(.layers)
  #expect(appState.actions.inspector.inspectorTab == .layers)

  model.revealInspectorSelectionTab()
  #expect(appState.actions.inspector.inspectorTab == .selection)
}
