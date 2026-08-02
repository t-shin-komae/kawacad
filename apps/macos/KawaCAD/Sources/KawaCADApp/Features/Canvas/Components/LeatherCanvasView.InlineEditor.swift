import AppKit
import KawaCADOutput
import SwiftUI

/// Rendering responsibilities extracted from the input-oriented canvas view.
/// The view still owns lifecycle and callbacks; this extension owns the
/// projection of the current immutable canvas snapshot into AppKit drawing.
extension LeatherCanvasView {
  func freeText(at point: CGPoint, in pageRect: CGRect) -> ProjectFreeText? {
    let coordinateSpace = coordinateSpace(in: pageRect)
    return freeTexts.reversed().first { freeText in
      let origin = coordinateSpace.canvasPoint(for: freeText.positionMM)
      let fontSize = max(9.0, freeText.fontSizeMM * coordinateSpace.scale)
      let attributed = NSAttributedString(
        string: freeText.content,
        attributes: [.font: NSFont.systemFont(ofSize: fontSize)]
      )
      let size = attributed.size()
      let rect = CGRect(
        x: origin.x - 5,
        y: origin.y - 5,
        width: size.width + 10,
        height: size.height + 10
      )
      return rect.contains(point)
    }
  }

  func syncInlineFreeTextEditorWithRequest() {
    inlineFreeTextEditor.sync(context: inlineTextEditorContext(in: pageRect(in: bounds)), in: self)
  }

  func reconcileInlineFreeTextEditorState() {
    inlineFreeTextEditor.reconcile(
      context: inlineTextEditorContext(in: pageRect(in: bounds)), in: self)
  }

  /// Compatibility entry point for canvas interaction tests and callers.
  /// Editor ownership remains in `CanvasInlineTextEditorController`.
  func endInlineFreeTextEditing(commit: Bool) {
    inlineFreeTextEditor.endEditing(commit: commit, in: self)
  }

  func displayFreeText(_ freeText: ProjectFreeText) -> ProjectFreeText {
    guard let dragState = freeTextDragState,
      dragState.freeTextID == freeText.id
    else {
      return freeText
    }
    let delta = CanvasInteractionState.delta(from: dragState.startPoint, to: dragState.currentPoint)
    return freeText.withPosition(freeText.positionMM.translatedBy(dxMM: delta.xMM, dyMM: delta.yMM))
  }

  var selectedFreeText: ProjectFreeText? {
    selectedFreeTextID.flatMap { selectedID in
      freeTexts.first(where: { $0.id == selectedID })
    }
  }

  var contextMenuFreeText: ProjectFreeText? {
    contextMenuFreeTextID.flatMap { freeTextID in
      freeTexts.first(where: { $0.id == freeTextID })
    }
  }

  func inlineFreeTextEditorFrame(for freeText: ProjectFreeText, in pageRect: CGRect) -> CGRect {
    let coordinateSpace = coordinateSpace(in: pageRect)
    let point = coordinateSpace.canvasPoint(for: freeText.positionMM)
    let fontSize = max(9.0, freeText.fontSizeMM * coordinateSpace.scale)
    let attributed = NSAttributedString(
      string: freeText.content.isEmpty ? " " : freeText.content,
      attributes: [.font: NSFont.systemFont(ofSize: fontSize)]
    )
    let measuredSize = attributed.boundingRect(
      with: NSSize(
        width: max(180, bounds.width - point.x - 32), height: CGFloat.greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    ).size
    let width = min(max(180, ceil(measuredSize.width) + 18), max(180, bounds.maxX - point.x - 16))
    let height = min(
      max(fontSize + 14, ceil(measuredSize.height) + 12),
      max(fontSize + 14, bounds.maxY - point.y - 16))
    return CGRect(
      x: point.x - 4,
      y: point.y - 4,
      width: width,
      height: height
    )
  }

  func inlineTextEditorContext(in pageRect: CGRect) -> CanvasInlineTextEditorContext {
    CanvasInlineTextEditorContext(
      freeTexts: freeTexts,
      isOutputPreviewMode: isOutputPreviewMode,
      requestedFreeTextID: freeTextInlineEditRequestID,
      editorFrame: { [weak self] freeText in
        self?.inlineFreeTextEditorFrame(for: freeText, in: pageRect) ?? .zero
      },
      fontSize: { [weak self] freeText in
        guard let self else { return 9 }
        return max(9.0, freeText.fontSizeMM * self.coordinateSpace(in: pageRect).scale)
      },
      updateFreeText: { [weak self] freeText in
        self?.onUpdateFreeText?(freeText) ?? false
      },
      requestHandled: { [weak self] requestID in
        self?.onFreeTextInlineEditRequestHandled?(requestID)
      }
    )
  }

}
