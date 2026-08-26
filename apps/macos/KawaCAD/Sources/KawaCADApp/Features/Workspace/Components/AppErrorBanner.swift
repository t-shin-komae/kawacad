import SwiftUI

/// Error presentation view, corresponding to React's `AppErrorBanner`.
struct AppErrorBanner: View {
  let presentation: AppErrorPresentation
  let onDismiss: () -> Void
  @State private var detailsExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(LeatherColors.warning)
          .accessibilityHidden(true)
          .frame(width: 18)

        VStack(alignment: .leading, spacing: 4) {
          Text(presentation.identity.category.title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(LeatherColors.ink)

          Text(presentation.message)
            .font(.system(size: 12))
            .foregroundStyle(LeatherColors.ink)

          if let recoverySuggestion = presentation.recoverySuggestion {
            Text(recoverySuggestion)
              .font(.system(size: 11))
              .foregroundStyle(LeatherColors.secondaryInk)
          }
        }

        Spacer(minLength: 8)

        if presentation.details != nil {
          Button(AppStrings.tr("error.banner.details")) {
            detailsExpanded.toggle()
          }
          .buttonStyle(.plain)
          .font(.system(size: 11, weight: .medium))
        }

        Button(AppStrings.tr("error.banner.dismiss")) {
          onDismiss()
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .medium))
      }

      if detailsExpanded, let details = presentation.details {
        Text(details)
          .font(.system(size: 11))
          .foregroundStyle(LeatherColors.secondaryInk)
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
