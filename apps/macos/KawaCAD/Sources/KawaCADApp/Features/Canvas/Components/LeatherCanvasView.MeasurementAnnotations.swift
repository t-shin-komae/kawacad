import AppKit
import KawaCADOutput
import SwiftUI

/// Rendering responsibilities extracted from the input-oriented canvas view.
/// The view still owns lifecycle and callbacks; this extension owns the
/// projection of the current immutable canvas snapshot into AppKit drawing.
extension LeatherCanvasView {
  func drawMeasurementAnnotations(in pageRect: CGRect) {
    guard !isOutputPreviewMode else {
      return
    }
    for annotation in measurementAnnotations where annotation.visible {
      guard let label = measurementAnnotationLabel(for: annotation),
        let resolved = canvasProjection.measurementAnnotations.first(where: {
          $0.id == annotation.id && $0.visible
        })
      else {
        continue
      }
      let highlighted =
        annotation.id == selectedMeasurementAnnotationID
        || highlightedPartMeasurementAnnotationIDs.contains(annotation.id)
      switch annotation.rawKind {
      case "distance":
        guard let first = resolved.startMM, let second = resolved.endMM else { continue }
        drawMeasurementLine(
          id: annotation.id,
          from: first,
          to: second,
          label: label,
          labelOffsetMM: annotation.labelOffsetMM,
          overallOffsetMM: annotation.overallOffsetMM,
          highlighted: highlighted,
          in: pageRect
        )
      case "segmentLength":
        guard let start = resolved.startMM, let end = resolved.endMM else { continue }
        drawMeasurementLine(
          id: annotation.id,
          from: start,
          to: end,
          label: label,
          labelOffsetMM: annotation.labelOffsetMM,
          overallOffsetMM: annotation.overallOffsetMM,
          highlighted: highlighted,
          in: pageRect
        )
      case "diameter":
        guard let start = resolved.startMM, let end = resolved.endMM else { continue }
        drawMeasurementLine(
          id: annotation.id,
          from: start,
          to: end,
          label: label,
          labelOffsetMM: annotation.labelOffsetMM,
          overallOffsetMM: annotation.overallOffsetMM,
          highlighted: highlighted,
          in: pageRect
        )
      case "radius":
        guard let center = resolved.centerMM, let start = resolved.startMM else { continue }
        drawMeasurementLine(
          id: annotation.id,
          from: center,
          to: start,
          label: label,
          labelOffsetMM: annotation.labelOffsetMM,
          overallOffsetMM: annotation.overallOffsetMM,
          highlighted: highlighted,
          in: pageRect
        )
      case "angle", "arcSweepAngle":
        guard let overlay = measurementAngleOverlay(for: annotation) else {
          continue
        }
        drawMeasurementAngleOverlay(
          overlay,
          labelOffsetMM: annotation.labelOffsetMM,
          overallOffsetMM: annotation.overallOffsetMM,
          highlighted: highlighted,
          in: pageRect
        )
      default:
        continue
      }
    }
  }

  func drawMeasurementLine(
    id: String,
    from start: ModelPoint,
    to end: ModelPoint,
    label: String,
    labelOffsetMM: ModelPoint,
    overallOffsetMM: ModelPoint,
    highlighted: Bool,
    in pageRect: CGRect
  ) {
    guard
      let layout = measurementLineLayout(
        from: start,
        to: end,
        label: label,
        labelOffsetMM: labelOffsetMM,
        overallOffsetMM: overallOffsetMM,
        in: pageRect
      )
    else {
      return
    }

    let color =
      highlighted
      ? NSColor(calibratedRed: 0.867, green: 0.337, blue: 0.082, alpha: 0.96)
      : NSColor(calibratedRed: 0.047, green: 0.376, blue: 0.345, alpha: 0.82)
    color.setStroke()
    let path = NSBezierPath()
    path.move(to: layout.shiftedStart)
    path.line(to: layout.shiftedEnd)
    path.move(to: layout.startPoint)
    path.line(to: layout.shiftedStart)
    path.move(to: layout.endPoint)
    path.line(to: layout.shiftedEnd)
    path.lineWidth = highlighted ? 1.5 : 1.0
    path.lineCapStyle = .round
    path.stroke()

    drawLinearDimensionArrowhead(
      at: layout.shiftedStart, toward: layout.shiftedEnd, color: color, highlighted: highlighted)
    drawLinearDimensionArrowhead(
      at: layout.shiftedEnd, toward: layout.shiftedStart, color: color, highlighted: highlighted)
    drawMeasurementLabel(label, in: layout.labelRect, highlighted: highlighted)
  }

