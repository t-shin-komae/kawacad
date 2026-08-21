import AppKit
import CoreGraphics
import KawaCADOutput
import Testing

@testable import KawaCADApp

struct CanvasLayoutTests {
  @Test
  func zoom_and_pan_scale_model_coordinates_while_hit_tolerance_stays_in_screen_points() {
    let base = CanvasCoordinateSpace(pageRect: CGRect(x: 0, y: 0, width: 520, height: 736))
    let zoomed = CanvasCoordinateSpace(
      pageRect: CGRect(x: 30, y: -18, width: 1040, height: 1472))
    let modelPoint = ModelPoint(xMM: 20, yMM: 15)
    let baseOffset = base.canvasPoint(for: modelPoint).offsetBy(
      dx: -base.originCanvasPoint.x,
      dy: -base.originCanvasPoint.y
    )
    let zoomedOffset = zoomed.canvasPoint(for: modelPoint).offsetBy(
      dx: -zoomed.originCanvasPoint.x,
      dy: -zoomed.originCanvasPoint.y
    )

    #expect(abs(zoomedOffset.x - baseOffset.x * 2) < 0.0001)
    #expect(abs(zoomedOffset.y - baseOffset.y * 2) < 0.0001)
    let baseRoundTrip = base.modelPoint(for: base.canvasPoint(for: modelPoint))
    let zoomedRoundTrip = zoomed.modelPoint(for: zoomed.canvasPoint(for: modelPoint))
    #expect(abs(baseRoundTrip.xMM - modelPoint.xMM) < 0.0001)
    #expect(abs(baseRoundTrip.yMM - modelPoint.yMM) < 0.0001)
    #expect(abs(zoomedRoundTrip.xMM - modelPoint.xMM) < 0.0001)
    #expect(abs(zoomedRoundTrip.yMM - modelPoint.yMM) < 0.0001)

    let line = lineEntity(
      id: "line:zoom-hit",
      label: "Zoom hit",
      start: .zero,
      end: ModelPoint(xMM: 20, yMM: 0)
    )
    let hitTesting = CanvasHitTesting(
      displayEntities: [line],
      derivedElements: [],
      selectedTool: .select,
      coordinateSpace: zoomed
    )
    let center = zoomed.canvasPoint(for: ModelPoint(xMM: 10, yMM: 0))
    #expect(
      hitTesting.lineTarget(
        at: CGPoint(x: center.x, y: center.y + CanvasMetrics.entityLineHitTolerancePx - 0.01)
      ) != nil
    )
    #expect(
      hitTesting.lineTarget(
        at: CGPoint(x: center.x, y: center.y + CanvasMetrics.entityLineHitTolerancePx + 0.01)
      ) == nil
    )
  }

  @Test
  func constraint_marker_layout_tracks_zoom_and_pan_with_the_coordinate_space() {
    let base = CanvasCoordinateSpace(pageRect: CGRect(x: 0, y: 0, width: 520, height: 736))
    let panned = CanvasCoordinateSpace(pageRect: CGRect(x: 30, y: -18, width: 520, height: 736))
    let baseRect = CanvasLayout.constraintMarkerRect(
      position: ModelPoint(xMM: 20, yMM: 15), stackIndex: 2, in: base)
    let pannedRect = CanvasLayout.constraintMarkerRect(
      position: ModelPoint(xMM: 20, yMM: 15), stackIndex: 2, in: panned)

    #expect(baseRect.size == pannedRect.size)
    #expect(abs(pannedRect.midX - baseRect.midX - 30) < 0.0001)
    #expect(abs(pannedRect.midY - baseRect.midY + 18) < 0.0001)
  }

  @Test
  func measurement_label_layout_grows_for_longer_text_without_moving_its_center() {
    let center = CGPoint(x: 180, y: 96)
    let short = CanvasLayout.measurementLabelRect(label: "10 mm", around: center)
    let long = CanvasLayout.measurementLabelRect(label: "1234.56 mm", around: center)

    #expect(long.width > short.width)
    #expect(abs(short.midX - center.x) < 0.0001)
    #expect(abs(long.midX - center.x) < 0.0001)
  }

  @Test
  func annotation_layout_is_shared_for_line_axis_and_short_angle_geometry() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let orientation: OutputPrintOrientation = .portrait
    let zero = ModelPoint(xMM: 0, yMM: 0)
    let line = CanvasAnnotationLayout.line(
      start: zero,
      end: ModelPoint(xMM: 20, yMM: 0),
      label: "20 mm",
      labelOffsetMM: zero,
      overallOffsetMM: zero,
      in: pageRect,
      orientation: orientation
    )
    let axis = CanvasAnnotationLayout.axis(
      start: zero,
      end: ModelPoint(xMM: 20, yMM: 4),
      axis: .horizontal,
      label: "20 mm",
      labelOffsetMM: zero,
      overallOffsetMM: zero,
      in: pageRect,
      orientation: orientation
    )
    let angle = CanvasAnnotationLayout.angle(
      overlay: AngleConstraintOverlay(
        constraintID: "angle",
        kind: .linePair,
        center: zero,
        start: ModelPoint(xMM: 10, yMM: 0),
        end: ModelPoint(xMM: 0, yMM: 10),
        signedDegrees: 200
      ),
      label: "200°",
      labelOffsetMM: zero,
      overallOffsetMM: zero,
      in: pageRect,
      orientation: orientation
    )

    #expect(line?.labelRect.contains(line?.labelPoint ?? .zero) == true)
    #expect(axis?.labelRect.contains(axis?.labelPoint ?? .zero) == true)
    #expect(angle?.radius ?? 0 < 44)
    #expect(angle?.labelRect.contains(angle?.labelPoint ?? .zero) == true)
    #expect(angle?.sweepAngleRad == degreesToRadians(200))
  }

  @Test
  func angle_layout_hit_region_follows_clockwise_and_counterclockwise_sweep() {
    let pageRect = CGRect(x: 0, y: 0, width: 520, height: 736)
    let zero = ModelPoint(xMM: 0, yMM: 0)
    let common = AngleConstraintOverlay(
      constraintID: "angle",
      kind: .linePair,
      center: zero,
      start: ModelPoint(xMM: 10, yMM: 0),
      end: ModelPoint(xMM: 0, yMM: 10),
      signedDegrees: 1
    )
    let counterclockwise = CanvasAnnotationLayout.angle(
      overlay: AngleConstraintOverlay(
        constraintID: common.constraintID,
        kind: common.kind,
        center: common.center,
        start: common.start,
        end: common.end,
        signedDegrees: 200
      ),
      label: "200°",
      labelOffsetMM: zero,
      overallOffsetMM: zero,
      in: pageRect,
      orientation: .portrait
    )
    let clockwise = CanvasAnnotationLayout.angle(
      overlay: AngleConstraintOverlay(
        constraintID: common.constraintID,
        kind: common.kind,
        center: common.center,
        start: common.start,
        end: common.end,
        signedDegrees: -90
      ),
      label: "-90°",
      labelOffsetMM: zero,
      overallOffsetMM: zero,
      in: pageRect,
      orientation: .portrait
    )

    guard let counterclockwise, let clockwise else {
      Issue.record("Expected angle layouts")
      return
    }
    let counterclockwisePoint = CGPoint(
      x: counterclockwise.centerPoint.x
        + counterclockwise.radius * CGFloat(cos(counterclockwise.startAngleRad + 1.5)),
      y: counterclockwise.centerPoint.y
        - counterclockwise.radius * CGFloat(sin(counterclockwise.startAngleRad + 1.5))
    )
    let clockwisePoint = CGPoint(
      x: clockwise.centerPoint.x
        + clockwise.radius * CGFloat(cos(clockwise.startAngleRad - 1.0)),
      y: clockwise.centerPoint.y
        - clockwise.radius * CGFloat(sin(clockwise.startAngleRad - 1.0))
    )
    let outsideClockwisePoint = CGPoint(
      x: clockwise.centerPoint.x
        + clockwise.radius * CGFloat(cos(clockwise.startAngleRad + 1.0)),
      y: clockwise.centerPoint.y
        - clockwise.radius * CGFloat(sin(clockwise.startAngleRad + 1.0))
    )

    #expect(counterclockwise.contains(counterclockwisePoint, radiusTolerance: 0.1))
    #expect(clockwise.contains(clockwisePoint, radiusTolerance: 0.1))
    #expect(!clockwise.contains(outsideClockwisePoint, radiusTolerance: 0.1))
  }

}
