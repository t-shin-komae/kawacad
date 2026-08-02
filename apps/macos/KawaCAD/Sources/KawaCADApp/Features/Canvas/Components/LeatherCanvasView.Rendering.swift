import AppKit
import KawaCADOutput
import SwiftUI

/// Rendering responsibilities extracted from the input-oriented canvas view.
/// The view still owns lifecycle and callbacks; this extension owns the
/// projection of the current immutable canvas snapshot into AppKit drawing.
extension LeatherCanvasView {
  func drawDraftPreview(in pageRect: CGRect) {
    guard let draftStartPoint else {
      return
    }
    let start = canvasPoint(for: draftStartPoint, in: pageRect)
    let markerRect = CGRect(x: start.x - 5, y: start.y - 5, width: 10, height: 10)
    NSColor(calibratedRed: 0.231, green: 0.510, blue: 0.964, alpha: 0.85).setStroke()
    let marker = NSBezierPath(ovalIn: markerRect)
    marker.lineWidth = 2
    marker.stroke()

    guard let draftCurrentPoint, draftCurrentPoint != draftStartPoint else {
      return
    }

    let end = canvasPoint(for: draftCurrentPoint, in: pageRect)
    NSColor(calibratedRed: 0.231, green: 0.510, blue: 0.964, alpha: 0.60).setStroke()
    switch selectedTool {
    case .line, .centerLine, .horizontalCenterLine, .verticalCenterLine:
      let previewEnd: CGPoint
      switch selectedTool {
      case .horizontalCenterLine:
        previewEnd = CGPoint(x: end.x, y: start.y)
      case .verticalCenterLine:
        previewEnd = CGPoint(x: start.x, y: end.y)
      default:
        previewEnd = end
      }
      let path = NSBezierPath()
      path.move(to: start)
      path.line(to: previewEnd)
      path.lineWidth = 2
      path.setLineDash([6, 4], count: 2, phase: 0)
      path.stroke()
    case .circle:
      let radius = hypot(
        draftCurrentPoint.xMM - draftStartPoint.xMM,
        draftCurrentPoint.yMM - draftStartPoint.yMM
      )
      let path = NSBezierPath(
        ovalIn: rect(forCircleAt: draftStartPoint, radiusMM: radius, in: pageRect))
      path.lineWidth = 2
      path.setLineDash([6, 4], count: 2, phase: 0)
      path.stroke()
    case .arc:
      if let arcStartPoint = draftArcStartPoint {
        let startPoint = canvasPoint(for: arcStartPoint, in: pageRect)
        let startMarkerRect = CGRect(x: startPoint.x - 4, y: startPoint.y - 4, width: 8, height: 8)
        let startMarker = NSBezierPath(ovalIn: startMarkerRect)
        startMarker.lineWidth = 2
        startMarker.stroke()

        guard
          let preview = draftArcPreview(
            center: draftStartPoint,
            start: arcStartPoint,
            end: draftCurrentPoint,
            sweepAngleRad: draftArcSweepAngleRad,
            in: pageRect
          )
        else {
          return
        }
        let path = NSBezierPath()
        path.appendArc(
          withCenter: start,
          radius: preview.radius,
          startAngle: preview.startAngleDeg,
          endAngle: preview.endAngleDeg,
          clockwise: preview.clockwise
        )
        path.lineWidth = 2
        path.setLineDash([6, 4], count: 2, phase: 0)
        path.stroke()
        drawArcDraftAngleLabel(preview.angleLabel, at: preview.labelPoint)
      } else {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = 2
        path.setLineDash([6, 4], count: 2, phase: 0)
        path.stroke()

        let markerRect = CGRect(x: end.x - 5, y: end.y - 5, width: 10, height: 10)
        let marker = NSBezierPath(ovalIn: markerRect)
        marker.lineWidth = 2
        marker.stroke()
      }
    case .select, .point, .roundHole, .stitchStartPoint, .freeText, .offset, .fillet, .coincident,
      .horizontal, .vertical, .parallel, .perpendicular, .tangent,
      .symmetric, .pointOnLine, .equalLength, .angle, .distance, .horizontalDistance,
      .verticalDistance, .lineLineDistance, .segmentLength, .diameter, .radius, .fixed,
      .measureDistance, .measureSegmentLength, .measureAngle, .measureRadius, .measureDiameter,
      .measureArcSweepAngle:
      break
    }
  }

