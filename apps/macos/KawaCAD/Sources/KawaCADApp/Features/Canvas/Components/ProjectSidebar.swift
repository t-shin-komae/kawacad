import SwiftUI

struct ProjectSidebar: View {
  struct ToolGroup: Equatable {
    let id: String
    let title: String
    let defaultExpanded: Bool
    let tools: [CanvasTool]
  }

  let state: ToolPaletteState
  let actions: ToolPaletteActions
  let width: CGFloat

  static let allToolGroups: [ToolGroup] = [
    ToolGroup(
      id: "drawing",
      title: AppStrings.tr("tool.group.drawing"),
      defaultExpanded: true,
      tools: [
        .select, .point, .line, .circle, .roundHole, .arc, .freeText, .stitchStartPoint,
        .centerLine, .horizontalCenterLine, .verticalCenterLine,
      ]
    ),
    ToolGroup(
      id: "derived",
      title: AppStrings.tr("sidebar.group.derived"),
      defaultExpanded: false,
      tools: [.offset, .fillet]
    ),
    ToolGroup(
      id: "constraint",
      title: AppStrings.tr("tool.group.constraint"),
      defaultExpanded: false,
      tools: [
        .coincident, .horizontal, .vertical, .parallel, .perpendicular, .tangent, .equalLength,
        .angle, .symmetric, .pointOnLine, .fixed,
      ]
    ),
    ToolGroup(
      id: "dimension",
      title: AppStrings.tr("sidebar.group.dimension"),
      defaultExpanded: true,
      tools: [
        .distance, .horizontalDistance, .verticalDistance, .lineLineDistance, .segmentLength,
        .diameter, .radius,
      ]
    ),
    ToolGroup(
      id: "measurement",
      title: AppStrings.tr("tool.group.measurement"),
      defaultExpanded: false,
      tools: [
        .measureDistance, .measureSegmentLength, .measureAngle, .measureRadius, .measureDiameter,
        .measureArcSweepAngle,
      ]
    ),
  ]

  static var toolGroups: [(title: String, tools: [CanvasTool])] {
    allToolGroups.map { ($0.title, $0.tools) }
  }

