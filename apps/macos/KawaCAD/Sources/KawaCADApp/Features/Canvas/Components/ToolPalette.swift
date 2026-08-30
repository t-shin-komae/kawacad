import AppKit
import SwiftUI

struct ToolPalette: View {
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
        .centerLine,
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
      HStack {
        VStack(alignment: .leading, spacing: 1) {
          Text(AppStrings.tr("sidebar.tools"))
            .font(.system(size: LeatherDesignMetrics.Typography.title, weight: .semibold))
            .foregroundStyle(LeatherColors.ink)
          Text(AppStrings.tr("sidebar.utility_palette"))
            .font(.system(size: LeatherDesignMetrics.Typography.label))
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
        .font(.system(size: LeatherDesignMetrics.Typography.section, weight: .semibold))
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
      .leatherControlHeight()
    }
    .padding(.bottom, 3)
  }

  private var patternLineStyleSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(AppStrings.tr("sidebar.pattern_line_style"))
        .font(.system(size: LeatherDesignMetrics.Typography.section, weight: .semibold))
        .foregroundStyle(LeatherColors.secondaryInk)
        .lineLimit(1)
        .padding(.horizontal, 2)

      PalettePopUpButton(
        items: state.sharedStyles.map { style in
          PalettePopUpItem(
            title: style.name,
            value: style.id
          )
        },
        selection: state.activePatternLineStyleID,
        width: contentWidth,
        accessibilityLabel: AppStrings.tr("sidebar.pattern_line_style"),
        onSelect: actions.setActivePatternLineStyle
      )
      .disabled(state.sharedStyles.isEmpty)

      Button {
        actions.applyActivePatternLineStyleToSelection()
      } label: {
        Label(AppStrings.tr("sidebar.pattern_line_style_apply"), systemImage: "paintbrush")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .leatherControlHeight()
      .disabled(state.selectedEntityCount == 0 || state.sharedStyles.isEmpty)
    }
    .padding(.bottom, 3)
  }

  private var roundHoleSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(AppStrings.tr("sidebar.round_hole"))
        .font(.system(size: LeatherDesignMetrics.Typography.section, weight: .semibold))
        .foregroundStyle(LeatherColors.secondaryInk)
        .lineLimit(1)
        .padding(.horizontal, 2)

      PalettePopUpButton(
        items: ProjectRoundHoleKind.allCases.map { kind in
          PalettePopUpItem(
            title: kind.displayName,
            value: kind
          )
        },
        selection: state.activeRoundHoleKind,
        width: contentWidth,
        accessibilityLabel: AppStrings.tr("sidebar.round_hole_kind"),
        onSelect: actions.setActiveRoundHoleKind
      )

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
        .font(.system(size: LeatherDesignMetrics.Typography.section, weight: .semibold))
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

struct PalettePopUpItem<Value: Hashable>: Equatable {
  let title: String
  let value: Value
}

final class PalettePopUpContainer: NSView {
  let button = NSPopUpButton(frame: .zero, pullsDown: false)
  var buttonWidthConstraint: NSLayoutConstraint?
  var preferredWidth: CGFloat = 0

  override var intrinsicContentSize: NSSize {
    NSSize(
      width: preferredWidth,
      height: max(button.intrinsicContentSize.height, LeatherDesignMetrics.Control.height)
    )
  }
}

struct PalettePopUpButton<Value: Hashable>: NSViewRepresentable {
  let items: [PalettePopUpItem<Value>]
  let selection: Value
  let width: CGFloat
  let accessibilityLabel: String
  let onSelect: (Value) -> Void

  @Environment(\.isEnabled) private var isEnabled

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  func makeNSView(context: Context) -> PalettePopUpContainer {
    let container = PalettePopUpContainer()
    let button = container.button
    button.target = context.coordinator
    button.action = #selector(Coordinator.selectionChanged(_:))
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setContentHuggingPriority(.defaultLow, for: .horizontal)
    button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    container.addSubview(button)
    let widthConstraint = button.widthAnchor.constraint(equalToConstant: width)
    container.buttonWidthConstraint = widthConstraint
    container.preferredWidth = width
    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      widthConstraint,
      button.topAnchor.constraint(equalTo: container.topAnchor),
      button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    return container
  }

  func updateNSView(_ container: PalettePopUpContainer, context: Context) {
    context.coordinator.parent = self
    let button = container.button
    if container.preferredWidth != width {
      container.preferredWidth = width
      container.buttonWidthConstraint?.constant = width
      container.invalidateIntrinsicContentSize()
    }
    if context.coordinator.items != items {
      button.removeAllItems()
      for item in items {
        button.addItem(withTitle: item.title)
      }
      context.coordinator.items = items
      container.invalidateIntrinsicContentSize()
    }

    if let selectedIndex = items.firstIndex(where: { $0.value == selection }),
      button.indexOfSelectedItem != selectedIndex
    {
      button.selectItem(at: selectedIndex)
    }
    button.isEnabled = isEnabled
    button.setAccessibilityLabel(accessibilityLabel)
  }

  func sizeThatFits(
    _ proposal: ProposedViewSize,
    nsView container: PalettePopUpContainer,
    context _: Context
  ) -> CGSize? {
    CGSize(
      width: width,
      height: proposal.height ?? container.button.fittingSize.height
    )
  }

  final class Coordinator: NSObject {
    var parent: PalettePopUpButton
    var items: [PalettePopUpItem<Value>] = []

    init(parent: PalettePopUpButton) {
      self.parent = parent
    }

    @objc func selectionChanged(_ sender: NSPopUpButton) {
      let index = sender.indexOfSelectedItem
      guard parent.items.indices.contains(index) else {
        return
      }
      parent.onSelect(parent.items[index].value)
    }
  }
}
