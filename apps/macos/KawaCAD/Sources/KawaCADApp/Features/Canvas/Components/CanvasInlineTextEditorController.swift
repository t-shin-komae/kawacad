import AppKit

/// Coordinates the AppKit text editor overlaid on the canvas.
///
/// The canvas supplies geometry and domain callbacks, while this object owns
/// editor lifecycle, delegate events, and committing user input.
struct CanvasInlineTextEditorContext {
  let freeTexts: [ProjectFreeText]
  let isOutputPreviewMode: Bool
  let requestedFreeTextID: String?
  let editorFrame: (ProjectFreeText) -> CGRect
  let fontSize: (ProjectFreeText) -> CGFloat
  let updateFreeText: (ProjectFreeText) -> Bool
  let requestHandled: (String) -> Void
}

final class CanvasInlineTextEditorController: NSObject, NSTextViewDelegate {
  private var editor: NSTextView?
  private(set) var editingID: String?
  private var context: CanvasInlineTextEditorContext?

  var isEditing: Bool { editor != nil }

  func sync(context: CanvasInlineTextEditorContext, in hostView: NSView) {
    self.context = context
    guard !context.isOutputPreviewMode,
      let requestedID = context.requestedFreeTextID,
      editingID != requestedID,
      let freeText = context.freeTexts.first(where: { $0.id == requestedID })
    else {
      return
    }
    beginEditing(freeText, context: context, in: hostView)
    context.requestHandled(requestedID)
  }

  func reconcile(context: CanvasInlineTextEditorContext, in hostView: NSView) {
    self.context = context
    guard let editingID else { return }
    if context.isOutputPreviewMode {
      endEditing(commit: true, in: hostView)
    } else if !context.freeTexts.contains(where: { $0.id == editingID }) {
      endEditing(commit: false, in: hostView)
    }
  }

  func beginEditing(
    _ freeText: ProjectFreeText,
    context: CanvasInlineTextEditorContext,
    in hostView: NSView
  ) {
    endEditing(commit: true, in: hostView)
    self.context = context

    let editor = NSTextView(frame: context.editorFrame(freeText))
    editor.string = freeText.content
    editor.font = NSFont.systemFont(ofSize: context.fontSize(freeText))
    editor.textColor = NSColor(LeatherColors.ink)
    editor.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.94)
    editor.drawsBackground = true
    editor.isRichText = false
    editor.isAutomaticQuoteSubstitutionEnabled = false
    editor.isAutomaticDashSubstitutionEnabled = false
    editor.allowsUndo = true
    editor.delegate = self
    editor.textContainerInset = NSSize(width: 4, height: 3)
    editor.textContainer?.widthTracksTextView = true
    editor.textContainer?.containerSize = NSSize(
      width: editor.bounds.width - 8, height: .greatestFiniteMagnitude)
    editor.minSize = NSSize(width: 80, height: editor.bounds.height)
    editor.maxSize = NSSize(width: hostView.bounds.width, height: .greatestFiniteMagnitude)
    editor.isHorizontallyResizable = false
    editor.isVerticallyResizable = true
    editor.autoresizingMask = []
    editor.wantsLayer = true
    editor.layer?.cornerRadius = 4
    editor.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.75).cgColor
    editor.layer?.borderWidth = 1

    editingID = freeText.id
    self.editor = editor
    hostView.addSubview(editor)
    hostView.window?.makeFirstResponder(editor)
    editor.selectAll(nil)
    hostView.needsDisplay = true
  }

  func endEditing(commit: Bool, in hostView: NSView) {
    guard let editor, let editingID else { return }
    let freeText = context?.freeTexts.first(where: { $0.id == editingID })
    self.editor = nil
    self.editingID = nil
    editor.delegate = nil
    editor.removeFromSuperview()
    if commit, let freeText, editor.string != freeText.content {
      _ = context?.updateFreeText(freeText.withContent(editor.string))
    }
    hostView.needsDisplay = true
  }

  func textDidChange(_ notification: Notification) {
    guard let editor = notification.object as? NSTextView,
      editor == self.editor,
      let editingID,
      let context,
      let freeText = context.freeTexts.first(where: { $0.id == editingID })
    else {
      return
    }
    editor.frame = context.editorFrame(freeText.withContent(editor.string))
  }

  func textDidEndEditing(_ notification: Notification) {
    guard notification.object as? NSTextView == editor,
      let hostView = editor?.superview
    else {
      return
    }
    endEditing(commit: true, in: hostView)
  }
}
