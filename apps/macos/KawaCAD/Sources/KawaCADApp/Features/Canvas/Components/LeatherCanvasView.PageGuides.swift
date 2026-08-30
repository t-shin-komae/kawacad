import AppKit
import KawaCADOutput
import SwiftUI

/// Shared visual priority for canvas aids. Primary geometry keeps its layer/style color.
enum CanvasVisualHierarchy {
  static let gridStroke = NSColor(calibratedRed: 0.372, green: 0.423, blue: 0.466, alpha: 0.13)
  static let gridLineWidth: CGFloat = 0.5
  static let a4SecondaryStroke = NSColor(
    calibratedRed: 0.372, green: 0.423, blue: 0.466, alpha: 0.35)
  static let a4PrimaryStroke = NSColor(
    calibratedRed: 0.372, green: 0.423, blue: 0.466, alpha: 0.68)
  static let a4SecondaryLineWidth: CGFloat = 0.8
  static let a4PrimaryLineWidth: CGFloat = 1.2
  static let a4ReferenceStroke = NSColor(
    calibratedRed: 0.039, green: 0.518, blue: 1.0, alpha: 0.35)
  static let a4ReferenceLineWidth: CGFloat = 0.8
  static let coordinateStroke = NSColor(
    calibratedRed: 0.039, green: 0.518, blue: 1.0, alpha: 0.72)
  static let coordinateLineWidth: CGFloat = 1.4
  static let originStroke = NSColor(
    calibratedRed: 1.0, green: 0.624, blue: 0.039, alpha: 0.92)
  static let originFill = NSColor(
    calibratedRed: 1.0, green: 0.624, blue: 0.039, alpha: 0.16)
  static let originLineWidth: CGFloat = 1.5
  static let originRadius: CGFloat = 8
  static let originCrossSize: CGFloat = 12
  static let selectionStroke = NSColor(
    calibratedRed: 0.231, green: 0.510, blue: 0.964, alpha: 0.28)
  static let selectionLineWidth: CGFloat = 3.0
  static let selectionDash: [CGFloat] = [5, 3]
  static let targetPendingStroke = NSColor(
    calibratedRed: 0.125, green: 0.290, blue: 0.675, alpha: 0.95)
  static let targetPendingFill = NSColor(
    calibratedRed: 0.231, green: 0.510, blue: 0.964, alpha: 0.14)
  static let targetPendingLineWidth: CGFloat = 3.0
  static let targetPendingDash: [CGFloat] = [7, 4]
  static let targetHoveredStroke = NSColor(
    calibratedRed: 0.016, green: 0.506, blue: 0.455, alpha: 0.92)
  static let targetHoveredFill = NSColor(
    calibratedRed: 0.016, green: 0.506, blue: 0.455, alpha: 0.10)
  static let targetHoveredLineWidth: CGFloat = 2.0
  static let targetHoveredDash: [CGFloat] = [2, 3]
  static let targetFeedbackRadius: CGFloat = 8
  static let snapStroke = targetHoveredStroke
  static let snapLineWidth: CGFloat = 1.5
  static let snapCrossSize: CGFloat = 8
  static let snapRingRadius: CGFloat = 4
  static let marqueeContainedStroke = NSColor(calibratedRed: 0.039, green: 0.518, blue: 1, alpha: 1)
  static let marqueeContainedFill = marqueeContainedStroke.withAlphaComponent(0.12)
  static let marqueeCrossingStroke = NSColor(
    calibratedRed: 0.204, green: 0.780, blue: 0.349, alpha: 1)
  static let marqueeCrossingFill = marqueeCrossingStroke.withAlphaComponent(0.12)
  static let marqueeLineWidth: CGFloat = 1.5
  static let marqueeCrossingDash: [CGFloat] = [6, 4]
  static let marqueeCandidateDash: [CGFloat] = [4, 3]
  static let marqueeCandidateLineWidth: CGFloat = 2
}

