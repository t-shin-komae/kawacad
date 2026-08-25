import Foundation
import KawaCADOutput
import Testing

@testable import KawaCADApp

@Test("UC4 DocumentSessionAdapter の Undo/Redo は過去の状態を復元する")
func uc4_document_session_adapter_undo_redo_restores_previous_states() {
  let backend = ScriptedDocumentSessionBackend(
    states: [
      "root": makeDocumentState(
        name: "Root",
        entities: []
      ),
      "after-add": makeDocumentState(
        name: "After Add",
        entities: [
          lineEntity(id: "entity:test-line", start: .zero, end: .init(xMM: 20.0, yMM: 0.0))
        ]
      ),
    ],
    transitions: [
      "root": ["after-add"],
      "after-add": ["root"],
    ]
  )

  let adapter = DocumentSessionAdapter(backend: backend)
  _ = requireSuccess(adapter.createNewDocument(viewMode: .editDisplay))
  #expect(adapter.hasDocument)
  #expect(!adapter.canUndo)
  #expect(!adapter.canRedo)

  _ = requireSuccess(adapter.applyCommand(testCommand(), viewMode: .editDisplay))
  #expect(adapter.canUndo)
  #expect(!adapter.canRedo)

  _ = requireSuccess(adapter.undo(viewMode: .editDisplay))
  #expect(!adapter.canUndo)
  #expect(adapter.canRedo)

  _ = requireSuccess(adapter.redo(viewMode: .editDisplay))
  #expect(adapter.canUndo)
  #expect(!adapter.canRedo)

  #expect(backend.createCount == 1)
}

@Test("UC4 DocumentSessionAdapter の空履歴 Undo/Redo は拒否され、Redo は新規変更で破棄される")
func uc4_document_session_adapter_empty_history_and_redo_discard_are_handled() {
  let backend = ScriptedDocumentSessionBackend(
    states: [
      "root": makeDocumentState(
        name: "Root",
        entities: []
      ),
      "after-add": makeDocumentState(
        name: "After Add",
        entities: [
          lineEntity(id: "entity:test-line", start: .zero, end: .init(xMM: 20.0, yMM: 0.0))
        ]
      ),
    ],
    transitions: [
      "root": ["after-add"],
      "after-add": ["root"],
    ]
  )

  let adapter = DocumentSessionAdapter(backend: backend)
  _ = requireSuccess(adapter.createNewDocument(viewMode: .editDisplay))
  #expect(!adapter.canUndo)
  #expect(!adapter.canRedo)

  switch adapter.undo(viewMode: .editDisplay) {
  case .failure(let message):
    #expect(message == "元に戻す操作はありません")
  case .success:
    Issue.record("expected empty undo to fail")
  }
  switch adapter.redo(viewMode: .editDisplay) {
  case .failure(let message):
    #expect(message == "やり直す操作はありません")
  case .success:
    Issue.record("expected empty redo to fail")
  }

  _ = requireSuccess(adapter.applyCommand(testCommand(), viewMode: .editDisplay))
  #expect(adapter.canUndo)
  #expect(!adapter.canRedo)

  _ = requireSuccess(adapter.undo(viewMode: .editDisplay))
  #expect(!adapter.canUndo)
  #expect(adapter.canRedo)

  _ = requireSuccess(adapter.applyCommand(testCommand(), viewMode: .editDisplay))
  #expect(adapter.canUndo)
  #expect(!adapter.canRedo)

  switch adapter.redo(viewMode: .editDisplay) {
  case .failure(let message):
    #expect(message == "やり直す操作はありません")
  case .success:
    Issue.record("expected redo to be cleared after a new change")
  }
  #expect(!adapter.canRedo)
  #expect(backend.createCount == 1)
}

