import AppKit
import KawaCADOutput
import SwiftUI

/// Rendering responsibilities extracted from the input-oriented canvas view.
/// The view still owns lifecycle and callbacks; this extension owns the
/// projection of the current immutable canvas snapshot into AppKit drawing.
extension LeatherCanvasView {
  func measurementAnnotationHit(at point: CGPoint, in pageRect: CGRect) -> MeasurementAnnotationHit?
  {
    for annotation in measurementAnnotations.reversed() where annotation.visible {
      guard let label = measurementAnnotationLabel(for: annotation),
        let resolved = canvasProjection.measurementAnnotations.first(where: {
          $0.id == annotation.id && $0.visible
        })
      else { continue }
      switch annotation.rawKind {
      case "distance":
        guard let first = resolved.startMM,
          let second = resolved.endMM,
          let layout = measurementLineLayout(
            from: first,
            to: second,
            label: label,
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            in: pageRect
          )
        else { continue }
        if layout.labelRect.insetBy(
          dx: -CanvasMetrics.annotationLabelHitPaddingPx,
          dy: -CanvasMetrics.annotationLabelHitPaddingPx
        ).contains(point) {
          return MeasurementAnnotationHit(annotation: annotation, labelOnly: true)
        }
        if distanceFrom(point, toSegmentStart: layout.shiftedStart, end: layout.shiftedEnd)
          <= CanvasMetrics.annotationLineHitTolerancePx
        {
          return MeasurementAnnotationHit(annotation: annotation, labelOnly: false)
        }
      case "segmentLength":
        guard let start = resolved.startMM,
          let end = resolved.endMM,
          let layout = measurementLineLayout(
            from: start,
            to: end,
            label: label,
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            in: pageRect
          )
        else { continue }
        if layout.labelRect.insetBy(
          dx: -CanvasMetrics.annotationLabelHitPaddingPx,
          dy: -CanvasMetrics.annotationLabelHitPaddingPx
        ).contains(point) {
          return MeasurementAnnotationHit(annotation: annotation, labelOnly: true)
        }
        if distanceFrom(point, toSegmentStart: layout.shiftedStart, end: layout.shiftedEnd)
          <= CanvasMetrics.annotationLineHitTolerancePx
        {
          return MeasurementAnnotationHit(annotation: annotation, labelOnly: false)
        }
      case "diameter":
        guard let start = resolved.startMM,
          let end = resolved.endMM,
          let layout = measurementLineLayout(
            from: start,
            to: end,
            label: label,
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            in: pageRect
          )
        else { continue }
        if layout.labelRect.insetBy(
          dx: -CanvasMetrics.annotationLabelHitPaddingPx,
          dy: -CanvasMetrics.annotationLabelHitPaddingPx
        ).contains(point) {
          return MeasurementAnnotationHit(annotation: annotation, labelOnly: true)
        }
        if distanceFrom(point, toSegmentStart: layout.shiftedStart, end: layout.shiftedEnd)
          <= CanvasMetrics.annotationLineHitTolerancePx
        {
          return MeasurementAnnotationHit(annotation: annotation, labelOnly: false)
        }
      case "radius":
        guard let center = resolved.centerMM,
          let start = resolved.startMM,
          let layout = measurementLineLayout(
            from: center,
            to: start,
            label: label,
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            in: pageRect
          )
        else { continue }
        if layout.labelRect.insetBy(
          dx: -CanvasMetrics.annotationLabelHitPaddingPx,
          dy: -CanvasMetrics.annotationLabelHitPaddingPx
        ).contains(point) {
          return MeasurementAnnotationHit(annotation: annotation, labelOnly: true)
        }
        if distanceFrom(point, toSegmentStart: layout.shiftedStart, end: layout.shiftedEnd)
          <= CanvasMetrics.annotationLineHitTolerancePx
        {
          return MeasurementAnnotationHit(annotation: annotation, labelOnly: false)
        }
      case "angle", "arcSweepAngle":
        guard let overlay = measurementAngleOverlay(for: annotation) else {
          continue
        }
        guard
          let layout = CanvasAnnotationLayout.angle(
            overlay: overlay,
            label: overlay.label,
            labelOffsetMM: annotation.labelOffsetMM,
            overallOffsetMM: annotation.overallOffsetMM,
            in: pageRect,
            orientation: a4ReferenceOrientation
          )
        else {
          continue
        }
        if layout.labelRect.insetBy(
          dx: -CanvasMetrics.annotationLabelHitPaddingPx,
          dy: -CanvasMetrics.annotationLabelHitPaddingPx
        ).contains(point) {
          return MeasurementAnnotationHit(annotation: annotation, labelOnly: true)
        }
      default:
        continue
      }
    }
    return nil
  }

