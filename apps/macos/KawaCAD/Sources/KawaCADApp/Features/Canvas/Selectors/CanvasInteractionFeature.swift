import Foundation

/// Pure canvas placement calculations.
enum CanvasInteractionFeature {
  static func drawingPlacementPoint(
    _ point: ModelPoint,
    modifiers: CanvasPlacementModifiers,
    pointSnapEnabled: Bool,
    gridSnapEnabled: Bool,
    entities: [CanvasEntity],
    linePointSnapToleranceMM: Double,
    gridSpacingMM: Double
  ) -> ModelPoint {
    guard !modifiers.suppressesSnap else {
      return point
    }
    if pointSnapEnabled,
      let nearest = nearestLinePointTarget(
        entities: entities,
        near: point,
        toleranceMM: linePointSnapToleranceMM
      )
    {
      return nearest.point
    }
    return gridSnapEnabled
      ? gridSnapped(point, spacingMM: gridSpacingMM)
      : point
  }

  static func arcPlacementEndPoint(
    center: ModelPoint,
    start: ModelPoint,
    candidate: ModelPoint,
    previousSweepAngleRad: Double?,
    forceAxis: Bool,
    angleSnapStepRad: Double
  ) -> ArcPlacementResult? {
    let radius = distance(center, start)
    guard radius > 0.0001 else {
      return nil
    }

    let startAngle = angleRadians(from: center, to: start)
    let candidateAngle = angleRadians(from: center, to: candidate)
    var sweepAngle: Double
    if let previousSweepAngleRad {
      sweepAngle =
        previousSweepAngleRad
        + normalizedSignedSweepAngle(
          startAngleRad: startAngle + previousSweepAngleRad,
          endAngleRad: candidateAngle
        )
    } else {
      sweepAngle = normalizedSignedSweepAngle(
        startAngleRad: startAngle,
        endAngleRad: candidateAngle
      )
    }
    if forceAxis {
      sweepAngle = (sweepAngle / angleSnapStepRad).rounded() * angleSnapStepRad
    }
    guard isValidArcSweep(sweepAngle) else {
      return nil
    }

    let snappedAngle = startAngle + sweepAngle
    return ArcPlacementResult(
      point: ModelPoint(
        xMM: center.xMM + radius * cos(snappedAngle),
        yMM: center.yMM + radius * sin(snappedAngle)
      ),
      sweepAngleRad: sweepAngle
    )
  }

  static func linePlacementEndPoint(
    from start: ModelPoint,
    to point: ModelPoint,
    modifiers: CanvasPlacementModifiers,
    pointSnapEnabled: Bool,
    gridSnapEnabled: Bool,
    entities: [CanvasEntity],
    linePointSnapToleranceMM: Double,
    gridSpacingMM: Double
  ) -> LinePlacementEnd {
    if !modifiers.suppressesSnap,
      pointSnapEnabled,
      let nearest = nearestLinePointTarget(
        entities: entities,
        near: point,
        toleranceMM: linePointSnapToleranceMM
      )
    {
      return LinePlacementEnd(
        point: nearest.point,
        target: nearest.target,
        orientation: orientationForSnappedPoint(start: start, end: nearest.point)
      )
    }

    let orientation = lineOrientation(
      from: start,
      to: point,
      forced: modifiers.forceAxis
    )
    guard let orientation else {
      return LinePlacementEnd(
        point: !modifiers.suppressesSnap && gridSnapEnabled
          ? gridSnapped(point, spacingMM: gridSpacingMM)
          : point,
        target: nil,
        orientation: nil
      )
    }

    let adjusted: ModelPoint
    switch orientation {
    case .horizontal:
      let x =
        !modifiers.suppressesSnap && gridSnapEnabled
        ? gridSnappedValue(point.xMM, spacingMM: gridSpacingMM)
        : point.xMM
      adjusted = ModelPoint(xMM: x, yMM: start.yMM)
    case .vertical:
      let y =
        !modifiers.suppressesSnap && gridSnapEnabled
        ? gridSnappedValue(point.yMM, spacingMM: gridSpacingMM)
        : point.yMM
      adjusted = ModelPoint(xMM: start.xMM, yMM: y)
    }
    return LinePlacementEnd(point: adjusted, target: nil, orientation: orientation)
  }

