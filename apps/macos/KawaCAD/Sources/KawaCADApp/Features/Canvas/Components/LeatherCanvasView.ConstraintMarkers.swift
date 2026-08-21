import AppKit
import KawaCADOutput
import SwiftUI

/// Draws constraint markers from an immutable canvas snapshot.
struct CanvasConstraintMarkerRenderer {
  struct Input {
    let constraints: [ProjectConstraint]
    let anchors: [ResolvedCanvasPoint]
    let coordinateSpace: CanvasCoordinateSpace
    let selectedConstraintID: String?
    let hoveredConstraintID: String?
  }

  let input: Input

  func draw(in pageRect: CGRect) {
    let markers = ConstraintMarkerLayout.markers(
      constraints: input.constraints,
      anchors: input.anchors
    )
    for marker in markers {
      let highlighted =
        marker.constraintID == input.selectedConstraintID
        || marker.constraintID == input.hoveredConstraintID
      drawConstraintMarker(marker, highlighted: highlighted, in: pageRect)
    }
  }

  func drawConstraintMarker(_ marker: ConstraintMarker, highlighted: Bool, in pageRect: CGRect) {
    let hitRect = CanvasLayout.constraintMarkerRect(
      position: marker.position,
      stackIndex: marker.stackIndex,
      in: input.coordinateSpace
    )
    let visualRect = hitRect.insetBy(
      dx: CanvasLayout.constraintMarkerInset, dy: CanvasLayout.constraintMarkerInset)

    if highlighted {
      NSColor(calibratedRed: 0.867, green: 0.337, blue: 0.082, alpha: 0.90).setFill()
      let path = NSBezierPath(roundedRect: visualRect, xRadius: 5, yRadius: 5)
      path.fill()
    }

    drawConstraintMarkerIcon(marker.tool.iconKind, in: visualRect, highlighted: highlighted)
    if highlighted {
      drawConstraintMarkerName(marker.displayName, beside: hitRect)
    }
  }

