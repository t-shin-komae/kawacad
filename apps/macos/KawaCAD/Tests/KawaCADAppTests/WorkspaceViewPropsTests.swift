import Testing

@testable import KawaCADApp

@Test("Workspace props は表示スナップショットと副作用を AppCoordinator 境界で分離する")
@MainActor
func workspace_props_keep_render_state_and_effects_separate() {
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(name: "Workspace Props")
  )
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedTool = .line
  appState.actions.document.alertMessage = UserAlertMessage(message: "test alert")

  let props = WorkspaceViewPropsFactory(
    actions: appState.actions,
    inspectorPresentation: appState.inspectorPresentation,
    canvasPresentation: appState.canvasPresentation
  )
  let state = props.workspaceViewState
  #expect(state.documentHeaderState.documentName == "Workspace Props")
  #expect(state.documentHeaderState.paperLabel == "A4 Portrait")
  #expect(state.toolbarState.selectedTool == .line)
  #expect(state.alertMessage?.message == "test alert")
  #expect(state.compactDrawer == nil)

  let actions = props.workspaceViewActions
  actions.updateWindowLayoutMode(.compact)
  actions.showCompactDrawer(.tools)
  actions.dismissAlert()

  #expect(appState.actions.workspace.windowLayoutMode == .compact)
  #expect(appState.actions.workspace.compactDrawer == .tools)
  #expect(appState.actions.document.alertMessage == nil)

  // A view receives an immutable render snapshot; a later state read is
  // required to observe effects emitted through the action boundary.
  #expect(state.compactDrawer == nil)
  #expect(
    WorkspaceViewPropsFactory(
      actions: appState.actions,
      inspectorPresentation: appState.inspectorPresentation,
      canvasPresentation: appState.canvasPresentation
    ).workspaceViewState.compactDrawer == .tools
  )

  appState.actions.workspace.setA4ReferenceOrientation(.landscape)
  #expect(
    WorkspaceViewPropsFactory(
      actions: appState.actions,
      inspectorPresentation: appState.inspectorPresentation,
      canvasPresentation: appState.canvasPresentation
    ).workspaceViewState.documentHeaderState.paperLabel == "A4 Landscape"
  )
}
