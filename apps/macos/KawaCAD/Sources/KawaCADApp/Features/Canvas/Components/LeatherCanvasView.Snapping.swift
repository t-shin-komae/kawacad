import AppKit
import KawaCADOutput
import SwiftUI

/// Rendering responsibilities extracted from the input-oriented canvas view.
/// The view still owns lifecycle and callbacks; this extension owns the
/// projection of the current immutable canvas snapshot into AppKit drawing.
extension LeatherCanvasView {
  var visibleEntities: [CanvasEntity] {
    entities.filter { entity in
      guard let layerID = entity.layerID,
        let layer = layers.first(where: { $0.id == layerID })
      else {
        return true
      }
      return layer.visible
    }
  }

  var isOutputPreviewMode: Bool {
    viewMode == .outputPreview
  }

  func pageRect(in rect: CGRect) -> CGRect {
    pageRect(in: rect, zoomScale: zoomScale, panOffset: panOffset)
  }

  func pageRect(in rect: CGRect, zoomScale: Double, panOffset: CGSize) -> CGRect {
    CanvasLayout.pageRect(
      in: rect,
      zoomScale: zoomScale,
      panOffset: panOffset,
      orientation: a4ReferenceOrientation
    )
  }

  func basePageSizeForA4ReferenceOrientation() -> CGSize {
    CanvasCoordinateSpace.referencePageSize(for: a4ReferenceOrientation)
  }

  func canvasBoundsRect(in pageRect: CGRect) -> CGRect {
    coordinateSpace(in: pageRect).canvasBoundsRect
  }

  func canvasPoint(for point: ModelPoint, in pageRect: CGRect) -> CGPoint {
    coordinateSpace(in: pageRect).canvasPoint(for: point)
  }

  func modelPoint(for point: CGPoint, in pageRect: CGRect) -> ModelPoint {
    coordinateSpace(in: pageRect).modelPoint(for: point)
  }

  func snappedModelPoint(
    for point: CGPoint,
    in pageRect: CGRect,
    excluding excludedTarget: CanvasSelectionTarget? = nil
  ) -> ModelPoint {
    let rawPoint = modelPoint(for: point, in: pageRect)
    var snapped = rawPoint
    if gridSnapEnabled {
      snapped = ModelPoint(
        xMM: (snapped.xMM / 5.0).rounded() * 5.0,
        yMM: (snapped.yMM / 5.0).rounded() * 5.0
      )
    }
    if pointSnapEnabled,
      let nearest = nearestSnapPoint(to: rawPoint, in: pageRect, excluding: excludedTarget)
    {
      snapped = nearest
    }
    interactionController.updateSnap(indicator: snapped, suppression: nil)
    return snapped
  }

  func placementModelPoint(
    for point: CGPoint,
    in pageRect: CGRect,
    modifiers: CanvasPlacementModifiers,
    excluding excludedTarget: CanvasSelectionTarget? = nil
  ) -> ModelPoint {
    guard !modifiers.suppressesSnap else {
      let rawPoint = modelPoint(for: point, in: pageRect)
      interactionController.updateSnap(indicator: nil, suppression: rawPoint)
      return rawPoint
    }
    return snappedModelPoint(for: point, in: pageRect, excluding: excludedTarget)
  }

  func lineToolModelPoint(
    for point: CGPoint,
    in pageRect: CGRect,
    modifiers: CanvasPlacementModifiers
  ) -> ModelPoint {
    let rawPoint = modelPoint(for: point, in: pageRect)
    interactionController.updateSnap(
      indicator: modifiers.suppressesSnap ? nil : interactionSnapshot().snapIndicatorPoint,
      suppression: modifiers.suppressesSnap ? rawPoint : nil
    )
    return rawPoint
  }

  func nearestSnapPoint(
    to point: ModelPoint,
    in pageRect: CGRect,
    excluding excludedTarget: CanvasSelectionTarget?
  ) -> ModelPoint? {
    let scale = canvasScale(in: pageRect)
    let thresholdMM = 10.0 / scale
    let entitySnapPoints =
      visibleEntities
      .flatMap(\.snapPointTargets)
      .map { item in
        (
          target: item.target,
          point: item.point,
          priority: item.target == nil ? 2 : 0
        )
      }
    let intersectionSnapPoints = lineIntersectionSnapPoints().map { point in
      (target: Optional<CanvasSelectionTarget>.none, point: point, priority: 1)
    }
    return (entitySnapPoints + intersectionSnapPoints)
      .filter { item in item.target == nil || item.target != excludedTarget }
      .min { first, second in
        let firstDistance = distance(first.point, point)
        let secondDistance = distance(second.point, point)
        if abs(firstDistance - secondDistance) <= thresholdMM * 0.25 {
          return first.priority < second.priority
        }
        return firstDistance < secondDistance
      }
      .flatMap { item in
        distance(item.point, point) <= thresholdMM ? item.point : nil
      }
  }