  static func activeDrawingLayerID(
    for tool: CanvasTool,
    activeLayerID: String,
    layers: [ProjectLayer]
  ) -> String {
    switch tool {
    case .centerLine, .horizontalCenterLine, .verticalCenterLine:
      return existingLayerID(
        preferredID: "layer:construction",
        fallback: activeLayerID,
        layers: layers,
        activeLayerID: activeLayerID
      )
    default:
      return activeLayerID
    }
  }

  static func drawingSharedStyleID(
    for tool: CanvasTool,
    activePatternDrawingStyleID: String?
  ) -> String? {
    switch tool {
    case .line, .roundHole, .arc, .centerLine, .horizontalCenterLine,
      .verticalCenterLine, .offset:
      return activePatternDrawingStyleID
    default:
      return nil
    }
  }

  static func lineTargetsForEqualLength(
    entities: [CanvasEntity]
  ) -> [CanvasSelectionTarget] {
    Array(
      entities.compactMap { entity in
        entity.lineSelectionTargets.first?.target
      }.prefix(2))
  }

  static func isValidArcSweep(_ sweepAngle: Double) -> Bool {
    let fullTurn = 2.0 * Double.pi
    return abs(sweepAngle) > 0.0001
      && abs(abs(sweepAngle) - fullTurn) > 0.0001
      && abs(sweepAngle) < fullTurn
  }

  static func gridSnapped(
    _ point: ModelPoint,
    spacingMM: Double
  ) -> ModelPoint {
    ModelPoint(
      xMM: gridSnappedValue(point.xMM, spacingMM: spacingMM),
      yMM: gridSnappedValue(point.yMM, spacingMM: spacingMM)
    )
  }

  static func gridSnappedValue(
    _ value: Double,
    spacingMM: Double
  ) -> Double {
    (value / spacingMM).rounded() * spacingMM
  }

  static func lineOrientation(
    from start: ModelPoint,
    to point: ModelPoint,
    forced: Bool
  ) -> LinePlacementOrientation? {
    let dx = point.xMM - start.xMM
    let dy = point.yMM - start.yMM
    let length = hypot(dx, dy)
    guard length > 0.001 else { return nil }
    if forced {
      return abs(dx) >= abs(dy) ? .horizontal : .vertical
    }

    let tolerance = max(1.0, length * 0.035)
    switch (abs(dy) <= tolerance, abs(dx) <= tolerance) {
    case (true, true):
      return abs(dy) <= abs(dx) ? .horizontal : .vertical
    case (true, false):
      return .horizontal
    case (false, true):
      return .vertical
    case (false, false):
      return nil
    }
  }

  static func orientationForSnappedPoint(
    start: ModelPoint,
    end: ModelPoint
  ) -> LinePlacementOrientation? {
    if abs(end.yMM - start.yMM) <= 0.001 {
      return .horizontal
    }
    if abs(end.xMM - start.xMM) <= 0.001 {
      return .vertical
    }
    return nil
  }

  static func distance(_ first: ModelPoint, _ second: ModelPoint) -> Double {
    hypot(first.xMM - second.xMM, first.yMM - second.yMM)
  }

  static func nearestLinePointTarget(
    entities: [CanvasEntity],
    near point: ModelPoint,
    toleranceMM: Double
  ) -> (target: CanvasSelectionTarget, point: ModelPoint)? {
    entities
      .flatMap(\.pointSelectionTargets)
      .min { first, second in
        distance(first.point, point) < distance(second.point, point)
      }
      .flatMap { nearest in
        distance(nearest.point, point) <= toleranceMM ? nearest : nil
      }
  }

  static func fixedMillimeterValue(
    _ result: ConstraintPreflightResult
  ) -> Double? {
    guard case .fixedMm(let value) = result.value else { return nil }
    return value
  }

  static func constraintTargetPayloads(
    from result: ConstraintPreflightResult,
    fallback: [[String: Any]]
  ) -> [[String: Any]] {
    guard let normalizedTargets = result.normalizedTargets else {
      return fallback
    }
    return normalizedTargets.compactMap { target in
      target.jsonValue.anyValue as? [String: Any]
    }
  }

  static func shouldPreserveOffsetSelection(
    selectedEntityIDs: Set<String>,
    hitEntity: CanvasEntity,
    derivedElements: [ProjectDerivedElement]
  ) -> Bool {
    guard selectedEntityIDs.count > 1 else { return false }
    if selectedEntityIDs.contains(hitEntity.id) {
      return true
    }
    guard let derivedElementID = hitEntity.derivedElementID,
      let fillet = derivedElements.first(where: {
        $0.id == derivedElementID && $0.kind == .fillet
      })
    else {
      return false
    }
    return selectedEntityIDs.allSatisfy(fillet.sourceEntityIDs.contains)
  }

