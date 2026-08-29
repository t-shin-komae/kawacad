import SwiftUI

struct RecoveryChooserDialog: View {
  let state: RecoveryChooserState
  let actions: RecoveryChooserActions
  let chooser: DocumentRecoveryChooserState

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(AppStrings.tr("document.recovery.chooser_title"))
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(LeatherColors.ink)

      Text(AppStrings.tr("document.recovery.chooser_message"))
        .font(.system(size: 12))
        .foregroundStyle(LeatherColors.secondaryInk)

      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(currentCandidates) { candidate in
            RecoveryCandidateRow(actions: actions, candidate: candidate)
          }
        }
      }
      HStack {
        Spacer()
        Button(AppStrings.tr("document.recovery.later")) {
          actions.postpone()
        }
        .keyboardShortcut(.cancelAction)
        .leatherControlHeight()
      }
    }
    .padding(20)
    .frame(minWidth: 620, minHeight: 320)
  }

  private var currentCandidates: [DocumentRecoveryCandidate] {
    state.candidates.isEmpty ? chooser.candidates : state.candidates
  }
}

private struct RecoveryCandidateRow: View {
  let actions: RecoveryChooserActions
  let candidate: DocumentRecoveryCandidate

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(candidate.displayName)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(LeatherColors.ink)

      Text(recoverySubtitle)
        .font(.system(size: 11))
        .foregroundStyle(LeatherColors.secondaryInk)

      if case .broken(let details) = candidate.status {
        Text(details)
          .font(.system(size: 11))
          .foregroundStyle(LeatherColors.secondaryInk)
      }

      HStack(spacing: 10) {
        Button(AppStrings.tr("document.recovery.recover")) {
          actions.recover(candidate)
        }
        .disabled(!candidate.isRecoverable)
        .leatherControlHeight()

        Button(AppStrings.tr("document.recovery.discard")) {
          actions.discard(candidate)
        }
        .buttonStyle(.borderedProminent)
        .leatherControlHeight()
        .tint(.red)

        Button(AppStrings.tr("document.recovery.show_in_finder")) {
          actions.revealInFinder(candidate)
        }
        .buttonStyle(.plain)
        .leatherControlHeight()
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(LeatherColors.panel)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }

  private var recoverySubtitle: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    let source =
      candidate.originalDocumentURL?.path ?? AppStrings.tr("document.recovery.unsaved_source")
    return AppStrings.tr(
      "document.recovery.updated_at", source, formatter.string(from: candidate.updatedAt))
  }
}
