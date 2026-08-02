import CoreGraphics

struct ClipboardBundle: Equatable {
  /// Core が所有し、UI は内容を解釈しない選択スナップショット。
  let clipboardJSON: String
  let anchorPoint: ModelPoint?
  let bounds: ModelBounds?
  let selectionCount: Int

  init(export: SelectionClipboardExport) {
    clipboardJSON = export.clipboardJson
    anchorPoint = export.anchorPoint?.modelPoint
    bounds = export.bounds.map(ModelBounds.init)
    selectionCount = export.rootCount
  }

  var isEmpty: Bool { clipboardJSON.isEmpty }
  var rootCount: Int { selectionCount }
}

struct ModelBounds: Equatable {
  let minPoint: ModelPoint
  let maxPoint: ModelPoint

  init(minPoint: ModelPoint, maxPoint: ModelPoint) {
    self.minPoint = minPoint
    self.maxPoint = maxPoint
  }

  init(_ bounds: CoreBounds) {
    minPoint = bounds.minPoint.modelPoint
    maxPoint = bounds.maxPoint.modelPoint
  }

  func translatedBy(dxMM: Double, dyMM: Double) -> ModelBounds {
    ModelBounds(
      minPoint: minPoint.translatedBy(dxMM: dxMM, dyMM: dyMM),
      maxPoint: maxPoint.translatedBy(dxMM: dxMM, dyMM: dyMM)
    )
  }

  func intersects(_ other: ModelBounds) -> Bool {
    minPoint.xMM <= other.maxPoint.xMM && maxPoint.xMM >= other.minPoint.xMM
      && minPoint.yMM <= other.maxPoint.yMM && maxPoint.yMM >= other.minPoint.yMM
  }
}

enum PastePlacementMode: String, Equatable {
  case cursor
  case nearSource
}

/// Presentation-only state for the brief choice shown after a paste.
struct PasteOptionsPresentation: Equatable {
  let clipboard: ClipboardBundle
  let sourceAnchor: ModelPoint
  let pasteNamespace: String
  let cursorPoint: ModelPoint?
  let canvasPoint: CGPoint?
  let nearSourcePoint: ModelPoint
  let activeMode: PastePlacementMode
}
