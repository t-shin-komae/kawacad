import SwiftUI

struct CanvasStatusBar: View {
  let state: CanvasStatusBarState
  let actions: CanvasStatusBarActions

  var body: some View {
    HStack(spacing: 12) {
      StatusItem(
        symbolName: "point.3.connected.trianglepath.dotted",
        text: AppStrings.tr("status_item.visible", state.visibleEntityCount))
      StatusItem(symbolName: "cursorarrow", text: state.selectionText)
      StatusItem(symbolName: "location", text: state.cursorCoordinateText)
      if let outputPreviewSummaryText = state.outputPreviewSummaryText {
        StatusItem(symbolName: outputPreviewSummarySymbolName, text: outputPreviewSummaryText)
          .layoutPriority(1)
      }
      StatusItem(symbolName: "info.circle", text: state.statusMessage, emphasis: true)
        .layoutPriority(1)
      Spacer(minLength: 0)
      Button(action: toggleBottomWorkbench) {
        Label(
          state.bottomWorkbenchVisible
            ? AppStrings.tr("status_item.hide_summary") : AppStrings.tr("status_item.show_summary"),
          systemImage: state.bottomWorkbenchVisible
            ? "rectangle.compress.vertical" : "rectangle.expand.vertical"
        )
      }
      .buttonStyle(.borderless)
      .font(.system(size: LeatherDesignMetrics.Typography.section, weight: .medium))
      .foregroundStyle(LeatherColors.secondaryInk)
      .accessibilityIdentifier(AccessibilityIdentifier.statusBottomWorkbench)
    }
    .padding(.horizontal, 12)
    .frame(height: 36)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(AppStrings.tr("accessibility.status_bar"))
    .accessibilityValue(statusAccessibilityValue)
    .accessibilityIdentifier(AccessibilityIdentifier.workspaceStatusBar)
    .background {
      MacVisualEffectBackground(style: .content)
    }
  }

  private var outputPreviewSummarySymbolName: String {
    state.outputPreviewHasWarnings ? "exclamationmark.triangle" : "doc.on.doc"
  }

  private var statusAccessibilityValue: String {
    AppStrings.tr(
      "accessibility.status_bar.value",
      state.visibleEntityCount,
      state.selectionText,
      state.cursorCoordinateText,
      state.statusMessage
    )
  }

  private func toggleBottomWorkbench() {
    actions.setBottomWorkbenchVisible(!state.bottomWorkbenchVisible)
  }
}

private struct StatusItem: View {
  let symbolName: String
  let text: String
  var emphasis = false

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: symbolName)
        .font(
          .system(
            size: emphasis
              ? LeatherDesignMetrics.Typography.body : LeatherDesignMetrics.Typography.label))
      Text(text)
        .font(
          .system(
            size: emphasis
              ? LeatherDesignMetrics.Typography.body : LeatherDesignMetrics.Typography.label)
        )
        .lineLimit(1)
    }
    .foregroundStyle(LeatherColors.ink)
  }
}
