import SwiftUI

struct WorkspaceCanvasSurface: View {
  let state: WorkspaceViewState
  let actions: WorkspaceViewActions

  var body: some View {
    ZStack(alignment: .topLeading) {
      CADCanvas(state: state.canvasState, actions: actions.canvasActions)

      ValueEntryDialogPresenter(
        state: state.constraintEntryHUDState,
        actions: actions.constraintEntryHUDActions
      )

      if let pasteOptionsPresentation = state.pasteOptionsPresentation {
        PasteOptionsOverlay(
          presentation: pasteOptionsPresentation,
          selectMode: actions.selectPastePlacement,
          dismiss: actions.dismissPasteOptions
        )
      }
    }
  }
}
