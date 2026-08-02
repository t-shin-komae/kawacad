import AppKit
import SwiftUI

/// Isolates NSWindow mutations from the SwiftUI workspace presentation tree.
struct WindowStateBridge: NSViewRepresentable {
  let title: String
  let accessibilityLabel: String
  let representedURL: URL?
  let isDocumentEdited: Bool
  var lifecycleController: (any DocumentLifecycleControlling)?

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      updateWindow(for: view)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async {
      updateWindow(for: nsView)
    }
  }

  private func updateWindow(for view: NSView) {
    guard let window = view.window,
      let lifecycleController = lifecycleController as? DocumentLifecycleController
    else {
      return
    }
    constrainWindowWidthToVisibleScreen(window)
    lifecycleController.attach(window: window)
    lifecycleController.updateWindowPresentation(
      title: title,
      accessibilityLabel: accessibilityLabel,
      representedURL: representedURL,
      isDocumentEdited: isDocumentEdited
    )
  }

  private func constrainWindowWidthToVisibleScreen(_ window: NSWindow) {
    guard let visibleFrame = window.screen?.visibleFrame else {
      return
    }
    window.minSize.width = min(WindowLayoutPolicy.minimumWindowWidth, visibleFrame.width)
    let constrainedWidth = WindowLayoutPolicy.constrainedWindowWidth(
      window.frame.width,
      visibleScreenWidth: visibleFrame.width
    )
    guard constrainedWidth != window.frame.width else {
      return
    }
    var frame = window.frame
    frame.size.width = constrainedWidth
    frame.origin.x = visibleFrame.minX
    window.setFrame(frame, display: true)
  }
}
