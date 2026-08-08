import AppKit
import SwiftUI

@main
struct KawaCADApp: App {
  @NSApplicationDelegateAdaptor(KawaCADAppDelegate.self) private var appDelegate
  @StateObject private var appState = AppCoordinator(
    documentRecoveryConfiguration: .live()
  )

  var body: some Scene {
    WindowGroup {
      MainWindowView()
        .environmentObject(appState)
        .onAppear {
          appState.documentLifecycleController = appDelegate.documentLifecycleController
          appDelegate.documentLifecycleController.requestWindowClose = { [weak appState] in
            appState?.actions.document.requestWindowClose() ?? true
          }
          appDelegate.documentLifecycleController.requestApplicationQuit = { [weak appState] in
            appState?.actions.document.requestApplicationQuit() ?? true
          }
          appDelegate.didResignActive = { [weak appState] in
            appState?.actions.recovery.handleApplicationWillResignActive()
          }
          appState.actions.recovery.handleApplicationLaunch()
        }
    }
    .commands {
      KawaCADCommands(
        actions: appState.actions,
        cadSession: appState.cadSession,
        annotationSelection: appState.annotationSelection,
        canvasPresentation: appState.canvasPresentation,
        documentPresentation: appState.documentPresentation,
        inspectorPresentation: appState.inspectorPresentation,
        workspacePreferences: appState.workspacePreferences,
        workspaceLayout: appState.workspaceLayout
      )
    }
  }
}

final class KawaCADAppDelegate: NSObject, NSApplicationDelegate {
  let documentLifecycleController = DocumentLifecycleController()
  var didResignActive: () -> Void = {}

  var setApplicationIcon: () -> Void = {
    let packagedIconURL = Bundle.main.url(forResource: "KawaCAD", withExtension: "icns")
    let resourceBundleURL = Bundle.main.executableURL?
      .deletingLastPathComponent()
      .appendingPathComponent("KawaCAD_KawaCADApp.bundle", isDirectory: true)
    let developmentIconURL =
      resourceBundleURL
      .flatMap(Bundle.init(url:))?
      .url(forResource: "AppIcon", withExtension: "png")
    guard let iconURL = packagedIconURL ?? developmentIconURL,
      let icon = NSImage(contentsOf: iconURL)
    else { return }
    NSApp.applicationIconImage = icon
  }

  var setActivationPolicy: (NSApplication.ActivationPolicy) -> Void = {
    _ = NSApp.setActivationPolicy($0)
  }

  var activateApplication: () -> Void = {
    NSRunningApplication.current.activate(options: [
      .activateAllWindows, .activateIgnoringOtherApps,
    ])
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    setApplicationIcon()
    setActivationPolicy(.regular)
    activateApplication()
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    activateApplication()
  }

  func applicationWillResignActive(_ notification: Notification) {
    didResignActive()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    documentLifecycleController.applicationShouldTerminate()
  }
}
