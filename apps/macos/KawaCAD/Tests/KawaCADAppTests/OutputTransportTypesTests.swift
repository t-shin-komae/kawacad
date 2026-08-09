import Foundation
import KawaCADOutput
import Testing

@testable import KawaCADApp

@Test("UI/Core interface schema は出力境界の主要定義を含む")
func ui_core_interface_schema_contains_output_contract_definitions() throws {
  let schema = try JSONSerialization.jsonObject(with: interfaceSchemaData()) as? [String: Any]
  let defs = try #require(schema?["$defs"] as? [String: Any])

  #expect(defs["buildOutputDocumentModelRequest"] != nil)
  #expect(defs["buildOutputDocumentModelResponse"] != nil)
  #expect(defs["renderPdfRequest"] != nil)
  #expect(defs["renderPrintRequest"] != nil)
  #expect(defs["outputDocumentModel"] != nil)
  #expect(defs["printRenderData"] != nil)
  let printRenderPage = try #require(defs["printRenderPage"] as? [String: Any])
  let printRenderPageProperties = try #require(printRenderPage["properties"] as? [String: Any])
  #expect(printRenderPageProperties["clipAreaMm"] != nil)
}

@Test("OutputBuildResult は buildOutputDocumentModel response JSON を型付きで decode できる")
func output_build_result_decodes_from_core_response_json() throws {
  let result = try JSONDecoder().decode(
    OutputBuildResult.self,
    from: interfaceFixtureData("build-output-document-model-response.json")
  )

  #expect(result.outputDocumentModel.paperSize == .a4)
  #expect(result.outputDocumentModel.pages.count == 1)
  #expect(result.outputDocumentModel.pages[0].gridColumn == 0)
  #expect(result.outputDocumentModel.pages[0].gridRow == 0)
  #expect(result.outputDocumentModel.pages[0].rotationDeg == 0)
  #expect(result.warnings == [.init(kind: .outOfPrintableBounds, message: "印刷可能領域からはみ出しています。")])
  #expect(result.outputDocumentModel.pages[0].graphics.count == 1)
}

@Test("OutputDocumentModel encode は Rust core 互換の camelCase geometry payload を使う")
func output_document_model_encodes_geometry_payloads_for_rust_core() throws {
  let model = OutputDocumentModel(
    paperSize: .a4,
    orientation: .portrait,
    scale: .actualSize,
    pageCount: 1,
    pages: [
      OutputPage(
        widthMm: 210.0,
        heightMm: 297.0,
        rotationDeg: 0,
        printableAreaMm: OutputPrintableAreaMm(
          leftMm: -100.0,
          rightMm: 100.0,
          topMm: 143.5,
          bottomMm: -143.5
        ),
        graphics: [
          OutputGraphic(
            entityId: "entity:line-a",
            kind: .lineSegment,
            geometry: .lineSegment(
              startMm: OutputPointMm(xMm: 25.0, yMm: 65.0),
              endMm: OutputPointMm(xMm: 70.0, yMm: 65.0)
            ),
            style: .default
          )
        ],
        texts: [],
        guide: nil
      )
    ]
  )

  let encoded = try JSONEncoder().encode(model)
  let json = try #require(String(data: encoded, encoding: .utf8))

  #expect(json.contains("\"startMm\""))
  #expect(json.contains("\"endMm\""))
}

@Test("OutputText は自由テキスト kind と文字サイズを decode できる")
func output_text_decodes_free_text_kind_and_font_size() throws {
  let json = """
    {
      "kind": "freeText",
      "content": "Skive edge",
      "positionMm": { "xMm": 12.0, "yMm": -8.0 },
      "fontSizeMm": 4.5
    }
    """
  let text = try JSONDecoder().decode(OutputText.self, from: Data(json.utf8))

  #expect(text.kind == .freeText)
  #expect(text.content == "Skive edge")
  #expect(text.positionMm == OutputPointMm(xMm: 12.0, yMm: -8.0))
  #expect(text.fontSizeMm == 4.5)
}

