import CoreGraphics

enum CanvasRenderPass: Equatable {
  case background
  case grid
  case coordinateReference
  case entities
  case stitchStartPoints
  case freeTexts
  case selectedPartOrigin
  case outputPreviewTexts
  case outputPreviewPages
  case selectedConstraintTargets
  case constraintTargetFeedback
  case coincidentPointGroups
  case dimensionConstraints
  case measurementAnnotations
  case constraintMarkers
  case draftPreview
  case selectionMarquee
  case dragFeedback
  case snapIndicator
}

/// Purely describes the draw order. AppKit drawing remains an execution detail of the view.
struct CanvasRenderPlan: Equatable {
  let passes: [CanvasRenderPass]

  init(gridVisible: Bool, outputPreview: Bool) {
    var passes: [CanvasRenderPass] = [.background]
    if gridVisible && !outputPreview {
      passes.append(.grid)
    }
    if !outputPreview {
      passes.append(.coordinateReference)
    }
    passes += [
      .entities,
      .stitchStartPoints,
      .freeTexts,
      .selectedPartOrigin,
      .outputPreviewTexts,
      .outputPreviewPages,
    ]
    if !outputPreview {
      passes += [
        .selectedConstraintTargets,
        .constraintTargetFeedback,
        .coincidentPointGroups,
        .dimensionConstraints,
        .measurementAnnotations,
        .constraintMarkers,
        .draftPreview,
        .selectionMarquee,
        .dragFeedback,
        .snapIndicator,
      ]
    }
    self.passes = passes
  }
}

/// Drawing surface consumed by `CanvasRenderer`.
///
/// The AppKit view implements these primitives, while ordering and mode-specific
/// pass selection remain independently testable here.
protocol CanvasRenderPassDrawing: AnyObject {
  func drawCanvasBackground(dirtyRect: CGRect, canvasBounds: CGRect)
  func drawGrid(in canvasBounds: CGRect, pageRect: CGRect)
  func drawCoordinateReference(in pageRect: CGRect)
  func drawEntities(in pageRect: CGRect)
  func drawStitchStartPoints(in pageRect: CGRect)
  func drawFreeTexts(in pageRect: CGRect)
  func drawSelectedPartOrigin(in pageRect: CGRect)
  func drawOutputPreviewTexts(in pageRect: CGRect)
  func drawOutputPreviewPages()
  func drawSelectedConstraintTargets(in pageRect: CGRect)
  func drawConstraintTargetFeedback(in pageRect: CGRect)
  func drawCoincidentPointGroups(in pageRect: CGRect)
  func drawDimensionConstraints(in pageRect: CGRect)
  func drawMeasurementAnnotations(in pageRect: CGRect)
  func drawConstraintMarkers(in pageRect: CGRect)
  func drawDraftPreview(in pageRect: CGRect)
  func drawSelectionMarquee()
  func drawDragFeedback()
  func drawSnapIndicator(in pageRect: CGRect)
}

/// Executes a render plan without reading actions or mutating interaction state.
struct CanvasRenderer {
  func draw(
    plan: CanvasRenderPlan,
    pageRect: CGRect,
    dirtyRect: CGRect,
    canvasBounds: CGRect,
    on surface: CanvasRenderPassDrawing
  ) {
    for pass in plan.passes {
      switch pass {
      case .background:
        surface.drawCanvasBackground(dirtyRect: dirtyRect, canvasBounds: canvasBounds)
      case .grid:
        surface.drawGrid(in: canvasBounds, pageRect: pageRect)
      case .coordinateReference:
        surface.drawCoordinateReference(in: pageRect)
      case .entities:
        surface.drawEntities(in: pageRect)
      case .stitchStartPoints:
        surface.drawStitchStartPoints(in: pageRect)
      case .freeTexts:
        surface.drawFreeTexts(in: pageRect)
      case .selectedPartOrigin:
        surface.drawSelectedPartOrigin(in: pageRect)
      case .outputPreviewTexts:
        surface.drawOutputPreviewTexts(in: pageRect)
      case .outputPreviewPages:
        surface.drawOutputPreviewPages()
      case .selectedConstraintTargets:
        surface.drawSelectedConstraintTargets(in: pageRect)
      case .constraintTargetFeedback:
        surface.drawConstraintTargetFeedback(in: pageRect)
      case .coincidentPointGroups:
        surface.drawCoincidentPointGroups(in: pageRect)
      case .dimensionConstraints:
        surface.drawDimensionConstraints(in: pageRect)
      case .measurementAnnotations:
        surface.drawMeasurementAnnotations(in: pageRect)
      case .constraintMarkers:
        surface.drawConstraintMarkers(in: pageRect)
      case .draftPreview:
        surface.drawDraftPreview(in: pageRect)
      case .selectionMarquee:
        surface.drawSelectionMarquee()
      case .dragFeedback:
        surface.drawDragFeedback()
      case .snapIndicator:
        surface.drawSnapIndicator(in: pageRect)
      }
    }
  }
}
