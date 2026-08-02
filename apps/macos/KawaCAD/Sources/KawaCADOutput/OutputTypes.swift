import Foundation

public enum OutputPrintOrientation: String, Codable, Equatable {
  case portrait
  case landscape
}

public struct OutputPageSizeMm: Equatable {
  public let widthMm: Double
  public let heightMm: Double

  public init(widthMm: Double, heightMm: Double) {
    self.widthMm = widthMm
    self.heightMm = heightMm
  }
}

public enum OutputPaperDefaults {
  public static let a4PortraitSizeMm = OutputPageSizeMm(widthMm: 210.0, heightMm: 297.0)
  public static let a4LandscapeSizeMm = OutputPageSizeMm(widthMm: 297.0, heightMm: 210.0)

  public static func a4PageSizeMm(for orientation: OutputPrintOrientation) -> OutputPageSizeMm {
    switch orientation {
    case .portrait:
      a4PortraitSizeMm
    case .landscape:
      a4LandscapeSizeMm
    }
  }

  public static func pdfPrintableAreaMm(for orientation: OutputPrintOrientation)
    -> OutputPrintableAreaMm
  {
    let pageSize = a4PageSizeMm(for: orientation)
    let insetMm = 5.0
    return OutputPrintableAreaMm(
      leftMm: -pageSize.widthMm / 2.0 + insetMm,
      rightMm: pageSize.widthMm / 2.0 - insetMm,
      topMm: pageSize.heightMm / 2.0 - insetMm,
      bottomMm: -pageSize.heightMm / 2.0 + insetMm
    )
  }
}

public struct OutputPresentationOptions: Equatable {
  public let orientation: OutputPrintOrientation
  public let includeDimensionLabels: Bool
  public let includeScaleGuide: Bool
  public let rotationDeg: Int

  public init(
    orientation: OutputPrintOrientation,
    includeDimensionLabels: Bool,
    includeScaleGuide: Bool,
    rotationDeg: Int
  ) {
    self.orientation = orientation
    self.includeDimensionLabels = includeDimensionLabels
    self.includeScaleGuide = includeScaleGuide
    self.rotationDeg = rotationDeg
  }
}

public struct OutputPrintableAreaMm: Codable, Equatable {
  public let leftMm: Double
  public let rightMm: Double
  public let topMm: Double
  public let bottomMm: Double

  public init(leftMm: Double, rightMm: Double, topMm: Double, bottomMm: Double) {
    self.leftMm = leftMm
    self.rightMm = rightMm
    self.topMm = topMm
    self.bottomMm = bottomMm
  }

  public var jsonObject: [String: Double] {
    [
      "leftMm": leftMm,
      "rightMm": rightMm,
      "topMm": topMm,
      "bottomMm": bottomMm,
    ]
  }
}

public struct OutputBuildOptions: Equatable {
  public let orientation: OutputPrintOrientation
  public let includeDimensionLabels: Bool
  public let includeScaleGuide: Bool
  public let rotationDeg: Int
  public let printableAreaMm: OutputPrintableAreaMm

  public init(
    orientation: OutputPrintOrientation,
    includeDimensionLabels: Bool,
    includeScaleGuide: Bool,
    rotationDeg: Int,
    printableAreaMm: OutputPrintableAreaMm
  ) {
    self.orientation = orientation
    self.includeDimensionLabels = includeDimensionLabels
    self.includeScaleGuide = includeScaleGuide
    self.rotationDeg = rotationDeg
    self.printableAreaMm = printableAreaMm
  }
}

public struct OutputWarning: Codable, Equatable {
  public let kind: OutputWarningKind
  public let message: String

  public init(kind: OutputWarningKind, message: String) {
    self.kind = kind
    self.message = message
  }
}

public enum OutputWarningKind: String, Codable, Equatable {
  case emptyDocument
  case outOfPrintableBounds
  case pageBoundaryCrossing
  case actualScaleNotGuaranteed
}

public struct OutputBuildResult: Codable, Equatable {
  public let outputDocumentModel: OutputDocumentModel
  public let warnings: [OutputWarning]

  public init(outputDocumentModel: OutputDocumentModel, warnings: [OutputWarning]) {
    self.outputDocumentModel = outputDocumentModel
    self.warnings = warnings
  }
}

public struct OutputError: Error, Equatable, LocalizedError {
  public let message: String

  public init(_ message: String) {
    self.message = message
  }

  public var errorDescription: String? {
    message
  }
}

