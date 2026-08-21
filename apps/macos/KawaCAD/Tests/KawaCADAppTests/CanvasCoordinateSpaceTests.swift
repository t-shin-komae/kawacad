import AppKit
import CoreGraphics
import KawaCADOutput
import Testing

@testable import KawaCADApp

struct CanvasCoordinateSpaceTests {
  @Test
  func center_origin_maps_to_page_center() {
    let space = CanvasCoordinateSpace(pageRect: CGRect(x: 40, y: 60, width: 520, height: 736))

    #expect(space.canvasPoint(for: .zero) == CGPoint(x: 300, y: 428))
  }

  @Test
  func positive_y_maps_upward_on_canvas() {
    let space = CanvasCoordinateSpace(pageRect: CGRect(x: 40, y: 60, width: 520, height: 736))

    let center = space.canvasPoint(for: .zero)
    let above = space.canvasPoint(for: ModelPoint(xMM: 0, yMM: 25))

    #expect(above.y < center.y)
  }

  @Test
  func round_trips_model_coordinates_using_centered_axes() {
    let space = CanvasCoordinateSpace(pageRect: CGRect(x: 0, y: 0, width: 520, height: 736))
    let original = ModelPoint(xMM: -42.5, yMM: 63.25)

    let canvasPoint = space.canvasPoint(for: original)
    let decoded = space.modelPoint(for: canvasPoint)

    #expect(abs(decoded.xMM - original.xMM) < 0.0001)
    #expect(abs(decoded.yMM - original.yMM) < 0.0001)
  }

  @Test
  func round_trips_model_coordinates_when_page_is_panned() {
    let space = CanvasCoordinateSpace(pageRect: CGRect(x: 36, y: -28, width: 650, height: 920))
    let original = ModelPoint(xMM: 32.25, yMM: -47.5)

    let canvasPoint = space.canvasPoint(for: original)
    let decoded = space.modelPoint(for: canvasPoint)

    #expect(abs(decoded.xMM - original.xMM) < 0.0001)
    #expect(abs(decoded.yMM - original.yMM) < 0.0001)
  }

  @Test
  func round_trips_model_coordinates_outside_origin_a4_page() {
    let space = CanvasCoordinateSpace(pageRect: CGRect(x: 0, y: 0, width: 520, height: 736))
    let original = ModelPoint(xMM: 320.0, yMM: -410.0)

    let canvasPoint = space.canvasPoint(for: original)
    let decoded = space.modelPoint(for: canvasPoint)

    #expect(abs(decoded.xMM - original.xMM) < 0.0001)
    #expect(abs(decoded.yMM - original.yMM) < 0.0001)
  }

  @Test
  func model_point_is_clamped_to_centered_a4_grid_bounds() {
    let space = CanvasCoordinateSpace(pageRect: CGRect(x: 0, y: 0, width: 520, height: 736))

    let decoded = space.modelPoint(for: CGPoint(x: -5_000, y: 5_000))

    #expect(decoded.xMM == -525.0)
    #expect(decoded.yMM == -742.5)
  }

  @Test
  func canvas_bounds_rect_spans_centered_a4_grid() {
    let space = CanvasCoordinateSpace(pageRect: CGRect(x: 0, y: 0, width: 520, height: 736))

    #expect(abs(space.canvasBoundsRect.width - space.pageWidthMM * 5.0 * space.scale) < 0.0001)
    #expect(abs(space.canvasBoundsRect.height - space.pageHeightMM * 5.0 * space.scale) < 0.0001)
    #expect(abs(space.canvasBoundsRect.midX - space.originCanvasPoint.x) < 0.0001)
    #expect(abs(space.canvasBoundsRect.midY - space.originCanvasPoint.y) < 0.0001)
  }

