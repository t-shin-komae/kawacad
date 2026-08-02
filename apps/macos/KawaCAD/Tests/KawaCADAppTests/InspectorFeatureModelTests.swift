import Testing

@testable import KawaCADApp

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
