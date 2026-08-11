import SwiftUI

struct RecoverySaveFailureBanner: View {
  let banner: DocumentRecoveryBannerState
  let onRetry: () -> Void
  let onDismiss: () -> Void
  @State private var detailsExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
          Text(banner.message)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(LeatherColors.ink)

          if detailsExpanded {
            Text(banner.details)
              .font(.system(size: 11))
              .foregroundStyle(LeatherColors.secondaryInk)
          }
        }

        Spacer(minLength: 8)

        Button(AppStrings.tr("common.retry")) {
          onRetry()
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .medium))

        Button(AppStrings.tr("error.banner.details")) {
          detailsExpanded.toggle()
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .medium))

        Button(AppStrings.tr("error.banner.dismiss")) {
          onDismiss()
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .medium))
      }
    }
    .padding(12)
    .background(LeatherColors.panel)
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(LeatherColors.panelStroke.opacity(0.7))
    )
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
  }
}