public typealias OutputResult<T> = Result<T, OutputError>

public enum OutputPaperSize: String, Codable, Equatable {
  case a4
}

public enum OutputScale: String, Codable, Equatable {
  case actualSize
}

public struct OutputPointMm: Codable, Equatable {
  public let xMm: Double
  public let yMm: Double

  public init(xMm: Double, yMm: Double) {
    self.xMm = xMm
    self.yMm = yMm
  }
}

public enum OutputLinePattern: String, Codable, Equatable {
  case solid
  case dashed
  case dotted
  case construction
}

public struct OutputRGBA: Codable, Equatable {
  public let red: Double
  public let green: Double
  public let blue: Double
  public let alpha: Double

  public init(red: Double, green: Double, blue: Double, alpha: Double) {
    self.red = red
    self.green = green
    self.blue = blue
    self.alpha = alpha
  }
}

public struct OutputLayerStyle: Codable, Equatable {
  public let stroke: OutputRGBA
  public let strokeWidthMm: Double
  public let pattern: OutputLinePattern

  public init(stroke: OutputRGBA, strokeWidthMm: Double, pattern: OutputLinePattern) {
    self.stroke = stroke
    self.strokeWidthMm = strokeWidthMm
    self.pattern = pattern
  }

  public static let `default` = OutputLayerStyle(
    stroke: OutputRGBA(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
    strokeWidthMm: 0.2,
    pattern: .solid
  )
}

public enum OutputGraphicKind: String, Codable, Equatable {
  case point
  case lineSegment
  case circle
  case arc
  case centerLine
}

public enum OutputTextKind: String, Codable, Equatable {
  case dimensionLabel
  case guideLabel
  case freeText
}

public struct OutputGuide: Codable, Equatable {
  public let startMm: OutputPointMm
  public let endMm: OutputPointMm
  public let label: String
  public let labelPositionMm: OutputPointMm

  public init(
    startMm: OutputPointMm, endMm: OutputPointMm, label: String, labelPositionMm: OutputPointMm
  ) {
    self.startMm = startMm
    self.endMm = endMm
    self.label = label
    self.labelPositionMm = labelPositionMm
  }
}

public struct OutputText: Codable, Equatable {
  public let kind: OutputTextKind
  public let content: String
  public let positionMm: OutputPointMm
  public let fontSizeMm: Double

  public init(kind: OutputTextKind, content: String, positionMm: OutputPointMm, fontSizeMm: Double)
  {
    self.kind = kind
    self.content = content
    self.positionMm = positionMm
    self.fontSizeMm = fontSizeMm
  }
}

public enum OutputGraphicGeometry: Equatable {
  case point(positionMm: OutputPointMm)
  case lineSegment(startMm: OutputPointMm, endMm: OutputPointMm)
  case circle(centerMm: OutputPointMm, radiusMm: Double)
  case arc(centerMm: OutputPointMm, radiusMm: Double, startAngleRad: Double, sweepAngleRad: Double)
  case centerLine(startMm: OutputPointMm, endMm: OutputPointMm)
}

extension OutputGraphicGeometry: Codable {
  private enum CodingKeys: String, CodingKey {
    case kind
    case payload
  }

  private enum Kind: String, Codable {
    case point
    case lineSegment
    case circle
    case arc
    case centerLine
  }

  private struct PointPayload: Codable {
    let positionMm: OutputPointMm

    private enum CodingKeys: String, CodingKey {
      case positionMm = "position_mm"
    }

    init(positionMm: OutputPointMm) {
      self.positionMm = positionMm
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      positionMm = try container.decode(OutputPointMm.self, forKey: .positionMm)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(positionMm, forKey: .positionMm)
    }
  }

  private struct LinePayload: Codable {
    let startMm: OutputPointMm
    let endMm: OutputPointMm

    private enum CodingKeys: String, CodingKey {
      case startMm = "start_mm"
      case endMm = "end_mm"
    }

    init(startMm: OutputPointMm, endMm: OutputPointMm) {
      self.startMm = startMm
      self.endMm = endMm
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      startMm = try container.decode(OutputPointMm.self, forKey: .startMm)
      endMm = try container.decode(OutputPointMm.self, forKey: .endMm)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(startMm, forKey: .startMm)
      try container.encode(endMm, forKey: .endMm)
    }
  }

  private struct CirclePayload: Codable {
    let centerMm: OutputPointMm
    let radiusMm: Double