  func drawMeasurementAngleOverlay(
    _ overlay: AngleConstraintOverlay,
    labelOffsetMM: ModelPoint,
    overallOffsetMM: ModelPoint,
    highlighted: Bool,
    in pageRect: CGRect
  ) {
    let scale = canvasScale(in: pageRect)
    let overallOffset = canvasOffset(for: overallOffsetMM, scale: scale)
    let labelOffset = canvasOffset(for: labelOffsetMM, scale: scale)
    let centerPoint = canvasPoint(for: overlay.center, in: pageRect).offsetBy(
      dx: overallOffset.x, dy: overallOffset.y)
    let startPoint = canvasPoint(for: overlay.start, in: pageRect).offsetBy(
      dx: overallOffset.x, dy: overallOffset.y)
    let endPoint = canvasPoint(for: overlay.end, in: pageRect).offsetBy(
      dx: overallOffset.x, dy: overallOffset.y)
    let startVector = CGPoint(x: startPoint.x - centerPoint.x, y: startPoint.y - centerPoint.y)
    let endVector = CGPoint(x: endPoint.x - centerPoint.x, y: endPoint.y - centerPoint.y)
    let startLength = hypot(startVector.x, startVector.y)
    let endLength = hypot(endVector.x, endVector.y)
    guard startLength > 0.001, endLength > 0.001 else { return }

    let radius = max(18.0, min(min(startLength, endLength) * 0.34, 44.0))
    let startAngle = angleRadians(from: overlay.center, to: overlay.start)
    let sweepAngle = degreesToRadians(overlay.signedDegrees)
    let color =
      highlighted
      ? NSColor(calibratedRed: 0.867, green: 0.337, blue: 0.082, alpha: 0.96)
      : NSColor(calibratedRed: 0.047, green: 0.376, blue: 0.345, alpha: 0.82)
    color.setStroke()
    let baseline = NSBezierPath()
    baseline.move(to: centerPoint)
    baseline.line(to: point(from: centerPoint, toward: startPoint, distance: radius + 8.0))
    baseline.lineWidth = highlighted ? 1.7 : 1.1
    baseline.stroke()

    if abs(sweepAngle) > 0.0001 {
      let pathParameters = canvasArcPathParameters(
        startAngleRad: startAngle, sweepAngleRad: sweepAngle)
      let arc = NSBezierPath()
      arc.appendArc(
        withCenter: centerPoint,
        radius: radius,
        startAngle: pathParameters.startAngleDeg,
        endAngle: pathParameters.endAngleDeg,
        clockwise: pathParameters.clockwise
      )
      arc.lineWidth = highlighted ? 1.8 : 1.2
      arc.stroke()

      let startTip = point(from: centerPoint, angleRad: startAngle, radius: radius)
      let endTip = point(from: centerPoint, angleRad: startAngle + sweepAngle, radius: radius)
      drawAngleArrowhead(
        at: startTip,
        tangentAngleRad: startAngle + (sweepAngle >= 0 ? .pi / 2.0 : -.pi / 2.0),
        color: color,
        highlighted: highlighted
      )
      drawAngleArrowhead(
        at: endTip,
        tangentAngleRad: startAngle + sweepAngle + (sweepAngle >= 0 ? -.pi / 2.0 : .pi / 2.0),
        color: color,
        highlighted: highlighted
      )
    }
    let labelPoint = angleLabelPoint(
      center: centerPoint,
      startAngleRad: startAngle,
      sweepAngleRad: sweepAngle,
      radius: radius
    ).offsetBy(dx: labelOffset.x, dy: labelOffset.y)
    let labelRect = measurementLabelRect(label: overlay.label, around: labelPoint)
    drawMeasurementLabel(overlay.label, in: labelRect, highlighted: highlighted)
  }