  func dimensionConstraintAnnotationHit(
    at point: CGPoint,
    in pageRect: CGRect
  ) -> DimensionConstraintAnnotationHit? {
    for constraint in documentConstraints.reversed() where constraint.isDimensionConstraint {
      guard let label = dimensionLabel(for: constraint),
        let resolved = canvasProjection.dimensionConstraints.first(where: {
          $0.id == constraint.id && $0.visible
        })
      else { continue }
      let annotation = dimensionConstraintDisplayAnnotation(for: constraint.id)
      guard annotation.visible else { continue }
      switch constraint.rawKind {
      case "segmentLength", "distance", "pointLineDistance", "lineLineDistance", "diameter":
        guard let start = resolved.startMM, let end = resolved.endMM else { continue }
        if let hit = dimensionConstraintLineHit(
          constraint: constraint,
          start: start,
          end: end,
          label: label,
          annotation: annotation,
          point: point,
          in: pageRect
        ) {
          return hit
        }
      case "horizontalDistance", "verticalDistance":
        guard let first = resolved.startMM, let second = resolved.endMM else { continue }
        let axis: AxisDistanceDimensionAxis =
          constraint.rawKind == "horizontalDistance" ? .horizontal : .vertical
        if let hit = axisDimensionConstraintHit(
          constraint: constraint,
          first: first,
          second: second,
          axis: axis,
          label: label,
          annotation: annotation,
          point: point,
          in: pageRect
        ) {
          return hit
        }
      case "radius":
        guard let center = resolved.centerMM, let start = resolved.startMM else { continue }
        if let hit = dimensionConstraintLineHit(
          constraint: constraint,
          start: center,
          end: start,
          label: label,
          annotation: annotation,
          point: point,
          in: pageRect
        ) {
          return hit
        }
      case "angle":
        guard let overlay = angleConstraintOverlay(for: constraint),
          let hit = angleDimensionConstraintHit(
            constraint: constraint,
            overlay: overlay,
            annotation: annotation,
            point: point,
            in: pageRect
          )
        else { continue }
        return hit
      default:
        continue
      }
    }
    return nil
  }

  func dimensionConstraintLineHit(
    constraint: ProjectConstraint,
    start: ModelPoint,
    end: ModelPoint,
    label: String,
    annotation: ProjectDimensionConstraintAnnotation,
    point: CGPoint,
    in pageRect: CGRect
  ) -> DimensionConstraintAnnotationHit? {
    guard
      let layout = measurementLineLayout(
        from: start,
        to: end,
        label: label,
        labelOffsetMM: annotation.labelOffsetMM,
        overallOffsetMM: annotation.overallOffsetMM,
        in: pageRect
      )
    else {
      return nil
    }
    if layout.labelRect.insetBy(
      dx: -CanvasMetrics.annotationLabelHitPaddingPx,
      dy: -CanvasMetrics.annotationLabelHitPaddingPx
    ).contains(point) {
      return DimensionConstraintAnnotationHit(constraint: constraint, labelOnly: true)
    }
    if distanceFrom(point, toSegmentStart: layout.shiftedStart, end: layout.shiftedEnd)
      <= CanvasMetrics.annotationLineHitTolerancePx
    {
      return DimensionConstraintAnnotationHit(constraint: constraint, labelOnly: false)
    }
    return nil
  }

