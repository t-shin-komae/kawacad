import CoreGraphics
import Testing

@testable import KawaCADApp

struct CanvasSelectionResolverTests {
  @Test
  func select_hit_testing_prefers_base_entity_over_overlapping_derived_entity() {
    let resolver = makeResolver(
      selectedTool: .select,
      entities: [
        lineEntity(
          id: "entity:line-a",
          label: "Source Line",
          start: .zero,
          end: ModelPoint(xMM: 20, yMM: 0)
        ).withFilletSuppressedStyle(),
        lineEntity(
          id: "derived:fillet-a:resolved:0",
          label: "Derived Line",
          start: .zero,
          end: ModelPoint(xMM: 20, yMM: 0)
        ),
      ]
    )

    let target = resolver.entity(at: canvasPoint(ModelPoint(xMM: 5, yMM: 0)))?.entitySelectionTarget

    #expect(target?.entityID == "entity:line-a")
  }

  @Test
  func line_constraint_tools_prefer_base_line_over_overlapping_derived_line() {
    let resolver = makeResolver(
      selectedTool: .segmentLength,
      entities: [
        lineEntity(
          id: "entity:line-a",
          label: "Source Line",
          start: .zero,
          end: ModelPoint(xMM: 20, yMM: 0)
        ).withFilletSuppressedStyle(),
        lineEntity(
          id: "derived:fillet-a:resolved:0",
          label: "Derived Line",
          start: .zero,
          end: ModelPoint(xMM: 20, yMM: 0)
        ),
      ]
    )

    let target = resolver.preferredConstraintTarget(at: canvasPoint(ModelPoint(xMM: 5, yMM: 0)))

    #expect(target?.entityID == "entity:line-a")
  }

  @Test
  func point_on_line_prefers_point_target_over_line_target() {
    let resolver = makeResolver(
      selectedTool: .pointOnLine,
      entities: [
        lineEntity(
          id: "entity:line-a",
          label: "Line A",
          start: .zero,
          end: ModelPoint(xMM: 20, yMM: 0)
        )
      ]
    )

    let target = resolver.preferredConstraintTarget(at: canvasPoint(.zero))

    #expect(target?.entityID == "entity:line-a")
    #expect(target?.controlPoint == .start)
  }

  @Test
  func point_on_line_prefers_line_target_over_endpoint_after_pending_point() {
    let pendingPoint = CanvasSelectionTarget(
      entityID: "entity:point-a",
      entityLabel: "Point A",
      entityKind: .point,
      controlPoint: nil,
      point: ModelPoint(xMM: 4, yMM: 6)
    )
    let resolver = makeResolver(
      selectedTool: .pointOnLine,
      entities: [
        lineEntity(
          id: "entity:line-a",
          label: "Line A",
          start: .zero,
          end: ModelPoint(xMM: 20, yMM: 0)
        )
      ]
    )

    let target = resolver.preferredConstraintTarget(
      at: canvasPoint(.zero),
      pendingTargets: [pendingPoint]
    )

    #expect(target?.entityID == "entity:line-a")
    #expect(target?.controlPoint == nil)
  }

  @Test
  func measure_distance_prefers_endpoint_over_line_body() {
    let resolver = makeResolver(
      selectedTool: .measureDistance,
      entities: [
        lineEntity(
          id: "entity:line-a",
          label: "Line A",
          start: .zero,
          end: ModelPoint(xMM: 20, yMM: 0)
        )
      ]
    )

    let target = resolver.preferredConstraintTarget(at: canvasPoint(.zero))

    #expect(target?.entityID == "entity:line-a")
    #expect(target?.controlPoint == .start)
    #expect(resolver.isValidConstraintTarget(unwrap(target), pendingTargetCount: 0))
  }