  func drawConstraintMarkerName(_ name: String, beside rect: CGRect) {
    let text = NSAttributedString(
      string: name,
      attributes: [
        .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 0.984, green: 0.961, blue: 0.894, alpha: 1.0),
      ]
    )
    let textSize = text.size()
    let labelRect = CGRect(
      x: rect.maxX + 5.0,
      y: rect.midY - 9.0,
      width: textSize.width + 12.0,
      height: 18.0
    )
    NSColor(calibratedRed: 0.867, green: 0.337, blue: 0.082, alpha: 0.88).setFill()
    let path = NSBezierPath(roundedRect: labelRect, xRadius: 6, yRadius: 6)
    path.fill()
    text.draw(
      at: CGPoint(
        x: labelRect.minX + 6.0,
        y: labelRect.midY - textSize.height / 2.0
      ))
  }

  func drawConstraintMarkerIcon(
    _ iconKind: CanvasToolIconKind,
    in rect: CGRect,
    highlighted: Bool
  ) {
    let iconRect = rect.insetBy(dx: 2.0, dy: 2.0)
    let color =
      highlighted
      ? NSColor(calibratedRed: 1.0, green: 0.976, blue: 0.902, alpha: 1.0)
      : NSColor(calibratedRed: 0.047, green: 0.376, blue: 0.345, alpha: 0.94)

    let lineWidth: CGFloat = 1.6
    let dashStyle = [CGFloat(2.5), CGFloat(2.0)]

    func withMarkerAppearance(_ draw: () -> Void) {
      NSGraphicsContext.saveGraphicsState()
      if !highlighted {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.white.withAlphaComponent(0.86)
        shadow.shadowBlurRadius = 2.0
        shadow.shadowOffset = .zero
        shadow.set()
      }
      color.setStroke()
      color.setFill()
      draw()
      NSGraphicsContext.restoreGraphicsState()
    }

    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: iconRect.minX + iconRect.width * x, y: iconRect.minY + iconRect.height * y)
    }

    func strokeLine(_ start: CGPoint, _ end: CGPoint, dashed: Bool = false) {
      let path = NSBezierPath()
      path.move(to: start)
      path.line(to: end)
      path.lineWidth = lineWidth
      path.lineCapStyle = .round
      if dashed {
        path.setLineDash(dashStyle, count: dashStyle.count, phase: 0)
      }
      path.stroke()
    }

    func strokeCircle(center: CGPoint, radius: CGFloat) {
      let circleRect = CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
      )
      let path = NSBezierPath(ovalIn: circleRect)
      path.lineWidth = lineWidth
      path.stroke()
    }

    func fillCircle(center: CGPoint, radius: CGFloat) {
      NSBezierPath(
        ovalIn: CGRect(
          x: center.x - radius,
          y: center.y - radius,
          width: radius * 2,
          height: radius * 2
        )
      ).fill()
    }

    func strokeChevron(at tip: CGPoint, backA: CGPoint, backB: CGPoint) {
      strokeLine(backA, tip)
      strokeLine(backB, tip)
    }

    func strokeTick(center: CGPoint, height: CGFloat) {
      strokeLine(
        CGPoint(x: center.x - height * 0.35, y: center.y + height / 2),
        CGPoint(x: center.x + height * 0.35, y: center.y - height / 2)
      )
    }

    func drawMarkerText(_ text: String, at location: CGPoint) {
      let attributed = NSAttributedString(
        string: text,
        attributes: [
          .font: NSFont.systemFont(ofSize: iconRect.width * 0.34, weight: .bold),
          .foregroundColor: color,
        ]
      )
      let textSize = attributed.size()
      attributed.draw(
        at: CGPoint(x: location.x - textSize.width / 2, y: location.y - textSize.height / 2))
    }

    func drawSystemIcon(_ symbolName: String) {
      guard let source = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
        drawMarkerText(iconKind.fallbackSymbolName.prefix(1).uppercased(), at: point(0.5, 0.5))
        return
      }
      let configuration = NSImage.SymbolConfiguration(
        pointSize: iconRect.height * 0.95, weight: .semibold)
      let configured = source.withSymbolConfiguration(configuration) ?? source
      guard let image = configured.copy() as? NSImage else {
        configured.draw(in: iconRect)
        return
      }
      image.lockFocus()
      color.set()
      NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
      image.unlockFocus()
      image.draw(in: iconRect)
    }

    withMarkerAppearance {
      switch iconKind {
      case .system(let symbolName):
        drawSystemIcon(symbolName)
      case .point:
        fillCircle(center: point(0.5, 0.5), radius: iconRect.width * 0.16)
        strokeCircle(center: point(0.5, 0.5), radius: iconRect.width * 0.34)
      case .line:
        strokeLine(point(0.18, 0.82), point(0.82, 0.18))
        fillCircle(center: point(0.18, 0.82), radius: iconRect.width * 0.08)
        fillCircle(center: point(0.82, 0.18), radius: iconRect.width * 0.08)
      case .arc:
        strokeCircle(center: point(0.5, 0.54), radius: iconRect.width * 0.34)
      case .centerLine(.diagonal):
        strokeLine(point(0.16, 0.84), point(0.84, 0.16), dashed: true)
        fillCircle(center: point(0.5, 0.5), radius: iconRect.width * 0.07)
      case .centerLine(.horizontal):
        strokeLine(point(0.12, 0.5), point(0.88, 0.5), dashed: true)
        strokeLine(point(0.5, 0.18), point(0.5, 0.82), dashed: true)
      case .centerLine(.vertical):
        strokeLine(point(0.5, 0.12), point(0.5, 0.88), dashed: true)
        strokeLine(point(0.18, 0.5), point(0.82, 0.5), dashed: true)
      case .fillet:
        strokeLine(point(0.18, 0.82), point(0.18, 0.42))
        strokeLine(point(0.58, 0.82), point(0.18, 0.82))
      case .coincident:
        strokeCircle(center: point(0.42, 0.5), radius: iconRect.width * 0.18)
        strokeCircle(center: point(0.58, 0.5), radius: iconRect.width * 0.18)
        fillCircle(center: point(0.5, 0.5), radius: iconRect.width * 0.06)
      case .horizontalConstraint:
        strokeLine(point(0.05, 0.42), point(0.95, 0.42))
        strokeLine(point(0.05, 0.58), point(0.95, 0.58))
      case .verticalConstraint:
        strokeLine(point(0.42, 0.05), point(0.42, 0.95))
        strokeLine(point(0.58, 0.05), point(0.58, 0.95))
      case .parallel:
        strokeLine(point(0.28, 0.95), point(0.48, 0.05))
        strokeLine(point(0.56, 0.95), point(0.76, 0.05))
      case .perpendicular:
        strokeLine(point(0.05, 0.84), point(0.90, 0.84))
        strokeLine(point(0.05, 0.84), point(0.05, 0.05))
        strokeLine(point(0.05, 0.52), point(0.34, 0.52))
        strokeLine(point(0.34, 0.52), point(0.34, 0.84))
      case .symmetric:
        strokeLine(point(0.5, 0.05), point(0.5, 0.95), dashed: true)
        strokeLine(point(0.10, 0.32), point(0.40, 0.50))
        strokeLine(point(0.10, 0.68), point(0.40, 0.50))
        strokeLine(point(0.90, 0.32), point(0.60, 0.50))
        strokeLine(point(0.90, 0.68), point(0.60, 0.50))
      case .distance:
        fillCircle(center: point(0.20, 0.74), radius: iconRect.width * 0.065)
        fillCircle(center: point(0.80, 0.26), radius: iconRect.width * 0.065)
        strokeLine(point(0.20, 0.62), point(0.20, 0.36), dashed: true)
        strokeLine(point(0.80, 0.38), point(0.80, 0.64), dashed: true)
        strokeLine(point(0.30, 0.50), point(0.70, 0.50))
        strokeChevron(at: point(0.30, 0.50), backA: point(0.41, 0.42), backB: point(0.41, 0.58))
        strokeChevron(at: point(0.70, 0.50), backA: point(0.59, 0.42), backB: point(0.59, 0.58))
      case .segmentLength:
        strokeLine(point(0.16, 0.34), point(0.84, 0.34))
        fillCircle(center: point(0.16, 0.34), radius: iconRect.width * 0.055)
        fillCircle(center: point(0.84, 0.34), radius: iconRect.width * 0.055)
        strokeLine(point(0.16, 0.50), point(0.16, 0.78))
        strokeLine(point(0.84, 0.50), point(0.84, 0.78))
        strokeLine(point(0.25, 0.66), point(0.75, 0.66))
        strokeChevron(at: point(0.25, 0.66), backA: point(0.36, 0.58), backB: point(0.36, 0.74))
        strokeChevron(at: point(0.75, 0.66), backA: point(0.64, 0.58), backB: point(0.64, 0.74))
      case .angle:
        strokeLine(point(0.10, 0.88), point(0.92, 0.88))
        strokeLine(point(0.10, 0.88), point(0.70, 0.20))
        let arc = NSBezierPath()
        arc.appendArc(
          withCenter: point(0.10, 0.88),
          radius: iconRect.width * 0.34,
          startAngle: 44,
          endAngle: 0,
          clockwise: true
        )
        arc.lineWidth = lineWidth
        arc.stroke()
      case .diameter:
        strokeCircle(center: point(0.42, 0.58), radius: iconRect.width * 0.30)
        strokeLine(point(0.17, 0.58), point(0.67, 0.58))
        strokeChevron(at: point(0.17, 0.58), backA: point(0.29, 0.50), backB: point(0.29, 0.66))
        strokeChevron(at: point(0.67, 0.58), backA: point(0.55, 0.50), backB: point(0.55, 0.66))
        drawMarkerText("D", at: point(0.80, 0.20))
      case .radius:
        strokeCircle(center: point(0.42, 0.58), radius: iconRect.width * 0.30)
        strokeLine(point(0.42, 0.58), point(0.70, 0.48))
        fillCircle(center: point(0.42, 0.58), radius: iconRect.width * 0.045)
        drawMarkerText("r", at: point(0.80, 0.20))
      case .equalLength:
        strokeLine(point(0.16, 0.34), point(0.84, 0.34))
        strokeLine(point(0.16, 0.68), point(0.84, 0.68))
        strokeTick(center: point(0.42, 0.34), height: iconRect.width * 0.30)
        strokeTick(center: point(0.58, 0.68), height: iconRect.width * 0.30)
        fillCircle(center: point(0.16, 0.34), radius: iconRect.width * 0.045)
        fillCircle(center: point(0.84, 0.34), radius: iconRect.width * 0.045)
        fillCircle(center: point(0.16, 0.68), radius: iconRect.width * 0.045)
        fillCircle(center: point(0.84, 0.68), radius: iconRect.width * 0.045)
      }
    }
  }

}

