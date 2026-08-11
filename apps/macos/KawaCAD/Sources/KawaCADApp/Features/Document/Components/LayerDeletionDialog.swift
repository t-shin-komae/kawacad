import SwiftUI

struct LayerDeletionDialog: ViewModifier {
  let state: LayerDeletionDialogState
  let actions: LayerDeletionDialogActions

  func body(content: Content) -> some View {
    content.confirmationDialog(
      AppStrings.tr("dialog.delete_layer_title", state.confirmation?.layer.name ?? ""),
      isPresented: Binding(
        get: { state.confirmation != nil },
        set: { isPresented in
          if !isPresented {
            actions.dismiss()
          }
        }
      ),
      titleVisibility: .visible
    ) {
      Button(AppStrings.tr("common.delete"), role: .destructive) {
        actions.confirm()
      }
      Button(AppStrings.tr("common.cancel"), role: .cancel) {
        actions.cancel()
      }
    } message: {
      Text(state.confirmation?.message ?? "")
    }
  }
}
