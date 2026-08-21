import SwiftUI

struct CADCanvas: NSViewRepresentable {
  let renderInput: LeatherCanvasRenderInput
  let interactionInput: LeatherCanvasInteractionInput
  let actions: LeatherCanvasActionGroups

  func makeNSView(context: Context) -> LeatherCanvasView {
    return LeatherCanvasView(
      frame: .zero,
      renderInput: renderInput,
      interactionInput: interactionInput,
      actionGroups: actions
    )
  }

  func updateNSView(_ nsView: LeatherCanvasView, context: Context) {
    nsView.configure(
      renderInput: renderInput,
      interactionInput: interactionInput,
      actionGroups: actions
    )
    nsView.reconcileInlineFreeTextEditorState()
    nsView.syncInlineFreeTextEditorWithRequest()
    nsView.refreshAccessibilityState()
    nsView.needsDisplay = true
  }

}
