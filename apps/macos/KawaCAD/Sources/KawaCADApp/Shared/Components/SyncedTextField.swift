import SwiftUI

enum SyncedFieldPhase: Equatable {
  case clean
  case editing
  case invalid
  case committing
  case conflict
}

enum SyncedTextFieldMessageKind: Equatable {
  case syntax
  case domain
  case conflict
}

struct SyncedTextFieldMessage: Equatable, Error {
  let kind: SyncedTextFieldMessageKind
  let text: String
}

enum SyncedTextFieldCommitResult: Equatable {
  case success(canonicalValue: String? = nil)
  case failure(SyncedTextFieldMessage)
}

typealias SyncedTextFieldValidator = (String) -> SyncedTextFieldMessage?

struct SyncedTextFieldState: Equatable {
  private(set) var sourceValue: String
  private(set) var draftValue: String
  private(set) var phase: SyncedFieldPhase
  private(set) var message: SyncedTextFieldMessage?
  private(set) var latestSourceValue: String?

  var hasUncommittedEdit: Bool { phase != .clean }
  var isInvalid: Bool { phase == .invalid || phase == .conflict }

  init(sourceValue: String) {
    self.sourceValue = sourceValue
    self.draftValue = sourceValue
    self.phase = .clean
    self.message = nil
    self.latestSourceValue = nil
  }

  mutating func edit(_ value: String) {
    draftValue = value
    if phase != .committing {
      phase = .editing
    }
    message = nil
    latestSourceValue = nil
  }

  mutating func applyValidationMessage(_ message: SyncedTextFieldMessage?) {
    guard phase == .editing || phase == .invalid else {
      return
    }
    self.message = message
    phase = message == nil ? .editing : .invalid
  }

  mutating func syncFromSource(_ value: String, whileFocused: Bool) {
    sourceValue = value
    if !whileFocused || phase == .clean || draftValue == value {
      draftValue = value
      phase = .clean
      message = nil
      latestSourceValue = nil
      return
    }
    latestSourceValue = value
    phase = .conflict
    message = SyncedTextFieldMessage(
      kind: .conflict,
      text: AppStrings.tr("field.conflict.message")
    )
  }

  mutating func commit(_ perform: (String) -> SyncedTextFieldCommitResult) -> Bool {
    let submittedValue = draftValue
    phase = .committing
    switch perform(submittedValue) {
    case .success(let canonicalValue):
      let acceptedValue = canonicalValue ?? submittedValue
      sourceValue = acceptedValue
      draftValue = acceptedValue
      phase = .clean
      message = nil
      latestSourceValue = nil
      return true
    case .failure(let message):
      draftValue = submittedValue
      self.message = message
      phase = message.kind == .conflict ? .conflict : .invalid
      return false
    }
  }

  mutating func revertToSource() {
    draftValue = latestSourceValue ?? sourceValue
    sourceValue = draftValue
    phase = .clean
    message = nil
    latestSourceValue = nil
  }

  mutating func acceptLatestSource() {
    guard let latestSourceValue else {
      revertToSource()
      return
    }
    sourceValue = latestSourceValue
    draftValue = latestSourceValue
    phase = .clean
    message = nil
    self.latestSourceValue = nil
  }
}

struct SyncedTextField: View {
  let placeholder: String
  let sourceValue: String
  let onCommitResult: (String) -> SyncedTextFieldCommitResult
  var width: CGFloat?
  var font: Font = .system(size: 12)
  var textFieldStyle: SyncedTextFieldStyle = .rounded
  var onValidate: SyncedTextFieldValidator?
  var onDraftValueChange: ((String) -> Void)?
  @State private var fieldState: SyncedTextFieldState
  @State private var validationTask: Task<Void, Never>?
  @FocusState private var isFocused: Bool

  init(
    placeholder: String,
    sourceValue: String,
    onCommit: @escaping (String) -> Bool,
    width: CGFloat? = nil,
    font: Font = .system(size: 12),
    textFieldStyle: SyncedTextFieldStyle = .rounded,
    onValidate: SyncedTextFieldValidator? = nil,
    onDraftValueChange: ((String) -> Void)? = nil,
    genericFailureMessage: String = AppStrings.tr("field.error.invalid_value")
  ) {
    self.placeholder = placeholder
    self.sourceValue = sourceValue
    self.onCommitResult = { value in
      onCommit(value)
        ? .success(canonicalValue: nil)
        : .failure(SyncedTextFieldMessage(kind: .domain, text: genericFailureMessage))
    }
    self.width = width
    self.font = font
    self.textFieldStyle = textFieldStyle
    self.onValidate = onValidate
    self.onDraftValueChange = onDraftValueChange
    self._fieldState = State(initialValue: SyncedTextFieldState(sourceValue: sourceValue))
  }