    private enum CodingKeys: String, CodingKey {
      case centerMm = "center_mm"
      case radiusMm = "radius_mm"
    }

    init(centerMm: OutputPointMm, radiusMm: Double) {
      self.centerMm = centerMm
      self.radiusMm = radiusMm
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      centerMm = try container.decode(OutputPointMm.self, forKey: .centerMm)
      radiusMm = try container.decode(Double.self, forKey: .radiusMm)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(centerMm, forKey: .centerMm)
      try container.encode(radiusMm, forKey: .radiusMm)
    }
  }

  private struct ArcPayload: Codable {
    let centerMm: OutputPointMm
    let radiusMm: Double
    let startAngleRad: Double
    let sweepAngleRad: Double

    private enum CodingKeys: String, CodingKey {
      case centerMm = "center_mm"
      case radiusMm = "radius_mm"
      case startAngleRad = "start_angle_rad"
      case sweepAngleRad = "sweep_angle_rad"
    }

    init(centerMm: OutputPointMm, radiusMm: Double, startAngleRad: Double, sweepAngleRad: Double) {
      self.centerMm = centerMm
      self.radiusMm = radiusMm
      self.startAngleRad = startAngleRad
      self.sweepAngleRad = sweepAngleRad
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      centerMm = try container.decode(OutputPointMm.self, forKey: .centerMm)
      radiusMm = try container.decode(Double.self, forKey: .radiusMm)
      startAngleRad = try container.decode(Double.self, forKey: .startAngleRad)
      sweepAngleRad = try container.decode(Double.self, forKey: .sweepAngleRad)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(centerMm, forKey: .centerMm)
      try container.encode(radiusMm, forKey: .radiusMm)
      try container.encode(startAngleRad, forKey: .startAngleRad)
      try container.encode(sweepAngleRad, forKey: .sweepAngleRad)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .kind) {
    case .point:
      let payload = try container.decode(PointPayload.self, forKey: .payload)
      self = .point(positionMm: payload.positionMm)
    case .lineSegment:
      let payload = try container.decode(LinePayload.self, forKey: .payload)
      self = .lineSegment(startMm: payload.startMm, endMm: payload.endMm)
    case .circle:
      let payload = try container.decode(CirclePayload.self, forKey: .payload)
      self = .circle(centerMm: payload.centerMm, radiusMm: payload.radiusMm)
    case .arc:
      let payload = try container.decode(ArcPayload.self, forKey: .payload)
      self = .arc(
        centerMm: payload.centerMm,
        radiusMm: payload.radiusMm,
        startAngleRad: payload.startAngleRad,
        sweepAngleRad: payload.sweepAngleRad
      )
    case .centerLine:
      let payload = try container.decode(LinePayload.self, forKey: .payload)
      self = .centerLine(startMm: payload.startMm, endMm: payload.endMm)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .point(let positionMm):
      try container.encode(Kind.point, forKey: .kind)
      try container.encode(PointPayload(positionMm: positionMm), forKey: .payload)
    case .lineSegment(let startMm, let endMm):
      try container.encode(Kind.lineSegment, forKey: .kind)
      try container.encode(LinePayload(startMm: startMm, endMm: endMm), forKey: .payload)
    case .circle(let centerMm, let radiusMm):
      try container.encode(Kind.circle, forKey: .kind)
      try container.encode(CirclePayload(centerMm: centerMm, radiusMm: radiusMm), forKey: .payload)
    case .arc(let centerMm, let radiusMm, let startAngleRad, let sweepAngleRad):
      try container.encode(Kind.arc, forKey: .kind)
      try container.encode(
        ArcPayload(
          centerMm: centerMm,
          radiusMm: radiusMm,
          startAngleRad: startAngleRad,
          sweepAngleRad: sweepAngleRad
        ),
        forKey: .payload
      )
    case .centerLine(let startMm, let endMm):
      try container.encode(Kind.centerLine, forKey: .kind)
      try container.encode(LinePayload(startMm: startMm, endMm: endMm), forKey: .payload)
    }
  }
}

public struct OutputGraphic: Codable, Equatable {
  public let entityId: String
  public let kind: OutputGraphicKind
  public let geometry: OutputGraphicGeometry
  public let style: OutputLayerStyle