  func axisDimensionConstraintHit(
    constraint: ProjectConstraint,
    first: ModelPoint,
    second: ModelPoint,
    axis: AxisDistanceDimensionAxis,
    label: String,
    annotation: ProjectDimensionConstraintAnnotation,
    point: CGPoint,
    in pageRect: CGRect
  ) -> DimensionConstraintAnnotationHit? {
    let layoutAxis: CanvasAnnotationLayout.Axis =
      axis == .horizontal ? .horizontal : .vertical
    guard
      let layout = CanvasAnnotationLayout.axis(
        start: first,
        end: second,
        axis: layoutAxis,
        label: label,
        labelOffsetMM: annotation.labelOffsetMM,
        overallOffsetMM: annotation.overallOffsetMM,
        in: pageRect,
        orientation: a4ReferenceOrientation
      )
    else {
      return nil
    }
    if layout.labelRect.insetBy(
      dx: -CanvasMetrics.annotationLabelHitPaddingPx,
      dy: -CanvasMetrics.annotationLabelHitPaddingPx
    ).contains(point) {
      return DimensionConstraintAnnotationHit(constraint: constraint, labelOnly: true)
    }
    if distanceFrom(point, toSegmentStart: layout.dimensionStart, end: layout.dimensionEnd)
      <= CanvasMetrics.annotationLineHitTolerancePx
    {
      return DimensionConstraintAnnotationHit(constraint: constraint, labelOnly: false)
    }
    return nil
  }

  func angleDimensionConstraintHit(
    constraint: ProjectConstraint,
    overlay: AngleConstraintOverlay,
    annotation: ProjectDimensionConstraintAnnotation,
    point: CGPoint,
    in pageRect: CGRect
  ) -> DimensionConstraintAnnotationHit? {
    guard
      let layout = CanvasAnnotationLayout.angle(
        overlay: overlay,
        label: overlay.label,
        labelOffsetMM: annotation.labelOffsetMM,
        overallOffsetMM: annotation.overallOffsetMM,
        in: pageRect,
        orientation: a4ReferenceOrientation
      )
    else {
      return nil
    }
    if layout.labelRect.insetBy(
      dx: -CanvasMetrics.annotationLabelHitPaddingPx,
      dy: -CanvasMetrics.annotationLabelHitPaddingPx
    ).contains(point) {
      return DimensionConstraintAnnotationHit(constraint: constraint, labelOnly: true)
    }
    if layout.contains(point, radiusTolerance: CanvasMetrics.annotationArcHitTolerancePx) {
      return DimensionConstraintAnnotationHit(constraint: constraint, labelOnly: false)
    }
    return nil
  }

  func constraintMarkers(in pageRect: CGRect) -> [ConstraintMarker] {
    guard !isOutputPreviewMode else {
      return []
    }
    return ConstraintMarkerLayout.markers(
      constraints: documentConstraints,
      anchors: canvasProjection.constraintMarkers
    )
  }

  func constraintMarkerID(at point: CGPoint, in pageRect: CGRect) -> String? {
    constraintMarker(at: point, in: pageRect)?.constraintID
  }

  func dimensionConstraintAnnotationHitInfo(
    at point: CGPoint,
    in pageRect: CGRect
  ) -> (constraintID: String, labelOnly: Bool)? {
    dimensionConstraintAnnotationHit(at: point, in: pageRect).map {
      ($0.constraint.id, $0.labelOnly)
    }
  }

  func constraintMarker(at point: CGPoint, in pageRect: CGRect) -> ConstraintMarker? {
    let tolerance = CanvasMetrics.constraintMarkerHitTolerancePx
    return constraintMarkers(in: pageRect)
      .reversed()
      .first { marker in
        return constraintMarkerRect(marker, in: pageRect)
          .insetBy(dx: -tolerance, dy: -tolerance)
          .contains(point)
      }
  }

  func updateHoveredConstraintMarker(for point: CGPoint, in pageRect: CGRect) {
    guard canvasBoundsRect(in: pageRect).contains(point), selectedTool == .select else {
      commandExecutor.clearHoverConstraint()
      return
    }
    commandExecutor.hoverConstraint(constraintMarker(at: point, in: pageRect)?.constraintID)
  }

  func constraintMarkerRect(_ marker: ConstraintMarker, in pageRect: CGRect) -> CGRect {
    CanvasLayout.constraintMarkerRect(
      position: marker.position,
      stackIndex: marker.stackIndex,
      in: coordinateSpace(in: pageRect)
    )
  }

  func constraintMarkerVisualRect(_ marker: ConstraintMarker, in pageRect: CGRect) -> CGRect {
    constraintMarkerRect(marker, in: pageRect).insetBy(dx: 2.0, dy: 2.0)
  }

