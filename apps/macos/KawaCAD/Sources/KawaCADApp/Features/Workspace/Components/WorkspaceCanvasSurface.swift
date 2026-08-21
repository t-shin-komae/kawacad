import SwiftUI

struct WorkspaceCanvasSurface: View {
  let state: WorkspaceCanvasSurfaceState
  let actions: WorkspaceCanvasSurfaceActions

  var body: some View {
    ZStack(alignment: .topLeading) {
      CADCanvas(
        renderInput: state.canvasRenderInput,
        interactionInput: state.canvasInteractionInput,
        actions: actions.canvasActionGroups
      )

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