  func lineIntersectionSnapPoints() -> [ModelPoint] {
    let segments = visibleEntities.flatMap(\.lineSelectionTargets)
    var points: [ModelPoint] = []
    for firstIndex in segments.indices {
      for secondIndex in segments.index(after: firstIndex)..<segments.endIndex {
        let first = segments[firstIndex]
        let second = segments[secondIndex]
        guard first.target.entityID != second.target.entityID,
          let point = segmentIntersection(
            firstStart: first.start,
            firstEnd: first.end,
            secondStart: second.start,
            secondEnd: second.end
          ),
          !points.contains(where: { distance($0, point) <= 0.0001 })
        else {
          continue
        }
        points.append(point)
      }
    }
    return points
  }

  func segmentIntersection(
    firstStart: ModelPoint,
    firstEnd: ModelPoint,
    secondStart: ModelPoint,
    secondEnd: ModelPoint
  ) -> ModelPoint? {
    let firstDX = firstEnd.xMM - firstStart.xMM
    let firstDY = firstEnd.yMM - firstStart.yMM
    let secondDX = secondEnd.xMM - secondStart.xMM
    let secondDY = secondEnd.yMM - secondStart.yMM
    let denominator = firstDX * secondDY - firstDY * secondDX
    guard abs(denominator) > 0.000001 else {
      return nil
    }

    let deltaX = secondStart.xMM - firstStart.xMM
    let deltaY = secondStart.yMM - firstStart.yMM
    let firstT = (deltaX * secondDY - deltaY * secondDX) / denominator
    let secondT = (deltaX * firstDY - deltaY * firstDX) / denominator
    guard (-0.000001...1.000001).contains(firstT),
      (-0.000001...1.000001).contains(secondT)
    else {
      return nil
    }

    return ModelPoint(
      xMM: firstStart.xMM + firstT * firstDX,
      yMM: firstStart.yMM + firstT * firstDY
    )
  }

  func distance(_ first: ModelPoint, _ second: ModelPoint) -> Double {
    hypot(first.xMM - second.xMM, first.yMM - second.yMM)
  }

  func drawSnapIndicator(in pageRect: CGRect) {
    if let snapSuppressionPoint = interactionSnapshot().snapSuppressionPoint,
      gridSnapEnabled || pointSnapEnabled
    {
      drawSnapSuppressionBadge(at: snapSuppressionPoint, in: pageRect)
      return
    }
    guard let snapIndicatorPoint = interactionSnapshot().snapIndicatorPoint,
      gridSnapEnabled || pointSnapEnabled
    else {
      return
    }
    let point = canvasPoint(for: snapIndicatorPoint, in: pageRect)
    CanvasVisualHierarchy.snapStroke.setStroke()
    let path = NSBezierPath()
    path.move(to: CGPoint(x: point.x - CanvasVisualHierarchy.snapCrossSize, y: point.y))
    path.line(to: CGPoint(x: point.x + CanvasVisualHierarchy.snapCrossSize, y: point.y))
    path.move(to: CGPoint(x: point.x, y: point.y - CanvasVisualHierarchy.snapCrossSize))
    path.line(to: CGPoint(x: point.x, y: point.y + CanvasVisualHierarchy.snapCrossSize))
    path.lineWidth = CanvasVisualHierarchy.snapLineWidth
    path.stroke()
    let ring = NSBezierPath(
      ovalIn: CGRect(
        x: point.x - CanvasVisualHierarchy.snapRingRadius,
        y: point.y - CanvasVisualHierarchy.snapRingRadius,
        width: CanvasVisualHierarchy.snapRingRadius * 2,
        height: CanvasVisualHierarchy.snapRingRadius * 2
      ))
    ring.lineWidth = CanvasVisualHierarchy.snapLineWidth
    ring.stroke()
  }

  func drawSnapSuppressionBadge(at modelPoint: ModelPoint, in pageRect: CGRect) {
    let point = canvasPoint(for: modelPoint, in: pageRect)
    let text = NSAttributedString(
      string: "SNAP OFF",
      attributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.984, green: 0.961, blue: 0.894, alpha: 1.0),
      ]
    )
    let size = text.size()
    let rect = CGRect(
      x: point.x + 10,
      y: point.y + 10,
      width: size.width + 12,
      height: size.height + 7
    )
    NSColor(calibratedRed: 0.290, green: 0.322, blue: 0.365, alpha: 0.88).setFill()
    NSColor(calibratedRed: 0.984, green: 0.961, blue: 0.894, alpha: 0.92).setStroke()
    let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
    path.lineWidth = 1.0
    path.fill()
    path.stroke()
    text.draw(at: CGPoint(x: rect.minX + 6, y: rect.minY + 3))
  }
}
