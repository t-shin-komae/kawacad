import AppKit
import Foundation
import Testing

@testable import KawaCADApp

@Test("UI統合回帰 UC1 アプリ起動時に regular app として前面化する")
@MainActor
func ui_bootstrap_uc1_application_delegate_promotes_menu_bar_app() {
  let appDelegate = KawaCADAppDelegate()
  var activationPolicies: [NSApplication.ActivationPolicy] = []
  var activationCallCount = 0

  appDelegate.setActivationPolicy = { activationPolicies.append($0) }
  appDelegate.activateApplication = { activationCallCount += 1 }

  appDelegate.applicationDidFinishLaunching(
    Notification(name: NSApplication.didFinishLaunchingNotification))
  appDelegate.applicationDidBecomeActive(
    Notification(name: NSApplication.didBecomeActiveNotification))

  #expect(activationPolicies == [.regular])
  #expect(activationCallCount == 2)
}

@Test("UC1 AppDelegate は最後のウィンドウを閉じるとアプリ終了を要求する")
@MainActor
func ui_bootstrap_uc1_application_delegate_terminates_after_last_window_closed() {
  let appDelegate = KawaCADAppDelegate()

  #expect(appDelegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
}

@Test("UC1 AppDelegate は dirty 終了要求を terminateLater で保留できる")
@MainActor
func ui_bootstrap_uc1_application_delegate_can_defer_termination() {
  let appDelegate = KawaCADAppDelegate()
  appDelegate.documentLifecycleController.requestApplicationQuit = { false }

  #expect(appDelegate.applicationShouldTerminate(NSApplication.shared) == .terminateLater)
  appDelegate.documentLifecycleController.replyToApplicationTermination(false)
}
