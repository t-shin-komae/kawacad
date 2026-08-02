import SwiftUI

struct DocumentHeader: View {
  let state: DocumentHeaderState
  let actions: DocumentHeaderActions

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      SyncedTextField(
        placeholder: AppStrings.tr("header.project_name_placeholder"),
        sourceValue: state.documentName,
        onCommitResult: { value in
          actions.commitDocumentName(value)
        },
        font: .system(size: 15, weight: .semibold),
        textFieldStyle: .plain,
        onDraftValueChange: actions.updateDocumentNameDraft
      )
      .frame(width: 220, alignment: .leading)
      .disabled(!state.canRenameDocument)

      Text(AppStrings.tr("header.file_info", state.unitLabel, state.paperLabel))
        .font(.system(size: 11))
        .foregroundStyle(LeatherColors.secondaryInk)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
  }
}