  func markerOffset(for stackIndex: Int) -> CGSize {
    CanvasLayout.constraintMarkerOffset(for: stackIndex)
  }
  func constraintTargetObjects(_ constraint: ProjectConstraint) -> [CoreConstraintTarget]? {
    CoreConstraintTarget.decodeList(from: constraint.targetsJSON)
  }

  func canvasSelectionTarget(for target: CoreConstraintTarget) -> CanvasSelectionTarget? {
    guard let entity = visibleEntities.first(where: { $0.id == target.entityID }) else {
      return nil
    }
    switch target {
    case .entity:
      if entity.supportsLinearConstraint {
        return entity.lineSelectionTargets.first?.target
      }
      return entity.entitySelectionTarget
    case .controlPoint(_, let point):
      return entity.pointSelectionTargets
        .first(where: { $0.target.controlPoint?.wirePoint == point })?
        .target
    }
  }

  func canvasScale(in pageRect: CGRect) -> CGFloat {
    coordinateSpace(in: pageRect).scale
  }

  func coordinateSpace(in pageRect: CGRect) -> CanvasCoordinateSpace {
    CanvasCoordinateSpace(pageRect: pageRect, orientation: a4ReferenceOrientation)
  }

  func hitTesting(in pageRect: CGRect) -> CanvasHitTesting {
    CanvasHitTesting(
      displayEntities: visibleEntities,
      derivedElements: derivedElements,
      selectedTool: selectedTool,
      coordinateSpace: coordinateSpace(in: pageRect)
    )
  }

  func rect(forCircleAt center: ModelPoint, radiusMM: Double, in pageRect: CGRect) -> CGRect {
    let centerPoint = canvasPoint(for: center, in: pageRect)
    let scale = canvasScale(in: pageRect)
    let radius = radiusMM * scale
    return CGRect(
      x: centerPoint.x - radius,
      y: centerPoint.y - radius,
      width: radius * 2,
      height: radius * 2
    )
  }

  func hitRect(for entity: CanvasEntity, in pageRect: CGRect) -> CGRect {
    hitTesting(in: pageRect).hitRect(for: entity)
  }

  func marqueeCandidateIDs(startPoint: CGPoint, currentPoint: CGPoint) -> Set<String> {
    let pageRect = pageRect(in: bounds)
    let canvasRect = CanvasInteractionState.normalizedRect(from: startPoint, to: currentPoint)
    return CanvasMarqueeSelection(coordinateSpace: coordinateSpace(in: pageRect)).candidateIDs(
      from: visibleEntities.filter { !isFilletResolvedEntity($0) },
      in: canvasRect,
      mode: CanvasMarqueeSelectionMode(startPoint: startPoint, currentPoint: currentPoint)
    )
  }

  func entity(
    at point: CGPoint,
    in pageRect: CGRect,
    preferring preferredEntityIDs: Set<String> = []
  ) -> CanvasEntity? {
    hitTesting(in: pageRect).entity(at: point, preferring: preferredEntityIDs)
  }

  func isFilletResolvedEntity(_ entity: CanvasEntity) -> Bool {
    hitTesting(in: pageRect(in: bounds)).isFilletResolvedEntity(entity)
  }

  func isEntitySelected(_ entity: CanvasEntity) -> Bool {
    selectedEntityID == entity.id || selectedEntityIDs.contains(entity.id)
  }

  func controlPointTarget(
    at point: CGPoint,
    in pageRect: CGRect,
    includeEditHandles: Bool = false
  ) -> CanvasSelectionTarget? {
    hitTesting(in: pageRect).controlPointTarget(at: point, includeEditHandles: includeEditHandles)
  }

  func lineTarget(at point: CGPoint, in pageRect: CGRect) -> CanvasSelectionTarget? {
    hitTesting(in: pageRect).lineTarget(at: point)
  }

  func distanceFromCanvasPoint(_ point: CGPoint, toSegmentStart start: CGPoint, end: CGPoint)
    -> CGFloat
  {
    CanvasHitTesting.distanceFromCanvasPoint(point, toSegmentStart: start, end: end)
  }

  func radiansToDegrees(_ radians: Double) -> CGFloat {
    CGFloat(radians * 180 / Double.pi)
  }

}