  func draftArcPreview(
    center: ModelPoint,
    start: ModelPoint,
    end: ModelPoint?,
    sweepAngleRad: Double?,
    in pageRect: CGRect
  ) -> (
    radius: CGFloat, startAngleDeg: Double, endAngleDeg: Double, clockwise: Bool,
    labelPoint: CGPoint, angleLabel: String
  )? {
    guard let end else {
      return nil
    }
    let radiusMM = hypot(start.xMM - center.xMM, start.yMM - center.yMM)
    let radius = CGFloat(radiusMM * canvasScale(in: pageRect))
    guard radius > 0.0001 else {
      return nil
    }
    let startAngle = angleRadians(from: center, to: start)
    let sweepAngle =
      sweepAngleRad
      ?? normalizedSignedSweepAngle(
        startAngleRad: startAngle,
        endAngleRad: angleRadians(from: center, to: end)
      )
    guard abs(sweepAngle) > 0.0001 else {
      return nil
    }

    let labelAngle = startAngle + sweepAngle / 2.0
    let labelRadiusMM = radiusMM + 8.0
    let labelPoint = canvasPoint(
      for: ModelPoint(
        xMM: center.xMM + labelRadiusMM * cos(labelAngle),
        yMM: center.yMM + labelRadiusMM * sin(labelAngle)
      ),
      in: pageRect
    )
    let angleLabel = String(format: "%.0f°", abs(radiansToDegrees(sweepAngle)))
    let pathParameters = canvasArcPathParameters(
      startAngleRad: startAngle, sweepAngleRad: sweepAngle)
    return (
      radius: radius,
      startAngleDeg: pathParameters.startAngleDeg,
      endAngleDeg: pathParameters.endAngleDeg,
      clockwise: pathParameters.clockwise,
      labelPoint: labelPoint,
      angleLabel: angleLabel
    )
  }

