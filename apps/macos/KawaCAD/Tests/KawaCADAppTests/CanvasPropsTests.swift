import Testing

@testable import KawaCADApp

@Test("Canvas props は表示状態をスナップショット化し操作を AppCoordinator 境界へ委譲する")
@MainActor
func canvas_props_keep_render_state_and_effects_separate() {
  let documentEntity = pointEntity(id: "entity:document", point: .zero)
  let previewEntity = pointEntity(id: "entity:preview", point: .init(xMM: 12, yMM: 8))
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(
      name: "Canvas Props",
      parts: [
        ProjectPart(
          id: "part:canvas",
          name: "Canvas Part",
          originMM: ModelPoint(xMM: 3, yMM: 4),
          outlineEntityIDs: [documentEntity.id],
          holeEntityIDGroups: [],
          entityIDs: [documentEntity.id],
          derivedElementIDs: [],
          freeTextIDs: [],
          measurementAnnotationIDs: []
        )
      ],
      entities: [documentEntity],
      constraintStatus: .underConstrained
    )
  )
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )
  appState.actions.canvas.previewEntities = [previewEntity]
  appState.actions.canvas.selectedTool = .line
  appState.actions.canvas.freeTextInlineEditRequestID = "request:active"
  appState.actions.inspector.inspectorSelectedPartID = "part:canvas"
  appState.actions.inspector.isSettingPartOrigin = true

  let renderInput = appState.actions.canvas.canvasRenderInput
  #expect(renderInput.document.entities.map(\.id) == ["entity:preview"])
  #expect(renderInput.draft.selectedTool == .line)
  #expect(
    appState.actions.canvas.canvasInteractionInput.freeTextInlineEditRequestID == "request:active")
  #expect(renderInput.draft.selectedPartOrigin == ModelPoint(xMM: 3, yMM: 4))
  #expect(appState.actions.canvas.canvasInteractionInput.isSettingPartOrigin)

  let actions = appState.actions.canvas.canvasActionGroups
  actions.editing.freeTextInlineEditRequestHandled("request:stale")
  #expect(appState.actions.canvas.freeTextInlineEditRequestID == "request:active")
  actions.editing.freeTextInlineEditRequestHandled("request:active")
  #expect(appState.actions.canvas.freeTextInlineEditRequestID == nil)

  actions.editing.activateTool(.circle)
  #expect(appState.actions.canvas.selectedTool == .circle)
}
@Test("パーツ選択は通常図形と解決済み派生図形を強調対象にし原点を表示する")
@MainActor
func part_selection_expands_canvas_highlight_and_origin() {
  let base = pointEntity(id: "entity:base", point: .zero)
  let resolved = pointEntity(id: "derived:stitch:resolved:0", point: ModelPoint(xMM: 5, yMM: 5))
  let part = ProjectPart(
    id: "part:highlight",
    name: "Highlight",
    originMM: ModelPoint(xMM: 2, yMM: 3),
    outlineEntityIDs: [base.id],
    holeEntityIDGroups: [],
    entityIDs: [base.id],
    derivedElementIDs: ["derived:stitch"],
    freeTextIDs: ["free-text:note"],
    measurementAnnotationIDs: ["measurement:width"]
  )
  let store = StubDocumentSessionAdapter(
    createNewDocumentState: makeDocumentState(
      name: "Part Highlight",
      parts: [part],
      entities: [base, resolved]
    )
  )
  let appState = AppCoordinator(
    documentAdapter: store,
    coreStatusProvider: { .connected(.init(fileFormatMajor: 0, schemaMajor: 0)) }
  )

  appState.actions.parts.selectPartContents(part)

  #expect(appState.actions.canvas.selectedEntityIDs == [base.id, resolved.id])
  #expect(appState.actions.inspector.inspectorSelectedPartID == part.id)
  #expect(appState.actions.canvas.canvasRenderInput.draft.selectedPartOrigin == part.originMM)
  #expect(
    appState.actions.canvas.canvasRenderInput.selection.highlightedPartEntityIDs == [
      base.id, resolved.id,
    ])
  #expect(
    appState.actions.canvas.canvasRenderInput.selection.highlightedPartFreeTextIDs == [
      "free-text:note"
    ])
  #expect(
    appState.actions.canvas.canvasRenderInput.selection.highlightedPartMeasurementAnnotationIDs == [
      "measurement:width"
    ])
}