extension LeatherCanvasView {
  func drawConstraintMarkers(in pageRect: CGRect) {
    guard !isOutputPreviewMode else {
      return
    }
    CanvasConstraintMarkerRenderer(
      input: CanvasConstraintMarkerRenderer.Input(
        constraints: documentConstraints,
        anchors: canvasProjection.constraintMarkers,
        coordinateSpace: coordinateSpace(in: pageRect),
        selectedConstraintID: selectedConstraintID,
        hoveredConstraintID: hoveredConstraintID
      )
    ).draw(in: pageRect)
  }

  func dimensionLabel(for constraint: ProjectConstraint) -> String? {
    func axisLabel(_ base: String) -> String {
      switch constraint.rawKind {
      case "horizontalDistance":
        return "\(AppStrings.tr("tool.horizontal_distance")) \(base)"
      case "verticalDistance":
        return "\(AppStrings.tr("tool.vertical_distance")) \(base)"
      default:
        return base
      }
    }

    if let valueMM = constraint.valueMM {
      return axisLabel(String(format: "%.2f mm", valueMM))
    }
    if let valueDegrees = constraint.valueDegrees {
      return formatAngleDegrees(valueDegrees)
    }
    if let parameterID = constraint.valueParameterID,
      let parameter = parameters.first(where: { $0.id == parameterID })
    {
      return axisLabel("\(parameter.name) \(String(format: "%.2f", parameter.valueMM)) mm")
    }
    return nil
  }
}