  func drawMeasurementLabel(_ label: String, in rect: CGRect, highlighted: Bool) {
    let foreground =
      highlighted
      ? NSColor(calibratedRed: 0.984, green: 0.961, blue: 0.894, alpha: 1.0)
      : NSColor(calibratedRed: 0.090, green: 0.125, blue: 0.165, alpha: 0.94)
    let background =
      highlighted
      ? NSColor(calibratedRed: 0.867, green: 0.337, blue: 0.082, alpha: 0.90)
      : NSColor(calibratedWhite: 1.0, alpha: 0.82)
    background.setFill()
    let bubble = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
    bubble.fill()
    NSAttributedString(
      string: label,
      attributes: [
        .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
        .foregroundColor: foreground,
      ]
    ).draw(at: CGPoint(x: rect.minX + 5, y: rect.minY + 2.5))
  }

  func dimensionConstraintColor(highlighted: Bool) -> NSColor {
    highlighted
      ? NSColor(calibratedRed: 0.867, green: 0.337, blue: 0.082, alpha: 0.96)
      : NSColor(calibratedRed: 0.180, green: 0.260, blue: 0.420, alpha: 0.86)
  }

  func drawLinearDimensionArrowhead(
    at point: CGPoint, toward other: CGPoint, color: NSColor, highlighted: Bool
  ) {
    let dx = other.x - point.x
    let dy = other.y - point.y
    let length = hypot(dx, dy)
    guard length > 0.001 else {
      return
    }
    let arrowLength: CGFloat = highlighted ? 10.0 : 8.0
    let arrowHalfWidth: CGFloat = highlighted ? 4.2 : 3.4
    let unit = CGPoint(x: dx / length, y: dy / length)
    let normal = CGPoint(x: -unit.y, y: unit.x)
    let base = CGPoint(
      x: point.x + unit.x * arrowLength,
      y: point.y + unit.y * arrowLength
    )
    let first = CGPoint(
      x: base.x + normal.x * arrowHalfWidth,
      y: base.y + normal.y * arrowHalfWidth
    )
    let second = CGPoint(
      x: base.x - normal.x * arrowHalfWidth,
      y: base.y - normal.y * arrowHalfWidth
    )
    color.setFill()
    let arrow = NSBezierPath()
    arrow.move(to: point)
    arrow.line(to: first)
    arrow.line(to: second)
    arrow.close()
    arrow.fill()
  }

  struct MeasurementLineLayout {
    let startPoint: CGPoint
    let endPoint: CGPoint
    let shiftedStart: CGPoint
    let shiftedEnd: CGPoint
    let labelRect: CGRect
  }

  struct MeasurementAnnotationHit {
    let annotation: ProjectMeasurementAnnotation
    let labelOnly: Bool
  }

  struct DimensionConstraintAnnotationHit {
    let constraint: ProjectConstraint
    let labelOnly: Bool
  }

  func dimensionConstraintDisplayAnnotation(for constraintID: String)
    -> ProjectDimensionConstraintAnnotation
  {
    let base =
      dimensionConstraintAnnotations.first(where: { $0.constraintID == constraintID })
      ?? ProjectDimensionConstraintAnnotation(
        constraintID: constraintID,
        labelOffsetMM: ModelPoint(xMM: 0, yMM: 0),
        overallOffsetMM: ModelPoint(xMM: 0, yMM: 0),
        visible: true
      )
    guard let drag = dimensionConstraintDragState,
      drag.constraintID == constraintID
    else {
      return base
    }
    let delta = CanvasInteractionState.delta(from: drag.startPoint, to: drag.currentPoint)
    return base.withOffsets(
      labelOffsetMM: drag.labelOnly
        ? base.labelOffsetMM.translatedBy(dxMM: delta.xMM, dyMM: delta.yMM)
        : base.labelOffsetMM,
      overallOffsetMM: drag.labelOnly
        ? base.overallOffsetMM
        : base.overallOffsetMM.translatedBy(dxMM: delta.xMM, dyMM: delta.yMM)
    )
  }

