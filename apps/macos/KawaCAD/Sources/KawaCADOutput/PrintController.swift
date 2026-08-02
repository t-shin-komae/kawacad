import AppKit
import Foundation

public struct LivePrintController: PrintControlling {
  private let runPrintOperation: (PrintView, NSPrintInfo, String) -> Bool
  private let runPrintPanel: (NSPrintInfo) -> NSApplication.ModalResponse

  public init() {
    self.runPrintOperation = Self.runAppKitPrintOperation
    self.runPrintPanel = Self.runAppKitPrintPanel
  }

  init(
    runPrintOperation: @escaping (PrintView, NSPrintInfo, String) -> Bool,
    runPrintPanel: @escaping (NSPrintInfo) -> NSApplication.ModalResponse = Self.runAppKitPrintPanel
  ) {
    self.runPrintOperation = runPrintOperation
    self.runPrintPanel = runPrintPanel
  }

  public func makeOutputBuildOptions(presentation: OutputPresentationOptions) -> OutputResult<
    OutputBuildOptions
  > {
    let printInfo = Self.makePrintInfo(for: presentation.orientation)
    let options = OutputBuildOptions(
      orientation: presentation.orientation,
      includeDimensionLabels: presentation.includeDimensionLabels,
      includeScaleGuide: presentation.includeScaleGuide,
      rotationDeg: presentation.rotationDeg,
      printableAreaMm: Self.printableAreaMM(from: printInfo, orientation: presentation.orientation)
    )
    return .success(options)
  }

  public func captureDirectPrintSession(
    presentation: OutputPresentationOptions
  ) -> OutputResult<OutputDirectPrintCaptureResult> {
    let printInfo = Self.makePrintInfo(for: presentation.orientation)
    let response = runPrintPanel(printInfo)
    guard response == .OK else {
      return .success(.cancelled)
    }
    return .success(.ready(OutputDirectPrintSession(printInfo: printInfo)))
  }

  public func prepareDirectPrintSession(
    presentation: OutputPresentationOptions,
    session: OutputDirectPrintSession
  ) -> OutputResult<OutputPreparedDirectPrintSession> {
    let printInfo = (session.printInfo.copy() as? NSPrintInfo) ?? session.printInfo
    let capturedSession = OutputDirectPrintSession(printInfo: printInfo)

    guard capturedSession.isA4Paper else {
      return .failure(OutputError(OutputStrings.tr("output.direct_print_requires_a4")))
    }
    guard capturedSession.isActualScale else {
      return .failure(OutputError(OutputStrings.tr("output.direct_print_requires_actual_scale")))
    }

    printInfo.orientation = presentation.orientation == .portrait ? .portrait : .landscape
    printInfo.paperSize = Self.paperSizePoints(for: presentation.orientation)
    let preparedSession = OutputDirectPrintSession(printInfo: printInfo)

    return .success(
      OutputPreparedDirectPrintSession(
        session: preparedSession,
        buildOptions: OutputBuildOptions(
          orientation: presentation.orientation,
          includeDimensionLabels: presentation.includeDimensionLabels,
          includeScaleGuide: presentation.includeScaleGuide,
          rotationDeg: presentation.rotationDeg,
          printableAreaMm: preparedSession.printableAreaMm
        )
      )
    )
  }

  public func runDirectPrint(
    renderData: OutputPrintRenderData,
    session: OutputDirectPrintSession,
    documentName: String
  ) -> OutputResult<Void> {
    guard !renderData.pages.isEmpty else {
      return .failure(OutputError(OutputStrings.tr("output.direct_print_start_failed")))
    }

    let printInfo = (session.printInfo.copy() as? NSPrintInfo) ?? session.printInfo
    let printView = PrintView(renderData: renderData)
    let jobTitle = OutputStrings.tr("output.direct_print_job_title", documentName)

    guard runPrintOperation(printView, printInfo, jobTitle) else {
      return .failure(OutputError(OutputStrings.tr("output.direct_print_start_failed")))
    }

    return .success(())
  }

  private static func runAppKitPrintPanel(printInfo: NSPrintInfo) -> NSApplication.ModalResponse {
    NSApplication.ModalResponse(rawValue: NSPrintPanel().runModal(with: printInfo))
  }

  private static func runAppKitPrintOperation(
    printView: PrintView,
    printInfo: NSPrintInfo,
    jobTitle: String
  ) -> Bool {
    let operation = NSPrintOperation(view: printView, printInfo: printInfo)
    operation.showsPrintPanel = false
    operation.showsProgressPanel = true
    operation.jobTitle = jobTitle
    return operation.run()
  }

