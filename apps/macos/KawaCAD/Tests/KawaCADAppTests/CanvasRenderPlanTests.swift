import CoreGraphics
import KawaCADOutput
import Testing

@testable import KawaCADApp

struct CanvasRenderPlanTests {
  @Test
  func edit_canvas_keeps_overlay_order_after_entity_content() {
    let plan = CanvasRenderPlan(gridVisible: true, outputPreview: false)

    #expect(plan.passes.first == .background)
    #expect(
      plan.passes.firstIndex(of: .entities) ?? 0 < plan.passes.firstIndex(of: .draftPreview) ?? 0)
    #expect(plan.passes.last == .snapIndicator)
  }

  @Test
  func output_preview_plan_excludes_edit_overlays() {
    let plan = CanvasRenderPlan(gridVisible: true, outputPreview: true)

    #expect(
      plan.passes == [
        .background,
        .entities,
        .stitchStartPoints,
        .freeTexts,
        .selectedPartOrigin,
        .outputPreviewTexts,
        .outputPreviewPages,
      ])
  }

  @Test
  func renderer_executes_the_plan_without_a_canvas_view() {
    let surface = RecordingCanvasRenderSurface()
    CanvasRenderer().draw(
      plan: CanvasRenderPlan(gridVisible: false, outputPreview: true),
      pageRect: CGRect(x: 10, y: 20, width: 300, height: 400),
      dirtyRect: CGRect(x: 0, y: 0, width: 40, height: 50),
      canvasBounds: CGRect(x: 0, y: 0, width: 640, height: 480),
      on: surface
    )

    #expect(
      surface.passes == [
        .background,
        .entities,
        .stitchStartPoints,
        .freeTexts,
        .selectedPartOrigin,
        .outputPreviewTexts,
        .outputPreviewPages,
      ])
  }

  @Test
  func annotation_renderer_exposes_the_same_layout_used_for_drawing() {
    let item = CanvasAnnotationRenderer.Item(
      kind: .measurement,
      label: "20 mm",
      geometry: .line(start: .zero, end: ModelPoint(xMM: 20, yMM: 0)),
      labelOffsetMM: .zero,
      overallOffsetMM: .zero,
      highlighted: false
    )
    let renderer = CanvasAnnotationRenderer(
      input: CanvasAnnotationRenderer.Input(items: [item], orientation: .portrait))

    guard
      case .line(let layout) = renderer.layout(
        for: item,
        in: CGRect(x: 0, y: 0, width: 520, height: 736)
      )
    else {
      Issue.record("Expected a line annotation layout")
      return
    }

    #expect(layout.labelRect.contains(layout.labelPoint))
  }
}

private final class RecordingCanvasRenderSurface: CanvasRenderPassDrawing {
  var passes: [CanvasRenderPass] = []

  func drawCanvasBackground(dirtyRect: CGRect, canvasBounds: CGRect) { passes.append(.background) }
  func drawGrid(in canvasBounds: CGRect, pageRect: CGRect) { passes.append(.grid) }
  func drawCoordinateReference(in pageRect: CGRect) { passes.append(.coordinateReference) }
  func drawEntities(in pageRect: CGRect) { passes.append(.entities) }
  func drawStitchStartPoints(in pageRect: CGRect) { passes.append(.stitchStartPoints) }
  func drawFreeTexts(in pageRect: CGRect) { passes.append(.freeTexts) }
  func drawSelectedPartOrigin(in pageRect: CGRect) { passes.append(.selectedPartOrigin) }
  func drawOutputPreviewTexts(in pageRect: CGRect) { passes.append(.outputPreviewTexts) }
  func drawOutputPreviewPages() { passes.append(.outputPreviewPages) }
  func drawSelectedConstraintTargets(in pageRect: CGRect) {
    passes.append(.selectedConstraintTargets)
  }
  func drawConstraintTargetFeedback(in pageRect: CGRect) {
    passes.append(.constraintTargetFeedback)
  }
  func drawCoincidentPointGroups(in pageRect: CGRect) { passes.append(.coincidentPointGroups) }
  func drawDimensionConstraints(in pageRect: CGRect) { passes.append(.dimensionConstraints) }
  func drawMeasurementAnnotations(in pageRect: CGRect) { passes.append(.measurementAnnotations) }
  func drawConstraintMarkers(in pageRect: CGRect) { passes.append(.constraintMarkers) }
  func drawDraftPreview(in pageRect: CGRect) { passes.append(.draftPreview) }
  func drawSelectionMarquee() { passes.append(.selectionMarquee) }
  func drawDragFeedback() { passes.append(.dragFeedback) }
  func drawSnapIndicator(in pageRect: CGRect) { passes.append(.snapIndicator) }
}
