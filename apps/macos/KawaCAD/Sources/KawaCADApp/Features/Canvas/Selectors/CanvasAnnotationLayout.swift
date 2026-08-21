import AppKit
import CoreGraphics
import KawaCADOutput

/// Immutable geometry shared by annotation rendering and hit testing.
struct CanvasAnnotationLayout {
  enum Axis {
    case horizontal
    case vertical
  }

  struct Line {
    let startPoint: CGPoint
    let endPoint: CGPoint
    let shiftedStart: CGPoint
    let shiftedEnd: CGPoint
    let labelPoint: CGPoint
    let labelRect: CGRect
  }

  struct AxisLine {
    let firstPoint: CGPoint
    let secondPoint: CGPoint
    let dimensionStart: CGPoint
    let dimensionEnd: CGPoint
    let labelPoint: CGPoint
    let labelRect: CGRect
  }

  struct Angle {
    let centerPoint: CGPoint
    let startPoint: CGPoint
    let endPoint: CGPoint
    let radius: CGFloat
    let startAngleRad: Double
    let sweepAngleRad: Double
    let labelPoint: CGPoint
    let labelRect: CGRect

    func contains(_ point: CGPoint, radiusTolerance: CGFloat) -> Bool {
      let dx = point.x - centerPoint.x
      let dy = -(point.y - centerPoint.y)
      let distance = hypot(dx, dy)
      guard abs(distance - radius) <= radiusTolerance else {
        return false
      }
      let angle = atan2(dy, dx)
      let directedAngle = normalizedAngle(angle - startAngleRad)
      if sweepAngleRad >= 0 {
        return directedAngle <= sweepAngleRad + 0.0001
      }
      return directedAngle >= (2.0 * Double.pi + sweepAngleRad - 0.0001)
    }
  }