/// Rendering responsibilities extracted from the input-oriented canvas view.
/// The view still owns lifecycle and callbacks; this extension owns the
/// projection of the current immutable canvas snapshot into AppKit drawing.
extension LeatherCanvasView {
  func drawGrid(in rect: NSRect, pageRect: CGRect) {
    guard let context = NSGraphicsContext.current?.cgContext else {
      return
    }

    context.saveGState()
    context.setStrokeColor(CanvasVisualHierarchy.gridStroke.cgColor)
    context.setLineWidth(CanvasVisualHierarchy.gridLineWidth)

    let coordinateSpace = coordinateSpace(in: pageRect)
    let canvasBounds = coordinateSpace.canvasBoundsRect
    let minorSpacing = CGFloat(5.0) * coordinateSpace.scale
    guard minorSpacing > 2 else {
      context.restoreGState()
      return
    }

    var x = coordinateSpace.originCanvasPoint.x
    while x >= canvasBounds.minX {
      context.move(to: CGPoint(x: x, y: canvasBounds.minY))
      context.addLine(to: CGPoint(x: x, y: canvasBounds.maxY))
      x -= minorSpacing
    }

    x = coordinateSpace.originCanvasPoint.x + minorSpacing
    while x <= canvasBounds.maxX {
      context.move(to: CGPoint(x: x, y: canvasBounds.minY))
      context.addLine(to: CGPoint(x: x, y: canvasBounds.maxY))
      x += minorSpacing
    }

    var y = coordinateSpace.originCanvasPoint.y
    while y >= canvasBounds.minY {
      context.move(to: CGPoint(x: canvasBounds.minX, y: y))
      context.addLine(to: CGPoint(x: canvasBounds.maxX, y: y))
      y -= minorSpacing
    }

    y = coordinateSpace.originCanvasPoint.y + minorSpacing
    while y <= canvasBounds.maxY {
      context.move(to: CGPoint(x: canvasBounds.minX, y: y))
      context.addLine(to: CGPoint(x: canvasBounds.maxX, y: y))
      y += minorSpacing
    }

    context.strokePath()
    context.restoreGState()
  }

  @discardableResult
  func drawA4Page(in rect: NSRect) -> CGRect {
    let pageRect = pageRect(in: rect)

    guard a4ReferenceVisible && !isOutputPreviewMode else {
      return pageRect
    }

    let coordinateSpace = coordinateSpace(in: pageRect)
    let canvasBounds = coordinateSpace.canvasBoundsRect

    LeatherColors.canvasBackground.setFill()
    NSBezierPath(rect: canvasBounds).fill()

    let pageOffset = CanvasCoordinateSpace.a4GridPageLimit / 2
    for row in 0..<CanvasCoordinateSpace.a4GridPageLimit {
      for column in 0..<CanvasCoordinateSpace.a4GridPageLimit {
        let pageCenterX = Double(column - pageOffset) * coordinateSpace.pageWidthMM
        let pageCenterY = Double(pageOffset - row) * coordinateSpace.pageHeightMM
        let topLeft = coordinateSpace.canvasPoint(
          for: ModelPoint(
            xMM: pageCenterX - coordinateSpace.pageWidthMM / 2.0,
            yMM: pageCenterY + coordinateSpace.pageHeightMM / 2.0
          ))
        let tileRect = CGRect(
          x: topLeft.x,
          y: topLeft.y,
          width: coordinateSpace.pageWidthMM * coordinateSpace.scale,
          height: coordinateSpace.pageHeightMM * coordinateSpace.scale
        )
        let border = NSBezierPath(rect: tileRect)
        border.lineWidth =
          row == pageOffset && column == pageOffset
          ? CanvasVisualHierarchy.a4PrimaryLineWidth
          : CanvasVisualHierarchy.a4SecondaryLineWidth
        (row == pageOffset && column == pageOffset
          ? CanvasVisualHierarchy.a4PrimaryStroke
          : CanvasVisualHierarchy.a4SecondaryStroke).setStroke()
        border.stroke()
      }
    }

    CanvasVisualHierarchy.a4ReferenceStroke.setStroke()
    let referencePath = NSBezierPath(rect: pageRect)
    referencePath.lineWidth = CanvasVisualHierarchy.a4ReferenceLineWidth
    referencePath.setLineDash([5, 4], count: 2, phase: 0)
    referencePath.stroke()

    let labelAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
      .foregroundColor: NSColor.secondaryLabelColor,
    ]
    NSAttributedString(string: "DrawingSnapshot / A4 5x5 / 100%", attributes: labelAttributes)
      .draw(at: CGPoint(x: pageRect.minX + 14, y: pageRect.minY + 12))

