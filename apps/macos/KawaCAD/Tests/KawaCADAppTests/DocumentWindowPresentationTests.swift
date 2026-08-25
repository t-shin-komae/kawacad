import Foundation
import Testing

@testable import KawaCADApp

@Test("保存済み文書はファイル名をウインドウタイトルにする")
func saved_document_window_title_uses_file_name() {
  let presentation = DocumentWindowPresentation(
    documentURL: URL(fileURLWithPath: "/tmp/keyholder-round.kawa"),
    isDocumentEdited: false
  )

  #expect(presentation.title == "keyholder-round.kawa")
  #expect(presentation.accessibilityLabel.contains("keyholder-round.kawa"))
  #expect(presentation.accessibilityLabel.contains(AppStrings.tr("window.accessibility.saved")))
}

@Test("未保存文書は既定名と未保存状態をタイトルにする")
func unsaved_document_window_title_identifies_state() {
  let presentation = DocumentWindowPresentation(
    documentURL: nil,
    isDocumentEdited: true
  )

  #expect(presentation.title == "無題プロジェクト — 未保存")
  #expect(presentation.accessibilityLabel.contains("無題プロジェクト"))
  #expect(presentation.accessibilityLabel.contains(AppStrings.tr("window.accessibility.edited")))
}

@Test("アプリ状態のタイトルは保存先のファイル名を反映する")
@MainActor
func app_state_window_presentation_updates_for_save_as() {
  let store = StubDocumentSessionAdapter(createNewDocumentState: makeDocumentState())
  let appState = AppCoordinator(documentAdapter: store)
  store.documentURL = URL(fileURLWithPath: "/tmp/old-file.kawa")

  #expect(appState.actions.document.documentWindowPresentation.title == "old-file.kawa")

  store.documentURL = URL(fileURLWithPath: "/tmp/new-file.kawa")
  #expect(appState.actions.document.documentWindowPresentation.title == "new-file.kawa")
}
