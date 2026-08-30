import SwiftUI

struct DetailRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
        .font(.system(size: 11))
        .foregroundStyle(LeatherColors.secondaryInk)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .frame(minWidth: 72, alignment: .leading)
      Spacer(minLength: 12)
      Text(value)
        .font(.system(size: 12))
        .foregroundStyle(LeatherColors.ink)
        .multilineTextAlignment(.trailing)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }
}

struct SharedStyleSelectionField: View {
  let selectedStyleID: String?
  let sharedStyles: [ProjectSharedStyle]
  let onChange: (String?) -> Bool

  private let noStyleID = "__no_shared_style__"

  var body: some View {
    Picker(
      AppStrings.tr("inspector.shared_style"),
      selection: Binding(
        get: { selectedStyleID ?? noStyleID },
        set: { value in
          _ = onChange(value == noStyleID ? nil : value)
        }
      )
    ) {
      Text(AppStrings.tr("inspector.shared_style_none")).tag(noStyleID)
      ForEach(sharedStyles) { style in
        Text(style.name).tag(style.id)
      }
    }
    .font(.system(size: 12))
    .disabled(sharedStyles.isEmpty)
  }
}

enum StyleEditorConstants {
  static let customColorSelectionID = "__custom_color__"
  static let customStrokeWidthSelection = -1.0
}

struct StyleEditorRow<AccessoryButtons: View, DeleteButton: View>: View {
  let style: ProjectSharedStyle
  let namePlaceholder: String
  let onChange: (ProjectSharedStyle) -> Bool
  let accessoryButtons: AccessoryButtons
  let deleteButton: DeleteButton

  @State private var customEditor: LayerStyleCustomEditor?

  var body: some View {
    InsetSurface {
      VStack(alignment: .leading, spacing: 7) {
        HStack(spacing: 8) {
          LayerColorSwatch(colorHex: normalizedHex(style.colorHex), size: 11)
          SyncedTextField(
            placeholder: namePlaceholder,
            sourceValue: style.name,
            onCommitResult: { value in
              switch CommonFieldValidators.requiredName(value) {
              case .success(let canonicalValue):
                guard onChange(style.withName(canonicalValue ?? value)) else {
                  return .failure(
                    .init(kind: .domain, text: AppStrings.tr("field.error.invalid_value")))
                }
                return .success(canonicalValue: canonicalValue)
              case .failure(let message):
                return .failure(message)
              }
            },
            font: .system(size: 12, weight: .semibold)
          )
          Spacer(minLength: 4)
          accessoryButtons
          deleteButton
        }

        styleSummary

        if let customEditor {
          customStyleEditor(customEditor)
        }
      }
    }
  }

