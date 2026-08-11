import SwiftUI

struct WorkspaceInspector: View {
  let appState: InspectorFeatureModel
  let width: CGFloat

  var body: some View {
    InspectorPanel(appState: appState)
      .frame(width: width)
      .background(MacVisualEffectBackground(style: .sidebar))
      .overlay(alignment: .leading) {
        Rectangle()
          .fill(LeatherColors.panelStroke.opacity(0.65))
          .frame(width: 1)
      }
  }
}
