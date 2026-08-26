import KawaCADOutput
import SwiftUI

enum CADToolbarDensity: Equatable {
  case expanded
  case condensed
}

struct CADToolbar: View {
  let state: CADToolbarState
  let actions: CADToolbarActions
  let workspaceLayoutMode: WindowLayoutMode
  let density: CADToolbarDensity

  private var toolPaletteIsVisible: Bool {
    workspaceLayoutMode != .compact && state.toolPaletteVisible
  }

  private var toolPaletteActionLabel: String {
    AppStrings.tr(
      toolPaletteIsVisible ? "toolbar.hide_tool_palette" : "toolbar.show_tool_palette"
    )
  }

  var body: some View {
    HStack(spacing: 8) {
      Button {
        actions.toggleToolPalette(workspaceLayoutMode)
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "sidebar.left")
            .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(LeatherColors.secondaryInk)
        .frame(width: 32, alignment: .leading)
      }
      .buttonStyle(.plain)
      .help(toolPaletteActionLabel)
      .accessibilityLabel(toolPaletteActionLabel)
      .accessibilityIdentifier(AccessibilityIdentifier.toolbarTools)

      Divider()
        .frame(height: 30)

      HStack(spacing: 8) {
        HStack(spacing: 8) {
          ToolIcon(tool: state.selectedTool, size: 18, color: LeatherColors.ink)
            .frame(width: 22)
          Text(state.selectedTool.displayName)
            .font(.system(size: 13))
            .lineLimit(1)
            .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.selectedTool.displayName)

      }
      .foregroundStyle(LeatherColors.ink)
      .frame(minWidth: 112, alignment: .leading)

      if density == .expanded {
        Divider()
          .frame(height: 30)

        Picker(
          AppStrings.tr("toolbar.drawing_layer"),
          selection: Binding(
            get: { state.activeLayerID },
            set: actions.setActiveLayer
          )
        ) {
          ForEach(state.layers) { layer in
            Text(layer.name).tag(layer.id)
          }
        }
        .frame(width: 220)
        .accessibilityIdentifier(AccessibilityIdentifier.toolbarDrawingLayer)
      }

      if density == .expanded {
        ToolbarMetric(
          text: AppStrings.tr("toolbar.zoom_percent", Int((state.zoomScale * 100).rounded())))
      }

      ControlGroup {
        Button {
          actions.zoomToFit()
        } label: {
          Image(systemName: "rectangle.arrowtriangle.2.inward")
            .frame(width: 22, height: 22)
        }
        .help(AppStrings.tr("toolbar.zoom_to_fit"))
        .accessibilityLabel(AppStrings.tr("toolbar.zoom_to_fit"))
        .accessibilityIdentifier(AccessibilityIdentifier.toolbarZoomToFit)

        if density == .expanded {
          Button {
            actions.zoomOut()
          } label: {
            Image(systemName: "minus.magnifyingglass")
              .frame(width: 22, height: 22)
          }
          .help(AppStrings.tr("toolbar.zoom_out"))
          .accessibilityLabel(AppStrings.tr("toolbar.zoom_out"))
          .accessibilityIdentifier(AccessibilityIdentifier.toolbarZoomOut)

          Button {
            actions.zoomIn()
          } label: {
            Image(systemName: "plus.magnifyingglass")
              .frame(width: 22, height: 22)
          }
          .help(AppStrings.tr("toolbar.zoom_in"))
          .accessibilityLabel(AppStrings.tr("toolbar.zoom_in"))
          .accessibilityIdentifier(AccessibilityIdentifier.toolbarZoomIn)
        }
      }

      if density == .expanded {
        ControlGroup {
          ToolbarToggleButton(
            title: AppStrings.tr("toolbar.grid"),
            iconKind: .grid,
            isOn: state.gridVisible,
            accessibilityIdentifier: AccessibilityIdentifier.toolbarGrid,
            action: actions.setGridVisible
          )
          ToolbarToggleButton(
            title: AppStrings.tr("toolbar.a4"),
            iconKind: .page,
            isOn: state.a4ReferenceVisible,
            accessibilityIdentifier: AccessibilityIdentifier.toolbarA4Reference,
            action: actions.setA4ReferenceVisible
          )
          ToolbarOrientationToggle(
            orientation: state.a4ReferenceOrientation,
            accessibilityIdentifier: AccessibilityIdentifier.toolbarLandscapeOrientation,
            action: actions.setA4ReferenceOrientation
          )
          ToolbarToggleButton(
            title: AppStrings.tr("toolbar.grid_snap"),
            iconKind: .gridSnap,
            isOn: state.gridSnapEnabled,
            accessibilityIdentifier: AccessibilityIdentifier.toolbarGridSnap,
            action: actions.setGridSnapEnabled
          )
          ToolbarToggleButton(
            title: AppStrings.tr("toolbar.point_snap"),
            iconKind: .pointSnap,
            isOn: state.pointSnapEnabled,
            accessibilityIdentifier: AccessibilityIdentifier.toolbarPointSnap,
            action: actions.setPointSnapEnabled
          )
        }
        .tint(LeatherColors.selectedControlFill)
      }

      Spacer()

      Button {
        actions.toggleInspector(workspaceLayoutMode)
      } label: {
        Image(systemName: "sidebar.right")
          .font(.system(size: 12, weight: .semibold))
          .frame(width: 24, height: 24)
      }
      .buttonStyle(.plain)
      .help(AppStrings.tr("menu.inspector"))
      .accessibilityLabel(AppStrings.tr("menu.inspector"))
      .accessibilityIdentifier(AccessibilityIdentifier.toolbarInspector)

      Picker(
        AppStrings.tr("toolbar.view_mode"),
        selection: Binding(
          get: { state.viewMode },
          set: actions.setViewMode
        )
      ) {
        ForEach(CanvasViewMode.allCases) { mode in
          Text(mode.displayName).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .accessibilityLabel(AppStrings.tr("toolbar.view_mode"))
      .accessibilityIdentifier(AccessibilityIdentifier.toolbarViewMode)
      .frame(width: 236)

      Menu {
        overflowMenuContent
      } label: {
        Image(systemName: "ellipsis.circle")
          .font(.system(size: 16, weight: .semibold))
      }
      .menuStyle(.borderlessButton)
      .accessibilityLabel(AppStrings.tr("toolbar.more_actions"))
      .accessibilityIdentifier(AccessibilityIdentifier.toolbarOverflow)
    }
    .padding(.horizontal, 14)
    .frame(height: 54)
  }

  @ViewBuilder
  private var overflowMenuContent: some View {
    if density == .condensed {
      layerPickerMenu
      Divider()
    }

    Button(AppStrings.tr("toolbar.zoom_out")) {
      actions.zoomOut()
    }
    Button(AppStrings.tr("toolbar.zoom_in")) {
      actions.zoomIn()
    }

    Divider()

    Button(AppStrings.tr("toolbar.grid")) {
      actions.setGridVisible(!state.gridVisible)
    }
    Button(AppStrings.tr("toolbar.a4")) {
      actions.setA4ReferenceVisible(!state.a4ReferenceVisible)
    }
    Button(AppStrings.tr("toolbar.grid_snap")) {
      actions.setGridSnapEnabled(!state.gridSnapEnabled)
    }
    Button(AppStrings.tr("toolbar.point_snap")) {
      actions.setPointSnapEnabled(!state.pointSnapEnabled)
    }
    Toggle(
      AppStrings.tr("toolbar.a4_landscape"),
      isOn: Binding(
        get: { state.a4ReferenceOrientation == .landscape },
        set: { actions.setA4ReferenceOrientation($0 ? .landscape : .portrait) }
      )
    )
  }

  private var layerPickerMenu: some View {
    Menu(AppStrings.tr("toolbar.drawing_layer")) {
      ForEach(state.layers) { layer in
        Button(layer.name) {
          actions.setActiveLayer(layer.id)
        }
      }
    }
  }

}

private struct ToolbarOrientationToggle: View {
  let orientation: OutputPrintOrientation
  let accessibilityIdentifier: String
  let action: (OutputPrintOrientation) -> Void

