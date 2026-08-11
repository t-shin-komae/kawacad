import SwiftUI

/// Arranges the canvas and inspector for the current responsive workspace mode.
/// The parent owns the surrounding chrome and transient presentations; this view
/// owns only inspector sizing while its layout is visible.
struct WorkspaceCanvasLayout<CanvasColumn: View, InspectorPanel: View>: View {
  let state: WorkspaceViewState
  let actions: WorkspaceViewActions
  let policy: WindowLayoutPolicy
  let canvasColumn: CanvasColumn
  let inspectorPanel: (CGFloat) -> InspectorPanel

  @State private var inspectorResizeBaseWidth: CGFloat?

  var body: some View {
    switch policy.mode {
    case .wide:
      HStack(spacing: 0) {
        canvasColumn
          .frame(maxWidth: .infinity)

        if state.inspectorPanelVisible {
          PanelResizeHandle(alignment: .leading) { translation in
            let base = inspectorResizeBaseWidth ?? state.inspectorPanelWidth
            inspectorResizeBaseWidth = inspectorResizeBaseWidth ?? base
            actions.setInspectorPanelWidth(
              clamp(
                base - translation.width,
                within: WindowLayoutPolicy.inspectorDockWidthRange
              )
            )
          } onEnded: {
            inspectorResizeBaseWidth = nil
          } onKeyboardAdjust: { delta in
            actions.setInspectorPanelWidth(
              clamp(
                state.inspectorPanelWidth + delta,
                within: WindowLayoutPolicy.inspectorDockWidthRange
              )
            )
          }

          inspectorPanel(policy.inspectorDockWidth)
        }
      }
    case .regular:
      ZStack {
        canvasColumn
          .frame(maxWidth: .infinity)

        if state.inspectorPanelVisible {
          HStack(spacing: 0) {
            PanelResizeHandle(alignment: .leading) { translation in
              let base = inspectorResizeBaseWidth ?? state.inspectorPanelWidth
              inspectorResizeBaseWidth = inspectorResizeBaseWidth ?? base
              actions.setInspectorPanelWidth(
                clamp(base - translation.width, within: overlayInspectorWidthRange)
              )
            } onEnded: {
              inspectorResizeBaseWidth = nil
            } onKeyboardAdjust: { delta in
              actions.setInspectorPanelWidth(
                clamp(state.inspectorPanelWidth + delta, within: overlayInspectorWidthRange)
              )
            }
            .frame(width: WindowLayoutPolicy.panelResizeHandleWidth)

            inspectorPanel(policy.overlayInspectorWidth)
              .shadow(color: .black.opacity(0.08), radius: 6, x: -2, y: 0)
          }
          .frame(maxWidth: .infinity, alignment: .trailing)
        }
      }
    case .compact:
      ZStack {
        canvasColumn
          .frame(maxWidth: .infinity)

        if let drawer = state.compactDrawer {
          Color.black.opacity(0.12)
            .contentShape(Rectangle())
            .onTapGesture {
              actions.showCompactDrawer(nil)
            }
            .zIndex(20)

          switch drawer {
          case .tools:
            ToolPalette(
              state: state.toolPaletteState,
              actions: actions.toolPaletteActions,
              width: policy.compactToolDrawerWidth
            )
            .shadow(color: .black.opacity(0.12), radius: 8, x: 2, y: 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .zIndex(21)
          case .inspector:
            inspectorPanel(policy.compactInspectorDrawerWidth)
              .shadow(color: .black.opacity(0.12), radius: 8, x: -2, y: 0)
              .frame(maxWidth: .infinity, alignment: .trailing)
              .zIndex(21)
          }
        }
      }
    }
  }

  private var overlayInspectorWidthRange: ClosedRange<CGFloat> {
    let maximum = min(
      WindowLayoutPolicy.maximumInspectorWidth,
      max(
        WindowLayoutPolicy.minimumInspectorContentWidth,
        policy.workspaceWidth * 0.36
      )
    )
    return WindowLayoutPolicy.minimumInspectorContentWidth...maximum
  }

  private func clamp(_ value: CGFloat, within range: ClosedRange<CGFloat>) -> CGFloat {
    min(max(value, range.lowerBound), range.upperBound)
  }
}