  public init(
    entityId: String, kind: OutputGraphicKind, geometry: OutputGraphicGeometry,
    style: OutputLayerStyle
  ) {
    self.entityId = entityId
    self.kind = kind
    self.geometry = geometry
    self.style = style
  }

}

public struct OutputPage: Codable, Equatable {
  public let widthMm: Double
  public let heightMm: Double
  public let gridColumn: Int
  public let gridRow: Int
  public let rotationDeg: Int
  public let printableAreaMm: OutputPrintableAreaMm
  public let graphics: [OutputGraphic]
  public let texts: [OutputText]
  public let guide: OutputGuide?

  public init(
    widthMm: Double,
    heightMm: Double,
    gridColumn: Int = 0,
    gridRow: Int = 0,
    rotationDeg: Int,
    printableAreaMm: OutputPrintableAreaMm,
    graphics: [OutputGraphic],
    texts: [OutputText],
    guide: OutputGuide?
  ) {
    self.widthMm = widthMm
    self.heightMm = heightMm
    self.gridColumn = gridColumn
    self.gridRow = gridRow
    self.rotationDeg = rotationDeg
    self.printableAreaMm = printableAreaMm
    self.graphics = graphics
    self.texts = texts
    self.guide = guide
  }

}

public struct OutputDocumentModel: Codable, Equatable {
  public let paperSize: OutputPaperSize
  public let orientation: OutputPrintOrientation
  public let scale: OutputScale
  public let pageCount: Int
  public let pages: [OutputPage]

  public init(
    paperSize: OutputPaperSize,
    orientation: OutputPrintOrientation,
    scale: OutputScale,
    pageCount: Int,
    pages: [OutputPage]
  ) {
    self.paperSize = paperSize
    self.orientation = orientation
    self.scale = scale
    self.pageCount = pageCount
    self.pages = pages
  }

}

public enum OutputStrokeKind: String, Codable, Equatable {
  case graphic
  case guide
}

public enum OutputPrintRenderCommand: Equatable {
  case strokeLine(
    startMm: OutputPointMm, endMm: OutputPointMm, style: OutputLayerStyle, kind: OutputStrokeKind)
  case strokeCircle(centerMm: OutputPointMm, radiusMm: Double, style: OutputLayerStyle)
  case strokeArc(
    centerMm: OutputPointMm, radiusMm: Double, startAngleRad: Double, sweepAngleRad: Double,
    style: OutputLayerStyle)
  case drawPoint(centerMm: OutputPointMm, style: OutputLayerStyle)
  case drawText(
    positionMm: OutputPointMm, content: String, kind: OutputTextKind, fontSizeMm: Double)
}

extension OutputPrintRenderCommand: Codable {
  private enum CodingKeys: String, CodingKey {
    case kind
    case payload
  }

  private enum Kind: String, Codable {
    case strokeLine
    case strokeCircle
    case strokeArc
    case drawPoint
    case drawText
  }

  private struct StrokeLinePayload: Codable {
    let startMm: OutputPointMm
    let endMm: OutputPointMm
    let style: OutputLayerStyle
    let kind: OutputStrokeKind

    private enum CodingKeys: String, CodingKey {
      case startMm = "start_mm"
      case endMm = "end_mm"
      case style
      case kind
    }

    init(
      startMm: OutputPointMm, endMm: OutputPointMm, style: OutputLayerStyle, kind: OutputStrokeKind
    ) {
      self.startMm = startMm
      self.endMm = endMm
      self.style = style
      self.kind = kind
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      startMm = try container.decode(OutputPointMm.self, forKey: .startMm)
      endMm = try container.decode(OutputPointMm.self, forKey: .endMm)
      style = try container.decode(OutputLayerStyle.self, forKey: .style)
      kind = try container.decode(OutputStrokeKind.self, forKey: .kind)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(startMm, forKey: .startMm)
      try container.encode(endMm, forKey: .endMm)
      try container.encode(style, forKey: .style)
      try container.encode(kind, forKey: .kind)
    }
  }

  private struct StrokeCirclePayload: Codable {
    let centerMm: OutputPointMm
    let radiusMm: Double
    let style: OutputLayerStyle

    private enum CodingKeys: String, CodingKey {
      case centerMm = "center_mm"
      case radiusMm = "radius_mm"
      case style
    }

    init(centerMm: OutputPointMm, radiusMm: Double, style: OutputLayerStyle) {
      self.centerMm = centerMm
      self.radiusMm = radiusMm
      self.style = style
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      centerMm = try container.decode(OutputPointMm.self, forKey: .centerMm)
      radiusMm = try container.decode(Double.self, forKey: .radiusMm)
      style = try container.decode(OutputLayerStyle.self, forKey: .style)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(centerMm, forKey: .centerMm)
      try container.encode(radiusMm, forKey: .radiusMm)
      try container.encode(style, forKey: .style)
    }
  }