@Test("OutputPrintRenderCommand は自由テキスト drawText の文字サイズを decode できる")
func print_render_command_decodes_free_text_font_size() throws {
  let json = """
    {
      "kind": "drawText",
      "payload": {
        "position_mm": { "xMm": 12.0, "yMm": -8.0 },
        "content": "Skive edge",
        "kind": "freeText",
        "font_size_mm": 4.5
      }
    }
    """
  let command = try JSONDecoder().decode(OutputPrintRenderCommand.self, from: Data(json.utf8))

  #expect(
    command
      == .drawText(
        positionMm: OutputPointMm(xMm: 12.0, yMm: -8.0),
        content: "Skive edge",
        kind: .freeText,
        fontSizeMm: 4.5
      ))
}

@Test("OutputDocumentModel は render request 用に encode / decode を往復できる")
func output_document_model_round_trips_for_render_requests() throws {
  let model = try JSONDecoder().decode(
    OutputDocumentModel.self,
    from: interfaceFixtureData("output-document-model.json")
  )
  let data = try JSONEncoder().encode(model)
  let decoded = try JSONDecoder().decode(OutputDocumentModel.self, from: data)

  #expect(decoded == model)
}

@Test("OutputPrintRenderData は renderPrint response JSON を型付きで decode できる")
func output_print_render_data_decodes_from_engine_response_json() throws {
  let result = try JSONDecoder().decode(
    OutputPrintRenderData.self,
    from: interfaceFixtureData("print-render-data.json")
  )

  #expect(result.orientation == .portrait)
  #expect(result.pages.count == 1)
  #expect(
    result.pages[0].clipAreaMm
      == OutputPrintableAreaMm(
        leftMm: -105.0,
        rightMm: 105.0,
        topMm: 148.5,
        bottomMm: -148.5
      ))
  #expect(result.pages[0].commands.count == 2)
}

@Test("OutputPrintRenderPage はページクリップ領域を decode できる")
func output_print_render_page_decodes_clip_area() throws {
  let json = """
    {
      "widthMm": 210.0,
      "heightMm": 297.0,
      "rotationDeg": 0,
      "printableAreaMm": {
        "leftMm": -100.0,
        "rightMm": 100.0,
        "topMm": 143.5,
        "bottomMm": -143.5
      },
      "clipAreaMm": {
        "leftMm": -105.0,
        "rightMm": 105.0,
        "topMm": 148.5,
        "bottomMm": -148.5
      },
      "commands": []
    }
    """

  let page = try JSONDecoder().decode(OutputPrintRenderPage.self, from: Data(json.utf8))

  #expect(
    page.clipAreaMm
      == OutputPrintableAreaMm(
        leftMm: -105.0,
        rightMm: 105.0,
        topMm: 148.5,
        bottomMm: -148.5
      ))
}

@Test("renderPdf / renderPrint request の model JSON は Swift DTO で decode できる")
func render_requests_embed_output_document_model_json() throws {
  let renderPDFModel = try outputDocumentModelFromRenderRequest("render-pdf-request.json")
  let renderPrintModel = try outputDocumentModelFromRenderRequest("render-print-request.json")

  #expect(renderPDFModel.pageCount == 1)
  #expect(renderPDFModel.pages[0].gridColumn == 0)
  #expect(renderPDFModel.pages[0].gridRow == 0)
  #expect(renderPrintModel.pageCount == 1)
  #expect(renderPrintModel.pages[0].gridColumn == 0)
  #expect(renderPrintModel.pages[0].gridRow == 0)
  #expect(renderPrintModel.pages[0].texts.count == 1)
  #expect(renderPrintModel.pages[0].guide?.label == "50mm")
}

private func outputDocumentModelFromRenderRequest(_ fixtureName: String) throws
  -> OutputDocumentModel
{
  let object =
    try JSONSerialization.jsonObject(with: interfaceFixtureData(fixtureName)) as? [String: Any]
  let payload = try #require(object?["payload"] as? [String: Any])
  let json = try #require(payload["outputDocumentModelJson"] as? String)
  return try JSONDecoder().decode(OutputDocumentModel.self, from: Data(json.utf8))
}
