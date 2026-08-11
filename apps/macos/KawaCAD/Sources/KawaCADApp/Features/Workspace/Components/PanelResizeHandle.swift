import SwiftUI

struct PanelResizeHandle: View {
  let alignment: HorizontalAlignment
  let onChanged: (CGSize) -> Void
  let onEnded: () -> Void
  let onKeyboardAdjust: (CGFloat) -> Void

  var body: some View {
    Rectangle()
      .fill(Color.clear)
      .frame(width: WindowLayoutPolicy.panelResizeHandleWidth)
      .contentShape(Rectangle())
      .overlay(alignment: alignment == .leading ? .leading : .trailing) {
        Rectangle()
          .fill(LeatherColors.panelStroke.opacity(0.7))
          .frame(width: 1)
      }
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            onChanged(value.translation)
          }
          .onEnded { _ in
            onEnded()
          }
      )
      .accessibilityLabel(AppStrings.tr("accessibility.resize_panel"))
      .accessibilityHint(AppStrings.tr("accessibility.resize_panel_hint"))
      .focusable()
      .onMoveCommand { direction in
        switch (alignment, direction) {
        case (.trailing, .right), (.leading, .left):
          onKeyboardAdjust(8)
        case (.trailing, .left), (.leading, .right):
          onKeyboardAdjust(-8)
        default:
          break
        }
      }
      .accessibilityAdjustableAction { direction in
        onKeyboardAdjust(direction == .increment ? 8 : -8)
      }
  }
}