  func measurementLineLayout(
    from start: ModelPoint,
    to end: ModelPoint,
    label: String,
    labelOffsetMM: ModelPoint,
    overallOffsetMM: ModelPoint,
    in pageRect: CGRect
  ) -> MeasurementLineLayout? {
    let scale = canvasScale(in: pageRect)
    let startPoint = canvasPoint(for: start, in: pageRect)
    let endPoint = canvasPoint(for: end, in: pageRect)
    let dx = endPoint.x - startPoint.x
    let dy = endPoint.y - startPoint.y
    let length = hypot(dx, dy)
    guard length > 0.001 else {
      return nil
    }
    let normal = CGPoint(x: -dy / length * 12.0, y: dx / length * 12.0)
    let overallOffset = canvasOffset(for: overallOffsetMM, scale: scale)
    let labelOffset = canvasOffset(for: labelOffsetMM, scale: scale)
    let shiftedStart = CGPoint(
      x: startPoint.x + normal.x + overallOffset.x,
      y: startPoint.y + normal.y + overallOffset.y
    )
    let shiftedEnd = CGPoint(
      x: endPoint.x + normal.x + overallOffset.x,
      y: endPoint.y + normal.y + overallOffset.y
    )
    let labelPoint = CGPoint(
      x: (shiftedStart.x + shiftedEnd.x) / 2.0 + normal.x * 0.35 + labelOffset.x,
      y: (shiftedStart.y + shiftedEnd.y) / 2.0 + normal.y * 0.35 + labelOffset.y
    )
    return MeasurementLineLayout(
      startPoint: startPoint,
      endPoint: endPoint,
      shiftedStart: shiftedStart,
      shiftedEnd: shiftedEnd,
      labelRect: measurementLabelRect(label: label, around: labelPoint)
    )
  }