  @Test
  func distance_tool_prefers_line_endpoint_control_point_over_line_body() {
    let resolver = makeResolver(
      selectedTool: .distance,
      entities: [
        lineEntity(
          id: "entity:line-a",
          label: "Line A",
          start: .zero,
          end: ModelPoint(xMM: 20, yMM: 0)
        )
      ]
    )

    let target = resolver.preferredConstraintTarget(at: canvasPoint(.zero))

    #expect(target?.entityID == "entity:line-a")
    #expect(target?.controlPoint == .start)
    #expect(resolver.isValidConstraintTarget(unwrap(target), pendingTargetCount: 0))
  }

  @Test
  func distance_tool_accepts_center_line_endpoint_control_points() {
    let resolver = makeResolver(
      selectedTool: .distance,
      entities: [
        centerLineEntity(
          id: "entity:center-line-a",
          label: "Center Line A",
          start: .zero,
          end: ModelPoint(xMM: 20, yMM: 0)
        )
      ]
    )

    let target = resolver.preferredConstraintTarget(at: canvasPoint(.zero))

    #expect(target?.entityID == "entity:center-line-a")
    #expect(target?.controlPoint == .start)
    #expect(resolver.isValidConstraintTarget(unwrap(target), pendingTargetCount: 0))
  }

  @Test
  func distance_tool_accepts_arc_endpoint_control_points() {
    let resolver = makeResolver(
      selectedTool: .distance,
      entities: [
        arcEntity(
          id: "entity:arc-a",
          label: "Arc A",
          center: .zero,
          radiusMM: 10,
          startAngleRad: 0,
          sweepAngleRad: .pi / 2
        )
      ]
    )

    let target = resolver.preferredConstraintTarget(at: canvasPoint(ModelPoint(xMM: 10, yMM: 0)))

    #expect(target?.entityID == "entity:arc-a")
    #expect(target?.controlPoint == .arcStart)
    #expect(resolver.isValidConstraintTarget(unwrap(target), pendingTargetCount: 0))
  }

  @Test
  func tangent_tool_accepts_line_endpoint_control_points() {
    let resolver = makeResolver(
      selectedTool: .tangent,
      entities: [
        lineEntity(
          id: "entity:line-a",
          label: "Line A",
          start: .zero,
          end: ModelPoint(xMM: 20, yMM: 0)
        )
      ]
    )

    let target = resolver.preferredConstraintTarget(at: canvasPoint(.zero))

    #expect(target?.entityID == "entity:line-a")
    #expect(target?.controlPoint == .start)
    #expect(resolver.isValidConstraintTarget(unwrap(target), pendingTargetCount: 0))
  }

  @Test
  func tangent_tool_accepts_arc_endpoint_control_points() {
    let resolver = makeResolver(
      selectedTool: .tangent,
      entities: [
        arcEntity(
          id: "entity:arc-a",
          label: "Arc A",
          center: .zero,
          radiusMM: 10,
          startAngleRad: 0,
          sweepAngleRad: .pi / 2
        )
      ]
    )

    let target = resolver.preferredConstraintTarget(at: canvasPoint(ModelPoint(xMM: 10, yMM: 0)))

    #expect(target?.entityID == "entity:arc-a")
    #expect(target?.controlPoint == .arcStart)
    #expect(resolver.isValidConstraintTarget(unwrap(target), pendingTargetCount: 0))
  }

  @Test
  func tangent_tool_prefers_arc_endpoint_after_pending_line_endpoint_at_same_point() {
    let lineEnd = CanvasSelectionTarget(
      entityID: "entity:line-a",
      entityLabel: "Line A",
      entityKind: .lineSegment,
      controlPoint: .end,
      point: .zero
    )
    let resolver = makeResolver(
      selectedTool: .tangent,
      entities: [
        arcEntity(
          id: "entity:arc-a",
          label: "Arc A",
          center: ModelPoint(xMM: 10, yMM: 0),
          radiusMM: 10,
          startAngleRad: .pi,
          sweepAngleRad: .pi / 2
        ),
        lineEntity(
          id: "entity:line-a",
          label: "Line A",
          start: ModelPoint(xMM: -10, yMM: 0),
          end: .zero
        ),
      ]
    )

    let target = resolver.preferredConstraintTarget(
      at: canvasPoint(.zero),
      pendingTargets: [lineEnd]
    )

    #expect(target?.entityID == "entity:arc-a")
    #expect(target?.controlPoint == .arcStart)
  }

