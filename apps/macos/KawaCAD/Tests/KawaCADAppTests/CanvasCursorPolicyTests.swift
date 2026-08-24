import Testing

@testable import KawaCADApp

@Test("選択ツールは対象上だけ開いた手になる")
func selectionCursorReflectsTarget() {
  let base = CanvasCursorState(
    tool: .select,
    outputPreview: false,
    pointerInsideCanvas: true,
    hasTarget: false,
    inlineTextEditing: false,
    settingPartOrigin: false,
    dragging: false
  )
  #expect(CanvasCursorPolicy.cursor(for: base) == .arrow)
  #expect(
    CanvasCursorPolicy.cursor(
      for: CanvasCursorState(
        tool: .select,
        outputPreview: false,
        pointerInsideCanvas: true,
        hasTarget: true,
        inlineTextEditing: false,
        settingPartOrigin: false,
        dragging: false
      )) == .openHand)
}

@Test("作図・文字・ドラッグの状態をポインタで区別する")
func drawingAndEditingCursors() {
  #expect(
    CanvasCursorPolicy.cursor(
      for: CanvasCursorState(
        tool: .line,
        outputPreview: false,
        pointerInsideCanvas: true,
        hasTarget: false,
        inlineTextEditing: false,
        settingPartOrigin: false,
        dragging: false
      )) == .crosshair)
  #expect(
    CanvasCursorPolicy.cursor(
      for: CanvasCursorState(
        tool: .select,
        outputPreview: false,
        pointerInsideCanvas: true,
        hasTarget: false,
        inlineTextEditing: true,
        settingPartOrigin: false,
        dragging: false
      )) == .iBeam)
  #expect(
    CanvasCursorPolicy.cursor(
      for: CanvasCursorState(
        tool: .select,
        outputPreview: false,
        pointerInsideCanvas: true,
        hasTarget: true,
        inlineTextEditing: false,
        settingPartOrigin: false,
        dragging: true
      )) == .closedHand)
}

@Test("拘束対象の有無と出力プレビューを反映する")
func targetAndPreviewCursors() {
  #expect(
    CanvasCursorPolicy.cursor(
      for: CanvasCursorState(
        tool: .distance,
        outputPreview: false,
        pointerInsideCanvas: true,
        hasTarget: false,
        inlineTextEditing: false,
        settingPartOrigin: false,
        dragging: false
      )) == .operationNotAllowed)
  #expect(
    CanvasCursorPolicy.cursor(
      for: CanvasCursorState(
        tool: .distance,
        outputPreview: false,
        pointerInsideCanvas: true,
        hasTarget: true,
        inlineTextEditing: false,
        settingPartOrigin: false,
        dragging: false
      )) == .pointingHand)
  #expect(
    CanvasCursorPolicy.cursor(
      for: CanvasCursorState(
        tool: .line,
        outputPreview: true,
        pointerInsideCanvas: true,
        hasTarget: false,
        inlineTextEditing: false,
        settingPartOrigin: false,
        dragging: false
      )) == .arrow)
}