  private var styleSummary: some View {
    HStack(alignment: .top, spacing: 8) {
      linePatternMenu
      colorMenu
      strokeWidthMenu
    }
    .padding(7)
    .background(LeatherColors.insetFill)
    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 7, style: .continuous)
        .stroke(LeatherColors.panelStroke.opacity(0.42), lineWidth: 1)
    )
  }

  private var linePatternMenu: some View {
    LayerStylePickerField(
      title: AppStrings.tr("inspector.line_pattern"), value: style.linePattern.displayName
    ) {
      LinePatternPreview(pattern: style.linePattern, colorHex: normalizedHex(style.colorHex))
        .frame(width: 34, height: 10)
    } control: {
      Picker(AppStrings.tr("inspector.line_pattern"), selection: linePatternSelection) {
        ForEach(LinePattern.allCases) { pattern in
          Text(pattern.displayName).tag(pattern)
        }
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .controlSize(.small)
      .leatherControlHeight()
    }
    .help(AppStrings.tr("inspector.select_line_pattern"))
  }

  private var colorMenu: some View {
    LayerStylePickerField(title: AppStrings.tr("inspector.color"), value: colorDisplayName) {
      LayerColorSwatch(colorHex: normalizedHex(style.colorHex), size: 14)
    } control: {
      Picker(AppStrings.tr("inspector.color"), selection: colorSelection) {
        ForEach(LayerColorPreset.all) { preset in
          Text(preset.displayName).tag(preset.id)
        }
        Text(AppStrings.tr("inspector.custom_option")).tag(
          StyleEditorConstants.customColorSelectionID)
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .controlSize(.small)
      .leatherControlHeight()
    }
    .help(AppStrings.tr("inspector.select_color"))
  }

  private var strokeWidthMenu: some View {
    LayerStylePickerField(
      title: AppStrings.tr("inspector.line_width"), value: strokeWidthDisplayName
    ) {
      LayerStrokeWidthPreview(widthMM: style.strokeWidthMM, colorHex: normalizedHex(style.colorHex))
        .frame(width: 34, height: 10)
    } control: {
      Picker(AppStrings.tr("inspector.line_width"), selection: strokeWidthSelection) {
        ForEach(LayerStrokeWidthPreset.all) { preset in
          Text(preset.displayName).tag(preset.widthMM)
        }
        Text(AppStrings.tr("inspector.custom_option")).tag(
          StyleEditorConstants.customStrokeWidthSelection)
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .controlSize(.small)
      .leatherControlHeight()
    }
    .help(AppStrings.tr("inspector.select_line_width"))
  }

  @ViewBuilder
  private func customStyleEditor(_ editor: LayerStyleCustomEditor) -> some View {
    HStack(spacing: 8) {
      switch editor {
      case .color:
        Text(AppStrings.tr("inspector.custom_color"))
          .font(.system(size: LeatherDesignMetrics.Typography.label, weight: .medium))
          .foregroundStyle(LeatherColors.secondaryInk)
        SyncedTextField(
          placeholder: "#RRGGBB",
          sourceValue: normalizedHex(style.colorHex),
          onCommitResult: { value in
            switch CommonFieldValidators.hexColor(value) {
            case .success(let canonicalValue):
              return commitColorResult(canonicalValue)
            case .failure(let message):
              return .failure(message)
            }
          },
          width: 92,
          font: .system(size: 11, weight: .medium),
          onValidate: hexColorSyntaxValidation
        )
      case .strokeWidth:
        Text(AppStrings.tr("inspector.custom_line_width"))
          .font(.system(size: LeatherDesignMetrics.Typography.label, weight: .medium))
          .foregroundStyle(LeatherColors.secondaryInk)
        SyncedTextField(
          placeholder: AppStrings.tr("inspector.stroke_width_placeholder"),
          sourceValue: CommonFieldParsers.displayString(
            for: style.strokeWidthMM, maximumFractionDigits: 2),
          onCommitResult: commitStrokeWidthResult,
          width: 74,
          font: .system(size: 11, weight: .medium),
          onValidate: CommonFieldValidators.optionalDecimalSyntax
        )
        Text(AppStrings.tr("common.unit_mm"))
          .font(.system(size: LeatherDesignMetrics.Typography.label))
          .foregroundStyle(LeatherColors.secondaryInk)
      }
      Spacer(minLength: 0)
      Button {
        customEditor = nil
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .semibold))
          .frame(width: 24, height: 24)
      }
      .buttonStyle(.borderless)
      .foregroundStyle(LeatherColors.secondaryInk)
      .accessibilityLabel(AppStrings.tr("inspector.close_custom_input"))
      .help(AppStrings.tr("inspector.close_custom_input"))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(LeatherColors.insetFill)
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
  }

  private var linePatternSelection: Binding<LinePattern> {
    Binding(
      get: { style.linePattern },
      set: { pattern in
        customEditor = nil
        _ = commitStyle(
          colorHex: style.colorHex, strokeWidthMM: style.strokeWidthMM, pattern: pattern)
      }
    )
  }

  private var colorSelection: Binding<String> {
    Binding(
      get: {
        LayerColorPreset.matching(normalizedHex(style.colorHex))?.id
          ?? StyleEditorConstants.customColorSelectionID
      },
      set: { selection in
        guard selection != StyleEditorConstants.customColorSelectionID else {
          customEditor = .color
          return
        }
        if let preset = LayerColorPreset.all.first(where: { $0.id == selection }) {
          customEditor = nil
          _ = commitColor(preset.colorHex)
        }
      }
    )
  }

  private var strokeWidthSelection: Binding<Double> {
    Binding(
      get: {
        LayerStrokeWidthPreset.matching(style.strokeWidthMM)?.widthMM
          ?? StyleEditorConstants.customStrokeWidthSelection
      },
      set: { selection in
        guard selection != StyleEditorConstants.customStrokeWidthSelection else {
          customEditor = .strokeWidth
          return
        }
        customEditor = nil
        _ = commitStrokeWidth(String(format: "%.2f", selection))
      }
    )
  }

  private func commitColor(_ value: String) -> Bool {
    switch CommonFieldValidators.hexColor(value) {
    case .success(let canonicalValue):
      return commitColorResult(canonicalValue) == .success(canonicalValue: canonicalValue)
    case .failure:
      return false
    }
  }

  private func commitStrokeWidth(_ value: String) -> Bool {
    switch commitStrokeWidthResult(value) {
    case .success:
      return true
    case .failure:
      return false
    }
  }

  private func commitColorResult(_ canonical: String?) -> SyncedTextFieldCommitResult {
    let value = canonical ?? normalizedHex(style.colorHex)
    guard
      commitStyle(colorHex: value, strokeWidthMM: style.strokeWidthMM, pattern: style.linePattern)
    else {
      return .failure(.init(kind: .domain, text: AppStrings.tr("field.error.invalid_value")))
    }
    return .success(canonicalValue: value)
  }

  private func commitStrokeWidthResult(_ value: String) -> SyncedTextFieldCommitResult {
    switch CommonFieldValidators.positiveNumber(value, maximumFractionDigits: 2) {
    case .success(let canonicalValue):
      guard case .success(let width) = CommonFieldParsers.decimalValue(canonicalValue ?? value),
        commitStyle(colorHex: style.colorHex, strokeWidthMM: width, pattern: style.linePattern)
      else {
        return .failure(.init(kind: .domain, text: AppStrings.tr("field.error.invalid_value")))
      }
      return .success(canonicalValue: canonicalValue)
    case .failure(let message):
      return .failure(message)
    }
  }

  private func commitStyle(colorHex: String, strokeWidthMM: Double, pattern: LinePattern) -> Bool {
    onChange(
      style.withStyle(colorHex: colorHex, strokeWidthMM: strokeWidthMM, linePattern: pattern))
  }

  private func normalizedHex(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
  }

  private var colorDisplayName: String {
    LayerColorPreset.matching(normalizedHex(style.colorHex))?.displayName
      ?? normalizedHex(style.colorHex)
  }

  private var strokeWidthDisplayName: String {
    LayerStrokeWidthPreset.matching(style.strokeWidthMM)?.displayName
      ?? String(format: "%.2f mm", style.strokeWidthMM)
  }

  private func hexColorSyntaxValidation(_ value: String) -> SyncedTextFieldMessage? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return nil
    }
    let canonical = trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
    if canonical.count < 7 {
      return nil
    }
    return switch CommonFieldValidators.hexColor(canonical) {
    case .success:
      nil
    case .failure(let message):
      message
    }
  }

}