  @Test
  func landscape_orientation_uses_landscape_a4_grid_bounds() {
    let space = CanvasCoordinateSpace(
      pageRect: CGRect(x: 0, y: 0, width: 736, height: 520),
      orientation: .landscape
    )

    let decoded = space.modelPoint(for: CGPoint(x: 5_000, y: -5_000))

    #expect(space.pageWidthMM == 297.0)
    #expect(space.pageHeightMM == 210.0)
    #expect(decoded.xMM == 742.5)
    #expect(decoded.yMM == 525.0)
    #expect(abs(space.canvasBoundsRect.width - 297.0 * 5.0 * space.scale) < 0.0001)
    #expect(abs(space.canvasBoundsRect.height - 210.0 * 5.0 * space.scale) < 0.0001)
  }

  @Test
  @MainActor
  func portrait_and_landscape_reference_frames_keep_same_model_distance_scale() {
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: CGRect(x: 0, y: 0, width: 1_000, height: 1_000))
    inputs.a4ReferenceOrientation = .portrait
    let portraitRect = view.pageRect(in: view.bounds, zoomScale: 1.0, panOffset: .zero)
    inputs.a4ReferenceOrientation = .landscape
    let landscapeRect = view.pageRect(in: view.bounds, zoomScale: 1.0, panOffset: .zero)

    let baseScale = CanvasCoordinateSpace.displayPointsPerMillimeter
    #expect(abs(portraitRect.width - 210.0 * baseScale) < 0.0001)
    #expect(abs(portraitRect.height - 297.0 * baseScale) < 0.0001)
    #expect(abs(landscapeRect.width - 297.0 * baseScale) < 0.0001)
    #expect(abs(landscapeRect.height - 210.0 * baseScale) < 0.0001)

    let portrait = CanvasCoordinateSpace(pageRect: portraitRect)
    let landscape = CanvasCoordinateSpace(pageRect: landscapeRect, orientation: .landscape)

    #expect(abs(portrait.scale - baseScale) < 0.0001)
    #expect(abs(portrait.scale - landscape.scale) < 0.0001)

    inputs.a4ReferenceOrientation = .portrait
    let enlargedRect = view.pageRect(in: view.bounds, zoomScale: 2.5, panOffset: .zero)
    let enlarged = CanvasCoordinateSpace(pageRect: enlargedRect)
    #expect(abs(enlarged.scale - baseScale * 2.5) < 0.0001)

    let point = ModelPoint(xMM: 120.0, yMM: -80.0)
    let portraitPoint = portrait.canvasPoint(for: point)
    let landscapePoint = landscape.canvasPoint(for: point)
    let portraitOffset = CGSize(
      width: portraitPoint.x - portrait.originCanvasPoint.x,
      height: portraitPoint.y - portrait.originCanvasPoint.y
    )
    let landscapeOffset = CGSize(
      width: landscapePoint.x - landscape.originCanvasPoint.x,
      height: landscapePoint.y - landscape.originCanvasPoint.y
    )

    #expect(abs(portraitOffset.width - landscapeOffset.width) < 0.0001)
    #expect(abs(portraitOffset.height - landscapeOffset.height) < 0.0001)
  }

  @Test
  func arc_path_parameters_keep_drawn_arc_endpoint_aligned_with_model_endpoint() {
    let space = CanvasCoordinateSpace(pageRect: CGRect(x: 0, y: 0, width: 520, height: 736))
    let center = ModelPoint(xMM: 0, yMM: 0)
    let radiusMM = 20.0
    let startAngleRad = 0.0
    let sweepAngleRad = Double.pi / 2.0
    let parameters = canvasArcPathParameters(
      startAngleRad: startAngleRad, sweepAngleRad: sweepAngleRad)

    let centerPoint = space.canvasPoint(for: center)
    let endPoint = space.canvasPoint(for: ModelPoint(xMM: 0, yMM: 20))
    let path = NSBezierPath()
    path.appendArc(
      withCenter: centerPoint,
      radius: radiusMM * space.scale,
      startAngle: CGFloat(parameters.startAngleDeg),
      endAngle: CGFloat(parameters.endAngleDeg),
      clockwise: parameters.clockwise
    )

    #expect(abs(path.currentPoint.x - endPoint.x) < 0.001)
    #expect(abs(path.currentPoint.y - endPoint.y) < 0.001)
  }
}
