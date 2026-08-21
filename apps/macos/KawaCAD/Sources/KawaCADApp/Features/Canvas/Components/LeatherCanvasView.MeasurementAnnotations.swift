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
    var items: [CanvasAnnotationRenderer.Item] = []
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
        items.append(
          CanvasAnnotationRenderer.Item(
            kind: .measurement,
            label: label,
            geometry: .line(start: first, end: second),
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            highlighted: highlighted
          )
        )
      case "segmentLength":
        guard let start = resolved.startMM, let end = resolved.endMM else { continue }
        items.append(
          CanvasAnnotationRenderer.Item(
            kind: .measurement,
            label: label,
            geometry: .line(start: start, end: end),
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            highlighted: highlighted
          )
        )
      case "diameter":
        guard let start = resolved.startMM, let end = resolved.endMM else { continue }
        items.append(
          CanvasAnnotationRenderer.Item(
            kind: .measurement,
            label: label,
            geometry: .line(start: start, end: end),
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            highlighted: highlighted
          )
        )
      case "radius":
        guard let center = resolved.centerMM, let start = resolved.startMM else { continue }
        items.append(
          CanvasAnnotationRenderer.Item(
            kind: .measurement,
            label: label,
            geometry: .line(start: center, end: start),
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            highlighted: highlighted
          )
        )
      case "angle", "arcSweepAngle":
        guard let overlay = measurementAngleOverlay(for: annotation) else {
          continue
        }
        items.append(
          CanvasAnnotationRenderer.Item(
            kind: .measurement,
            label: overlay.label,
            geometry: .angle(overlay),
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            highlighted: highlighted
          )
        )
      default:
        continue
      }
    }
    CanvasAnnotationRenderer(
      input: CanvasAnnotationRenderer.Input(
        items: items,
        orientation: a4ReferenceOrientation
      )
    ).draw(in: pageRect)
  }

  typealias MeasurementLineLayout = CanvasAnnotationLayout.Line

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
    guard let drag = interactionSnapshot().dimensionConstraintDragState,
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
    CanvasAnnotationLayout.line(
      start: start,
      end: end,
      label: label,
      labelOffsetMM: labelOffsetMM,
      overallOffsetMM: overallOffsetMM,
      in: pageRect,
      orientation: a4ReferenceOrientation
    )
  }

  func measurementLabelRect(label: String, around point: CGPoint) -> CGRect {
    CanvasLayout.measurementLabelRect(label: label, around: point)
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

}
