import SwiftUI

struct CanvasOperationGuide: View {
  let tool: CanvasTool
  let instruction: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: tool.symbolName)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(LeatherColors.accent)
        .frame(width: 16)
      Text(tool.displayName)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(LeatherColors.ink)
        .lineLimit(1)
      Text(instruction)
        .font(.system(size: 11))
        .foregroundStyle(LeatherColors.secondaryInk)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 11)
    .padding(.vertical, 6)
    .background {
      MacVisualEffectBackground(style: .content)
        .clipShape(Capsule())
    }
    .overlay {
      Capsule()
        .stroke(LeatherColors.accent.opacity(0.34), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text(tool.displayName))
    .accessibilityValue(Text(instruction))
    .allowsHitTesting(false)
  }
}
