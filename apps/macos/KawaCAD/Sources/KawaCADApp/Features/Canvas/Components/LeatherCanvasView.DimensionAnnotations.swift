import AppKit
import KawaCADOutput
import SwiftUI

/// Rendering responsibilities extracted from the input-oriented canvas view.
/// The view still owns lifecycle and callbacks; this extension owns the
/// projection of the current immutable canvas snapshot into AppKit drawing.
extension LeatherCanvasView {
  func drawDimensionConstraints(in pageRect: CGRect) {
    guard !isOutputPreviewMode else {
      return
    }
    let dimensionConstraints = documentConstraints.filter(\.isDimensionConstraint)
    guard !dimensionConstraints.isEmpty else {
      return
    }

    for constraint in dimensionConstraints {
      guard let label = dimensionLabel(for: constraint),
        let resolved = canvasProjection.dimensionConstraints.first(where: {
          $0.id == constraint.id && $0.visible
        })
      else {
        continue
      }
      let annotation = dimensionConstraintDisplayAnnotation(for: constraint.id)
      guard annotation.visible else {
        continue
      }
      let highlighted =
        constraint.id == selectedConstraintID || constraint.id == hoveredConstraintID

      if constraint.rawKind == "segmentLength",
        let start = resolved.startMM,
        let end = resolved.endMM
      {
        drawDimensionLine(
          from: start,
          to: end,
          label: label,
          labelOffsetMM: annotation.labelOffsetMM,
          overallOffsetMM: annotation.overallOffsetMM,
          highlighted: highlighted,
          in: pageRect
        )
        continue
      }

      switch constraint.rawKind {
      case "angle":
        guard let overlay = angleConstraintOverlay(for: constraint) else {
          continue
        }
        drawAngleConstraintOverlay(
          overlay,
          labelOffsetMM: annotation.labelOffsetMM,
          overallOffsetMM: annotation.overallOffsetMM,
          highlighted: highlighted,
          in: pageRect
        )
      case "distance":
        guard let first = resolved.startMM, let second = resolved.endMM else {
          continue
        }
        drawDimensionLine(
          from: first,
          to: second,
          label: label,
          labelOffsetMM: annotation.labelOffsetMM,
          overallOffsetMM: annotation.overallOffsetMM,
          highlighted: highlighted,
          in: pageRect
        )
      case "horizontalDistance":
        guard let first = resolved.startMM, let second = resolved.endMM else {
          continue
        }
        drawAxisDistanceDimensionLine(
          from: first,
          to: second,
          axis: .horizontal,
          label: label,
          labelOffsetMM: annotation.labelOffsetMM,
          overallOffsetMM: annotation.overallOffsetMM,
          highlighted: highlighted,
          in: pageRect
        )
      case "verticalDistance":
        guard let first = resolved.startMM, let second = resolved.endMM else {
          continue
        }
        drawAxisDistanceDimensionLine(
          from: first,
          to: second,
          axis: .vertical,
          label: label,
          labelOffsetMM: annotation.labelOffsetMM,
          overallOffsetMM: annotation.overallOffsetMM,
          highlighted: highlighted,
          in: pageRect
        )
      case "pointLineDistance":
        guard let point = resolved.startMM, let projected = resolved.endMM else {
          continue
        }
        drawDimensionLine(
          from: point,
          to: projected,
          label: label,
          labelOffsetMM: annotation.labelOffsetMM,
          overallOffsetMM: annotation.overallOffsetMM,
          highlighted: highlighted,
          in: pageRect
        )
      case "lineLineDistance":
        guard let midpoint = resolved.startMM, let projected = resolved.endMM else {
          continue
        }
        drawDimensionLine(
          from: midpoint,
          to: projected,
          label: label,
          labelOffsetMM: annotation.labelOffsetMM,
          overallOffsetMM: annotation.overallOffsetMM,
          highlighted: highlighted,
          in: pageRect
        )
      case "diameter":
        guard let start = resolved.startMM, let end = resolved.endMM else {
          continue
        }
        drawDimensionLine(
          from: start,
          to: end,
          label: label,
          labelOffsetMM: annotation.labelOffsetMM,
          overallOffsetMM: annotation.overallOffsetMM,
          highlighted: highlighted,
          in: pageRect
        )
      case "radius":
        guard let center = resolved.centerMM, let start = resolved.startMM else {
          continue
        }
        drawDimensionLine(
          from: center,
          to: start,
          label: label,
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

  func drawDimensionLine(
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

    let color = dimensionConstraintColor(highlighted: highlighted)
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

  enum AxisDistanceDimensionAxis {
    case horizontal
    case vertical
  }

  func drawAxisDistanceDimensionLine(
    from first: ModelPoint,
    to second: ModelPoint,
    axis: AxisDistanceDimensionAxis,
    label: String,
    labelOffsetMM: ModelPoint,
    overallOffsetMM: ModelPoint,
    highlighted: Bool,
    in pageRect: CGRect
  ) {
    let scale = canvasScale(in: pageRect)
    let overallOffset = canvasOffset(for: overallOffsetMM, scale: scale)
    let labelOffset = canvasOffset(for: labelOffsetMM, scale: scale)
    let firstPoint = canvasPoint(for: first, in: pageRect)
    let secondPoint = canvasPoint(for: second, in: pageRect)
    let span: CGFloat
    let dimensionStart: CGPoint
    let dimensionEnd: CGPoint
    let firstExtensionEnd: CGPoint
    let secondExtensionEnd: CGPoint
    let labelPoint: CGPoint

    switch axis {
    case .horizontal:
      span = abs(secondPoint.x - firstPoint.x)
      guard span > 0.001 else {
        return
      }
      let dimensionY = min(firstPoint.y, secondPoint.y) - 16.0 + overallOffset.y
      dimensionStart = CGPoint(x: firstPoint.x, y: dimensionY)
      dimensionEnd = CGPoint(x: secondPoint.x, y: dimensionY)
      firstExtensionEnd = dimensionStart
      secondExtensionEnd = dimensionEnd
      labelPoint = CGPoint(
        x: (dimensionStart.x + dimensionEnd.x) / 2.0 + labelOffset.x,
        y: dimensionY - 14.0 + labelOffset.y
      )
    case .vertical:
      span = abs(secondPoint.y - firstPoint.y)
      guard span > 0.001 else {
        return
      }
      let dimensionX = max(firstPoint.x, secondPoint.x) + 16.0 + overallOffset.x
      dimensionStart = CGPoint(x: dimensionX, y: firstPoint.y)
      dimensionEnd = CGPoint(x: dimensionX, y: secondPoint.y)
      firstExtensionEnd = dimensionStart
      secondExtensionEnd = dimensionEnd
      labelPoint = CGPoint(
        x: dimensionX + 8.0 + labelOffset.x,
        y: (dimensionStart.y + dimensionEnd.y) / 2.0 + labelOffset.y
      )
    }

    let color = dimensionConstraintColor(highlighted: highlighted)
    color.setStroke()
    let path = NSBezierPath()
    path.move(to: dimensionStart)
    path.line(to: dimensionEnd)
    path.move(to: firstPoint)
    path.line(to: firstExtensionEnd)
    path.move(to: secondPoint)
    path.line(to: secondExtensionEnd)
    path.lineWidth = highlighted ? 1.5 : 1.0
    path.lineCapStyle = .round
    path.stroke()

    drawLinearDimensionArrowhead(
      at: dimensionStart, toward: dimensionEnd, color: color, highlighted: highlighted)
    drawLinearDimensionArrowhead(
      at: dimensionEnd, toward: dimensionStart, color: color, highlighted: highlighted)
    drawMeasurementLabel(
      label, in: measurementLabelRect(label: label, around: labelPoint), highlighted: highlighted)
  }

}