  func measurementLabelRect(label: String, around point: CGPoint) -> CGRect {
    let text = NSAttributedString(
      string: label,
      attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .semibold)]
    )
    let size = text.size()
    return CGRect(
      x: point.x - size.width / 2.0 - 5.0,
      y: point.y - size.height / 2.0 - 2.5,
      width: size.width + 10.0,
      height: size.height + 5.0
    )
  }

  func canvasOffset(for offset: ModelPoint, scale: CGFloat) -> CGPoint {
    CGPoint(x: offset.xMM * scale, y: -offset.yMM * scale)
  }

  func distanceFrom(_ point: CGPoint, toSegmentStart start: CGPoint, end: CGPoint) -> CGFloat {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let lengthSquared = dx * dx + dy * dy
    guard lengthSquared > 0.001 else {
      return hypot(point.x - start.x, point.y - start.y)
    }
    let t = max(
      0.0, min(1.0, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
    let projected = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
    return hypot(point.x - projected.x, point.y - projected.y)
  }

  func measurementAnnotationLabel(for annotation: ProjectMeasurementAnnotation) -> String? {
    guard let evaluation = measurementEvaluations.first(where: { $0.annotationId == annotation.id })
    else {
      return nil
    }
    switch evaluation.value {
    case .fixedMm(let value):
      return String(format: "%.2f mm", value)
    case .fixedDegrees(let value):
      return String(format: "%.1f°", value)
    case .parameter:
      return nil
    }
  }

  func measurementAngleOverlay(
    for annotation: ProjectMeasurementAnnotation
  ) -> AngleConstraintOverlay? {
    guard
      let evaluation = measurementEvaluations.first(where: { $0.annotationId == annotation.id }),
      let resolved = canvasProjection.measurementAnnotations.first(where: {
        $0.id == annotation.id && $0.visible
      }),
      let center = resolved.centerMM,
      let start = resolved.startMM,
      let end = resolved.endMM,
      case .fixedDegrees(let degrees) = evaluation.value
    else { return nil }
    return AngleConstraintOverlay(
      constraintID: annotation.id,
      kind: resolved.arc == true ? .arc : .linePair,
      center: center,
      start: start,
      end: end,
      signedDegrees: degrees
    )
  }

  func angleConstraintOverlay(for constraint: ProjectConstraint) -> AngleConstraintOverlay? {
    guard constraint.rawKind == "angle",
      let resolved = canvasProjection.dimensionConstraints.first(where: {
        $0.id == constraint.id && $0.visible
      }),
      let center = resolved.centerMM,
      let start = resolved.startMM,
      let end = resolved.endMM,
      let signedDegrees = constraint.valueDegrees
    else { return nil }
    return AngleConstraintOverlay(
      constraintID: constraint.id,
      kind: resolved.arc == true ? .arc : .linePair,
      center: center,
      start: start,
      end: end,
      signedDegrees: signedDegrees
    )
  }

  func drawAngleConstraintOverlay(
    _ overlay: AngleConstraintOverlay,
    labelOffsetMM: ModelPoint,
    overallOffsetMM: ModelPoint,
    highlighted: Bool,
    in pageRect: CGRect
  ) {
    let scale = canvasScale(in: pageRect)
    let overallOffset = canvasOffset(for: overallOffsetMM, scale: scale)
    let labelOffset = canvasOffset(for: labelOffsetMM, scale: scale)
    let centerPoint = canvasPoint(for: overlay.center, in: pageRect).offsetBy(
      dx: overallOffset.x, dy: overallOffset.y)
    let startPoint = canvasPoint(for: overlay.start, in: pageRect).offsetBy(
      dx: overallOffset.x, dy: overallOffset.y)
    let endPoint = canvasPoint(for: overlay.end, in: pageRect).offsetBy(
      dx: overallOffset.x, dy: overallOffset.y)
    let startVector = CGPoint(x: startPoint.x - centerPoint.x, y: startPoint.y - centerPoint.y)
    let endVector = CGPoint(x: endPoint.x - centerPoint.x, y: endPoint.y - centerPoint.y)
    let startLength = hypot(startVector.x, startVector.y)
    let endLength = hypot(endVector.x, endVector.y)
    guard startLength > 0.001, endLength > 0.001 else {
      return
    }

    let baseRadius = min(startLength, endLength)
    let radius = max(18.0, min(baseRadius * 0.34, 44.0))
    let startAngle = angleRadians(from: overlay.center, to: overlay.start)
    let sweepAngle = degreesToRadians(overlay.signedDegrees)
    let drawsArc = abs(sweepAngle) > 0.0001
    let color =
      highlighted
      ? NSColor(calibratedRed: 0.867, green: 0.337, blue: 0.082, alpha: 0.96)
      : NSColor(calibratedRed: 0.047, green: 0.376, blue: 0.345, alpha: 0.82)

    NSGraphicsContext.saveGraphicsState()
    if highlighted, drawsArc {
      let pathParameters = canvasArcPathParameters(
        startAngleRad: startAngle, sweepAngleRad: sweepAngle)
      color.withAlphaComponent(0.12).setFill()
      let wedge = NSBezierPath()
      wedge.move(to: centerPoint)
      wedge.appendArc(
        withCenter: centerPoint,
        radius: radius,
        startAngle: pathParameters.startAngleDeg,
        endAngle: pathParameters.endAngleDeg,
        clockwise: pathParameters.clockwise
      )
      wedge.close()
      wedge.fill()
    }

    color.setStroke()
    let baseline = NSBezierPath()
    baseline.move(to: centerPoint)
    baseline.line(to: point(from: centerPoint, toward: startPoint, distance: radius + 8.0))
    baseline.lineWidth = highlighted ? 2.0 : 1.2
    baseline.lineCapStyle = .round
    baseline.stroke()

    if drawsArc {
      let pathParameters = canvasArcPathParameters(
        startAngleRad: startAngle, sweepAngleRad: sweepAngle)
      let arc = NSBezierPath()
      arc.appendArc(
        withCenter: centerPoint,
        radius: radius,
        startAngle: pathParameters.startAngleDeg,
        endAngle: pathParameters.endAngleDeg,
        clockwise: pathParameters.clockwise
      )
      arc.lineWidth = highlighted ? 2.0 : 1.4
      arc.lineCapStyle = .round
      arc.stroke()

      let startTip = point(from: centerPoint, angleRad: startAngle, radius: radius)
      let endTip = point(from: centerPoint, angleRad: startAngle + sweepAngle, radius: radius)
      drawAngleArrowhead(
        at: startTip,
        tangentAngleRad: startAngle + (sweepAngle >= 0 ? .pi / 2.0 : -.pi / 2.0),
        color: color,
        highlighted: highlighted
      )
      drawAngleArrowhead(
        at: endTip,
        tangentAngleRad: startAngle + sweepAngle + (sweepAngle >= 0 ? -.pi / 2.0 : .pi / 2.0),
        color: color,
        highlighted: highlighted
      )
    }

    drawAngleConstraintLabel(
      overlay.label,
      at: angleLabelPoint(
        center: centerPoint, startAngleRad: startAngle, sweepAngleRad: sweepAngle, radius: radius
      )
      .offsetBy(dx: labelOffset.x, dy: labelOffset.y),
      highlighted: highlighted
    )
    NSGraphicsContext.restoreGraphicsState()
  }

  func drawAngleArrowhead(
    at tip: CGPoint,
    tangentAngleRad: Double,
    color: NSColor,
    highlighted: Bool
  ) {
    let length: CGFloat = highlighted ? 9.0 : 7.5
    let halfWidth: CGFloat = highlighted ? 4.0 : 3.3
    let direction = CGPoint(
      x: CGFloat(cos(tangentAngleRad)),
      y: -CGFloat(sin(tangentAngleRad))
    )
    let normal = CGPoint(x: -direction.y, y: direction.x)
    let base = CGPoint(
      x: tip.x - direction.x * length,
      y: tip.y - direction.y * length
    )
    let first = CGPoint(
      x: base.x + normal.x * halfWidth,
      y: base.y + normal.y * halfWidth
    )
    let second = CGPoint(
      x: base.x - normal.x * halfWidth,
      y: base.y - normal.y * halfWidth
    )
    color.setFill()
    let path = NSBezierPath()
    path.move(to: tip)
    path.line(to: first)
    path.line(to: second)
    path.close()
    path.fill()
  }

  func drawAngleConstraintLabel(_ label: String, at point: CGPoint, highlighted: Bool) {
    let foreground =
      highlighted
      ? NSColor(calibratedRed: 0.984, green: 0.961, blue: 0.894, alpha: 1.0)
      : NSColor(calibratedRed: 0.090, green: 0.125, blue: 0.165, alpha: 0.94)
    let background =
      highlighted
      ? NSColor(calibratedRed: 0.867, green: 0.337, blue: 0.082, alpha: 0.90)
      : NSColor(calibratedWhite: 1.0, alpha: 0.78)
    let text = NSAttributedString(
      string: label,
      attributes: [
        .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
        .foregroundColor: foreground,
      ]
    )
    let size = text.size()
    let rect = CGRect(
      x: point.x - size.width / 2.0 - 5.0,
      y: point.y - size.height / 2.0 - 2.5,
      width: size.width + 10.0,
      height: size.height + 5.0
    )
    background.setFill()
    let path = NSBezierPath(roundedRect: rect, xRadius: 5.0, yRadius: 5.0)
    path.fill()
    text.draw(at: CGPoint(x: rect.minX + 5.0, y: rect.minY + 2.5))
  }

  func angleLabelPoint(
    center: CGPoint,
    startAngleRad: Double,
    sweepAngleRad: Double,
    radius: CGFloat
  ) -> CGPoint {
    point(
      from: center,
      angleRad: startAngleRad + sweepAngleRad / 2.0,
      radius: radius + 18.0
    )
  }

  func point(from start: CGPoint, toward end: CGPoint, distance: CGFloat) -> CGPoint {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let length = hypot(dx, dy)
    guard length > 0.001 else {
      return start
    }
    return CGPoint(
      x: start.x + dx / length * distance,
      y: start.y + dy / length * distance
    )
  }

  func point(from center: CGPoint, angleRad: Double, radius: CGFloat) -> CGPoint {
    CGPoint(
      x: center.x + radius * CGFloat(cos(angleRad)),
      y: center.y - radius * CGFloat(sin(angleRad))
    )
  }

}
