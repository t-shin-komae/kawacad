import AppKit
import SwiftUI
import Testing

@testable import KawaCADApp

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