  init(
    placeholder: String,
    sourceValue: String,
    onCommitResult: @escaping (String) -> SyncedTextFieldCommitResult,
    width: CGFloat? = nil,
    font: Font = .system(size: 12),
    textFieldStyle: SyncedTextFieldStyle = .rounded,
    onValidate: SyncedTextFieldValidator? = nil,
    onDraftValueChange: ((String) -> Void)? = nil
  ) {
    self.placeholder = placeholder
    self.sourceValue = sourceValue
    self.onCommitResult = onCommitResult
    self.width = width
    self.font = font
    self.textFieldStyle = textFieldStyle
    self.onValidate = onValidate
    self.onDraftValueChange = onDraftValueChange
    self._fieldState = State(initialValue: SyncedTextFieldState(sourceValue: sourceValue))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      styledTextField
        .font(font)
        .frame(width: width)
        .leatherControlHeight()
        .focused($isFocused)
        .onSubmit(commit)
        .onChange(of: isFocused) { focused in
          if !focused,
            fieldState.hasUncommittedEdit,
            fieldState.phase != .conflict
          {
            commit()
          }
        }

      if let message = fieldState.message {
        Text(message.text)
          .font(.system(size: LeatherDesignMetrics.Typography.section))
          .foregroundStyle(
            message.kind == .conflict ? LeatherColors.warning : LeatherColors.destructive
          )
          .fixedSize(horizontal: false, vertical: true)
      }

      if fieldState.phase == .conflict {
        HStack(spacing: 8) {
          Button(AppStrings.tr("field.conflict.use_latest")) {
            validationTask?.cancel()
            fieldState.acceptLatestSource()
          }
          .buttonStyle(.plain)
          .font(.system(size: LeatherDesignMetrics.Typography.section, weight: .medium))

          Button(AppStrings.tr("field.conflict.apply_draft")) {
            commit()
          }
          .buttonStyle(.plain)
          .font(.system(size: LeatherDesignMetrics.Typography.section, weight: .medium))
        }
      }
    }
    .onAppear {
      fieldState = SyncedTextFieldState(sourceValue: sourceValue)
    }
    .onChange(of: sourceValue) { newValue in
      fieldState.syncFromSource(newValue, whileFocused: isFocused)
    }
    .onChange(of: fieldState.draftValue) { _ in
      onDraftValueChange?(fieldState.draftValue)
      scheduleValidation()
    }
    .onExitCommand {
      validationTask?.cancel()
      fieldState.revertToSource()
      onDraftValueChange?(fieldState.draftValue)
      isFocused = false
    }
  }

  @ViewBuilder
  private var styledTextField: some View {
    switch textFieldStyle {
    case .plain:
      textField
        .textFieldStyle(.plain)
    case .rounded:
      textField
        .textFieldStyle(.roundedBorder)
    }
  }

  private var textField: some View {
    TextField(
      placeholder,
      text: Binding(
        get: { fieldState.draftValue },
        set: { newValue in
          fieldState.edit(newValue)
        }
      )
    )
  }

  private func commit() {
    validationTask?.cancel()
    if let onValidate,
      let message = onValidate(fieldState.draftValue),
      message.kind == .syntax
    {
      fieldState.applyValidationMessage(message)
      return
    }
    let didCommit = fieldState.commit(onCommitResult)
    if !didCommit {
      isFocused = true
    }
  }

  private func scheduleValidation() {
    validationTask?.cancel()
    guard let onValidate, isFocused else {
      return
    }
    let currentDraft = fieldState.draftValue
    validationTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: 300_000_000)
      guard !Task.isCancelled, fieldState.draftValue == currentDraft else {
        return
      }
      fieldState.applyValidationMessage(onValidate(currentDraft))
    }
  }
}

enum SyncedTextFieldStyle {
  case plain
  case rounded
}

struct SyncedNumericFieldRow: View {
  let label: String
  let sourceValue: String
  let unit: String
  let onCommit: (String) -> Bool
  var isEnabled: Bool = true
  var onValidate: SyncedTextFieldValidator? = nil

  init(
    label: String,
    sourceValue: String,
    unit: String,
    onCommit: @escaping (String) -> Bool,
    isEnabled: Bool = true,
    onValidate: SyncedTextFieldValidator? = nil
  ) {
    self.label = label
    self.sourceValue = sourceValue
    self.unit = unit
    self.onCommit = onCommit
    self.isEnabled = isEnabled
    self.onValidate = onValidate
  }

  var body: some View {
    HStack(alignment: .top) {
      Text(label)
        .font(.system(size: 12))
        .foregroundStyle(LeatherColors.secondaryInk)
      Spacer(minLength: 8)
      SyncedTextField(
        placeholder: label,
        sourceValue: sourceValue,
        onCommit: onCommit,
        width: 86,
        onValidate: onValidate
      )
      .disabled(!isEnabled)
      Text(unit)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(LeatherColors.secondaryInk)
    }
    .opacity(isEnabled ? 1.0 : 0.5)
  }
}

