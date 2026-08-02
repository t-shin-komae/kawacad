import Combine

/// UI-facing error state, corresponding to React's `useAppErrorPresentation`.
///
/// Error identity and conversion remain pure in `AppErrorPresentation`.
/// Rendering belongs to `AppErrorBanner`.
final class AppErrorPresentationState: ObservableObject {
  @Published private(set) var presentation: AppErrorPresentation?

  func present(_ next: AppErrorPresentation) {
    guard let current = presentation, current.identity == next.identity else {
      presentation = next
      return
    }
    var merged = next
    merged.occurrenceCount = current.occurrenceCount + 1
    presentation = merged
  }

  func dismiss() {
    presentation = nil
  }
}
