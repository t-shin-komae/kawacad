import SwiftUI

struct PasteOptionsOverlay: View {
  let presentation: PasteOptionsPresentation
  let selectMode: (PastePlacementMode) -> Void
  let dismiss: () -> Void
  var standalone: Bool = false

  @ViewBuilder
  var body: some View {
    if standalone {
      content
    } else {
      content.position(overlayPosition)
    }
  }

  private var content: some View {
    HStack(spacing: 2) {
      Menu {
        Button {
          selectMode(.cursor)
        } label: {
          modeLabel("paste_options.cursor", mode: .cursor)
        }
        .disabled(presentation.cursorPoint == nil)
        Button {
          selectMode(.nearSource)
        } label: {
          modeLabel("paste_options.near_source", mode: .nearSource)
        }
      } label: {
        Label(AppStrings.tr("paste_options.label"), systemImage: "clipboard")
          .font(.system(size: 11, weight: .semibold))
          .padding(.horizontal, 8)
          .padding(.vertical, 5)
          .background(.regularMaterial, in: Capsule())
      }
      .menuStyle(.borderlessButton)

      Button(action: dismiss) {
        Image(systemName: "xmark")
          .font(.system(size: 9, weight: .bold))
          .frame(width: 20, height: 20)
      }
      .buttonStyle(.borderless)
      .accessibilityLabel(AppStrings.tr("paste_options.dismiss"))
    }
    .frame(minHeight: 28)
    .accessibilityIdentifier(AccessibilityIdentifier.pasteOptions)
    .accessibilityLabel(AppStrings.tr("paste_options.label"))
    .accessibilityValue(
      AppStrings.tr(
        presentation.activeMode == .cursor
          ? "paste_options.active_cursor"
          : "paste_options.active_near_source"
      )
    )
  }

  @ViewBuilder
  private func modeLabel(_ key: String, mode: PastePlacementMode) -> some View {
    if presentation.activeMode == mode {
      Label(AppStrings.tr(key), systemImage: "checkmark")
    } else {
      Text(AppStrings.tr(key))
    }
  }

  private var overlayPosition: CGPoint {
    guard let canvasPoint = presentation.canvasPoint else {
      return CGPoint(x: 130, y: 42)
    }
    return CGPoint(x: max(82, canvasPoint.x + 44), y: max(24, canvasPoint.y + 22))
  }
}
