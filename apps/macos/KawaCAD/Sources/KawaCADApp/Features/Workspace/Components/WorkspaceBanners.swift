import SwiftUI

/// The workspace overlay owns only banner composition. Recovery and error
/// state remain owned by their respective feature state objects.
struct WorkspaceBanners: View {
  let recoveryBanner: DocumentRecoveryBannerState?
  let errorPresentation: AppErrorPresentation?
  let onRetryRecovery: () -> Void
  let onDismissRecovery: () -> Void
  let onDismissError: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      if let recoveryBanner {
        RecoverySaveFailureBanner(
          banner: recoveryBanner,
          onRetry: onRetryRecovery,
          onDismiss: onDismissRecovery
        )
      }

      if let errorPresentation {
        AppErrorBanner(
          presentation: errorPresentation,
          onDismiss: onDismissError
        )
      }
    }
  }
}
