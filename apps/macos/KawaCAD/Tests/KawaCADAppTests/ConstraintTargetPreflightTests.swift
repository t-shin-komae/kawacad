import Testing

@testable import KawaCADApp

struct ConstraintTargetPreflightTests {
  @Test
  func point_target_leaves_circle_entity_target_unresolved_for_core_normalization() {
    let circle = CanvasEntity(
      id: "entity:circle-a",
      label: "Circle A",
      kind: .circle,
      layerID: "layer:cut-line",
      geometry: .circle(center: ModelPoint(xMM: 4, yMM: 5), radiusMM: 3)
    )

    let target = ConstraintTargetPreflight.pointTarget(
      from: circle.entitySelectionTarget,
      fallbackEntity: circle
    )

    // UI は選択意図（円そのもの）だけを送る。中心点への意味上の解決は Core の
    // preflight response が担うため、ここで controlPoint / point を補完してはならない。
    #expect(target == circle.entitySelectionTarget)
    #expect(target?.entityID == "entity:circle-a")
    #expect(target?.controlPoint == nil)
    #expect(target?.point == nil)
  }

  @Test
  func point_or_line_target_preserves_line_targets() {
    let line = lineEntity(
      id: "entity:line-a",
      start: .zero,
      end: ModelPoint(xMM: 10, yMM: 0)
    )

    let target = ConstraintTargetPreflight.pointOrLineTarget(
      from: line.entitySelectionTarget,
      fallbackEntity: line
    )

    #expect(target == line.entitySelectionTarget)
  }

  @Test
  func offset_supports_lines_circles_arcs_and_center_lines() {
    let line = lineEntity(id: "entity:line-a", start: .zero, end: ModelPoint(xMM: 10, yMM: 0))
    let circle = CanvasEntity(
      id: "entity:circle-a",
      label: "Circle A",
      kind: .circle,
      layerID: "layer:cut-line",
      geometry: .circle(center: .zero, radiusMM: 3)
    )

    #expect(ConstraintTargetPreflight.supportsOffsetTarget(line.entitySelectionTarget))
    #expect(ConstraintTargetPreflight.supportsOffsetTarget(circle.entitySelectionTarget))
  }

  @Test
  func offset_and_fillet_allow_derived_targets() {
    let entity = lineEntity(
      id: "derived:offset-a:resolved:0",
      start: .zero,
      end: ModelPoint(xMM: 10, yMM: 0)
    )

    #expect(
      ConstraintTargetPreflight.allowsDerivedTarget(
        tool: .offset,
        entity: entity,
        selectedDerivedElement: nil
      )
    )
    #expect(
      ConstraintTargetPreflight.allowsDerivedTarget(
        tool: .fillet,
        entity: entity,
        selectedDerivedElement: nil
      )
    )
  }

  @Test
  func radius_allows_fillet_arc_edit_only_when_selected_entity_is_fillet_arc() {
    let fillet = ProjectDerivedElement(
      id: "derived:fillet-a",
      layerID: "layer:cut-line",
      kind: .fillet,
      sourceEntityIDs: ["entity:a", "entity:b"],
      distanceMM: nil,
      distanceParameterID: nil,
      radiusMM: 2.0,
      radiusParameterID: nil
    )
    let arc = arcEntity(
      id: "derived:fillet-a:resolved:1",
      center: .zero,
      radiusMM: 2.0,
      startAngleRad: 0,
      sweepAngleRad: .pi / 2
    )
    let line = lineEntity(
      id: "derived:fillet-a:resolved:0",
      start: .zero,
      end: ModelPoint(xMM: 10, yMM: 0)
    )

    #expect(
      ConstraintTargetPreflight.shouldEditSelectedFilletRadius(
        tool: .radius,
        entity: arc,
        selectedDerivedElement: fillet
      )
    )
    #expect(
      ConstraintTargetPreflight.allowsDerivedTarget(
        tool: .radius,
        entity: arc,
        selectedDerivedElement: fillet
      )
    )
    #expect(
      ConstraintTargetPreflight.allowsDerivedTarget(
        tool: .radius,
        entity: line,
        selectedDerivedElement: fillet
      ) == false
    )
  }

  @Test
  func ordinary_constraint_tools_do_not_allow_derived_targets() {
    let entity = lineEntity(
      id: "derived:fillet-a:resolved:0",
      start: .zero,
      end: ModelPoint(xMM: 10, yMM: 0)
    )

    #expect(
      ConstraintTargetPreflight.allowsDerivedTarget(
        tool: .segmentLength,
        entity: entity,
        selectedDerivedElement: nil
      ) == false
    )
  }
}