@Test("UC5 DocumentSessionAdapter の保存と読み込みは同じ状態を再現する")
func uc5_document_session_adapter_save_and_reload_preserves_state() {
  let originalState = makeDocumentState(
    name: "Round Trip",
    entities: [
      pointEntity(id: "entity:anchor", point: .zero),
      lineEntity(id: "entity:line-a", start: .zero, end: .init(xMM: 30.0, yMM: 0.0)),
    ],
    constraintStatus: .underConstrained
  )
  let editedState = makeDocumentState(
    name: "Round Trip Saved",
    entities: [
      pointEntity(id: "entity:anchor", point: .zero),
      lineEntity(id: "entity:line-a", start: .zero, end: .init(xMM: 45.0, yMM: 0.0)),
    ],
    constraintStatus: .underConstrained
  )
  let backend = RoundTripDocumentSessionBackend(
    states: [
      "original": originalState,
      "edited": editedState,
    ],
    transitions: [
      "original": ["edited"]
    ]
  )
  let adapter = DocumentSessionAdapter(backend: backend)

  let created = requireSuccess(
    adapter.createNewDocument(viewMode: .editDisplay))
  #expect(created == originalState.withPersistence(isDirty: false, revision: "original"))
  #expect(adapter.documentURL == nil)
  #expect(!adapter.isDocumentDirty)

  let updated = requireSuccess(adapter.applyCommand(testCommand(), viewMode: .editDisplay))
  #expect(
    updated
      == editedState
      .withHistory(canUndo: true, canRedo: false)
      .withPersistence(isDirty: true, revision: "edited"))
  #expect(adapter.canUndo)
  #expect(!adapter.canRedo)
  #expect(adapter.isDocumentDirty)

  let saveURL = uniqueTempURL("round-trip.kawa")
  requireSuccess(adapter.saveDocument(to: saveURL), context: "saveDocument")
  #expect(adapter.documentURL == saveURL)
  #expect(!adapter.isDocumentDirty)

  let snapshotURL = uniqueTempURL("round-trip-snapshot.kawa")
  requireSuccess(adapter.writeSnapshot(to: snapshotURL), context: "writeSnapshot")
  #expect(adapter.documentURL == saveURL)

  let reopened = requireSuccess(adapter.openDocument(at: saveURL, viewMode: .editDisplay))
  #expect(reopened == editedState.withPersistence(isDirty: false, revision: "edited"))
  #expect(adapter.documentURL == saveURL)
  #expect(!adapter.canUndo)
  #expect(!adapter.canRedo)
  #expect(!adapter.isDocumentDirty)
  #expect(backend.createCount == 1)
  #expect(backend.savedPaths == [saveURL.path, snapshotURL.path])
  #expect(backend.openedPaths == [saveURL.path])
}

@Test("DocumentSessionAdapter は Undo で保存チェックポイントへ戻ると clean になる")
func document_session_adapter_restores_clean_checkpoint_after_undo() {
  let rootState = makeDocumentState(name: "Checkpoint Root", entities: [])
  let editedState = makeDocumentState(
    name: "Checkpoint Edited",
    entities: [lineEntity(id: "entity:line", start: .zero, end: .init(xMM: 10.0, yMM: 0.0))]
  )
  let backend = ScriptedDocumentSessionBackend(
    states: [
      "root": rootState,
      "edited": editedState,
    ],
    transitions: [
      "root": ["edited"],
      "edited": ["root"],
    ]
  )
  let adapter = DocumentSessionAdapter(backend: backend)

  _ = requireSuccess(adapter.createNewDocument(viewMode: .editDisplay))
  _ = requireSuccess(adapter.applyCommand(testCommand(), viewMode: .editDisplay))
  #expect(adapter.isDocumentDirty)

  _ = requireSuccess(adapter.undo(viewMode: .editDisplay))
  #expect(!adapter.isDocumentDirty)

  _ = requireSuccess(adapter.redo(viewMode: .editDisplay))
  #expect(adapter.isDocumentDirty)
}

@Test("DocumentSessionAdapter は output preview 固有の表示差分では dirty にならない")
func document_session_adapter_ignores_output_preview_only_differences_for_dirty_tracking() {
  let persistedRoot = makeDocumentState(
    name: "Preview Root",
    entities: [lineEntity(id: "entity:line-a", start: .zero, end: .init(xMM: 20.0, yMM: 0.0))]
  )
  let previewRoot = makeDocumentState(
    name: "Preview Root",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: .init(xMM: 20.0, yMM: 0.0)),
      lineEntity(id: "entity:preview-only", start: .zero, end: .init(xMM: 0.0, yMM: 20.0)),
    ]
  )
  let persistedEdited = makeDocumentState(
    name: "Preview Edited",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: .init(xMM: 25.0, yMM: 0.0))
    ]
  )
  let previewEdited = makeDocumentState(
    name: "Preview Edited",
    entities: [
      lineEntity(id: "entity:line-a", start: .zero, end: .init(xMM: 25.0, yMM: 0.0)),
      lineEntity(id: "entity:preview-only", start: .zero, end: .init(xMM: 0.0, yMM: 20.0)),
    ]
  )
  let backend = ScriptedDocumentSessionBackend(
    states: [
      "root": persistedRoot,
      "edited": persistedEdited,
    ],
    statesByViewMode: [
      "root": [
        CanvasViewMode.outputPreview.rawValue: previewRoot
      ],
      "edited": [
        CanvasViewMode.outputPreview.rawValue: previewEdited
      ],
    ],
    transitions: [
      "root": ["edited"],
      "edited": ["root"],
    ]
  )
  let adapter = DocumentSessionAdapter(backend: backend)

  let created = requireSuccess(
    adapter.createNewDocument(viewMode: .outputPreview))
  #expect(created == previewRoot.withPersistence(isDirty: false, revision: "root"))
  #expect(!adapter.isDocumentDirty)

  let reloaded = requireSuccess(adapter.loadState(viewMode: .outputPreview))
  #expect(
    reloaded
      == previewRoot
      .withHistory(canUndo: false, canRedo: false)
      .withPersistence(isDirty: false, revision: "root"))
  #expect(!adapter.isDocumentDirty)

  _ = requireSuccess(adapter.applyCommand(testCommand(), viewMode: .outputPreview))
  #expect(adapter.isDocumentDirty)

  _ = requireSuccess(adapter.undo(viewMode: .outputPreview))
  #expect(!adapter.isDocumentDirty)
}