  private struct StrokeArcPayload: Codable {
    let centerMm: OutputPointMm
    let radiusMm: Double
    let startAngleRad: Double
    let sweepAngleRad: Double
    let style: OutputLayerStyle

    private enum CodingKeys: String, CodingKey {
      case centerMm = "center_mm"
      case radiusMm = "radius_mm"
      case startAngleRad = "start_angle_rad"
      case sweepAngleRad = "sweep_angle_rad"
      case style
    }

    init(
      centerMm: OutputPointMm, radiusMm: Double, startAngleRad: Double, sweepAngleRad: Double,
      style: OutputLayerStyle
    ) {
      self.centerMm = centerMm
      self.radiusMm = radiusMm
      self.startAngleRad = startAngleRad
      self.sweepAngleRad = sweepAngleRad
      self.style = style
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      centerMm = try container.decode(OutputPointMm.self, forKey: .centerMm)
      radiusMm = try container.decode(Double.self, forKey: .radiusMm)
      startAngleRad = try container.decode(Double.self, forKey: .startAngleRad)
      sweepAngleRad = try container.decode(Double.self, forKey: .sweepAngleRad)
      style = try container.decode(OutputLayerStyle.self, forKey: .style)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(centerMm, forKey: .centerMm)
      try container.encode(radiusMm, forKey: .radiusMm)
      try container.encode(startAngleRad, forKey: .startAngleRad)
      try container.encode(sweepAngleRad, forKey: .sweepAngleRad)
      try container.encode(style, forKey: .style)
    }
  }

  private struct DrawPointPayload: Codable {
    let centerMm: OutputPointMm
    let style: OutputLayerStyle

    private enum CodingKeys: String, CodingKey {
      case centerMm = "center_mm"
      case style
    }

    init(centerMm: OutputPointMm, style: OutputLayerStyle) {
      self.centerMm = centerMm
      self.style = style
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      centerMm = try container.decode(OutputPointMm.self, forKey: .centerMm)
      style = try container.decode(OutputLayerStyle.self, forKey: .style)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(centerMm, forKey: .centerMm)
      try container.encode(style, forKey: .style)
    }
  }

  private struct DrawTextPayload: Codable {
    let positionMm: OutputPointMm
    let content: String
    let kind: OutputTextKind
    let fontSizeMm: Double

    private enum CodingKeys: String, CodingKey {
      case positionMm = "position_mm"
      case content
      case kind
      case fontSizeMm = "font_size_mm"
    }

