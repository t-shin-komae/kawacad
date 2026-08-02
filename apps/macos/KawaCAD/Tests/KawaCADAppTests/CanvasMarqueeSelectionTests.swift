import CoreGraphics
import Testing

@testable import KawaCADApp

struct CanvasMarqueeSelectionTests {
  private let coordinateSpace = CanvasCoordinateSpace(
    pageRect: CGRect(x: 0, y: 0, width: 520, height: 736)
  )

  @Test
  func contained_selection_requires_the_whole_logical_shape() {
    let selection = CanvasMarqueeSelection(coordinateSpace: coordinateSpace)
    let rect = canvasRect(from: ModelPoint(xMM: -12, yMM: -6), to: ModelPoint(xMM: 12, yMM: 6))
    let entities = [
      lineEntity(
        id: "entity:inside", start: ModelPoint(xMM: -10, yMM: 0), end: ModelPoint(xMM: 10, yMM: 0)),
      centerLineEntity(
        id: "entity:crossing", start: ModelPoint(xMM: -20, yMM: 0), end: ModelPoint(xMM: 20, yMM: 0)
      ),
      CanvasEntity(
        id: "entity:circle",
        label: "Circle",
        kind: .circle,
        layerID: "layer:cut-line",
        geometry: .circle(center: .zero, radiusMM: 8)
      ),
    ]

    #expect(
      selection.candidateIDs(from: entities, in: rect, mode: .contained)
        == ["entity:inside"]
    )
  }

  @Test
  func crossing_selection_uses_shape_intersections_not_bounding_rectangles() {
    let selection = CanvasMarqueeSelection(coordinateSpace: coordinateSpace)
    let rect = canvasRect(from: ModelPoint(xMM: -1, yMM: -1), to: ModelPoint(xMM: 1, yMM: 1))
    let entities = [
      lineEntity(
        id: "entity:crossing-line", start: ModelPoint(xMM: -4, yMM: 0),
        end: ModelPoint(xMM: 4, yMM: 0)),
      centerLineEntity(
        id: "entity:outside-collinear", start: ModelPoint(xMM: 2, yMM: 1),
        end: ModelPoint(xMM: 4, yMM: 1)),
      CanvasEntity(
        id: "entity:outer-circle",
        label: "Outer Circle",
        kind: .circle,
        layerID: "layer:cut-line",
        geometry: .circle(center: .zero, radiusMM: 10)
      ),
      arcEntity(
        id: "entity:outer-arc",
        center: .zero,
        radiusMM: 10,
        startAngleRad: 0,
        sweepAngleRad: .pi
      ),
    ]

    #expect(
      selection.candidateIDs(from: entities, in: rect, mode: .crossing)
        == ["entity:crossing-line"]
    )
  }

  @Test
  func arcs_are_contained_and_crossed_using_their_actual_sweep() {
    let selection = CanvasMarqueeSelection(coordinateSpace: coordinateSpace)
    let arc = arcEntity(
      id: "entity:arc",
      center: .zero,
      radiusMM: 10,
      startAngleRad: 0,
      sweepAngleRad: .pi / 2
    )

    let containedRect = canvasRect(
      from: ModelPoint(xMM: -1, yMM: -1), to: ModelPoint(xMM: 11, yMM: 11))
    let crossingRect = canvasRect(from: ModelPoint(xMM: 6, yMM: 6), to: ModelPoint(xMM: 8, yMM: 8))

    #expect(
      selection.candidateIDs(from: [arc], in: containedRect, mode: .contained) == ["entity:arc"])
    #expect(
      selection.candidateIDs(from: [arc], in: crossingRect, mode: .crossing) == ["entity:arc"])
  }

  @Test
  func circles_and_center_lines_use_the_same_contained_and_crossing_rules() {
    let selection = CanvasMarqueeSelection(coordinateSpace: coordinateSpace)
    let circle = CanvasEntity(
      id: "entity:circle",
      label: "Circle",
      kind: .circle,
      layerID: "layer:cut-line",
      geometry: .circle(center: .zero, radiusMM: 10)
    )
    let centerLine = centerLineEntity(
      id: "entity:centerline",
      start: ModelPoint(xMM: -15, yMM: 0),
      end: ModelPoint(xMM: 15, yMM: 0)
    )
    let containedRect = canvasRect(
      from: ModelPoint(xMM: -11, yMM: -11), to: ModelPoint(xMM: 11, yMM: 11))
    let crossingRect = canvasRect(
      from: ModelPoint(xMM: 9, yMM: -2), to: ModelPoint(xMM: 11, yMM: 2))

    #expect(
      selection.candidateIDs(from: [circle, centerLine], in: containedRect, mode: .contained) == [
        "entity:circle"
      ])
    #expect(
      selection.candidateIDs(from: [circle, centerLine], in: crossingRect, mode: .crossing) == [
        "entity:circle", "entity:centerline",
      ])
  }

  @Test
  func contained_selection_keeps_only_the_three_keyholder_top_elements() {
    let selection = CanvasMarqueeSelection(coordinateSpace: coordinateSpace)
    let topElements = [
      lineEntity(
        id: "entity:top-left", start: ModelPoint(xMM: -12, yMM: 20),
        end: ModelPoint(xMM: -4, yMM: 20)),
      lineEntity(
        id: "entity:top-center", start: ModelPoint(xMM: -4, yMM: 20),
        end: ModelPoint(xMM: 4, yMM: 20)),
      lineEntity(
        id: "entity:top-right", start: ModelPoint(xMM: 4, yMM: 20),
        end: ModelPoint(xMM: 12, yMM: 20)),
    ]
    let crossingSurroundings = [
      centerLineEntity(
        id: "entity:left-side", start: ModelPoint(xMM: -16, yMM: 20),
        end: ModelPoint(xMM: -8, yMM: 8)),
      lineEntity(
        id: "entity:right-side", start: ModelPoint(xMM: 8, yMM: 8),
        end: ModelPoint(xMM: 16, yMM: 20)),
    ]
    let rect = canvasRect(from: ModelPoint(xMM: -13, yMM: 18), to: ModelPoint(xMM: 13, yMM: 22))

    #expect(
      selection.candidateIDs(
        from: topElements + crossingSurroundings,
        in: rect,
        mode: .contained
      ) == ["entity:top-left", "entity:top-center", "entity:top-right"]
    )
  }

  private func canvasRect(from first: ModelPoint, to second: ModelPoint) -> CGRect {
    CanvasInteractionState.normalizedRect(
      from: coordinateSpace.canvasPoint(for: first),
      to: coordinateSpace.canvasPoint(for: second)
    )
  }
}
