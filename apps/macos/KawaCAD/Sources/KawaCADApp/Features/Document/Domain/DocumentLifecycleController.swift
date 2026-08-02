import AppKit

protocol DocumentLifecycleControlling: AnyObject {
  func continueClosingWindow()
  func replyToApplicationTermination(_ shouldTerminate: Bool)
}

final class DocumentLifecycleController: NSObject, DocumentLifecycleControlling, NSWindowDelegate {
  var requestWindowClose: () -> Bool = { true }
  var requestApplicationQuit: () -> Bool = { true }

  private weak var observedWindow: NSWindow?
  private var bypassNextWindowClose = false
  private var terminateReplyPending = false
  private var sheetEndObserver: NSObjectProtocol?

  deinit {
    removeSheetEndObserver()
  }

  func attach(window: NSWindow) {
    guard observedWindow !== window else {
      return
    }
    observedWindow = window
    window.delegate = self
  }

  func updateWindowPresentation(
    title: String,
    accessibilityLabel: String,
    representedURL: URL?,
    isDocumentEdited: Bool
  ) {
    observedWindow?.title = title
    observedWindow?.representedURL = representedURL
    observedWindow?.setAccessibilityLabel(accessibilityLabel)
    observedWindow?.isDocumentEdited = isDocumentEdited
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    if bypassNextWindowClose {
      bypassNextWindowClose = false
      return true
    }
    return requestWindowClose()
  }

  func continueClosingWindow() {
    guard let observedWindow else {
      return
    }
    if observedWindow.attachedSheet != nil {
      waitForAttachedSheetToClose(on: observedWindow)
    } else {
      closeObservedWindow()
    }
  }

  func applicationShouldTerminate() -> NSApplication.TerminateReply {
    if requestApplicationQuit() {
      return .terminateNow
    }
    terminateReplyPending = true
    return .terminateLater
  }

  func replyToApplicationTermination(_ shouldTerminate: Bool) {
    guard terminateReplyPending else {
      return
    }
    terminateReplyPending = false
    NSApp.reply(toApplicationShouldTerminate: shouldTerminate)
  }

  private func waitForAttachedSheetToClose(on window: NSWindow) {
    removeSheetEndObserver()
    sheetEndObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didEndSheetNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self, notification.object as? NSWindow === window else {
        return
      }
      self.removeSheetEndObserver()
      self.closeObservedWindow()
    }
  }

  private func closeObservedWindow() {
    guard let observedWindow else {
      return
    }
    // The user has already confirmed the destructive close. Close the
    // window directly rather than starting another close-request cycle.
    bypassNextWindowClose = true
    observedWindow.close()
    bypassNextWindowClose = false
  }

  private func removeSheetEndObserver() {
    guard let sheetEndObserver else {
      return
    }
    NotificationCenter.default.removeObserver(sheetEndObserver)
    self.sheetEndObserver = nil
  }
}
