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

    var items: [CanvasAnnotationRenderer.Item] = []
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
        items.append(
          CanvasAnnotationRenderer.Item(
            kind: .dimension,
            label: label,
            geometry: .line(start: start, end: end),
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            highlighted: highlighted
          )
        )
        continue
      }

      switch constraint.rawKind {
      case "angle":
        guard let overlay = angleConstraintOverlay(for: constraint) else {
          continue
        }
        items.append(
          CanvasAnnotationRenderer.Item(
            kind: .dimension,
            label: overlay.label,
            geometry: .angle(overlay),
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            highlighted: highlighted
          )
        )
      case "distance":
        guard let first = resolved.startMM, let second = resolved.endMM else {
          continue
        }
        items.append(
          CanvasAnnotationRenderer.Item(
            kind: .dimension,
            label: label,
            geometry: .line(start: first, end: second),
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            highlighted: highlighted
          )
        )
      case "horizontalDistance":
        guard let first = resolved.startMM, let second = resolved.endMM else {
          continue
        }
        items.append(
          CanvasAnnotationRenderer.Item(
            kind: .dimension,
            label: label,
            geometry: .axis(start: first, end: second, axis: .horizontal),
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            highlighted: highlighted
          )
        )
      case "verticalDistance":
        guard let first = resolved.startMM, let second = resolved.endMM else {
          continue
        }
        items.append(
          CanvasAnnotationRenderer.Item(
            kind: .dimension,
            label: label,
            geometry: .axis(start: first, end: second, axis: .vertical),
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            highlighted: highlighted
          )
        )
      case "pointLineDistance":
        guard let point = resolved.startMM, let projected = resolved.endMM else {
          continue
        }
        items.append(
          CanvasAnnotationRenderer.Item(
            kind: .dimension,
            label: label,
            geometry: .line(start: point, end: projected),
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            highlighted: highlighted
          )
        )
      case "lineLineDistance":
        guard let midpoint = resolved.startMM, let projected = resolved.endMM else {
          continue
        }
        items.append(
          CanvasAnnotationRenderer.Item(
            kind: .dimension,
            label: label,
            geometry: .line(start: midpoint, end: projected),
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            highlighted: highlighted
          )
        )
      case "diameter":
        guard let start = resolved.startMM, let end = resolved.endMM else {
          continue
        }
        items.append(
          CanvasAnnotationRenderer.Item(
            kind: .dimension,
            label: label,
            geometry: .line(start: start, end: end),
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            highlighted: highlighted
          )
        )
      case "radius":
        guard let center = resolved.centerMM, let start = resolved.startMM else {
          continue
        }
        items.append(
          CanvasAnnotationRenderer.Item(
            kind: .dimension,
            label: label,
            geometry: .line(start: center, end: start),
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

  enum AxisDistanceDimensionAxis {
    case horizontal
    case vertical
  }

}
