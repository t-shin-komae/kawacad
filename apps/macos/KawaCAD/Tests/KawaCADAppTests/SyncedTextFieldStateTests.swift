import Foundation
import Testing

@testable import KawaCADApp

@Test("同期入力状態は clean 時の外部更新をそのまま反映する")
func synced_text_field_state_syncs_from_source_when_clean() {
  var state = SyncedTextFieldState(sourceValue: "10.00")

  state.syncFromSource("14.00", whileFocused: false)

  #expect(state.draftValue == "14.00")
  #expect(state.phase == .clean)
}

@Test("同期入力状態は commit 成功時に canonical value を採用する")
func synced_text_field_state_keeps_submitted_value_after_successful_commit() {
  var submittedValue: String?
  var state = SyncedTextFieldState(sourceValue: "1.00")

  state.edit("2.500")
  let didCommit = state.commit { value in
    submittedValue = value
    return .success(canonicalValue: "2.5")
  }

  #expect(didCommit)
  #expect(submittedValue == "2.500")
  #expect(state.draftValue == "2.5")
  #expect(state.phase == .clean)
}

@Test("同期入力状態は commit 失敗時に draft とエラーメッセージを保持する")
func synced_text_field_state_keeps_invalid_draft_after_failed_commit() {
  var state = SyncedTextFieldState(sourceValue: "#111111")

  state.edit("#22")
  let didCommit = state.commit { _ in
    .failure(.init(kind: .domain, text: "#RRGGBB形式で入力してください"))
  }

  #expect(!didCommit)
  #expect(state.draftValue == "#22")
  #expect(state.phase == .invalid)
  #expect(state.message?.text == "#RRGGBB形式で入力してください")
}

@Test("同期入力状態は編集中の外部更新を conflict として保持する")
func synced_text_field_state_enters_conflict_when_source_changes_while_editing() {
  var state = SyncedTextFieldState(sourceValue: "10.00")

  state.edit("12.00")
  state.syncFromSource("14.00", whileFocused: true)

  #expect(state.phase == .conflict)
  #expect(state.draftValue == "12.00")
  #expect(state.latestSourceValue == "14.00")
  #expect(state.message?.kind == .conflict)
}

@Test("同期入力状態は最新値採用で conflict を解消する")
func synced_text_field_state_accepts_latest_value() {
  var state = SyncedTextFieldState(sourceValue: "10.00")

  state.edit("12.00")
  state.syncFromSource("14.00", whileFocused: true)
  state.acceptLatestSource()

  #expect(state.phase == .clean)
  #expect(state.draftValue == "14.00")
  #expect(state.message == nil)
}

@Test("共通数値 parser は locale 小数点と ASCII ドットを受け付ける")
func common_field_parsers_accept_locale_decimal_and_ascii_period() {
  let locale = Locale(identifier: "fr_FR")

  #expect(decimal(CommonFieldParsers.decimalValue("12,5", locale: locale)) == 12.5)
  #expect(decimal(CommonFieldParsers.decimalValue("12.5", locale: locale)) == 12.5)
}

@Test("共通数値 parser は指数表記と曖昧な区切りを拒否する")
func common_field_parsers_reject_exponent_and_ambiguous_separators() {
  #expect(errorMessage(CommonFieldParsers.decimalValue("1e3")) == "指数表記は使用できません")
  #expect(errorMessage(CommonFieldParsers.decimalValue("1,2.3")) == "小数点の書式が曖昧です")
}

@Test("共通 validator は正の値と色コードを canonical 化する")
func common_field_validators_produce_canonical_values() {
  #expect(CommonFieldValidators.positiveNumber("１２.５").canonicalValue == "12.5")
  #expect(CommonFieldValidators.positiveNumber("0.004").canonicalValue == "0.004")
  #expect(CommonFieldValidators.hexColor("aabbcc").canonicalValue == "#AABBCC")
}

private func decimal(_ result: Result<Double, SyncedTextFieldMessage>) -> Double? {
  switch result {
  case .success(let value):
    return value
  case .failure:
    return nil
  }
}

private func errorMessage(_ result: Result<Double, SyncedTextFieldMessage>) -> String? {
  switch result {
  case .success:
    return nil
  case .failure(let message):
    return message.text
  }
}

extension SyncedTextFieldCommitResult {
  fileprivate var canonicalValue: String? {
    switch self {
    case .success(let canonicalValue):
      return canonicalValue
    case .failure:
      return nil
    }
  }
}