enum LayerStyleCustomEditor {
  case color
  case strokeWidth
}

struct LayerStylePickerField<Preview: View, Control: View>: View {
  let title: String
  let value: String
  @ViewBuilder let preview: () -> Preview
  @ViewBuilder let control: () -> Control

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(alignment: .center, spacing: 6) {
        Text(title)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(LeatherColors.secondaryInk)
        preview()
          .frame(width: 34, alignment: .leading)
      }

      control()
        .frame(maxWidth: .infinity, alignment: .leading)
        .leatherControlHeight()

      Text(value)
        .font(.system(size: LeatherDesignMetrics.Typography.label, weight: .medium))
        .foregroundStyle(LeatherColors.secondaryInk)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
  }
}

struct LayerColorSwatch: View {
  let colorHex: String
  let size: CGFloat

  var body: some View {
    RoundedRectangle(cornerRadius: 3, style: .continuous)
      .fill(Color(hex: colorHex))
      .frame(width: size, height: size)
      .overlay(
        RoundedRectangle(cornerRadius: 3, style: .continuous)
          .stroke(LeatherColors.panelStroke.opacity(0.65), lineWidth: 0.7)
      )
  }
}

struct LayerStrokeWidthPreview: View {
  let widthMM: Double
  let colorHex: String

  var body: some View {
    GeometryReader { proxy in
      Path { path in
        let y = proxy.size.height / 2
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
      }
      .stroke(
        Color(hex: colorHex),
        style: StrokeStyle(lineWidth: max(1.0, min(4.0, CGFloat(widthMM) * 5.0)))
      )
    }
  }
}

struct LinePatternPreview: View {
  let pattern: LinePattern
  let colorHex: String

  var body: some View {
    GeometryReader { proxy in
      Path { path in
        let y = proxy.size.height / 2
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
      }
      .stroke(
        Color(hex: colorHex),
        style: StrokeStyle(lineWidth: 2, dash: dashPattern)
      )
    }
  }

  private var dashPattern: [CGFloat] {
    switch pattern {
    case .solid:
      return []
    case .dashed, .construction:
      return [8, 5]
    case .dotted:
      return [2, 4]
    }
  }
}

struct ParameterEditor: View {
  let parameter: ProjectParameter
  let appState: ParameterInspectorModel

