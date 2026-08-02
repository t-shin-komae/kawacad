import CoreGraphics

enum CanvasDragState: Equatable {
  case entities(
    entityIDs: Set<String>, anchorEntityID: String, startPoint: ModelPoint,
    currentPoint: ModelPoint, duplicating: Bool)
  case controlPoint(target: CanvasSelectionTarget, startPoint: ModelPoint, currentPoint: ModelPoint)
  case marquee(startPoint: CGPoint, currentPoint: CGPoint, extendingSelection: Bool)
}

struct CanvasInteractionState: Equatable {
  var dragState: CanvasDragState?

  var isDragging: Bool {
    dragState != nil
  }

  func hasCancellationTarget(
    draftStartPoint: ModelPoint?,
    draftCurrentPoint: ModelPoint?,
    draftArcStartPoint: ModelPoint?,
    pendingConstraintTargets: [CanvasSelectionTarget],
    selectedEntityID: String?,
    selectedEntityIDs: Set<String>,
    selectedConstraintID: String?
  ) -> Bool {
    dragState != nil
      || draftStartPoint != nil
      || draftCurrentPoint != nil
      || draftArcStartPoint != nil
      || !pendingConstraintTargets.isEmpty
      || !selectedEntityIDs.isEmpty
      || selectedEntityID != nil
      || selectedConstraintID != nil
  }

  static func normalizedRect(from startPoint: CGPoint, to currentPoint: CGPoint) -> CGRect {
    CGRect(
      x: min(startPoint.x, currentPoint.x),
      y: min(startPoint.y, currentPoint.y),
      width: abs(currentPoint.x - startPoint.x),
      height: abs(currentPoint.y - startPoint.y)
    )
  }

  static func delta(from startPoint: ModelPoint, to currentPoint: ModelPoint) -> ModelPoint {
    ModelPoint(
      xMM: currentPoint.xMM - startPoint.xMM,
      yMM: currentPoint.yMM - startPoint.yMM
    )
  }

  static func hasMeaningfulModelMovement(
    from startPoint: ModelPoint,
    to currentPoint: ModelPoint,
    tolerance: Double = 0.0001
  ) -> Bool {
    let delta = delta(from: startPoint, to: currentPoint)
    return abs(delta.xMM) > tolerance || abs(delta.yMM) > tolerance
  }

  static func hasMeaningfulPointMovement(
    from startPoint: ModelPoint,
    to currentPoint: ModelPoint,
    tolerance: Double = 0.0001
  ) -> Bool {
    hypot(startPoint.xMM - currentPoint.xMM, startPoint.yMM - currentPoint.yMM) > tolerance
  }
}
