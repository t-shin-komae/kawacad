import Foundation
import Testing

@testable import KawaCADApp

@Test("保存済み文書はファイル名を主識別子にし、異なるプロジェクト名を併記する")
func saved_document_window_title_identifies_file_and_project_name() {
  let presentation = DocumentWindowPresentation(
    documentName: "丸型キーホルダー",
    documentURL: URL(fileURLWithPath: "/tmp/keyholder-round.kawa"),
    isDocumentEdited: false
  )

  #expect(presentation.title == "keyholder-round.kawa — 丸型キーホルダー")
  #expect(presentation.accessibilityLabel.contains("keyholder-round.kawa"))
  #expect(presentation.accessibilityLabel.contains("丸型キーホルダー"))
  #expect(presentation.accessibilityLabel.contains(AppStrings.tr("window.accessibility.saved")))
}
@Test("実質同名の保存済み文書はファイル名だけをタイトルにする")
func saved_document_window_title_omits_duplicate_project_name() {
  let presentation = DocumentWindowPresentation(
    documentName: "KeyHolder",
    documentURL: URL(fileURLWithPath: "/tmp/keyholder.kawa"),
    isDocumentEdited: true
  )

  #expect(presentation.title == "keyholder.kawa")
  #expect(presentation.accessibilityLabel.contains(AppStrings.tr("window.accessibility.edited")))
}

@Test("未保存文書は内部プロジェクト名と未保存状態をタイトルとアクセシビリティに出す")
func unsaved_document_window_title_and_accessibility_identify_state() {
  let presentation = DocumentWindowPresentation(
    documentName: "新しい型紙",
    documentURL: nil,
    isDocumentEdited: true
  )

  #expect(presentation.title == "新しい型紙 — 未保存")
  #expect(presentation.accessibilityLabel.contains("新しい型紙"))
  #expect(presentation.accessibilityLabel.contains(AppStrings.tr("window.accessibility.edited")))
}

@Test("アプリ状態のタイトルはプロジェクト名変更と保存先変更を独立して反映する")
@MainActor
func app_state_window_presentation_updates_for_project_rename_and_save_as() {
  let initialState = makeDocumentState(name: "内部名称")
  let renamedState = makeDocumentState(name: "変更後名称")
  let store = StubDocumentSessionAdapter(createNewDocumentState: initialState)
  store.applyCommandState = renamedState
  let appState = AppCoordinator(documentAdapter: store)
  store.documentURL = URL(fileURLWithPath: "/tmp/old-file.kawa")

  #expect(appState.actions.document.documentWindowPresentation.title == "old-file.kawa — 内部名称")

  appState.actions.document.renameDocument(to: "変更後名称")
  #expect(appState.actions.document.documentWindowPresentation.title == "old-file.kawa — 変更後名称")

  store.documentURL = URL(fileURLWithPath: "/tmp/new-file.kawa")
  #expect(appState.actions.document.documentWindowPresentation.title == "new-file.kawa — 変更後名称")
}