  public static func makePrintInfo(for orientation: OutputPrintOrientation) -> NSPrintInfo {
    let printInfo = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo.shared
    printInfo.orientation = orientation == .portrait ? .portrait : .landscape
    printInfo.paperSize = paperSizePoints(for: orientation)
    printInfo.horizontalPagination = .clip
    printInfo.verticalPagination = .clip
    printInfo.isHorizontallyCentered = false
    printInfo.isVerticallyCentered = false
    return printInfo
  }

  static func printableAreaMM(
    from printInfo: NSPrintInfo,
    orientation: OutputPrintOrientation
  ) -> OutputPrintableAreaMm {
    let bounds = printInfo.imageablePageBounds
    let pageSize = printInfo.paperSize
    let pageWidthMM = pointsToMillimeters(pageSize.width)
    let pageHeightMM = pointsToMillimeters(pageSize.height)
    let minXMM = pointsToMillimeters(bounds.minX)
    let maxXMM = pointsToMillimeters(bounds.maxX)
    let minYMM = pointsToMillimeters(bounds.minY)
    let maxYMM = pointsToMillimeters(bounds.maxY)
    let rawArea = OutputPrintableAreaMm(
      leftMm: minXMM - pageWidthMM / 2.0,
      rightMm: maxXMM - pageWidthMM / 2.0,
      topMm: maxYMM - pageHeightMM / 2.0,
      bottomMm: minYMM - pageHeightMM / 2.0
    )
    return sanitizePrintableAreaMM(rawArea, orientation: orientation)
  }

  static func sanitizePrintableAreaMM(
    _ area: OutputPrintableAreaMm,
    orientation: OutputPrintOrientation
  ) -> OutputPrintableAreaMm {
    let values = [area.leftMm, area.rightMm, area.topMm, area.bottomMm]
    guard values.allSatisfy(\.isFinite),
      area.leftMm < area.rightMm,
      area.bottomMm < area.topMm
    else {
      return OutputPaperDefaults.pdfPrintableAreaMm(for: orientation)
    }
    return area
  }

  static func paperSizePoints(for orientation: OutputPrintOrientation) -> NSSize {
    let size = OutputPaperDefaults.a4PageSizeMm(for: orientation)
    return NSSize(
      width: millimetersToPoints(size.widthMm),
      height: millimetersToPoints(size.heightMm)
    )
  }

  static func pointsToMillimeters(_ points: CGFloat) -> Double {
    Double(points) * 25.4 / 72.0
  }
}

final class PrintView: NSView {
  private let pages: [OutputPrintRenderPage]
  private let pageRects: [NSRect]

  init(page: OutputPrintRenderPage) {
    self.pages = [page]
    self.pageRects = [
      NSRect(
        x: 0,
        y: 0,
        width: millimetersToPoints(page.widthMm),
        height: millimetersToPoints(page.heightMm)
      )
    ]
    super.init(
      frame: NSRect(
        x: 0,
        y: 0,
        width: millimetersToPoints(page.widthMm),
        height: millimetersToPoints(page.heightMm)
      )
    )
  }

