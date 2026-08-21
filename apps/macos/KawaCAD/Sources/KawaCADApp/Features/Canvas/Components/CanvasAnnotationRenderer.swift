import AppKit
import KawaCADOutput

/// Draws measurement and dimension annotations from a value-only snapshot.
/// The view prepares these items; it does not own annotation drawing rules.
struct CanvasAnnotationRenderer {
  enum Kind {
    case measurement
    case dimension
  }

  enum Geometry {
    case line(start: ModelPoint, end: ModelPoint)
    case axis(start: ModelPoint, end: ModelPoint, axis: CanvasAnnotationLayout.Axis)
    case angle(AngleConstraintOverlay)
  }

  struct Item {
    let kind: Kind
    let label: String
    let geometry: Geometry
    let labelOffsetMM: ModelPoint
    let overallOffsetMM: ModelPoint
    let highlighted: Bool
  }

  struct Input {
    let items: [Item]
    let orientation: OutputPrintOrientation
  }

  enum Layout {
    case line(CanvasAnnotationLayout.Line)
    case axis(CanvasAnnotationLayout.AxisLine)
    case angle(CanvasAnnotationLayout.Angle)
  }

  let input: Input

  func draw(in pageRect: CGRect) {
    for item in input.items {
      guard let layout = layout(for: item, in: pageRect) else { continue }
      switch layout {
      case .line(let line):
        drawLine(item, layout: line)
      case .axis(let axis):
        drawAxisLine(item, layout: axis)
      case .angle(let angle):
        drawAngle(item, layout: angle)
      }
    }
  }

  func layout(for item: Item, in pageRect: CGRect) -> Layout? {
    switch item.geometry {
    case .line(let start, let end):
      return CanvasAnnotationLayout.line(
        start: start,
        end: end,
        label: item.label,
        labelOffsetMM: item.labelOffsetMM,
        overallOffsetMM: item.overallOffsetMM,
        in: pageRect,
        orientation: input.orientation
      ).map(Layout.line)
    case .axis(let start, let end, let axis):
      return CanvasAnnotationLayout.axis(
        start: start,
        end: end,
        axis: axis,
        label: item.label,
        labelOffsetMM: item.labelOffsetMM,
        overallOffsetMM: item.overallOffsetMM,
        in: pageRect,
        orientation: input.orientation
      ).map(Layout.axis)
    case .angle(let overlay):
      return CanvasAnnotationLayout.angle(
        overlay: overlay,
        label: item.label,
        labelOffsetMM: item.labelOffsetMM,
        overallOffsetMM: item.overallOffsetMM,
        in: pageRect,
        orientation: input.orientation
      ).map(Layout.angle)
    }
  }

  private func drawLine(
    _ item: Item,
    layout: CanvasAnnotationLayout.Line
  ) {
    let color = color(for: item)
    color.setStroke()
    let path = NSBezierPath()
    path.move(to: layout.shiftedStart)
    path.line(to: layout.shiftedEnd)
    path.move(to: layout.startPoint)
    path.line(to: layout.shiftedStart)
    path.move(to: layout.endPoint)
    path.line(to: layout.shiftedEnd)
    path.lineWidth = item.highlighted ? 1.5 : 1.0
    path.lineCapStyle = .round
    path.stroke()

    drawArrowhead(
      at: layout.shiftedStart,
      toward: layout.shiftedEnd,
      color: color,
      highlighted: item.highlighted
    )
    drawArrowhead(
      at: layout.shiftedEnd,
      toward: layout.shiftedStart,
      color: color,
      highlighted: item.highlighted
    )
    drawLabel(item.label, in: layout.labelRect, highlighted: item.highlighted)
  }

  private func drawAxisLine(
    _ item: Item,
    layout: CanvasAnnotationLayout.AxisLine
  ) {
    let color = color(for: item)
    color.setStroke()
    let path = NSBezierPath()
    path.move(to: layout.dimensionStart)
    path.line(to: layout.dimensionEnd)
    path.move(to: layout.firstPoint)
    path.line(to: layout.dimensionStart)
    path.move(to: layout.secondPoint)
    path.line(to: layout.dimensionEnd)
    path.lineWidth = item.highlighted ? 1.5 : 1.0
    path.lineCapStyle = .round
    path.stroke()

    drawArrowhead(
      at: layout.dimensionStart, toward: layout.dimensionEnd, color: color,
      highlighted: item.highlighted)
    drawArrowhead(
      at: layout.dimensionEnd, toward: layout.dimensionStart, color: color,
      highlighted: item.highlighted)
    drawLabel(item.label, in: layout.labelRect, highlighted: item.highlighted)
  }

