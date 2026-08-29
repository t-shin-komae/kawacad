import SwiftUI

struct DocumentSaveConfirmationDialog: View {
  let confirmation: DocumentSaveConfirmation
  let actions: DocumentSaveConfirmationActions

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(confirmation.title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(LeatherColors.ink)

      Text(confirmation.reason)
        .font(.system(size: 12))
        .foregroundStyle(LeatherColors.secondaryInk)

      HStack(spacing: 10) {
        Spacer()

        Button(AppStrings.tr("common.cancel")) {
          actions.cancel()
        }
        .keyboardShortcut(.cancelAction)
        .leatherControlHeight()

        Button(AppStrings.tr("document.save_confirmation.discard"), role: .destructive) {
          actions.discard()
        }
        .buttonStyle(.borderedProminent)
        .leatherControlHeight()
        .tint(.red)
        .accessibilityLabel(AppStrings.tr("document.save_confirmation.discard"))

        Button(AppStrings.tr("menu.save")) {
          actions.save()
        }
        .keyboardShortcut(.defaultAction)
        .leatherControlHeight()
      }
    }
    .padding(20)
    .frame(minWidth: 420)
  }
}