  var body: some View {
    InsetSurface {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          VStack(alignment: .leading, spacing: 3) {
            SyncedTextField(
              placeholder: AppStrings.tr("inspector.parameter_name_placeholder"),
              sourceValue: parameter.name,
              onCommitResult: commitNameResult
            )
            Text(parameterUsageText)
              .font(.system(size: LeatherDesignMetrics.Typography.label))
              .foregroundStyle(LeatherColors.secondaryInk)
              .lineLimit(1)
          }

          Spacer(minLength: 6)

          SyncedTextField(
            placeholder: AppStrings.tr("inspector.value"),
            sourceValue: Self.format(parameter.valueMM),
            onCommitResult: commitValueResult,
            width: 82,
            onValidate: CommonFieldValidators.optionalDecimalSyntax
          )

          Text(parameter.unitLabel)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(LeatherColors.secondaryInk)

          Button(role: .destructive) {
            appState.actions.deleteParameter(parameter)
          } label: {
            Image(systemName: "trash")
              .frame(width: 22, height: 22)
          }
          .buttonStyle(.borderless)
        }

        SyncedTextField(
          placeholder: AppStrings.tr("inspector.parameter_memo_placeholder"),
          sourceValue: parameter.memo,
          onCommit: commitMemo
        )

        HStack(spacing: 6) {
          Image(systemName: parameter.isUnused ? "exclamationmark.circle" : "link")
            .foregroundStyle(
              parameter.isUnused ? LeatherColors.warning : LeatherColors.secondaryInk)
          Text(
            parameter.isUnused
              ? AppStrings.tr("inspector.parameter_unused_hint")
              : AppStrings.tr("inspector.parameter_used_hint")
          )
          .font(.system(size: 11))
          .foregroundStyle(parameter.isUnused ? LeatherColors.warning : LeatherColors.secondaryInk)
          .lineLimit(2)
        }
      }
    }
  }

  private func commitNameResult(_ value: String) -> SyncedTextFieldCommitResult {
    switch CommonFieldValidators.requiredName(value) {
    case .success(let canonicalValue):
      guard
        commitParameter(
          name: canonicalValue ?? value, valueMM: parameter.valueMM, memo: parameter.memo)
      else {
        return .failure(.init(kind: .domain, text: AppStrings.tr("field.error.invalid_value")))
      }
      return .success(canonicalValue: canonicalValue)
    case .failure(let message):
      return .failure(message)
    }
  }

  private func commitValueResult(_ text: String) -> SyncedTextFieldCommitResult {
    switch CommonFieldValidators.nonNegativeNumber(text) {
    case .success(let canonicalValue):
      guard case .success(let value) = CommonFieldParsers.decimalValue(canonicalValue ?? text),
        commitParameter(name: parameter.name, valueMM: value, memo: parameter.memo)
      else {
        return .failure(.init(kind: .domain, text: AppStrings.tr("field.error.invalid_value")))
      }
      return .success(canonicalValue: canonicalValue)
    case .failure(let message):
      return .failure(message)
    }
  }

  private func commitMemo(_ value: String) -> Bool {
    commitParameter(name: parameter.name, valueMM: parameter.valueMM, memo: value)
  }

  private func commitParameter(name: String, valueMM: Double, memo: String) -> Bool {
    appState.actions.updateParameter(
      ProjectParameter(
        id: parameter.id,
        name: name,
        valueMM: valueMM,
        unit: parameter.unit,
        memo: memo,
        usageCount: parameter.usageCount,
        usedConstraintIDs: parameter.usedConstraintIDs
      )
    )
  }

  private var parameterUsageText: String {
    if parameter.isUnused {
      return AppStrings.tr("inspector.parameter_unused")
    }
    return AppStrings.tr("inspector.parameter_usage", parameter.usageCount)
  }

  private static func format(_ value: Double) -> String {
    String(format: "%.2f", value)
  }
}

struct WrapChips: View {
  let items: [String]

  var body: some View {
    FlowLayout(items: items) { item in
      Text(item)
        .font(.system(size: LeatherDesignMetrics.Typography.label, weight: .semibold))
        .foregroundStyle(LeatherColors.secondaryInk)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(LeatherColors.insetFill)
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .stroke(LeatherColors.panelStroke.opacity(0.45))
        )
    }
  }
}

struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
  let items: Data
  let content: (Data.Element) -> Content

  init(items: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
    self.items = items
    self.content = content
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], alignment: .leading, spacing: 6
      ) {
        ForEach(Array(items), id: \.self) { item in
          content(item)
        }
      }
    }
  }
}