  func drawArcDraftAngleLabel(_ text: String, at point: CGPoint) {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
      .foregroundColor: NSColor(calibratedRed: 0.090, green: 0.125, blue: 0.165, alpha: 1.0),
      .backgroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.9),
    ]
    NSAttributedString(string: text, attributes: attributes)
      .draw(at: CGPoint(x: point.x + 6, y: point.y - 6))
  }

  func drawSelectionMarquee() {
    guard case .marquee(let startPoint, let currentPoint, _) = dragState else {
      return
    }
    let rect = CanvasInteractionState.normalizedRect(from: startPoint, to: currentPoint)
    guard rect.width > 3 || rect.height > 3 else {
      return
    }

    let mode = CanvasMarqueeSelectionMode(startPoint: startPoint, currentPoint: currentPoint)
    let color: NSColor =
      mode == .contained
      ? NSColor(calibratedRed: 0.231, green: 0.510, blue: 0.964, alpha: 1)
      : NSColor(calibratedRed: 0.18, green: 0.62, blue: 0.37, alpha: 1)
    color.withAlphaComponent(0.12).setFill()
    color.withAlphaComponent(0.85).setStroke()
    let path = NSBezierPath(rect: rect)
    path.lineWidth = 1
    if mode == .crossing {
      path.setLineDash([5, 3], count: 2, phase: 0)
    }
    path.fill()
    path.stroke()

    let candidateIDs = marqueeCandidateIDs(startPoint: startPoint, currentPoint: currentPoint)
    let currentPageRect = pageRect(in: bounds)
    for entity in visibleEntities where candidateIDs.contains(entity.id) {
      let entityRect = hitRect(for: entity, in: currentPageRect)
      drawMarqueeCandidateHighlight(around: entityRect, color: color)
    }
    let text =
      mode == .contained
      ? AppStrings.tr("canvas.marquee.contained", candidateIDs.count)
      : AppStrings.tr("canvas.marquee.crossing", candidateIDs.count)
    drawMarqueeBadge(text, near: rect, color: color)
  }

  func drawMarqueeCandidateHighlight(around rect: CGRect, color: NSColor) {
    color.withAlphaComponent(0.58).setStroke()
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: -3, dy: -3), xRadius: 6, yRadius: 6)
    path.lineWidth = 2
    path.setLineDash([3, 2], count: 2, phase: 0)
    path.stroke()
  }

  func drawMarqueeBadge(_ text: String, near rect: CGRect, color: NSColor) {
    let attributedText = NSAttributedString(
      string: text,
      attributes: [
        .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
        .foregroundColor: NSColor.white,
      ]
    )
    let size = attributedText.size()
    let badgeRect = CGRect(
      x: rect.minX + 4,
      y: max(0, rect.minY - size.height - 10),
      width: size.width + 12,
      height: size.height + 6
    )
    color.withAlphaComponent(0.94).setFill()
    NSBezierPath(roundedRect: badgeRect, xRadius: 4, yRadius: 4).fill()
    attributedText.draw(at: CGPoint(x: badgeRect.minX + 6, y: badgeRect.minY + 3))
  }

  func drawDragFeedback() {
    guard case .entities(let entityIDs, _, _, let currentPoint, let duplicating) = dragState else {
      return
    }
    let label =
      entityIDs.count == 1
      ? (duplicating ? AppStrings.tr("canvas.drag.copy") : AppStrings.tr("canvas.drag.move"))
      : AppStrings.tr(
        duplicating ? "canvas.drag.copy_count" : "canvas.drag.move_count",
        entityIDs.count
      )
    drawDragBadge(label, near: currentPoint, duplicating: duplicating)
  }

  func drawDragBadge(_ label: String, near modelPoint: ModelPoint, duplicating: Bool) {
    let pageRect = pageRect(in: bounds)
    let point = canvasPoint(for: modelPoint, in: pageRect)
    let text = NSAttributedString(
      string: label,
      attributes: [
        .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
        .foregroundColor: NSColor.white,
      ]
    )
    let size = text.size()
    let rect = CGRect(
      x: point.x + 12,
      y: point.y - 28,
      width: size.width + 18,
      height: size.height + 8
    )
    let fill =
      duplicating
      ? NSColor(calibratedRed: 0.016, green: 0.506, blue: 0.455, alpha: 0.92)
      : NSColor(calibratedRed: 0.125, green: 0.290, blue: 0.675, alpha: 0.90)
    fill.setFill()
    NSColor.white.withAlphaComponent(0.84).setStroke()
    let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
    path.lineWidth = 1
    path.fill()
    path.stroke()
    text.draw(at: CGPoint(x: rect.minX + 9, y: rect.minY + 4))
  }

  func drawEntities(in pageRect: CGRect) {
    if entities.isEmpty {
      drawEmptyState(in: pageRect)
      return
    }

    for entity in visibleEntities {
      drawEntity(entity, in: pageRect)
    }
  }

  func drawFreeTexts(in pageRect: CGRect) {
    guard !isOutputPreviewMode else {
      return
    }
    for freeText in freeTexts {
      if freeText.id == inlineFreeTextEditor.editingID {
        continue
      }
      let displayFreeText = displayFreeText(freeText)
      drawText(
        displayFreeText.content,
        at: displayFreeText.positionMM,
        fontSizeMM: displayFreeText.fontSizeMM,
        color: LeatherColors.ink,
        highlighted: displayFreeText.id == selectedFreeTextID
          || highlightedPartFreeTextIDs.contains(displayFreeText.id),
        in: pageRect
      )
    }
  }

  func drawStitchStartPoints(in pageRect: CGRect) {
    for stitchStartPoint in stitchStartPoints {
      guard let position = stitchStartPointPosition(stitchStartPoint) else {
        continue
      }
      let canvasPoint = canvasPoint(for: position, in: pageRect)
      let selected =
        stitchStartPoint.id == selectedStitchStartPointID
        || highlightedPartStitchStartPointIDs.contains(stitchStartPoint.id)
      let size: CGFloat = selected ? 13 : 10
      let rect = CGRect(
        x: canvasPoint.x - size / 2,
        y: canvasPoint.y - size / 2,
        width: size,
        height: size
      )
      NSColor(calibratedRed: 0.090, green: 0.125, blue: 0.165, alpha: 0.96).setFill()
      NSBezierPath(ovalIn: rect).fill()
      NSColor.white.setStroke()
      let path = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
      path.lineWidth = selected ? 2 : 1.4
      path.stroke()
    }
  }

  func stitchStartPointPosition(_ stitchStartPoint: ProjectStitchStartPoint) -> ModelPoint? {
    canvasProjection.stitchStartPoints.first {
      $0.id == stitchStartPoint.id && $0.visible
    }?.positionMM
  }

  func stitchStartPoint(at point: CGPoint, in pageRect: CGRect) -> ProjectStitchStartPoint? {
    stitchStartPoints.reversed().first { stitchStartPoint in
      guard let position = stitchStartPointPosition(stitchStartPoint) else {
        return false
      }
      let canvasPoint = canvasPoint(for: position, in: pageRect)
      return CGRect(x: canvasPoint.x - 8, y: canvasPoint.y - 8, width: 16, height: 16).contains(
        point)
    }
  }

  func drawOutputPreviewTexts(in pageRect: CGRect) {
    guard isOutputPreviewMode,
      let outputPreviewModel
    else {
      return
    }
    for page in outputPreviewModel.pages {
      let pageCenter = ModelPoint(
        xMM: Double(page.gridColumn) * page.widthMm,
        yMM: Double(page.gridRow) * page.heightMm
      )
      for text in page.texts {
        let modelPoint = ModelPoint(
          xMM: pageCenter.xMM + text.positionMm.xMm,
          yMM: pageCenter.yMM + text.positionMm.yMm
        )
        drawText(
          text.content,
          at: modelPoint,
          fontSizeMM: text.fontSizeMm,
          color: text.kind == .freeText ? LeatherColors.ink : LeatherColors.secondaryInk,
          highlighted: false,
          in: pageRect
        )
      }
    }
  }

  func drawText(
    _ content: String,
    at positionMM: ModelPoint,
    fontSizeMM: Double,
    color: Color,
    highlighted: Bool,
    in pageRect: CGRect
  ) {
    let coordinateSpace = coordinateSpace(in: pageRect)
    let point = coordinateSpace.canvasPoint(for: positionMM)
    let fontSize = max(9.0, fontSizeMM * coordinateSpace.scale)
    let attributed = NSAttributedString(
      string: content,
      attributes: [
        .font: NSFont.systemFont(ofSize: fontSize),
        .foregroundColor: NSColor(color),
      ]
    )
    let size = attributed.size()
    if highlighted {
      let rect = CGRect(
        x: point.x - 4,
        y: point.y - 3,
        width: size.width + 8,
        height: size.height + 6
      )
      NSColor.systemBlue.withAlphaComponent(0.12).setFill()
      NSColor.systemBlue.withAlphaComponent(0.75).setStroke()
      let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
      path.lineWidth = 1
      path.fill()
      path.stroke()
    }
    attributed.draw(at: point)
  }

  func drawOutputPreviewPages() {
    guard isOutputPreviewMode,
      let outputPreviewModel,
      !outputPreviewModel.pages.isEmpty
    else {
      return
    }

    let pageRects = outputPreviewPageRects(in: bounds)
    let borderColor = NSColor.systemBlue.withAlphaComponent(0.78)
    let fillColor = NSColor.systemBlue.withAlphaComponent(0.045)
    let labelAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
      .foregroundColor: NSColor.white,
    ]

    for (index, rect) in pageRects.enumerated() {
      fillColor.setFill()
      NSBezierPath(rect: rect).fill()

      borderColor.setStroke()
      let border = NSBezierPath(rect: rect)
      border.lineWidth = 1.4
      border.setLineDash([7, 4], count: 2, phase: 0)
      border.stroke()

      let label = "\(index + 1)"
      let attributedLabel = NSAttributedString(string: label, attributes: labelAttributes)
      let labelSize = attributedLabel.size()
      let badgeRect = CGRect(
        x: rect.minX + 8,
        y: rect.minY + 8,
        width: max(24, labelSize.width + 14),
        height: labelSize.height + 8
      )
      NSColor.systemBlue.withAlphaComponent(0.92).setFill()
      let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 5, yRadius: 5)
      badge.fill()
      attributedLabel.draw(
        at: CGPoint(
          x: badgeRect.midX - labelSize.width / 2.0,
          y: badgeRect.midY - labelSize.height / 2.0
        ))
    }
  }

  func drawEntity(_ entity: CanvasEntity, in pageRect: CGRect) {
    let style = lineStyle(for: entity, in: pageRect)
    let stroke = style.color

    switch entity.geometry {
    case .point(let point):
      let canvasPoint = canvasPoint(for: point, in: pageRect)
      let markerSize = max(6, style.lineWidth * 2.5)
      let rect = CGRect(
        x: canvasPoint.x - markerSize / 2,
        y: canvasPoint.y - markerSize / 2,
        width: markerSize,
        height: markerSize
      )
      stroke.setFill()
      NSBezierPath(ovalIn: rect).fill()

    case .line(let start, let end, _):
      let startPoint = canvasPoint(for: start, in: pageRect)
      let endPoint = canvasPoint(for: end, in: pageRect)
      let path = NSBezierPath()
      path.move(to: startPoint)
      path.line(to: endPoint)
      let lineStyle = style.distinguished(for: entity)
      apply(style: lineStyle, to: path)
      lineStyle.color.setStroke()
      path.stroke()

    case .circle(let center, let radiusMM):
      stroke.setStroke()
      let rect = rect(forCircleAt: center, radiusMM: radiusMM, in: pageRect)
      let path = NSBezierPath(ovalIn: rect)
      apply(style: style, to: path)
      path.stroke()

    case .arc(let center, let radiusMM, let startAngleRad, let sweepAngleRad):
      stroke.setStroke()
      drawArc(
        center: center,
        radiusMM: radiusMM,
        startAngleRad: startAngleRad,
        sweepAngleRad: sweepAngleRad,
        style: style,
        in: pageRect
      )

    case .unsupported:
      break
    }

    if !isOutputPreviewMode {
      if filletDraftEntityIDs.contains(entity.id) {
        drawFilletDraftHighlight(around: hitRect(for: entity, in: pageRect))
      } else if isEntitySelected(entity) {
        drawSelectionHighlight(around: hitRect(for: entity, in: pageRect))
      } else if highlightedPartEntityIDs.contains(entity.id) {
        drawPartHighlight(around: hitRect(for: entity, in: pageRect))
      }
    }
    if !isOutputPreviewMode,
      isEntitySelected(entity) || selectedTool.isConstraintTool || selectedTool.isMeasurementTool
    {
      drawControlPointHandles(for: entity, in: pageRect)
    }
  }

  func drawSelectionHighlight(around rect: CGRect) {
    NSColor(calibratedRed: 0.231, green: 0.510, blue: 0.964, alpha: 0.28).setStroke()
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: -4, dy: -4), xRadius: 8, yRadius: 8)
    path.lineWidth = 3
    path.stroke()
  }

  func drawFilletDraftHighlight(around rect: CGRect) {
    NSColor.systemPurple.withAlphaComponent(0.76).setStroke()
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: -5, dy: -5), xRadius: 8, yRadius: 8)
    path.lineWidth = 3
    path.setLineDash([6, 3], count: 2, phase: 0)
    path.stroke()
  }

  func drawPartHighlight(around rect: CGRect) {
    NSColor.systemOrange.withAlphaComponent(0.55).setStroke()
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: -3, dy: -3), xRadius: 7, yRadius: 7)
    path.lineWidth = 2
    path.stroke()
  }

  func drawConstraintTargetFeedback(in pageRect: CGRect) {
    guard !isOutputPreviewMode else {
      return
    }
    guard selectedTool.isConstraintTool || selectedTool.isMeasurementTool else {
      return
    }

    for target in pendingConstraintTargets {
      drawConstraintTarget(target, selected: true, in: pageRect)
    }

    if let hoveredConstraintTarget,
      !pendingConstraintTargets.contains(hoveredConstraintTarget)
    {
      drawConstraintTarget(hoveredConstraintTarget, selected: false, in: pageRect)
    }

    if let constraintHoverPoint {
      drawConstraintGuidanceBadge(near: constraintHoverPoint)
    }
  }

  func drawSelectedConstraintTargets(in pageRect: CGRect) {
    guard !isOutputPreviewMode else {
      return
    }
    guard selectedTool == .select,
      let selectedConstraintID,
      let constraint = documentConstraints.first(where: { $0.id == selectedConstraintID }),
      let targets = constraintTargetObjects(constraint)
    else {
      return
    }

    for target in targets {
      if case .entity = target,
        let entity = visibleEntities.first(where: { $0.id == target.entityID }),
        !entity.supportsLinearConstraint,
        entity.kind != .point
      {
        drawEntityConstraintTarget(entity, in: pageRect)
        continue
      }
      guard let selectionTarget = canvasSelectionTarget(for: target) else {
        continue
      }
      drawConstraintTarget(selectionTarget, selected: true, in: pageRect)
    }
  }

  func drawEntityConstraintTarget(_ entity: CanvasEntity, in pageRect: CGRect) {
    let stroke = NSColor(calibratedRed: 0.125, green: 0.290, blue: 0.675, alpha: 0.95)
    let fill = NSColor(calibratedRed: 0.231, green: 0.510, blue: 0.964, alpha: 0.14)
    let rect = hitRect(for: entity, in: pageRect).insetBy(dx: -5, dy: -5)
    let path: NSBezierPath
    switch entity.geometry {
    case .circle, .arc:
      path = NSBezierPath(ovalIn: rect)
    default:
      path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
    }
    fill.setFill()
    stroke.setStroke()
    path.lineWidth = 3.0
    path.fill()
    path.stroke()
  }

  func drawConstraintTarget(_ target: CanvasSelectionTarget, selected: Bool, in pageRect: CGRect) {
    let stroke =
      selected
      ? NSColor(calibratedRed: 0.125, green: 0.290, blue: 0.675, alpha: 0.95)
      : NSColor(calibratedRed: 0.016, green: 0.506, blue: 0.455, alpha: 0.92)
    let fill =
      selected
      ? NSColor(calibratedRed: 0.231, green: 0.510, blue: 0.964, alpha: 0.14)
      : NSColor(calibratedRed: 0.016, green: 0.506, blue: 0.455, alpha: 0.10)
    let lineWidth: CGFloat = selected ? 3.0 : 2.0

    if target.isLineTarget,
      let line =
        visibleEntities
        .first(where: { $0.id == target.entityID })?
        .lineSelectionTargets
        .first(where: {
          $0.target.entityID == target.entityID && $0.target.controlPoint == target.controlPoint
        })
    {
      let path = NSBezierPath()
      path.move(to: canvasPoint(for: line.start, in: pageRect))
      path.line(to: canvasPoint(for: line.end, in: pageRect))
      path.lineWidth = lineWidth
      path.lineCapStyle = .round
      stroke.setStroke()
      path.stroke()
      return
    }

    if let point = target.point {
      let canvasPoint = canvasPoint(for: point, in: pageRect)
      let rect = CGRect(x: canvasPoint.x - 8, y: canvasPoint.y - 8, width: 16, height: 16)
      fill.setFill()
      stroke.setStroke()
      let path = NSBezierPath(ovalIn: rect)
      path.lineWidth = lineWidth
      path.fill()
      path.stroke()
      return
    }

    guard let entity = visibleEntities.first(where: { $0.id == target.entityID }) else {
      return
    }
    fill.setFill()
    stroke.setStroke()
    let rect = hitRect(for: entity, in: pageRect).insetBy(dx: -5, dy: -5)
    let path: NSBezierPath
    switch entity.geometry {
    case .circle, .arc:
      path = NSBezierPath(ovalIn: rect)
    default:
      path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
    }
    path.lineWidth = lineWidth
    path.fill()
    path.stroke()
  }

  func drawConstraintGuidanceBadge(near point: CGPoint) {
    let text = NSAttributedString(
      string: constraintGuidanceText(),
      attributes: [
        .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 0.016, green: 0.506, blue: 0.455, alpha: 1.0),
      ]
    )
    let textSize = text.size()
    let rect = CGRect(
      x: point.x + 12,
      y: point.y + 12,
      width: textSize.width + 14,
      height: textSize.height + 7
    )
    NSColor(calibratedWhite: 1.0, alpha: 0.92).setFill()
    NSColor(calibratedRed: 0.016, green: 0.506, blue: 0.455, alpha: 0.58).setStroke()
    let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
    path.lineWidth = 1
    path.fill()
    path.stroke()
    text.draw(at: CGPoint(x: rect.minX + 7, y: rect.minY + 3.5))
  }

  func constraintGuidanceText() -> String {
    switch selectedTool {
    case .distance, .measureDistance:
      return pendingConstraintTargets.isEmpty
        ? AppStrings.tr("canvas.constraint_hint.point_or_line")
        : AppStrings.tr("canvas.constraint_hint.next_point_or_line")
    case .horizontal, .vertical:
      return pendingConstraintTargets.isEmpty
        ? AppStrings.tr("canvas.constraint_hint.point_or_line")
        : AppStrings.tr("canvas.constraint_hint.next_point_or_line")
    case .horizontalDistance, .verticalDistance:
      return pendingConstraintTargets.isEmpty
        ? AppStrings.tr("canvas.constraint_hint.point")
        : AppStrings.tr("canvas.constraint_hint.next_point")
    case .coincident:
      return pendingConstraintTargets.isEmpty
        ? AppStrings.tr("canvas.constraint_hint.point")
        : AppStrings.tr("canvas.constraint_hint.next_point")
    case .parallel, .perpendicular, .equalLength, .angle, .segmentLength, .fillet,
      .measureSegmentLength, .measureAngle:
      return pendingConstraintTargets.isEmpty
        ? AppStrings.tr("canvas.constraint_hint.line")
        : AppStrings.tr("canvas.constraint_hint.next_line")
    case .diameter, .measureDiameter:
      return AppStrings.tr("canvas.constraint_hint.circle")
    case .radius, .measureRadius:
      return AppStrings.tr("canvas.constraint_hint.circle_or_arc")
    case .measureArcSweepAngle:
      return AppStrings.tr("canvas.constraint_hint.circle_or_arc")
    case .fixed:
      return AppStrings.tr("canvas.constraint_hint.point_or_center")
    case .symmetric:
      return pendingConstraintTargets.count < 2
        ? AppStrings.tr("canvas.constraint_hint.point")
        : AppStrings.tr("canvas.constraint_hint.next_axis")
    default:
      return AppStrings.tr("canvas.constraint_hint.target")
    }
  }

  func drawCoincidentPointGroups(in pageRect: CGRect) {
    guard selectedTool == .select || selectedTool.isConstraintTool || selectedTool.isMeasurementTool
    else {
      return
    }
    let visibleEntityIDs = Set(visibleEntities.map(\.id))
    for group in coincidentPointGroups
    where coincidentGroupIsVisible(group, visibleEntityIDs: visibleEntityIDs) {
      let point = canvasPoint(for: group.representative, in: pageRect)
      let rect = CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)
      NSColor(calibratedRed: 0.949, green: 0.322, blue: 0.137, alpha: 0.92).setStroke()
      NSColor(calibratedRed: 1.0, green: 0.949, blue: 0.882, alpha: 0.86).setFill()
      let path = NSBezierPath(ovalIn: rect)
      path.lineWidth = 2
      path.fill()
      path.stroke()
    }
  }

  func coincidentGroupIsVisible(_ group: CoincidentPointGroup, visibleEntityIDs: Set<String>)
    -> Bool
  {
    guard let targets = CoreConstraintTarget.decodeList(from: group.targetsJSON) else {
      return false
    }
    let targetEntityIDs = targets.map(\.entityID)
    return !targetEntityIDs.isEmpty && targetEntityIDs.allSatisfy { visibleEntityIDs.contains($0) }
  }

  func drawControlPointHandles(for entity: CanvasEntity, in pageRect: CGRect) {
    let targets =
      selectedTool == .select && selectedEntityID == entity.id
      ? entity.editPointTargets
      : entity.pointSelectionTargets
    for item in targets {
      let point = canvasPoint(for: item.point, in: pageRect)
      let rect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
      let selected = pendingConstraintTargets.contains(item.target)
      let isEditOnlyHandle = item.target.controlPoint?.isConstraintCompatible == false
      let fill =
        selected
        ? NSColor(calibratedRed: 0.231, green: 0.510, blue: 0.964, alpha: 1.0)
        : isEditOnlyHandle
          ? NSColor(calibratedRed: 1.0, green: 0.969, blue: 0.863, alpha: 0.98)
          : NSColor(calibratedWhite: 1.0, alpha: 0.96)
      let stroke =
        selected
        ? NSColor(calibratedRed: 0.125, green: 0.290, blue: 0.675, alpha: 1.0)
        : isEditOnlyHandle
          ? NSColor(calibratedRed: 0.635, green: 0.361, blue: 0.000, alpha: 0.95)
          : NSColor(calibratedRed: 0.090, green: 0.125, blue: 0.165, alpha: 0.82)

      fill.setFill()
      stroke.setStroke()
      let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
      path.lineWidth = selected ? 2 : 1
      path.fill()
      path.stroke()
    }
  }

  func drawEmptyState(in pageRect: CGRect) {
    let markerRect = CGRect(x: pageRect.midX - 21, y: pageRect.midY - 42, width: 42, height: 42)
    NSColor(calibratedRed: 0.392, green: 0.439, blue: 0.490, alpha: 0.38).setStroke()
    let marker = NSBezierPath(ovalIn: markerRect)
    marker.lineWidth = 2
    marker.setLineDash([4, 4], count: 2, phase: 0)
    marker.stroke()

    let titleAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
      .foregroundColor: NSColor(calibratedRed: 0.090, green: 0.125, blue: 0.165, alpha: 1.0),
    ]
    let bodyAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 11, weight: .regular),
      .foregroundColor: NSColor(calibratedRed: 0.392, green: 0.439, blue: 0.490, alpha: 1.0),
    ]

    NSAttributedString(string: AppStrings.tr("canvas.empty.title"), attributes: titleAttributes)
      .draw(at: CGPoint(x: pageRect.midX - 96, y: pageRect.midY + 14))
    NSAttributedString(string: AppStrings.tr("canvas.empty.body"), attributes: bodyAttributes)
      .draw(at: CGPoint(x: pageRect.midX - 132, y: pageRect.midY + 36))
  }

  func layerStyle(for layerID: String?, in pageRect: CGRect) -> CanvasLineStyle {
    guard let layerID,
      let layer = layers.first(where: { $0.id == layerID })
    else {
      return CanvasLineStyle(
        color: NSColor(calibratedRed: 0.067, green: 0.094, blue: 0.153, alpha: 1.0),
        lineWidth: 2,
        pattern: .solid
      )
    }
    let lineWidth = max(1, CGFloat(layer.strokeWidthMM) * canvasScale(in: pageRect))
    return CanvasLineStyle(
      color: NSColor(hex: layer.colorHex),
      lineWidth: lineWidth,
      pattern: layer.linePattern
    )
  }

  func lineStyle(for entity: CanvasEntity, in pageRect: CGRect) -> CanvasLineStyle {
    if let styleID = entity.styleID,
      let sharedStyle = sharedStyles.first(where: { $0.id == styleID })
    {
      return CanvasLineStyle(
        color: NSColor(hex: sharedStyle.colorHex),
        lineWidth: max(1, CGFloat(sharedStyle.strokeWidthMM) * canvasScale(in: pageRect)),
        pattern: sharedStyle.linePattern
      )
    }
    return layerStyle(for: entity.layerID, in: pageRect)
  }

  func apply(style: CanvasLineStyle, to path: NSBezierPath) {
    path.lineWidth = style.lineWidth
    if let dashPattern = style.dashPattern {
      path.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
      return
    }
    switch style.pattern {
    case .solid:
      path.setLineDash(nil, count: 0, phase: 0)
    case .dashed, .construction:
      path.setLineDash([style.lineWidth * 4, style.lineWidth * 2.5], count: 2, phase: 0)
    case .dotted:
      path.setLineDash([style.lineWidth, style.lineWidth * 2], count: 2, phase: 0)
    }
  }

  func drawArc(
    center: ModelPoint,
    radiusMM: Double,
    startAngleRad: Double,
    sweepAngleRad: Double,
    style: CanvasLineStyle,
    in pageRect: CGRect
  ) {
    let centerPoint = canvasPoint(for: center, in: pageRect)
    let pathParameters = canvasArcPathParameters(
      startAngleRad: startAngleRad, sweepAngleRad: sweepAngleRad)
    let path = NSBezierPath()
    path.appendArc(
      withCenter: centerPoint,
      radius: radiusMM * canvasScale(in: pageRect),
      startAngle: CGFloat(pathParameters.startAngleDeg),
      endAngle: CGFloat(pathParameters.endAngleDeg),
      clockwise: pathParameters.clockwise
    )
    apply(style: style, to: path)
    path.stroke()
  }
}
