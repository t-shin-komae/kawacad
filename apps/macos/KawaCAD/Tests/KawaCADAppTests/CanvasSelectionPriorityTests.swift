import Testing

@testable import KawaCADApp

struct CanvasSelectionPriorityTests {
  @Test
  func selection_specs_cover_constraint_and_measurement_target_policies() {
    #expect(CanvasTool.distance.targetSelectionSpec.selectionPriority == .pointThenLine)
    #expect(
      CanvasTool.distance.targetSelectionSpec.allowedTargetKinds == [.line, .centerLine, .point])
    #expect(CanvasTool.horizontalDistance.targetSelectionSpec.selectionPriority == .pointFirst)
    #expect(CanvasTool.horizontalDistance.targetSelectionSpec.allowedTargetKinds == [.point])
    #expect(CanvasTool.verticalDistance.targetSelectionSpec.selectionPriority == .pointFirst)
    #expect(CanvasTool.verticalDistance.targetSelectionSpec.allowedTargetKinds == [.point])
    #expect(CanvasTool.measureDistance.targetSelectionSpec.selectionPriority == .pointFirst)
    #expect(CanvasTool.measureDistance.targetSelectionSpec.allowedTargetKinds == [.point])
    #expect(CanvasTool.measureAngle.targetSelectionSpec.allowedTargetKinds == [.line, .centerLine])
    #expect(CanvasTool.measureArcSweepAngle.targetSelectionSpec.allowedTargetKinds == [.arc])
    #expect(
      CanvasTool.measureSegmentLength.targetSelectionSpec.derivedTargetPolicy
        == .normalizeFilletLineToSource)
    #expect(CanvasTool.offset.targetSelectionSpec.derivedTargetPolicy == .allow)
    #expect(CanvasTool.horizontal.targetSelectionSpec.derivedTargetPolicy == .reject)
  }

  @Test
  func select_tool_prefers_control_points_over_entity_body() {
    let controlPoint = CanvasSelectionTarget(
      entityID: "entity:line-a",
      entityLabel: "Line A",
      entityKind: .lineSegment,
      controlPoint: .start,
      point: .zero
    )
    let entityTarget = CanvasSelectionTarget(
      entityID: "entity:line-a",
      entityLabel: "Line A",
      entityKind: .lineSegment,
      controlPoint: nil,
      point: nil
    )

    let resolved = CanvasSelectionPriority.preferredEntitySelectionTarget(
      controlPointTarget: controlPoint,
      entityTarget: entityTarget
    )

    #expect(resolved == controlPoint)
  }

  @Test
  func distance_tool_prefers_point_over_line_and_entity_targets() {
    let lineTarget = CanvasSelectionTarget(
      entityID: "entity:line-a",
      entityLabel: "Line A",
      entityKind: .lineSegment,
      controlPoint: nil,
      point: nil
    )
    let pointTarget = CanvasSelectionTarget(
      entityID: "entity:point-a",
      entityLabel: "Point A",
      entityKind: .point,
      controlPoint: .center,
      point: .zero
    )
    let entityTarget = CanvasSelectionTarget(
      entityID: "entity:circle-a",
      entityLabel: "Circle A",
      entityKind: .circle,
      controlPoint: nil,
      point: nil
    )

    let resolved = CanvasSelectionPriority.preferredConstraintTarget(
      for: .distance,
      lineTarget: lineTarget,
      pointTarget: pointTarget,
      entityTarget: entityTarget
    )

    #expect(resolved == pointTarget)
  }

  @Test
  func measurement_distance_tool_prefers_point_over_line_target() {
    let lineTarget = CanvasSelectionTarget(
      entityID: "entity:line-a",
      entityLabel: "Line A",
      entityKind: .lineSegment,
      controlPoint: nil,
      point: nil
    )
    let pointTarget = CanvasSelectionTarget(
      entityID: "entity:line-a",
      entityLabel: "Line A",
      entityKind: .lineSegment,
      controlPoint: .start,
      point: .zero
    )

    let resolved = CanvasSelectionPriority.preferredConstraintTarget(
      for: .measureDistance,
      lineTarget: lineTarget,
      pointTarget: pointTarget,
      entityTarget: nil
    )

    #expect(resolved == pointTarget)
  }

  @Test
  func point_on_line_tool_prefers_control_point_over_line_body() {
    let lineTarget = CanvasSelectionTarget(
      entityID: "entity:fold-line",
      entityLabel: "Fold Line",
      entityKind: .lineSegment,
      controlPoint: nil,
      point: nil
    )
    let pointTarget = CanvasSelectionTarget(
      entityID: "entity:fold-line",
      entityLabel: "Fold Line",
      entityKind: .lineSegment,
      controlPoint: .start,
      point: .zero
    )

    let resolved = CanvasSelectionPriority.preferredConstraintTarget(
      for: .pointOnLine,
      lineTarget: lineTarget,
      pointTarget: pointTarget,
      entityTarget: nil
    )

    #expect(resolved == pointTarget)
  }

  @Test
  func point_on_line_tool_prefers_line_after_pending_point() {
    let pendingPoint = CanvasSelectionTarget(
      entityID: "entity:point-a",
      entityLabel: "Point A",
      entityKind: .point,
      controlPoint: nil,
      point: .zero
    )
    let lineTarget = CanvasSelectionTarget(
      entityID: "entity:fold-line",
      entityLabel: "Fold Line",
      entityKind: .lineSegment,
      controlPoint: nil,
      point: nil
    )
    let pointTarget = CanvasSelectionTarget(
      entityID: "entity:fold-line",
      entityLabel: "Fold Line",
      entityKind: .lineSegment,
      controlPoint: .start,
      point: .zero
    )

    let resolved = CanvasSelectionPriority.preferredConstraintTarget(
      for: .pointOnLine,
      lineTarget: lineTarget,
      pointTarget: pointTarget,
      entityTarget: nil,
      pendingTargets: [pendingPoint]
    )

    #expect(resolved == lineTarget)
  }

  @Test
  func symmetric_tool_prefers_line_after_two_pending_points() {
    let pendingFirstPoint = CanvasSelectionTarget(
      entityID: "entity:point-a",
      entityLabel: "Point A",
      entityKind: .point,
      controlPoint: nil,
      point: .zero
    )
    let pendingSecondPoint = CanvasSelectionTarget(
      entityID: "entity:point-b",
      entityLabel: "Point B",
      entityKind: .point,
      controlPoint: nil,
      point: ModelPoint(xMM: 4.0, yMM: 0.0)
    )
    let lineTarget = CanvasSelectionTarget(
      entityID: "entity:axis",
      entityLabel: "Axis",
      entityKind: .lineSegment,
      controlPoint: nil,
      point: nil
    )

    let resolved = CanvasSelectionPriority.preferredConstraintTarget(
      for: .symmetric,
      lineTarget: lineTarget,
      pointTarget: nil,
      entityTarget: nil,
      pendingTargets: [pendingFirstPoint, pendingSecondPoint]
    )

    #expect(resolved == lineTarget)
  }

  @Test
  func offset_tool_prefers_line_over_point_and_entity_targets() {
    let lineTarget = CanvasSelectionTarget(
      entityID: "entity:line-a",
      entityLabel: "Line A",
      entityKind: .lineSegment,
      controlPoint: nil,
      point: nil
    )
    let pointTarget = CanvasSelectionTarget(
      entityID: "entity:point-a",
      entityLabel: "Point A",
      entityKind: .point,
      controlPoint: .center,
      point: .zero
    )
    let entityTarget = CanvasSelectionTarget(
      entityID: "entity:circle-a",
      entityLabel: "Circle A",
      entityKind: .circle,
      controlPoint: nil,
      point: nil
    )

    let resolved = CanvasSelectionPriority.preferredConstraintTarget(
      for: .offset,
      lineTarget: lineTarget,
      pointTarget: pointTarget,
      entityTarget: entityTarget
    )

    #expect(resolved == lineTarget)
  }

  @Test
  func radius_tool_prefers_point_target_over_entity_target() {
    let pointTarget = CanvasSelectionTarget(
      entityID: "entity:arc-a",
      entityLabel: "Arc A",
      entityKind: .arc,
      controlPoint: .arcStart,
      point: .zero
    )
    let entityTarget = CanvasSelectionTarget(
      entityID: "entity:arc-a",
      entityLabel: "Arc A",
      entityKind: .arc,
      controlPoint: nil,
      point: nil
    )

    let resolved = CanvasSelectionPriority.preferredConstraintTarget(
      for: .radius,
      lineTarget: nil,
      pointTarget: pointTarget,
      entityTarget: entityTarget
    )

    #expect(resolved == pointTarget)
  }
}
