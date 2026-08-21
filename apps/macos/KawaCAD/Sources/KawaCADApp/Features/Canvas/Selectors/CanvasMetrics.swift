import CoreGraphics

/// Canvas interaction metrics are screen points unless the name says zoom.
enum CanvasMetrics {
  static let entityCandidatePaddingPx: CGFloat = 8
  static let entityLineHitTolerancePx: CGFloat = 8
  static let annotationLineHitTolerancePx: CGFloat = 5
  static let annotationArcHitTolerancePx: CGFloat = 6
  static let annotationLabelHitPaddingPx: CGFloat = 4
  static let constraintMarkerHitTolerancePx: CGFloat = 6
  static let stitchStartPointHitTolerancePx: CGFloat = 8
  static let controlPointHitSizePx: CGFloat = 16
  static let zoomMinimum = 0.5
  static let zoomMaximum = 3.0
}