  static func line(
    start: ModelPoint,
    end: ModelPoint,
    label: String,
    labelOffsetMM: ModelPoint,
    overallOffsetMM: ModelPoint,
    in pageRect: CGRect,
    orientation: OutputPrintOrientation
  ) -> Line? {
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect, orientation: orientation)
    let startPoint = coordinateSpace.canvasPoint(for: start)
    let endPoint = coordinateSpace.canvasPoint(for: end)
    let dx = endPoint.x - startPoint.x
    let dy = endPoint.y - startPoint.y
    let length = hypot(dx, dy)
    guard length > 0.001 else {
      return nil
    }
    let normal = CGPoint(x: -dy / length * 12.0, y: dx / length * 12.0)
    let overallOffset = canvasOffset(overallOffsetMM, scale: coordinateSpace.scale)
    let labelOffset = canvasOffset(labelOffsetMM, scale: coordinateSpace.scale)
    let shiftedStart = startPoint.offsetBy(
      dx: normal.x + overallOffset.x,
      dy: normal.y + overallOffset.y
    )
    let shiftedEnd = endPoint.offsetBy(
      dx: normal.x + overallOffset.x,
      dy: normal.y + overallOffset.y
    )
    let labelPoint = CGPoint(
      x: (shiftedStart.x + shiftedEnd.x) / 2.0 + normal.x * 0.35 + labelOffset.x,
      y: (shiftedStart.y + shiftedEnd.y) / 2.0 + normal.y * 0.35 + labelOffset.y
    )
    return Line(
      startPoint: startPoint,
      endPoint: endPoint,
      shiftedStart: shiftedStart,
      shiftedEnd: shiftedEnd,
      labelPoint: labelPoint,
      labelRect: CanvasLayout.measurementLabelRect(label: label, around: labelPoint)
    )
  }

  static func axis(
    start: ModelPoint,
    end: ModelPoint,
    axis: Axis,
    label: String,
    labelOffsetMM: ModelPoint,
    overallOffsetMM: ModelPoint,
    in pageRect: CGRect,
    orientation: OutputPrintOrientation
  ) -> AxisLine? {
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect, orientation: orientation)
    let firstPoint = coordinateSpace.canvasPoint(for: start)
    let secondPoint = coordinateSpace.canvasPoint(for: end)
    let overallOffset = canvasOffset(overallOffsetMM, scale: coordinateSpace.scale)
    let labelOffset = canvasOffset(labelOffsetMM, scale: coordinateSpace.scale)
    let dimensionStart: CGPoint
    let dimensionEnd: CGPoint
    let labelPoint: CGPoint
    switch axis {
    case .horizontal:
      guard abs(secondPoint.x - firstPoint.x) > 0.001 else {
        return nil
      }
      let y = min(firstPoint.y, secondPoint.y) - 16.0 + overallOffset.y
      dimensionStart = CGPoint(x: firstPoint.x, y: y)
      dimensionEnd = CGPoint(x: secondPoint.x, y: y)
      labelPoint = CGPoint(
        x: (dimensionStart.x + dimensionEnd.x) / 2.0 + labelOffset.x,
        y: y - 14.0 + labelOffset.y
      )
    case .vertical:
      guard abs(secondPoint.y - firstPoint.y) > 0.001 else {
        return nil
      }
      let x = max(firstPoint.x, secondPoint.x) + 16.0 + overallOffset.x
      dimensionStart = CGPoint(x: x, y: firstPoint.y)
      dimensionEnd = CGPoint(x: x, y: secondPoint.y)
      labelPoint = CGPoint(
        x: x + 8.0 + labelOffset.x,
        y: (dimensionStart.y + dimensionEnd.y) / 2.0 + labelOffset.y
      )
    }
    return AxisLine(
      firstPoint: firstPoint,
      secondPoint: secondPoint,
      dimensionStart: dimensionStart,
      dimensionEnd: dimensionEnd,
      labelPoint: labelPoint,
      labelRect: CanvasLayout.measurementLabelRect(label: label, around: labelPoint)
    )
  }

  static func angle(
    overlay: AngleConstraintOverlay,
    label: String,
    labelOffsetMM: ModelPoint,
    overallOffsetMM: ModelPoint,
    in pageRect: CGRect,
    orientation: OutputPrintOrientation
  ) -> Angle? {
    let coordinateSpace = CanvasCoordinateSpace(pageRect: pageRect, orientation: orientation)
    let overallOffset = canvasOffset(overallOffsetMM, scale: coordinateSpace.scale)
    let labelOffset = canvasOffset(labelOffsetMM, scale: coordinateSpace.scale)
    let centerPoint = coordinateSpace.canvasPoint(for: overlay.center).offsetBy(
      dx: overallOffset.x,
      dy: overallOffset.y
    )
    let startPoint = coordinateSpace.canvasPoint(for: overlay.start).offsetBy(
      dx: overallOffset.x,
      dy: overallOffset.y
    )
    let endPoint = coordinateSpace.canvasPoint(for: overlay.end).offsetBy(
      dx: overallOffset.x,
      dy: overallOffset.y
    )
    let startLength = hypot(startPoint.x - centerPoint.x, startPoint.y - centerPoint.y)
    let endLength = hypot(endPoint.x - centerPoint.x, endPoint.y - centerPoint.y)
    guard startLength > 0.001, endLength > 0.001 else {
      return nil
    }
    let radius = max(18.0, min(min(startLength, endLength) * 0.34, 44.0))
    let startAngleRad = angleRadians(from: overlay.center, to: overlay.start)
    let sweepAngleRad = degreesToRadians(overlay.signedDegrees)
    let labelPoint = point(
      from: centerPoint,
      angleRad: startAngleRad + sweepAngleRad / 2.0,
      radius: radius + 18.0
    ).offsetBy(dx: labelOffset.x, dy: labelOffset.y)
    return Angle(
      centerPoint: centerPoint,
      startPoint: startPoint,
      endPoint: endPoint,
      radius: radius,
      startAngleRad: startAngleRad,
      sweepAngleRad: sweepAngleRad,
      labelPoint: labelPoint,
      labelRect: CanvasLayout.measurementLabelRect(label: label, around: labelPoint)
    )
  }

  private static func canvasOffset(_ offset: ModelPoint, scale: CGFloat) -> CGPoint {
    CGPoint(x: offset.xMM * scale, y: -offset.yMM * scale)
  }

  private static func point(from center: CGPoint, angleRad: Double, radius: CGFloat) -> CGPoint {
    CGPoint(
      x: center.x + radius * CGFloat(cos(angleRad)),
      y: center.y - radius * CGFloat(sin(angleRad))
    )
  }

  private static func normalizedAngle(_ angle: Double) -> Double {
    let fullTurn = 2.0 * Double.pi
    let normalized = angle.truncatingRemainder(dividingBy: fullTurn)
    return normalized >= 0 ? normalized : normalized + fullTurn
  }
}