  init(renderData: OutputPrintRenderData) {
    self.pages = renderData.pages
    self.pageRects = Self.makePageRects(for: renderData.pages)
    let width = pageRects.map(\.width).max() ?? 0
    let height = pageRects.last?.maxY ?? 0
    super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override var isFlipped: Bool {
    false
  }

  override func knowsPageRange(_ range: NSRangePointer) -> Bool {
    range.pointee = NSRange(location: 1, length: pages.count)
    return true
  }

  override func rectForPage(_ pageNumber: Int) -> NSRect {
    pageRect(for: pageNumber) ?? .zero
  }

  override func locationOfPrintRect(_ rect: NSRect) -> NSPoint {
    .zero
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    for (index, pageRect) in pageRects.enumerated() where dirtyRect.intersects(pageRect) {
      draw(page: pages[index], in: pageRect)
    }
  }

  func pageForPrintPage(_ pageNumber: Int) -> OutputPrintRenderPage? {
    guard pages.indices.contains(pageNumber - 1) else {
      return nil
    }
    return pages[pageNumber - 1]
  }

  private static func makePageRects(for pages: [OutputPrintRenderPage]) -> [NSRect] {
    var rects: [NSRect] = []
    var currentY: CGFloat = 0
    for page in pages {
      let size = NSSize(
        width: millimetersToPoints(page.widthMm),
        height: millimetersToPoints(page.heightMm)
      )
      rects.append(NSRect(x: 0, y: currentY, width: size.width, height: size.height))
      currentY += size.height
    }
    return rects
  }

  private func pageRect(for pageNumber: Int) -> NSRect? {
    guard pageRects.indices.contains(pageNumber - 1) else {
      return nil
    }
    return pageRects[pageNumber - 1]
  }

  private func draw(page: OutputPrintRenderPage, in pageRect: NSRect) {
    NSGraphicsContext.saveGraphicsState()
    if let clipAreaMm = page.clipAreaMm {
      NSBezierPath(rect: rectInPage(clipAreaMm, pageRect: pageRect)).addClip()
    }
    defer {
      NSGraphicsContext.restoreGraphicsState()
    }

    for command in page.commands {
      switch command {
      case .strokeLine(let startMM, let endMM, let style, _):
        nsColor(style.stroke).setStroke()
        let path = NSBezierPath()
        path.lineWidth = millimetersToPoints(style.strokeWidthMm)
        let dashPattern = lineDashPattern(for: style.pattern)
        path.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        path.move(to: pointInPage(startMM, pageRect: pageRect))
        path.line(to: pointInPage(endMM, pageRect: pageRect))
        path.stroke()
      case .strokeCircle(let centerMM, let radiusMM, let style):
        nsColor(style.stroke).setStroke()
        let radiusPT = millimetersToPoints(radiusMM)
        let center = pointInPage(centerMM, pageRect: pageRect)
        let rect = NSRect(
          x: center.x - radiusPT, y: center.y - radiusPT, width: radiusPT * 2.0,
          height: radiusPT * 2.0)
        let path = NSBezierPath(ovalIn: rect)
        path.lineWidth = millimetersToPoints(style.strokeWidthMm)
        let dashPattern = lineDashPattern(for: style.pattern)
        path.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        path.stroke()
      case .strokeArc(let centerMM, let radiusMM, let startAngleRad, let sweepAngleRad, let style):
        nsColor(style.stroke).setStroke()
        let path = NSBezierPath()
        path.lineWidth = millimetersToPoints(style.strokeWidthMm)
        let dashPattern = lineDashPattern(for: style.pattern)
        path.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        let startAngle = radiansToDegrees(startAngleRad)
        let endAngle = radiansToDegrees(startAngleRad + sweepAngleRad)
        path.appendArc(
          withCenter: pointInPage(centerMM, pageRect: pageRect),
          radius: millimetersToPoints(radiusMM),
          startAngle: startAngle,
          endAngle: endAngle,
          clockwise: sweepAngleRad < 0
        )
        path.stroke()
      case .drawPoint(let centerMM, let style):
        nsColor(style.stroke).setStroke()
        let radiusPT = millimetersToPoints(0.5)
        let center = pointInPage(centerMM, pageRect: pageRect)
        let rect = NSRect(
          x: center.x - radiusPT, y: center.y - radiusPT, width: radiusPT * 2.0,
          height: radiusPT * 2.0)
        let path = NSBezierPath(ovalIn: rect)
        path.lineWidth = millimetersToPoints(style.strokeWidthMm)
        path.stroke()
      case .drawText(let positionMM, let content, _, let fontSizeMM):
        let attributes: [NSAttributedString.Key: Any] = [
          .font: NSFont.systemFont(ofSize: max(1.0, fontSizeMM * 72.0 / 25.4)),
          .foregroundColor: NSColor.black,
        ]
        NSString(string: content).draw(
          at: pointInPage(positionMM, pageRect: pageRect), withAttributes: attributes)
      }
    }
  }

  private func pointInPage(_ pointMM: OutputPointMm, pageRect: NSRect) -> NSPoint {
    NSPoint(
      x: pageRect.midX + millimetersToPoints(pointMM.xMm),
      y: pageRect.midY + millimetersToPoints(pointMM.yMm)
    )
  }

  private func rectInPage(_ areaMM: OutputPrintableAreaMm, pageRect: NSRect) -> NSRect {
    let origin = pointInPage(
      OutputPointMm(xMm: areaMM.leftMm, yMm: areaMM.bottomMm), pageRect: pageRect)
    return NSRect(
      x: origin.x,
      y: origin.y,
      width: millimetersToPoints(areaMM.rightMm - areaMM.leftMm),
      height: millimetersToPoints(areaMM.topMm - areaMM.bottomMm)
    )
  }
}

private func millimetersToPoints(_ mm: Double) -> CGFloat {
  CGFloat(mm * 72.0 / 25.4)
}

private func pointsToMillimeters(_ points: CGFloat) -> Double {
  Double(points) * 25.4 / 72.0
}

private func radiansToDegrees(_ radians: Double) -> Double {
  radians * 180.0 / .pi
}

private func nsColor(_ rgba: OutputRGBA) -> NSColor {
  NSColor(red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
}

private func lineDashPattern(for pattern: OutputLinePattern) -> [CGFloat] {
  switch pattern {
  case .solid:
    []
  case .dashed:
    [6, 3]
  case .dotted:
    [1, 2]
  case .construction:
    [3, 2]
  }
}
