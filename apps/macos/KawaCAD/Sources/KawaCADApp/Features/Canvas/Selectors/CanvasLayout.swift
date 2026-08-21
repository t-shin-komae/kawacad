import AppKit
import KawaCADOutput

/// Pure geometry shared by Canvas drawing and hit testing.
struct CanvasLayout {
  static let constraintMarkerSize: CGFloat = 22.0
  static let constraintMarkerInset: CGFloat = 2.0
  static let labelHorizontalPadding: CGFloat = 5.0
  static let labelVerticalPadding: CGFloat = 2.5

  static func pageRect(
    in canvasBounds: CGRect,
    zoomScale: Double,
    panOffset: CGSize,
    orientation: OutputPrintOrientation
  ) -> CGRect {
    let boundedZoomScale = min(
      max(zoomScale, CanvasMetrics.zoomMinimum), CanvasMetrics.zoomMaximum)
    let basePageSize = CanvasCoordinateSpace.referencePageSize(for: orientation)
    let pageSize = CGSize(
      width: basePageSize.width * boundedZoomScale,
      height: basePageSize.height * boundedZoomScale
    )
    return CGRect(
      x: canvasBounds.midX - pageSize.width / 2 + panOffset.width,
      y: canvasBounds.midY - pageSize.height / 2 + panOffset.height,
      width: pageSize.width,
      height: pageSize.height
    )
  }

  static func constraintMarkerRect(
    position: ModelPoint,
    stackIndex: Int,
    in coordinateSpace: CanvasCoordinateSpace
  ) -> CGRect {
    let anchor = coordinateSpace.canvasPoint(for: position)
    let offset = constraintMarkerOffset(for: stackIndex)
    return CGRect(
      x: anchor.x + offset.width,
      y: anchor.y + offset.height,
      width: constraintMarkerSize,
      height: constraintMarkerSize
    )
  }

  static func constraintMarkerOffset(for stackIndex: Int) -> CGSize {
    CGSize(
      width: 10.0 + CGFloat(stackIndex % 4) * 24.0,
      height: -24.0 - CGFloat(stackIndex / 4) * 24.0
    )
  }

  static func measurementLabelRect(label: String, around point: CGPoint) -> CGRect {
    let text = NSAttributedString(
      string: label,
      attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .semibold)]
    )
    let size = text.size()
    return CGRect(
      x: point.x - size.width / 2.0 - labelHorizontalPadding,
      y: point.y - size.height / 2.0 - labelVerticalPadding,
      width: size.width + labelHorizontalPadding * 2.0,
      height: size.height + labelVerticalPadding * 2.0
    )
  }
}