    drawScaleGuide(at: CGPoint(x: pageRect.minX + 20, y: pageRect.maxY - 34))
    return pageRect
  }

  func drawCoordinateReference(in pageRect: CGRect) {
    guard let context = NSGraphicsContext.current?.cgContext else {
      return
    }
    let coordinateSpace = coordinateSpace(in: pageRect)
    let origin = coordinateSpace.originCanvasPoint
    let axisColor = CanvasVisualHierarchy.coordinateStroke

    context.saveGState()
    context.setStrokeColor(axisColor.cgColor)
    context.setLineWidth(CanvasVisualHierarchy.coordinateLineWidth)

    context.move(to: origin)
    context.addLine(to: CGPoint(x: min(origin.x + 70, pageRect.maxX), y: origin.y))
    context.move(to: origin)
    context.addLine(to: CGPoint(x: origin.x, y: max(origin.y - 70, pageRect.minY)))
    context.strokePath()

    context.setFillColor(axisColor.cgColor)
    context.move(to: CGPoint(x: min(origin.x + 70, pageRect.maxX), y: origin.y))
    context.addLine(to: CGPoint(x: min(origin.x + 62, pageRect.maxX), y: origin.y - 4))
    context.addLine(to: CGPoint(x: min(origin.x + 62, pageRect.maxX), y: origin.y + 4))
    context.closePath()
    context.fillPath()

    context.move(to: CGPoint(x: origin.x, y: max(origin.y - 70, pageRect.minY)))
    context.addLine(to: CGPoint(x: origin.x - 4, y: max(origin.y - 62, pageRect.minY)))
    context.addLine(to: CGPoint(x: origin.x + 4, y: max(origin.y - 62, pageRect.minY)))
    context.closePath()
    context.fillPath()

    let markerRect = CGRect(x: origin.x - 4, y: origin.y - 4, width: 8, height: 8)
    context.setFillColor(NSColor.white.withAlphaComponent(0.95).cgColor)
    context.fillEllipse(in: markerRect)
    context.setStrokeColor(axisColor.cgColor)
    context.strokeEllipse(in: markerRect)
    context.restoreGState()

    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 10, weight: .bold),
      .foregroundColor: axisColor,
      .backgroundColor: NSColor.textBackgroundColor.withAlphaComponent(0.72),
    ]
    NSAttributedString(string: AppStrings.tr("canvas.origin_label"), attributes: attributes)
      .draw(at: CGPoint(x: origin.x + 7, y: max(pageRect.minY + 4, origin.y - 18)))
    NSAttributedString(string: "X", attributes: attributes)
      .draw(at: CGPoint(x: min(origin.x + 76, pageRect.maxX - 10), y: origin.y - 7))
    NSAttributedString(string: "Y", attributes: attributes)
      .draw(at: CGPoint(x: origin.x - 14, y: max(origin.y - 86, pageRect.minY)))
  }

  func drawScaleGuide(at point: CGPoint) {
    guard let context = NSGraphicsContext.current?.cgContext else {
      return
    }
    context.saveGState()
    context.setStrokeColor(
      NSColor(calibratedRed: 0.090, green: 0.125, blue: 0.165, alpha: 0.72).cgColor)
    context.setLineWidth(3)
    context.move(to: point)
    context.addLine(to: CGPoint(x: point.x + 112, y: point.y))
    context.strokePath()
    context.restoreGState()

    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
      .foregroundColor: NSColor(calibratedRed: 0.090, green: 0.125, blue: 0.165, alpha: 1.0),
    ]
    NSAttributedString(string: AppStrings.tr("canvas.scale_guide_label"), attributes: attributes)
      .draw(at: CGPoint(x: point.x, y: point.y + 8))
  }
}
