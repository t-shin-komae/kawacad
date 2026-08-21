import AppKit
import KawaCADOutput
import Testing

@testable import KawaCADApp

@Test("出力プレビューは Core の OutputPage グリッド位置からページ矩形を生成する")
@MainActor
func output_preview_page_rects_follow_core_output_page_grid_positions() {
  let inputs = CanvasTestInputBuilder()
  let view = inputs.makeView(frame: NSRect(x: 0, y: 0, width: 520, height: 736))
  inputs.viewMode = .outputPreview
  inputs.outputPreviewModel = OutputDocumentModel(
    paperSize: .a4,
    orientation: .portrait,
    scale: .actualSize,
    pageCount: 2,
    pages: [
      OutputPage(
        widthMm: 210.0,
        heightMm: 297.0,
        gridColumn: -1,
        gridRow: 1,
        rotationDeg: 0,
        printableAreaMm: OutputPaperDefaults.pdfPrintableAreaMm(for: .portrait),
        graphics: [],
        texts: [],
        guide: nil
      ),
      OutputPage(
        widthMm: 210.0,
        heightMm: 297.0,
        gridColumn: 1,
        gridRow: -1,
        rotationDeg: 0,
        printableAreaMm: OutputPaperDefaults.pdfPrintableAreaMm(for: .portrait),
        graphics: [],
        texts: [],
        guide: nil
      ),
    ]
  )

  let rects = view.outputPreviewPageRects(in: view.bounds)

  #expect(rects.count == 2)
  #expect(rects[0].minX < rects[1].minX)
  #expect(rects[0].minY < rects[1].minY)
  #expect(rects[0].width == rects[1].width)
  #expect(rects[0].height == rects[1].height)
}

@Test("編集表示では出力プレビューのページ矩形を返さない")
@MainActor
func edit_display_does_not_expose_output_preview_page_rects() {
  let inputs = CanvasTestInputBuilder()
  let view = inputs.makeView(frame: NSRect(x: 0, y: 0, width: 520, height: 736))
  inputs.viewMode = .editDisplay
  inputs.outputPreviewModel = sampleOutputDocumentModel()

  #expect(view.outputPreviewPageRects(in: view.bounds).isEmpty)
}
