import SwiftUI

struct WorkspaceInspector: View {
  let model: InspectorPanelModel
  let width: CGFloat

  var body: some View {
    InspectorPanel(model: model)
      .frame(width: width)
      .background(MacVisualEffectBackground(style: .sidebar))
      .overlay(alignment: .leading) {
        Rectangle()
          .fill(LeatherColors.panelStroke.opacity(0.65))
          .frame(width: 1)
      }
  }
}