@Test("DocumentSessionAdapter は recovery snapshot を元URL付きの dirty 文書として開く")
func document_session_adapter_opens_recovery_snapshot_as_dirty_document() {
  let recoveredState = makeDocumentState(
    name: "Recovered",
    entities: [lineEntity(id: "entity:recovered", start: .zero, end: .init(xMM: 20.0, yMM: 0.0))]
  )
  let recoveryURL = uniqueTempURL("recovery-snapshot.kawa")
  let originalURL = uniqueTempURL("original-document.kawa")
  let backend = ScriptedDocumentSessionBackend(
    states: [
      recoveryURL.lastPathComponent: recoveredState
    ]
  )
  let adapter = DocumentSessionAdapter(backend: backend)

  let recovered = requireSuccess(
    adapter.recoverDocument(
      from: recoveryURL,
      suggestedDocumentURL: originalURL,
      viewMode: .editDisplay
    )
  )

  #expect(
    recovered
      == recoveredState.withPersistence(
        isDirty: false,
        revision: recoveryURL.lastPathComponent
      ))
  #expect(adapter.documentURL == originalURL)
  #expect(adapter.isDocumentDirty)

  requireSuccess(adapter.saveDocument(to: originalURL), context: "saveDocument")
  #expect(!adapter.isDocumentDirty)
}

@Test("DocumentSessionAdapter は failed new document でも現在の状態とURLを保持する")
func document_session_adapter_keeps_current_document_when_create_new_fails() {
  let lastAppliedState = makeDocumentState(
    name: "Current Document",
    entities: [pointEntity(id: "entity:current", point: .zero)]
  )
  let backend = ScriptedDocumentSessionBackend(
    states: [
      "root": lastAppliedState
    ],
    createResults: [
      .success("root"),
      .failure("create failed"),
    ]
  )
  let adapter = DocumentSessionAdapter(backend: backend)

  _ = requireSuccess(adapter.createNewDocument(viewMode: .editDisplay))
  _ = requireSuccess(adapter.applyCommand(testCommand(), viewMode: .editDisplay))
  let currentURL = uniqueTempURL("current-document.kawa")
  requireSuccess(adapter.saveDocument(to: currentURL), context: "saveDocument")

  switch adapter.createNewDocument(viewMode: .editDisplay) {
  case .failure(let message):
    #expect(message == "create failed")
  case .success:
    Issue.record("expected createNewDocument to fail")
  }

  #expect(adapter.documentURL == currentURL)
  #expect(adapter.lastAppliedState?.entities == lastAppliedState.entities)
  #expect(adapter.hasDocument)
}

@Test("DocumentSessionAdapter は open 後の状態読み込み失敗時に最後の成功 URL と状態を維持する")
func document_session_adapter_keeps_last_successful_document_when_open_load_fails() {
  let lastAppliedState = makeDocumentState(
    name: "Current Document",
    entities: [
      pointEntity(id: "entity:current", point: .zero)
    ]
  )
  let failedOpenState = makeDocumentState(
    name: "Failed Open",
    entities: [
      pointEntity(id: "entity:failed", point: .init(xMM: 1.0, yMM: 1.0))
    ]
  )
  let failedOpenURL = uniqueTempURL("failed-open.kawa")
  let backend = ScriptedDocumentSessionBackend(
    states: [
      "root": lastAppliedState,
      failedOpenURL.lastPathComponent: failedOpenState,
    ],
    loadFailuresByKey: [
      failedOpenURL.lastPathComponent: "decode failed"
    ]
  )
  let adapter = DocumentSessionAdapter(backend: backend)

  _ = requireSuccess(adapter.createNewDocument(viewMode: .editDisplay))
  let currentURL = uniqueTempURL("current-document.kawa")
  requireSuccess(adapter.saveDocument(to: currentURL), context: "saveDocument")

  switch adapter.openDocument(at: failedOpenURL, viewMode: .editDisplay) {
  case .failure(let message):
    #expect(message == "decode failed")
  case .success:
    Issue.record("expected openDocument to fail")
  }

  #expect(adapter.documentURL == currentURL)
  #expect(
    adapter.lastAppliedState == lastAppliedState.withPersistence(isDirty: false, revision: "root"))
  #expect(adapter.hasDocument)
}