  var body: some View {
    Toggle(
      isOn: Binding(
        get: { isLandscape },
        set: { action($0 ? .landscape : .portrait) }
      )
    ) {
      Image(systemName: isLandscape ? "rectangle" : "rectangle.portrait")
        .font(.system(size: 12, weight: .semibold))
        .frame(width: 28, height: 28)
        .foregroundStyle(
          isLandscape ? LeatherColors.selectedControlInk : LeatherColors.secondaryInk)
    }
    .toggleStyle(.button)
    .help(AppStrings.tr("toolbar.a4_landscape"))
    .accessibilityLabel(AppStrings.tr("toolbar.a4_landscape"))
    .accessibilityValue(isLandscape ? AppStrings.tr("common.on") : AppStrings.tr("common.off"))
    .accessibilityIdentifier(accessibilityIdentifier)
  }

  private var isLandscape: Bool {
    orientation == .landscape
  }
}

private struct ToolbarMetric: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(LeatherColors.secondaryInk)
      .padding(.horizontal, 8)
      .frame(height: 22)
      .background(LeatherColors.insetFill)
      .clipShape(Capsule())
  }
}

private struct ToolbarToggleButton: View {
  let title: String
  let iconKind: ToolbarToggleIconKind
  let isOn: Bool
  let accessibilityIdentifier: String
  let action: (Bool) -> Void

  var body: some View {
    Toggle(
      isOn: Binding(
        get: { isOn },
        set: action
      )
    ) {
      ToolbarToggleIcon(
        kind: iconKind,
        color: isOn ? LeatherColors.selectedControlInk : LeatherColors.secondaryInk
      )
      .frame(width: 28, height: 28)
    }
    .toggleStyle(.button)
    .help(title)
    .accessibilityLabel(title)
    .accessibilityValue(isOn ? AppStrings.tr("common.on") : AppStrings.tr("common.off"))
    .accessibilityIdentifier(accessibilityIdentifier)
  }
}

private enum ToolbarToggleIconKind {
  case grid
  case page
  case gridSnap
  case pointSnap
}

private struct ToolbarToggleIcon: View {
  let kind: ToolbarToggleIconKind
  let color: Color

  var body: some View {
    ZStack {
      Image(systemName: symbolName)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(color)

      if showsSnapDot {
        Circle()
          .fill(color)
          .frame(width: 4.5, height: 4.5)
          .offset(x: 5, y: -5)
      }
    }
  }

  private var symbolName: String {
    switch kind {
    case .grid:
      return "squareshape.split.3x3"
    case .gridSnap:
      return "square.grid.3x3"
    case .page:
      return "doc"
    case .pointSnap:
      return "scope"
    }
  }

  private var showsSnapDot: Bool {
    switch kind {
    case .gridSnap, .pointSnap:
      return true
    case .grid, .page:
      return false
    }
  }
}
