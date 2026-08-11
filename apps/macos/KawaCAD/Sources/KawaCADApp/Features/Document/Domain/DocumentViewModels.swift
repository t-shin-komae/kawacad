import Foundation

struct ModelPoint: Hashable, Codable {
  let xMM: Double
  let yMM: Double

  enum CodingKeys: String, CodingKey {
    case xMM = "xMm"
    case yMM = "yMm"
  }

  var jsonObject: [String: Double] {
    ["xMm": xMM, "yMm": yMM]
  }

  func translatedBy(dxMM: Double, dyMM: Double) -> ModelPoint {
    ModelPoint(xMM: xMM + dxMM, yMM: yMM + dyMM)
  }
}

struct ProjectFreeText: Identifiable, Hashable {
  let id: String
  let content: String
  let positionMM: ModelPoint
  let fontSizeMM: Double

  var jsonObject: [String: Any] {
    [
      "id": id,
      "content": content,
      "positionMm": positionMM.jsonObject,
      "fontSizeMm": fontSizeMM,
    ]
  }

  func withContent(_ content: String) -> ProjectFreeText {
    ProjectFreeText(id: id, content: content, positionMM: positionMM, fontSizeMM: fontSizeMM)
  }

  func withPosition(_ positionMM: ModelPoint) -> ProjectFreeText {
    ProjectFreeText(id: id, content: content, positionMM: positionMM, fontSizeMM: fontSizeMM)
  }

  func withFontSize(_ fontSizeMM: Double) -> ProjectFreeText {
    ProjectFreeText(id: id, content: content, positionMM: positionMM, fontSizeMM: fontSizeMM)
  }
}