enum CommonFieldParsers {
  static func normalizedText(_ text: String, locale: Locale = .current) -> String {
    let decimalSeparator = locale.decimalSeparator ?? "."
    return
      text
      .replacingOccurrences(of: "０", with: "0")
      .replacingOccurrences(of: "１", with: "1")
      .replacingOccurrences(of: "２", with: "2")
      .replacingOccurrences(of: "３", with: "3")
      .replacingOccurrences(of: "４", with: "4")
      .replacingOccurrences(of: "５", with: "5")
      .replacingOccurrences(of: "６", with: "6")
      .replacingOccurrences(of: "７", with: "7")
      .replacingOccurrences(of: "８", with: "8")
      .replacingOccurrences(of: "９", with: "9")
      .replacingOccurrences(of: "－", with: "-")
      .replacingOccurrences(of: "．", with: decimalSeparator)
      .replacingOccurrences(of: "，", with: ",")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func decimalValue(_ text: String, locale: Locale = .current) -> Result<
    Double, SyncedTextFieldMessage
  > {
    let normalized = normalizedText(text, locale: locale)
    if normalized.contains("e") || normalized.contains("E") {
      return .failure(.init(kind: .syntax, text: AppStrings.tr("field.error.no_exponent")))
    }
    let decimalSeparator = locale.decimalSeparator ?? "."
    let alternateSeparator = decimalSeparator == "." ? "," : "."
    if normalized.contains(decimalSeparator), normalized.contains(alternateSeparator) {
      return .failure(.init(kind: .syntax, text: AppStrings.tr("field.error.ambiguous_decimal")))
    }
    if normalized.isEmpty || normalized == "-" || normalized == decimalSeparator
      || normalized == "-\(decimalSeparator)"
    {
      return .failure(.init(kind: .syntax, text: AppStrings.tr("field.error.incomplete_number")))
    }
    if normalized.contains(locale.groupingSeparator ?? ",")
      && (locale.groupingSeparator ?? ",") != decimalSeparator
    {
      return .failure(
        .init(kind: .syntax, text: AppStrings.tr("field.error.grouping_not_supported")))
    }

    let canonical = normalized.replacingOccurrences(of: decimalSeparator, with: ".")
      .replacingOccurrences(of: alternateSeparator, with: ".")
    guard let value = Double(canonical), value.isFinite else {
      return .failure(.init(kind: .syntax, text: AppStrings.tr("field.error.invalid_number")))
    }
    return .success(value)
  }

  static func displayString(
    for value: Double,
    maximumFractionDigits: Int,
    locale: Locale = .current
  ) -> String {
    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = maximumFractionDigits
    formatter.usesGroupingSeparator = false
    return formatter.string(from: NSNumber(value: value == -0 ? 0 : value)) ?? String(value)
  }
}

enum CommonFieldValidators {
  private static func canonicalDecimalValue(
    _ text: String,
    value: Double,
    maximumFractionDigits: Int
  ) -> String {
    let preferred = CommonFieldParsers.displayString(
      for: value,
      maximumFractionDigits: maximumFractionDigits
    )
    switch CommonFieldParsers.decimalValue(preferred) {
    case .success(let formattedValue) where formattedValue == value:
      return preferred
    default:
      let normalized = CommonFieldParsers.normalizedText(text)
      return
        normalized
        .replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
        .replacingOccurrences(of: ",", with: ".")
    }
  }

  static func optionalDecimalSyntax(_ text: String) -> SyncedTextFieldMessage? {
    let normalized = CommonFieldParsers.normalizedText(text)
    if normalized.isEmpty || normalized == "-" || normalized.hasSuffix(".")
      || normalized.hasSuffix(",")
    {
      return nil
    }
    switch CommonFieldParsers.decimalValue(normalized) {
    case .success:
      return nil
    case .failure(let message):
      return message
    }
  }

  static func requiredName(_ text: String) -> SyncedTextFieldCommitResult {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return .failure(.init(kind: .domain, text: AppStrings.tr("field.error.name_required")))
    }
    return .success(canonicalValue: trimmed)
  }

  static func positiveNumber(_ text: String, maximumFractionDigits: Int = 2)
    -> SyncedTextFieldCommitResult
  {
    switch CommonFieldParsers.decimalValue(text) {
    case .success(let value):
      guard value > 0 else {
        return .failure(.init(kind: .domain, text: AppStrings.tr("field.error.positive_required")))
      }
      return .success(
        canonicalValue: canonicalDecimalValue(
          text, value: value, maximumFractionDigits: maximumFractionDigits))
    case .failure(let message):
      return .failure(message)
    }
  }

  static func nonNegativeNumber(_ text: String, maximumFractionDigits: Int = 3)
    -> SyncedTextFieldCommitResult
  {
    switch CommonFieldParsers.decimalValue(text) {
    case .success(let value):
      guard value >= 0 else {
        return .failure(
          .init(kind: .domain, text: AppStrings.tr("field.error.non_negative_required")))
      }
      return .success(
        canonicalValue: canonicalDecimalValue(
          text, value: value, maximumFractionDigits: maximumFractionDigits))
    case .failure(let message):
      return .failure(message)
    }
  }

  static func hexColor(_ text: String) -> SyncedTextFieldCommitResult {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    let canonical = trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
    let body = canonical.dropFirst()
    guard body.count == 6, body.allSatisfy(\.isHexDigit) else {
      return .failure(.init(kind: .domain, text: AppStrings.tr("field.error.hex_color")))
    }
    return .success(canonicalValue: canonical)
  }
}
