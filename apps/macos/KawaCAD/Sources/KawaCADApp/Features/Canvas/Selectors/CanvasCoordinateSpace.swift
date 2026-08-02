import CoreGraphics
import KawaCADOutput

struct CanvasCoordinateSpace {
  static let a4GridPageLimit = 5
  static let displayPointsPerMillimeter: CGFloat = 72.0 / 25.4

  static func referencePageSize(for orientation: OutputPrintOrientation) -> CGSize {
    let pageSizeMM = OutputPaperDefaults.a4PageSizeMm(for: orientation)
    return CGSize(
      width: pageSizeMM.widthMm * displayPointsPerMillimeter,
      height: pageSizeMM.heightMm * displayPointsPerMillimeter
    )
  }

  let pageRect: CGRect
  let orientation: OutputPrintOrientation

  init(pageRect: CGRect, orientation: OutputPrintOrientation = .portrait) {
    self.pageRect = pageRect
    self.orientation = orientation
  }

  var pageWidthMM: Double {
    OutputPaperDefaults.a4PageSizeMm(for: orientation).widthMm
  }

  var pageHeightMM: Double {
    OutputPaperDefaults.a4PageSizeMm(for: orientation).heightMm
  }

  var scale: CGFloat {
    min(pageRect.width / pageWidthMM, pageRect.height / pageHeightMM)
  }

  var minModelX: Double { -pageWidthMM * Double(Self.a4GridPageLimit) / 2.0 }
  var maxModelX: Double { pageWidthMM * Double(Self.a4GridPageLimit) / 2.0 }
  var minModelY: Double { -pageHeightMM * Double(Self.a4GridPageLimit) / 2.0 }
  var maxModelY: Double { pageHeightMM * Double(Self.a4GridPageLimit) / 2.0 }

  var originCanvasPoint: CGPoint {
    CGPoint(x: pageRect.midX, y: pageRect.midY)
  }

  var canvasBoundsRect: CGRect {
    let topLeft = canvasPoint(for: ModelPoint(xMM: minModelX, yMM: maxModelY))
    let bottomRight = canvasPoint(for: ModelPoint(xMM: maxModelX, yMM: minModelY))
    return CGRect(
      x: topLeft.x,
      y: topLeft.y,
      width: bottomRight.x - topLeft.x,
      height: bottomRight.y - topLeft.y
    )
  }

  func canvasPoint(for point: ModelPoint) -> CGPoint {
    let origin = originCanvasPoint
    return CGPoint(
      x: origin.x + point.xMM * scale,
      y: origin.y - point.yMM * scale
    )
  }

  func modelPoint(for point: CGPoint) -> ModelPoint {
    let origin = originCanvasPoint
    let xMM = ((point.x - origin.x) / scale).clamped(to: minModelX...maxModelX)
    let yMM = ((origin.y - point.y) / scale).clamped(to: minModelY...maxModelY)
    return ModelPoint(xMM: xMM, yMM: yMM)
  }
}

extension Double {
  fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