  private func drawAngle(
    _ item: Item,
    layout: CanvasAnnotationLayout.Angle
  ) {
    let color = color(for: item)
    color.setStroke()

    let baseline = NSBezierPath()
    baseline.move(to: layout.centerPoint)
    baseline.line(
      to: point(from: layout.centerPoint, toward: layout.startPoint, distance: layout.radius + 8.0))
    baseline.lineWidth = item.highlighted ? 2.0 : 1.2
    baseline.lineCapStyle = .round
    baseline.stroke()

    if abs(layout.sweepAngleRad) > 0.0001 {
      let parameters = canvasArcPathParameters(
        startAngleRad: layout.startAngleRad,
        sweepAngleRad: layout.sweepAngleRad
      )
      let arc = NSBezierPath()
      arc.appendArc(
        withCenter: layout.centerPoint,
        radius: layout.radius,
        startAngle: parameters.startAngleDeg,
        endAngle: parameters.endAngleDeg,
        clockwise: parameters.clockwise
      )
      arc.lineWidth = item.highlighted ? 2.0 : 1.4
      arc.lineCapStyle = .round
      arc.stroke()
      drawArrowhead(
        at: point(from: layout.centerPoint, angleRad: layout.startAngleRad, radius: layout.radius),
        tangentAngleRad: layout.startAngleRad
          + (layout.sweepAngleRad >= 0 ? .pi / 2.0 : -.pi / 2.0),
        color: color,
        highlighted: item.highlighted
      )
      drawArrowhead(
        at: point(
          from: layout.centerPoint,
          angleRad: layout.startAngleRad + layout.sweepAngleRad,
          radius: layout.radius
        ),
        tangentAngleRad: layout.startAngleRad + layout.sweepAngleRad
          + (layout.sweepAngleRad >= 0 ? -.pi / 2.0 : .pi / 2.0),
        color: color,
        highlighted: item.highlighted
      )
    }

    drawLabel(item.label, in: layout.labelRect, highlighted: item.highlighted)
  }

  private func color(for item: Item) -> NSColor {
    if item.highlighted {
      return NSColor(calibratedRed: 0.867, green: 0.337, blue: 0.082, alpha: 0.96)
    }
    switch item.kind {
    case .measurement:
      return NSColor(calibratedRed: 0.047, green: 0.376, blue: 0.345, alpha: 0.82)
    case .dimension:
      return NSColor(calibratedRed: 0.180, green: 0.260, blue: 0.420, alpha: 0.86)
    }
  }

  private func drawLabel(_ label: String, in rect: CGRect, highlighted: Bool) {
    let foreground =
      highlighted
      ? NSColor(calibratedRed: 0.984, green: 0.961, blue: 0.894, alpha: 1.0)
      : NSColor(calibratedRed: 0.090, green: 0.125, blue: 0.165, alpha: 0.94)
    let background =
      highlighted
      ? NSColor(calibratedRed: 0.867, green: 0.337, blue: 0.082, alpha: 0.90)
      : NSColor(calibratedWhite: 1.0, alpha: 0.82)
    let text = NSAttributedString(
      string: label,
      attributes: [
        .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
        .foregroundColor: foreground,
      ]
    )
    background.setFill()
    NSBezierPath(roundedRect: rect, xRadius: 5.0, yRadius: 5.0).fill()
    text.draw(at: CGPoint(x: rect.minX + 5.0, y: rect.minY + 2.5))
  }

  private func drawArrowhead(
    at point: CGPoint,
    toward other: CGPoint,
    color: NSColor,
    highlighted: Bool
  ) {
    let dx = other.x - point.x
    let dy = other.y - point.y
    let length = hypot(dx, dy)
    guard length > 0.001 else { return }
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
    let path = NSBezierPath()
    path.move(to: point)
    path.line(to: first)
    path.line(to: second)
    path.close()
    path.fill()
  }

  private func drawArrowhead(
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

  private func point(from start: CGPoint, toward end: CGPoint, distance: CGFloat) -> CGPoint {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let length = hypot(dx, dy)
    guard length > 0.001 else { return start }
    return CGPoint(x: start.x + dx / length * distance, y: start.y + dy / length * distance)
  }

  private func point(from center: CGPoint, angleRad: Double, radius: CGFloat) -> CGPoint {
    CGPoint(
      x: center.x + radius * CGFloat(cos(angleRad)),
      y: center.y - radius * CGFloat(sin(angleRad))
    )
  }
}