@Test("DocumentSessionAdapter は create 後の状態読み込み失敗でも現在の状態を維持する")
func document_session_adapter_keeps_current_document_when_new_document_load_fails() {
  let lastAppliedState = makeDocumentState(
    name: "Current Document",
    entities: [pointEntity(id: "entity:current", point: .zero)]
  )
  let backend = ScriptedDocumentSessionBackend(
    states: [
      "root": lastAppliedState,
      "replacement": makeDocumentState(name: "Replacement Document", entities: []),
    ],
    loadFailuresByKey: [
      "replacement": "load failed"
    ],
    createResults: [
      .success("root"),
      .success("replacement"),
    ]
  )
  let adapter = DocumentSessionAdapter(backend: backend)

  _ = requireSuccess(adapter.createNewDocument(viewMode: .editDisplay))
  let currentURL = uniqueTempURL("current-document.kawa")
  requireSuccess(adapter.saveDocument(to: currentURL), context: "saveDocument")

  switch adapter.createNewDocument(viewMode: .editDisplay) {
  case .failure(let message):
    #expect(message == "load failed")
  case .success:
    Issue.record("expected createNewDocument to fail")
  }

  #expect(adapter.documentURL == currentURL)
  #expect(
    adapter.lastAppliedState == lastAppliedState.withPersistence(isDirty: false, revision: "root"))
  #expect(adapter.hasDocument)
}

@Test("Output DocumentSessionAdapter は output document model request を session へ中継する")
func output_document_session_adapter_build_output_document_model_delegates_to_session() {
  let backend = ScriptedDocumentSessionBackend(
    states: [
      "root": makeDocumentState(name: "Output", entities: [])
    ]
  )
  let adapter = DocumentSessionAdapter(backend: backend)
  _ = requireSuccess(adapter.createNewDocument(viewMode: .editDisplay))

  let options = OutputBuildOptions(
    orientation: .portrait,
    includeDimensionLabels: true,
    includeScaleGuide: true,
    rotationDeg: 90,
    printableAreaMm: OutputPrintableAreaMm(
      leftMm: -100,
      rightMm: 100,
      topMm: 143.5,
      bottomMm: -143.5
    )
  )

  let result = requireSuccess(adapter.buildOutputDocumentModel(options: options))
  #expect(result.outputDocumentModel.pageCount == 1)

  let session = unwrap(backend.lastCreatedSession, context: "scripted session should be captured")
  #expect(session.outputBuildOptions == [options])
}

@Test("Output DocumentSessionAdapter は renderPDF request を session へ中継する")
func output_document_session_adapter_render_pdf_delegates_to_session() {
  let backend = ScriptedDocumentSessionBackend(
    states: [
      "root": makeDocumentState(name: "Output", entities: [])
    ]
  )
  let adapter = DocumentSessionAdapter(backend: backend)
  _ = requireSuccess(adapter.createNewDocument(viewMode: .editDisplay))

  let model = sampleOutputDocumentModel()
  let result = requireSuccess(adapter.renderPDF(outputDocumentModel: model))

  #expect(String(data: result, encoding: .utf8) == "%PDF-1.4\n")
  let session = unwrap(backend.lastCreatedSession, context: "scripted session should be captured")
  #expect(session.renderedOutputModels == [model])
}

@Test("Output DocumentSessionAdapter は renderPrint request を session へ中継する")
func output_document_session_adapter_render_print_delegates_to_session() {
  let backend = ScriptedDocumentSessionBackend(
    states: [
      "root": makeDocumentState(name: "Output", entities: [])
    ]
  )
  let adapter = DocumentSessionAdapter(backend: backend)
  _ = requireSuccess(adapter.createNewDocument(viewMode: .editDisplay))

  let model = sampleOutputDocumentModel()
  let result = requireSuccess(adapter.renderPrint(outputDocumentModel: model))

  #expect(result.orientation == .portrait)
  let session = unwrap(backend.lastCreatedSession, context: "scripted session should be captured")
  #expect(session.renderedOutputModels == [model])
}

private func testCommand() -> CoreDocumentCommand {
  CoreDocumentCommand(
    kind: .deleteEntity,
    payload: .string("entity:test")
  )
}
