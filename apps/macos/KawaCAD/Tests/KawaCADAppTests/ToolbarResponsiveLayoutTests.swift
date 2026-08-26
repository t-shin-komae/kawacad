import AppKit
import SwiftUI
import Testing

@testable import KawaCADApp

@Test("CADToolbar は選択中ツールの名前と設定値を現在状態から導出する")
@MainActor
func cad_toolbar_state_tracks_selected_tool_and_toggle_values() {
  let appState = AppCoordinator(
    documentAdapter: StubDocumentSessionAdapter(
      createNewDocumentState: makeDocumentState(name: "Toolbar State")
    ),
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.selectedTool = .line
  appState.actions.uiBindings.toolbar.setGridVisible(false)
  appState.actions.uiBindings.toolbar.setA4ReferenceVisible(true)
  appState.actions.uiBindings.toolbar.setGridSnapEnabled(false)
  appState.actions.uiBindings.toolbar.setPointSnapEnabled(true)

  let props = WorkspaceViewPropsFactory(
    actions: appState.actions,
    inspectorPresentation: appState.inspectorPresentation,
    canvasPresentation: appState.canvasPresentation
  )

  #expect(props.toolbarState.selectedTool == .line)
  #expect(props.toolbarState.gridVisible == false)
  #expect(props.toolbarState.a4ReferenceVisible)
  #expect(props.toolbarState.gridSnapEnabled == false)
  #expect(props.toolbarState.pointSnapEnabled)
}

@Test("CADToolbar の表示切替はツールパレットの状態と設定を更新する")
@MainActor
func cad_toolbar_toggles_tool_palette_visibility() {
  let originalVisibility = WorkspacePreferencesAdapter.toolPaletteVisible()
  defer { WorkspacePreferencesAdapter.setToolPaletteVisible(originalVisibility) }
  WorkspacePreferencesAdapter.setToolPaletteVisible(true)

  let appState = AppCoordinator(
    documentAdapter: StubDocumentSessionAdapter(
      createNewDocumentState: makeDocumentState(name: "Toolbar Tool Palette")
    ),
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  let props = WorkspaceViewPropsFactory(
    actions: appState.actions,
    inspectorPresentation: appState.inspectorPresentation,
    canvasPresentation: appState.canvasPresentation
  )

  props.toolbarActions.toggleToolPalette(.wide)
  #expect(appState.workspaceLayout.toolPaletteVisible == false)
  #expect(WorkspacePreferencesAdapter.toolPaletteVisible() == false)

  props.toolbarActions.toggleToolPalette(.wide)
  #expect(appState.workspaceLayout.toolPaletteVisible)
  #expect(WorkspacePreferencesAdapter.toolPaletteVisible())
}

@Test("CADToolbar の condensed 表示は regular workspace に収まり、表示モード幅を維持する")
@MainActor
func cad_toolbar_condensed_presentation_fits_regular_workspace() {
  let appState = AppCoordinator(
    documentAdapter: StubDocumentSessionAdapter(
      createNewDocumentState: makeDocumentState(name: "Toolbar Layout")
    ),
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  let props = WorkspaceViewPropsFactory(
    actions: appState.actions,
    inspectorPresentation: appState.inspectorPresentation,
    canvasPresentation: appState.canvasPresentation
  )

  let condensedWidth = NSHostingView(
    rootView: CADToolbar(
      state: props.toolbarState,
      actions: props.toolbarActions,
      workspaceLayoutMode: .regular,
      density: .condensed
    )
  ).fittingSize.width
  let expandedWidth = NSHostingView(
    rootView: CADToolbar(
      state: props.toolbarState,
      actions: props.toolbarActions,
      workspaceLayoutMode: .regular,
      density: .expanded
    )
  ).fittingSize.width

  #expect(condensedWidth >= 236)
  #expect(condensedWidth <= WindowLayoutPolicy.regularMinimumWorkspaceWidth)
  #expect(expandedWidth > condensedWidth)
}