  static func persistentMeasurementSelection(
    target: CanvasSelectionTarget,
    entity: CanvasEntity,
    entities: [CanvasEntity]
  ) -> (target: CanvasSelectionTarget, entity: CanvasEntity) {
    guard target.isLineTarget,
      let sourceID = entity.sourceEntityID,
      let sourceEntity = entities.first(where: { $0.id == sourceID })
    else {
      return (target, entity)
    }
    return (
      CanvasSelectionTarget(
        entityID: sourceEntity.id,
        entityLabel: sourceEntity.label,
        entityKind: sourceEntity.kind,
        controlPoint: nil,
        point: target.point
      ),
      sourceEntity
    )
  }

  static func existingLayerID(
    preferredID: String,
    fallback: String,
    layers: [ProjectLayer],
    activeLayerID: String
  ) -> String {
    if layers.contains(where: { $0.id == preferredID }) {
      return preferredID
    }
    if layers.contains(where: { $0.id == fallback }) {
      return fallback
    }
    return activeLayerID
  }

  static func initialConstraintSelectionMessage(for tool: CanvasTool) -> String {
    switch tool {
    case .distance:
      return AppStrings.tr("status.constraint_select_distance_initial")
    case .horizontalDistance, .verticalDistance:
      return AppStrings.tr("status.constraint_select_axis_distance_initial", tool.displayName)
    case .pointOnLine:
      return AppStrings.tr("status.constraint_select_point_on_line_initial")
    case .coincident:
      return AppStrings.tr("status.constraint_select_coincident_initial")
    case .horizontal, .vertical:
      return AppStrings.tr("status.constraint_select_point_or_line_initial", tool.displayName)
    case .parallel, .perpendicular, .equalLength, .angle, .lineLineDistance:
      return AppStrings.tr("status.constraint_select_line_initial", tool.displayName)
    case .tangent:
      return AppStrings.tr("status.constraint_select_tangent_initial")
    case .fixed:
      return AppStrings.tr("status.constraint_select_fixed_initial")
    case .segmentLength:
      return AppStrings.tr("status.constraint_select_segment_length_initial")
    case .diameter:
      return AppStrings.tr("status.constraint_select_diameter_initial")
    case .radius:
      return AppStrings.tr("status.constraint_select_radius_initial")
    case .symmetric:
      return AppStrings.tr("status.constraint_select_symmetric_initial")
    default:
      return AppStrings.tr("status.constraint_click_target_initial", tool.displayName)
    }
  }

  static func constraintSelectionProgressMessage(
    for tool: CanvasTool,
    selectedCount: Int,
    requiredCount: Int
  ) -> String {
    switch tool {
    case .distance:
      return AppStrings.tr(
        "status.constraint_select_distance_progress",
        selectedCount,
        requiredCount
      )
    case .horizontalDistance, .verticalDistance:
      return AppStrings.tr(
        "status.constraint_select_axis_distance_progress",
        tool.displayName,
        selectedCount,
        requiredCount
      )
    case .pointOnLine:
      return AppStrings.tr(
        "status.constraint_select_point_on_line_progress",
        selectedCount,
        requiredCount
      )
    case .coincident:
      return AppStrings.tr(
        "status.constraint_select_coincident_progress",
        selectedCount,
        requiredCount
      )
    case .horizontal, .vertical:
      return AppStrings.tr(
        "status.constraint_select_point_or_line_progress",
        tool.displayName,
        selectedCount,
        requiredCount
      )
    case .parallel, .perpendicular, .equalLength, .angle, .lineLineDistance:
      return AppStrings.tr(
        "status.constraint_select_line_progress",
        tool.displayName,
        selectedCount,
        requiredCount
      )
    case .tangent:
      return AppStrings.tr(
        "status.constraint_select_tangent_progress",
        selectedCount,
        requiredCount
      )
    default:
      return AppStrings.tr(
        "status.constraint_select_remaining",
        tool.displayName,
        max(requiredCount - selectedCount, 0)
      )
    }
  }

  static func constraintValueEntryStatusMessage(
    title: String,
    allowsParameterReference: Bool,
    hasParameters: Bool
  ) -> String {
    if allowsParameterReference, hasParameters {
      return AppStrings.tr("status.constraint_value_or_parameter", title)
    }
    return AppStrings.tr("status.constraint_value_only", title)
  }
}
