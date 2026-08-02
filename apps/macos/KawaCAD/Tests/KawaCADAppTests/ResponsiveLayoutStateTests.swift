import Testing

@testable import KawaCADApp

@Test("AppCoordinator は compact drawer を相互排他で扱い、compact 遷移時に閉じる")
@MainActor
func app_state_compact_drawer_state_transitions_are_safe() {
  let state = makeDocumentState(
    name: "Responsive Layout",
    entities: [lineEntity(id: "entity:line-a", start: .zero, end: .init(xMM: 10.0, yMM: 0.0))]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: state)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.workspace.showCompactDrawer(.tools)
  #expect(appState.actions.workspace.compactDrawer == .tools)

  appState.actions.workspace.showCompactDrawer(.inspector)
  #expect(appState.actions.workspace.compactDrawer == .inspector)

  appState.actions.canvas.cancelCurrentInteraction()
  #expect(appState.actions.workspace.compactDrawer == nil)

  appState.actions.workspace.showCompactDrawer(.tools)
  appState.actions.workspace.updateWindowLayoutMode(.compact)
  #expect(appState.actions.workspace.compactDrawer == nil)

  appState.actions.workspace.showCompactDrawer(.tools)
  appState.actions.workspace.updateWindowLayoutMode(.regular)
  appState.actions.workspace.updateWindowLayoutMode(.compact)
  #expect(appState.actions.workspace.compactDrawer == nil)
}
@Test("AppCoordinator は compact で選択が変わると inspector drawer を開く")
@MainActor
func app_state_opens_compact_inspector_for_new_selection() {
  let state = makeDocumentState(
    name: "Responsive Selection",
    entities: [
      lineEntity(
        id: "entity:line-a", label: "Line A", start: .zero, end: .init(xMM: 20.0, yMM: 0.0))
    ]
  )
  let store = StubDocumentSessionAdapter(createNewDocumentState: state)
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.workspace.updateWindowLayoutMode(.compact)
  appState.actions.workspace.inspectorPanelVisible = true
  appState.actions.canvas.selectEntity("entity:line-a")
  #expect(appState.actions.workspace.compactDrawer == .inspector)
}
