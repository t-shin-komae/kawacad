import AppKit
import Testing

@testable import KawaCADOutput

private let testDirectPrintSession = OutputDirectPrintSession(
  printInfo: LivePrintController.makePrintInfo(for: .portrait)
)

@Test("PrintView は直接印刷用に単一ページの印刷座標を返す")
func print_view_uses_single_page_print_coordinates() {
  let page = printRenderPage(widthMm: 210.0, heightMm: 297.0)
  let view = PrintView(page: page)
  var range = NSRange(location: 0, length: 0)

  #expect(view.knowsPageRange(&range))
  #expect(range.location == 1)
  #expect(range.length == 1)
  #expect(view.rectForPage(1) == view.bounds)
  #expect(view.rectForPage(2) == .zero)
  #expect(view.locationOfPrintRect(view.bounds) == .zero)
}

@Test("PrintView は複数ページの印刷ページ範囲とページ矩形を返す")
func print_view_uses_multi_page_print_coordinates() {
  let firstPage = printRenderPage(widthMm: 210.0, heightMm: 297.0, marker: "PAGE 1")
  let secondPage = printRenderPage(widthMm: 210.0, heightMm: 297.0, marker: "PAGE 2")
  let renderData = OutputPrintRenderData(
    orientation: .portrait,
    pages: [firstPage, secondPage]
  )
  let view = PrintView(renderData: renderData)
  var range = NSRange(location: 0, length: 0)
  let pageWidth = points(210.0)
  let pageHeight = points(297.0)

  #expect(view.knowsPageRange(&range))
  #expect(range.location == 1)
  #expect(range.length == 2)
  #expect(view.bounds == NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight * 2.0))
  #expect(view.rectForPage(1) == NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
  #expect(view.rectForPage(2) == NSRect(x: 0, y: pageHeight, width: pageWidth, height: pageHeight))
  #expect(view.rectForPage(3) == .zero)
}

@Test("PrintView は PrintRenderData.pages の順序でページを割り当てる")
func print_view_preserves_print_render_page_order() {
  let firstPage = printRenderPage(widthMm: 210.0, heightMm: 297.0, marker: "FIRST")
  let secondPage = printRenderPage(widthMm: 210.0, heightMm: 297.0, marker: "SECOND")
  let view = PrintView(
    renderData: OutputPrintRenderData(
      orientation: .portrait,
      pages: [firstPage, secondPage]
    ))

  #expect(view.pageForPrintPage(1) == firstPage)
  #expect(view.pageForPrintPage(2) == secondPage)
  #expect(view.pageForPrintPage(0) == nil)
  #expect(view.pageForPrintPage(3) == nil)
}

@Test("LivePrintController は複数ページの PrintRenderData を直接印刷経路へ渡せる")
func live_print_controller_accepts_multi_page_render_data() {
  let firstPage = printRenderPage(widthMm: 210.0, heightMm: 297.0, marker: "FIRST")
  let secondPage = printRenderPage(widthMm: 210.0, heightMm: 297.0, marker: "SECOND")
  let renderData = OutputPrintRenderData(
    orientation: .portrait,
    pages: [firstPage, secondPage]
  )
  var capturedRange = NSRange(location: 0, length: 0)
  var capturedTitle: String?
  var capturedOrientation: NSPrintInfo.PaperOrientation?
  let controller = LivePrintController { printView, printInfo, jobTitle in
    capturedTitle = jobTitle
    capturedOrientation = printInfo.orientation
    #expect(printView.knowsPageRange(&capturedRange))
    #expect(printView.pageForPrintPage(1) == firstPage)
    #expect(printView.pageForPrintPage(2) == secondPage)
    return true
  }

  let result = controller.runDirectPrint(
    renderData: renderData,
    session: testDirectPrintSession,
    documentName: "Multi Page"
  )

  if case .failure(let error) = result {
    Issue.record(
      "direct print should accept multi-page render data: \(String(describing: error.message))")
  }
  #expect(capturedRange.location == 1)
  #expect(capturedRange.length == 2)
  #expect(capturedTitle == "Multi Page の直接印刷")
  #expect(capturedOrientation == .portrait)
}

