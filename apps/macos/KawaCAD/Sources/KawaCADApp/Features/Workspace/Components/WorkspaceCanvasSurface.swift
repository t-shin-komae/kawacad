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

      if let instruction = CanvasOperationGuideState.instruction(
        selectedTool: state.canvasRenderInput.draft.selectedTool,
        viewMode: state.canvasRenderInput.viewport.viewMode,
        topBannerVisible: state.topBannerVisible,
        isSettingPartOrigin: state.canvasInteractionInput.isSettingPartOrigin,
        filletDraftEntityCount: state.canvasRenderInput.draft.filletDraftEntityIDs.count,
        filletDraftClosed: state.canvasRenderInput.draft.filletDraftClosed ?? false,
        draftPointCount: state.canvasRenderInput.draft.draftStartPoint == nil ? 0 : 1,
        hasArcStartPoint: state.canvasRenderInput.draft.draftArcStartPoint != nil,
        pendingConstraintTargetCount: state.canvasRenderInput.selection.pendingConstraintTargets
          .count
      ) {
        ZStack(alignment: .top) {
          LeatherColors.canvas
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .contentShape(Rectangle())
            .onTapGesture {}

          CanvasOperationGuide(
            tool: state.canvasRenderInput.draft.selectedTool,
            instruction: instruction
          )
          .frame(maxWidth: 640)
          .frame(maxWidth: .infinity, alignment: .top)
          .padding(.top, 10)
          .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
      }

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