  @Test
  func distance_tool_keeps_line_body_selectable_for_point_line_distance() {
    let resolver = makeResolver(
      selectedTool: .distance,
      entities: [
        lineEntity(
          id: "entity:line-a",
          label: "Line A",
          start: .zero,
          end: ModelPoint(xMM: 20, yMM: 0)
        )
      ]
    )

    let target = resolver.preferredConstraintTarget(at: canvasPoint(ModelPoint(xMM: 10, yMM: 0)))

    #expect(target?.entityID == "entity:line-a")
    #expect(target?.controlPoint == nil)
    #expect(target?.isLineTarget == true)
    #expect(resolver.isValidConstraintTarget(unwrap(target), pendingTargetCount: 0))
  }

  @Test
  func point_target_keeps_exact_geometry_when_click_is_within_hit_tolerance() {
    let exactPoint = ModelPoint(xMM: 4, yMM: 6)
    let resolver = makeResolver(
      selectedTool: .distance,
      entities: [
        pointEntity(
          id: "entity:point-a",
          label: "Point A",
          point: exactPoint
        )
      ]
    )

    let target = resolver.preferredConstraintTarget(
      at: canvasPoint(ModelPoint(xMM: 5, yMM: 7))
    )

    #expect(target?.entityID == "entity:point-a")
    #expect(target?.point == exactPoint)
  }

  @Test
  func circle_center_target_keeps_exact_geometry_when_click_is_within_hit_tolerance() {
    let exactCenter = ModelPoint(xMM: 4, yMM: 6)
    let circle = CanvasEntity(
      id: "entity:circle-a",
      label: "Circle A",
      kind: .circle,
      layerID: "layer:cut-line",
      geometry: .circle(center: exactCenter, radiusMM: 4)
    )
    let resolver = makeResolver(
      selectedTool: .distance,
      entities: [circle]
    )

    let target = resolver.preferredConstraintTarget(
      at: canvasPoint(ModelPoint(xMM: 5, yMM: 7))
    )

    #expect(target?.entityID == circle.id)
    #expect(target?.controlPoint == .center)
    #expect(target?.point == exactCenter)
  }

  @Test
  func measure_angle_does_not_pick_arc_entity() {
    let resolver = makeResolver(
      selectedTool: .measureAngle,
      entities: [
        arcEntity(
          id: "entity:arc-a",
          label: "Arc A",
          center: .zero,
          radiusMM: 10,
          startAngleRad: 0,
          sweepAngleRad: .pi / 2
        )
      ]
    )

    let target = resolver.preferredConstraintTarget(at: canvasPoint(ModelPoint(xMM: 10, yMM: 0)))

    #expect(target == nil)
  }

  @Test
  func measure_arc_sweep_angle_picks_arc_entity() {
    let resolver = makeResolver(
      selectedTool: .measureArcSweepAngle,
      entities: [
        arcEntity(
          id: "entity:arc-a",
          label: "Arc A",
          center: .zero,
          radiusMM: 10,
          startAngleRad: 0,
          sweepAngleRad: .pi / 2
        )
      ]
    )

    let target = resolver.preferredConstraintTarget(at: canvasPoint(ModelPoint(xMM: 10, yMM: 0)))

    #expect(target?.entityID == "entity:arc-a")
    #expect(target?.controlPoint == nil)
    #expect(resolver.isValidConstraintTarget(unwrap(target), pendingTargetCount: 0))
  }