@Test("LivePrintController は空の PrintRenderData では直接印刷を開始しない")
func live_print_controller_rejects_empty_render_data() {
  var didStartPrintOperation = false
  let controller = LivePrintController { _, _, _ in
    didStartPrintOperation = true
    return true
  }

  let result = controller.runDirectPrint(
    renderData: OutputPrintRenderData(orientation: .portrait, pages: []),
    session: testDirectPrintSession,
    documentName: "Empty"
  )

  if case .success = result {
    Issue.record("empty render data should fail")
  }
  #expect(!didStartPrintOperation)
}

@Test("LivePrintController は非A4用紙の captured session を直接印刷準備で拒否する")
func live_print_controller_rejects_non_a4_captured_session() {
  let printInfo = LivePrintController.makePrintInfo(for: .portrait)
  printInfo.paperSize = NSSize(width: points(148.0), height: points(210.0))
  let session = OutputDirectPrintSession(printInfo: printInfo)
  let controller = LivePrintController { _, _, _ in
    Issue.record("print operation should not start during prepare")
    return true
  }

  let result = controller.prepareDirectPrintSession(
    presentation: OutputPresentationOptions(
      orientation: .portrait,
      includeDimensionLabels: true,
      includeScaleGuide: true,
      rotationDeg: 0
    ),
    session: session
  )

  switch result {
  case .failure(let error):
    #expect(error.message == OutputStrings.tr("output.direct_print_requires_a4"))
  case .success:
    Issue.record("non-A4 captured session should fail")
  }
}

@Test("LivePrintController は非有限な印刷可能領域を A4 既定値へフォールバックする")
func live_print_controller_falls_back_for_non_finite_printable_area() {
  let fallback = OutputPaperDefaults.pdfPrintableAreaMm(for: .portrait)
  let area = LivePrintController.sanitizePrintableAreaMM(
    OutputPrintableAreaMm(
      leftMm: -.infinity,
      rightMm: 100.0,
      topMm: 143.5,
      bottomMm: -143.5
    ),
    orientation: .portrait
  )

  #expect(area == fallback)
}

@Test("LivePrintController は反転した印刷可能領域を A4 既定値へフォールバックする")
func live_print_controller_falls_back_for_inverted_printable_area() {
  let fallback = OutputPaperDefaults.pdfPrintableAreaMm(for: .landscape)
  let area = LivePrintController.sanitizePrintableAreaMM(
    OutputPrintableAreaMm(
      leftMm: 50.0,
      rightMm: -50.0,
      topMm: -20.0,
      bottomMm: 20.0
    ),
    orientation: .landscape
  )

  #expect(area == fallback)
}

@Test("LivePrintController は妥当な印刷可能領域をそのまま使う")
func live_print_controller_keeps_valid_printable_area() {
  let area = OutputPrintableAreaMm(
    leftMm: -100.0,
    rightMm: 100.0,
    topMm: 143.5,
    bottomMm: -143.5
  )

  #expect(LivePrintController.sanitizePrintableAreaMM(area, orientation: .portrait) == area)
}

private func printRenderPage(
  widthMm: Double,
  heightMm: Double,
  marker: String = "PAGE"
) -> OutputPrintRenderPage {
  OutputPrintRenderPage(
    widthMm: widthMm,
    heightMm: heightMm,
    rotationDeg: 0,
    printableAreaMm: OutputPrintableAreaMm(
      leftMm: -100.0,
      rightMm: 100.0,
      topMm: 143.5,
      bottomMm: -143.5
    ),
    commands: [
      .drawText(
        positionMm: OutputPointMm(xMm: 0.0, yMm: 0.0),
        content: marker,
        kind: .guideLabel,
        fontSizeMm: 3.5
      )
    ]
  )
}

private func points(_ mm: Double) -> CGFloat {
  CGFloat(mm * 72.0 / 25.4)
}