    init(positionMm: OutputPointMm, content: String, kind: OutputTextKind, fontSizeMm: Double) {
      self.positionMm = positionMm
      self.content = content
      self.kind = kind
      self.fontSizeMm = fontSizeMm
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      positionMm = try container.decode(OutputPointMm.self, forKey: .positionMm)
      content = try container.decode(String.self, forKey: .content)
      kind = try container.decode(OutputTextKind.self, forKey: .kind)
      fontSizeMm = try container.decode(Double.self, forKey: .fontSizeMm)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(positionMm, forKey: .positionMm)
      try container.encode(content, forKey: .content)
      try container.encode(kind, forKey: .kind)
      try container.encode(fontSizeMm, forKey: .fontSizeMm)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .kind) {
    case .strokeLine:
      let payload = try container.decode(StrokeLinePayload.self, forKey: .payload)
      self = .strokeLine(
        startMm: payload.startMm, endMm: payload.endMm, style: payload.style, kind: payload.kind)
    case .strokeCircle:
      let payload = try container.decode(StrokeCirclePayload.self, forKey: .payload)
      self = .strokeCircle(
        centerMm: payload.centerMm, radiusMm: payload.radiusMm, style: payload.style)
    case .strokeArc:
      let payload = try container.decode(StrokeArcPayload.self, forKey: .payload)
      self = .strokeArc(
        centerMm: payload.centerMm,
        radiusMm: payload.radiusMm,
        startAngleRad: payload.startAngleRad,
        sweepAngleRad: payload.sweepAngleRad,
        style: payload.style
      )
    case .drawPoint:
      let payload = try container.decode(DrawPointPayload.self, forKey: .payload)
      self = .drawPoint(centerMm: payload.centerMm, style: payload.style)
    case .drawText:
      let payload = try container.decode(DrawTextPayload.self, forKey: .payload)
      self = .drawText(
        positionMm: payload.positionMm,
        content: payload.content,
        kind: payload.kind,
        fontSizeMm: payload.fontSizeMm
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .strokeLine(let startMm, let endMm, let style, let kind):
      try container.encode(Kind.strokeLine, forKey: .kind)
      try container.encode(
        StrokeLinePayload(startMm: startMm, endMm: endMm, style: style, kind: kind),
        forKey: .payload)
    case .strokeCircle(let centerMm, let radiusMm, let style):
      try container.encode(Kind.strokeCircle, forKey: .kind)
      try container.encode(
        StrokeCirclePayload(centerMm: centerMm, radiusMm: radiusMm, style: style), forKey: .payload)
    case .strokeArc(let centerMm, let radiusMm, let startAngleRad, let sweepAngleRad, let style):
      try container.encode(Kind.strokeArc, forKey: .kind)
      try container.encode(
        StrokeArcPayload(
          centerMm: centerMm,
          radiusMm: radiusMm,
          startAngleRad: startAngleRad,
          sweepAngleRad: sweepAngleRad,
          style: style
        ),
        forKey: .payload
      )
    case .drawPoint(let centerMm, let style):
      try container.encode(Kind.drawPoint, forKey: .kind)
      try container.encode(DrawPointPayload(centerMm: centerMm, style: style), forKey: .payload)
    case .drawText(let positionMm, let content, let kind, let fontSizeMm):
      try container.encode(Kind.drawText, forKey: .kind)
      try container.encode(
        DrawTextPayload(
          positionMm: positionMm, content: content, kind: kind, fontSizeMm: fontSizeMm),
        forKey: .payload
      )
    }
  }
}

public struct OutputPrintRenderPage: Codable, Equatable {
  public let widthMm: Double
  public let heightMm: Double
  public let rotationDeg: Int
  public let printableAreaMm: OutputPrintableAreaMm
  public let clipAreaMm: OutputPrintableAreaMm?
  public let commands: [OutputPrintRenderCommand]

  public init(
    widthMm: Double,
    heightMm: Double,
    rotationDeg: Int,
    printableAreaMm: OutputPrintableAreaMm,
    commands: [OutputPrintRenderCommand],
    clipAreaMm: OutputPrintableAreaMm? = nil
  ) {
    self.widthMm = widthMm
    self.heightMm = heightMm
    self.rotationDeg = rotationDeg
    self.printableAreaMm = printableAreaMm
    self.clipAreaMm = clipAreaMm
    self.commands = commands
  }
}

public struct OutputPrintRenderData: Codable, Equatable {
  public let orientation: OutputPrintOrientation
  public let pages: [OutputPrintRenderPage]

  public init(orientation: OutputPrintOrientation, pages: [OutputPrintRenderPage]) {
    self.orientation = orientation
    self.pages = pages
  }
}

public enum OutputDirectPrintCaptureResult: Equatable {
  case cancelled
  case ready(OutputDirectPrintSession)
}

public struct OutputPreparedDirectPrintSession: Equatable {
  public let session: OutputDirectPrintSession
  public let buildOptions: OutputBuildOptions

  public init(session: OutputDirectPrintSession, buildOptions: OutputBuildOptions) {
    self.session = session
    self.buildOptions = buildOptions
  }
}

public protocol OutputSession {
  func buildOutputDocumentModel(options: OutputBuildOptions) -> OutputResult<OutputBuildResult>
  func renderPDF(outputDocumentModel: OutputDocumentModel) -> OutputResult<Data>
  func renderPrint(outputDocumentModel: OutputDocumentModel) -> OutputResult<OutputPrintRenderData>
}

public protocol PrintControlling {
  func makeOutputBuildOptions(presentation: OutputPresentationOptions) -> OutputResult<
    OutputBuildOptions
  >
  func captureDirectPrintSession(
    presentation: OutputPresentationOptions
  ) -> OutputResult<OutputDirectPrintCaptureResult>
  func prepareDirectPrintSession(
    presentation: OutputPresentationOptions,
    session: OutputDirectPrintSession
  ) -> OutputResult<OutputPreparedDirectPrintSession>
  func runDirectPrint(
    renderData: OutputPrintRenderData,
    session: OutputDirectPrintSession,
    documentName: String
  ) -> OutputResult<Void>
}