  init(
    state: ToolPaletteState, actions: ToolPaletteActions, width: CGFloat = ToolPaletteMetrics.width
  ) {
    self.state = state
    self.actions = actions
    self.width = width
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Image(systemName: "sidebar.left")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(LeatherColors.accent)
        VStack(alignment: .leading, spacing: 1) {
          Text(AppStrings.tr("sidebar.tools"))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(LeatherColors.ink)
          Text(AppStrings.tr("sidebar.utility_palette"))
            .font(.system(size: 10))
            .foregroundStyle(LeatherColors.secondaryInk)
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 12)
      .frame(height: 44)

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 7) {
          displayModeSection
          patternLineStyleSection
          roundHoleSection

          if !state.showsDetailedTools, state.selectedTool.isDetailedTool {
            activeDetailedToolSection
          }

          ForEach(displayedToolGroups, id: \.id) { group in
            VStack(alignment: .leading, spacing: 5) {
              Button {
                toggleGroup(group)
              } label: {
                HStack(spacing: 6) {
                  Image(systemName: isGroupExpanded(group) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                  Text(group.title)
                    .font(.system(size: 11, weight: .semibold))
                  Spacer(minLength: 0)
                }
                .foregroundStyle(LeatherColors.secondaryInk)
                .padding(.horizontal, 2)
              }
              .buttonStyle(.plain)

              if isGroupExpanded(group) {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 5) {
                  ForEach(group.tools) { tool in
                    PaletteToolButton(
                      tool: tool,
                      isSelected: state.selectedTool == tool
                    ) {
                      actions.activateTool(tool)
                    }
                  }
                }
              }
            }
          }

          Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 9)
      .padding(.vertical, 8)
    }
    .background {
      MacVisualEffectBackground(style: .sidebar)
    }
    .overlay(alignment: .trailing) {
      Rectangle()
        .fill(LeatherColors.panelStroke.opacity(0.65))
        .frame(width: 1)
    }
    .frame(minWidth: width, maxWidth: width, maxHeight: .infinity, alignment: .top)
  }

  private var displayedToolGroups: [ToolGroup] {
    Self.allToolGroups.compactMap { group in
      let tools = group.tools.filter { state.showsDetailedTools || $0.isBasicTool }
      guard !tools.isEmpty else {
        return nil
      }
      return ToolGroup(
        id: group.id,
        title: group.title,
        defaultExpanded: group.defaultExpanded,
        tools: tools
      )
    }
  }

  private var gridColumns: [GridItem] {
    if width >= 220 {
      return [
        GridItem(.flexible(minimum: 92, maximum: 120), spacing: 6),
        GridItem(.flexible(minimum: 92, maximum: 120), spacing: 6),
      ]
    }
    return [
      GridItem(.flexible(minimum: width - 24), spacing: 6)
    ]
  }

  private var displayModeSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(AppStrings.tr("sidebar.tool_display_mode"))
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(LeatherColors.secondaryInk)
        .lineLimit(1)
        .padding(.horizontal, 2)

      Button {
        actions.setShowsDetailedTools(!state.showsDetailedTools)
      } label: {
        Label(
          state.showsDetailedTools
            ? AppStrings.tr("sidebar.show_basic_tools")
            : AppStrings.tr("sidebar.show_detailed_tools"),
          systemImage: state.showsDetailedTools
            ? "rectangle.compress.vertical" : "rectangle.expand.vertical"
        )
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(.bottom, 3)
  }

  private var patternLineStyleSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(AppStrings.tr("sidebar.pattern_line_style"))
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(LeatherColors.secondaryInk)
        .lineLimit(1)
        .padding(.horizontal, 2)

      Menu {
        ForEach(state.sharedStyles) { style in
          Button {
            actions.setActivePatternLineStyle(style.id)
          } label: {
            HStack(spacing: 6) {
              PatternLineStyleSwatch(style: style)
              Text(style.name)
            }
          }
        }
      } label: {
        HStack(spacing: 6) {
          if let style = activePatternLineStyle {
            PatternLineStyleSwatch(style: style)
            Text(style.name)
          }
          Spacer(minLength: 0)
          Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 9, weight: .semibold))
        }
        .frame(width: contentWidth, height: 22, alignment: .leading)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .accessibilityLabel(AppStrings.tr("sidebar.pattern_line_style"))
      .disabled(state.sharedStyles.isEmpty)

      Button {
        actions.applyActivePatternLineStyleToSelection()
      } label: {
        Label(AppStrings.tr("sidebar.pattern_line_style_apply"), systemImage: "paintbrush")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .disabled(state.selectedEntityCount == 0 || state.sharedStyles.isEmpty)
    }
    .padding(.bottom, 3)
  }

  private var roundHoleSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(AppStrings.tr("sidebar.round_hole"))
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(LeatherColors.secondaryInk)
        .lineLimit(1)
        .padding(.horizontal, 2)

      Menu {
        ForEach(ProjectRoundHoleKind.allCases) { kind in
          Button(kind.displayName) {
            actions.setActiveRoundHoleKind(kind)
          }
        }
      } label: {
        HStack(spacing: 6) {
          Text(state.activeRoundHoleKind.displayName)
          Spacer(minLength: 0)
          Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 9, weight: .semibold))
        }
        .frame(width: contentWidth, height: 22, alignment: .leading)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .accessibilityLabel(AppStrings.tr("sidebar.round_hole_kind"))

      SyncedTextField(
        placeholder: AppStrings.tr("sidebar.round_hole_diameter_mm"),
        sourceValue: CommonFieldParsers.displayString(
          for: state.activeRoundHoleDiameterMM,
          maximumFractionDigits: 2
        ),
        onCommitResult: { text in
          switch CommonFieldValidators.positiveNumber(text, maximumFractionDigits: 2) {
          case .success(let canonicalValue):
            let value = CommonFieldParsers.decimalValue(canonicalValue ?? text)
            guard case .success(let parsed) = value,
              actions.setActiveRoundHoleDiameter(parsed)
            else {
              return .failure(
                .init(kind: .domain, text: AppStrings.tr("field.error.positive_required")))
            }
            return .success(canonicalValue: canonicalValue)
          case .failure(let message):
            return .failure(message)
          }
        },
        font: .system(size: 12, weight: .medium),
        onValidate: CommonFieldValidators.optionalDecimalSyntax,
        onDraftValueChange: { text in
          switch CommonFieldParsers.decimalValue(text) {
          case .success(let value):
            actions.setActiveRoundHoleDiameterInputValid(value > 0)
          case .failure:
            actions.setActiveRoundHoleDiameterInputValid(false)
          }
        }
      )
    }
    .padding(.bottom, 3)
  }

  private var activeDetailedToolSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(AppStrings.tr("sidebar.active_detailed_tool"))
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(LeatherColors.secondaryInk)
        .lineLimit(1)
        .padding(.horizontal, 2)

      LabeledToolButton(
        tool: state.selectedTool,
        isSelected: true
      ) {
        actions.setShowsDetailedTools(true)
      }
    }
    .padding(.bottom, 3)
  }

  private var contentWidth: CGFloat {
    max(0, width - 18)
  }

  private var activePatternLineStyle: ProjectSharedStyle? {
    state.sharedStyles.first { $0.id == state.activePatternLineStyleID }
  }

  private func isGroupExpanded(_ group: ToolGroup) -> Bool {
    if group.tools.contains(state.selectedTool) {
      return true
    }
    return !state.collapsedGroupIDs.contains(group.id)
  }

  private func toggleGroup(_ group: ToolGroup) {
    let willCollapse = isGroupExpanded(group)
    if willCollapse {
      actions.setGroupCollapsed(true, group.id)
    } else {
      actions.setGroupCollapsed(false, group.id)
    }
  }
}

private struct PatternLineStyleSwatch: View {
  let style: ProjectSharedStyle

  var body: some View {
    Rectangle()
      .fill(Color(hex: style.colorHex))
      .frame(width: 18, height: 3)
      .overlay {
        if style.linePattern != .solid {
          HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { _ in
              Rectangle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 2)
            }
          }
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 1))
  }
}