  @Test
  func offset_prefers_fillet_resolved_entity_target_over_nearby_source_lines() {
    let resolver = makeResolver(
      selectedTool: .offset,
      entities: [
        lineEntity(
          id: "entity:bottom",
          label: "Bottom",
          start: .zero,
          end: ModelPoint(xMM: 20, yMM: 0)
        ).withFilletSuppressedStyle(),
        lineEntity(
          id: "entity:right",
          label: "Right",
          start: ModelPoint(xMM: 20, yMM: 0),
          end: ModelPoint(xMM: 20, yMM: 10)
        ).withFilletSuppressedStyle(),
        arcEntity(
          id: "derived:fillet-a:resolved:1",
          label: "Fillet Arc",
          center: ModelPoint(xMM: 18, yMM: 2),
          radiusMM: 2,
          startAngleRad: -.pi / 2,
          sweepAngleRad: .pi / 2
        ),
      ],
      derivedElements: [
        ProjectDerivedElement(
          id: "derived:fillet-a",
          layerID: "layer:cut-line",
          kind: .fillet,
          sourceEntityIDs: ["entity:bottom", "entity:right", "entity:top", "entity:left"],
          distanceMM: nil,
          distanceParameterID: nil,
          radiusMM: 2.0,
          radiusParameterID: nil,
          filletClosed: true
        )
      ]
    )

    let target = resolver.preferredConstraintTarget(at: canvasPoint(ModelPoint(xMM: 19, yMM: 1)))

    #expect(target?.entityID == "derived:fillet-a:resolved:1")
  }

  @Test
  func validity_rejects_line_for_coincident_tool() {
    let resolver = makeResolver(
      selectedTool: .coincident,
      entities: [
        lineEntity(
          id: "entity:line-a",
          label: "Line A",
          start: .zero,
          end: ModelPoint(xMM: 20, yMM: 0)
        )
      ]
    )
    let target = resolver.entity(at: canvasPoint(ModelPoint(xMM: 5, yMM: 0)))?.entitySelectionTarget

    #expect(target != nil)
    #expect(resolver.isValidConstraintTarget(unwrap(target), pendingTargetCount: 0) == false)
  }

  @Test
  func entity_hit_uses_named_candidate_padding_once() {
    let resolver = makeResolver(
      selectedTool: .select,
      entities: [
        lineEntity(
          id: "entity:line-boundary",
          label: "Boundary",
          start: .zero,
          end: ModelPoint(xMM: 20, yMM: 0)
        )
      ]
    )
    let center = canvasPoint(ModelPoint(xMM: 10, yMM: 0))
    let inside = CGPoint(
      x: center.x,
      y: center.y + CanvasMetrics.entityCandidatePaddingPx - 0.01
    )
    let outside = CGPoint(
      x: center.x,
      y: center.y + CanvasMetrics.entityCandidatePaddingPx + 0.01
    )

    #expect(resolver.entity(at: inside)?.id == "entity:line-boundary")
    #expect(resolver.entity(at: outside) == nil)
  }

  @Test
  func cursor_entity_hit_uses_a_larger_hover_padding_without_changing_selection() {
    let resolver = makeResolver(
      selectedTool: .select,
      entities: [
        lineEntity(
          id: "entity:cursor-hover",
          label: "Cursor hover",
          start: .zero,
          end: ModelPoint(xMM: 20, yMM: 0)
        )
      ]
    )
    let center = canvasPoint(ModelPoint(xMM: 10, yMM: 0))
    let point = CGPoint(
      x: center.x,
      y: center.y + CanvasMetrics.entityCandidatePaddingPx + 1
    )

    #expect(resolver.entity(at: point) == nil)
    #expect(
      resolver.entity(
        at: point,
        preferring: [],
        candidatePadding: CanvasMetrics.cursorEntityCandidatePaddingPx
      )?.id == "entity:cursor-hover"
    )
  }

  private func makeResolver(
    selectedTool: CanvasTool,
    entities: [CanvasEntity],
    derivedElements: [ProjectDerivedElement] = []
  ) -> CanvasHitTesting {
    CanvasHitTesting(
      displayEntities: entities,
      derivedElements: derivedElements,
      selectedTool: selectedTool,
      coordinateSpace: CanvasCoordinateSpace(pageRect: pageRect)
    )
  }

  private var pageRect: CGRect {
    CGRect(x: 0, y: 0, width: 520, height: 736)
  }

  private func canvasPoint(_ point: ModelPoint) -> CGPoint {
    CanvasCoordinateSpace(pageRect: pageRect).canvasPoint(for: point)
  }
}
