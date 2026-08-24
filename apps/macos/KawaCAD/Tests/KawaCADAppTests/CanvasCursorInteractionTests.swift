import AppKit
import Testing

@testable import KawaCADApp

@Test("AppKitのカーソル更新だけでも図形上の開いた手を再取得する")
@MainActor
func appKit_cursor_updates_reacquire_select_target() {
  let inputs = CanvasTestInputBuilder()
  inputs.entities = [
    lineEntity(
      id: "entity:cursor-line",
      start: .zero,
      end: ModelPoint(xMM: 20, yMM: 0)
    )
  ]
  inputs.layers = defaultLayers()
  inputs.selectedTool = .select

  let view = inputs.makeView(frame: NSRect(x: 0, y: 0, width: 520, height: 736))
  let pageRect = view.pageRect(in: view.bounds)
  let linePoint = view.canvasPoint(for: ModelPoint(xMM: 10, yMM: 0), in: pageRect)
  let event = NSEvent.mouseEvent(
    with: .mouseMoved,
    location: linePoint,
    modifierFlags: [],
    timestamp: 0,
    windowNumber: 0,
    context: nil,
    eventNumber: 0,
    clickCount: 1,
    pressure: 1
  )
  #expect(event != nil)

  let previousCursor = NSCursor.current
  defer { previousCursor.set() }

  view.cursorUpdate(with: event!)
  #expect(NSCursor.current === NSCursor.openHand)

  NSCursor.arrow.set()
  view.resetCursorRects()
  #expect(NSCursor.current === NSCursor.openHand)
}

@Test("カーソル更新中のSwiftUI再構成後も開いた手を維持する")
@MainActor
func appKit_cursor_stays_after_state_reconfiguration_during_mouse_move() {
  let inputs = CanvasTestInputBuilder()
  inputs.entities = [
    lineEntity(
      id: "entity:cursor-reconfigure-line",
      start: .zero,
      end: ModelPoint(xMM: 20, yMM: 0)
    )
  ]
  inputs.layers = defaultLayers()
  inputs.selectedTool = .select

  let view = inputs.makeView(frame: NSRect(x: 0, y: 0, width: 520, height: 736))
  let pageRect = view.pageRect(in: view.bounds)
  let linePoint = view.canvasPoint(for: ModelPoint(xMM: 10, yMM: 0), in: pageRect)
  let event = NSEvent.mouseEvent(
    with: .mouseMoved,
    location: linePoint,
    modifierFlags: [],
    timestamp: 0,
    windowNumber: 0,
    context: nil,
    eventNumber: 0,
    clickCount: 1,
    pressure: 1
  )
  #expect(event != nil)

  inputs.onCursorPoint = { _, _ in
    inputs.syncForTest()
  }
  let previousCursor = NSCursor.current
  defer { previousCursor.set() }

  view.mouseMoved(with: event!)
  #expect(NSCursor.current === NSCursor.openHand)

  view.resetCursorRects()
  #expect(NSCursor.current === NSCursor.openHand)
}

@Test("実ウィンドウのカーソル矩形再構築後も開いた手を維持する")
@MainActor
func appKit_window_cursor_stays_on_select_target_after_cursor_rect_reset() {
  let inputs = CanvasTestInputBuilder()
  inputs.entities = [
    lineEntity(
      id: "entity:cursor-window-line",
      start: .zero,
      end: ModelPoint(xMM: 20, yMM: 0)
    )
  ]
  inputs.layers = defaultLayers()
  inputs.selectedTool = .select

  let view = inputs.makeView(frame: NSRect(x: 0, y: 0, width: 520, height: 736))
  let window = NSWindow(
    contentRect: view.frame,
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
  )
  window.isReleasedWhenClosed = false
  window.contentView = view
  window.makeKeyAndOrderFront(nil)
  NSApp.activate(ignoringOtherApps: true)
  defer {
    window.orderOut(nil)
    window.close()
  }

  let pageRect = view.pageRect(in: view.bounds)
  let linePoint = view.canvasPoint(for: ModelPoint(xMM: 10, yMM: 0), in: pageRect)
  let event = NSEvent.mouseEvent(
    with: .mouseMoved,
    location: linePoint,
    modifierFlags: [],
    timestamp: 0,
    windowNumber: window.windowNumber,
    context: nil,
    eventNumber: 1,
    clickCount: 1,
    pressure: 1
  )
  #expect(event != nil)

  let previousCursor = NSCursor.current
  defer { previousCursor.set() }

  view.updateTrackingAreas()
  view.mouseMoved(with: event!)
  RunLoop.main.run(until: Date().addingTimeInterval(0.05))
  #expect(NSCursor.current === NSCursor.openHand)

  NSCursor.arrow.set()
  view.updateTrackingAreas()
  view.resetCursorRects()
  window.invalidateCursorRects(for: view)
  RunLoop.main.run(until: Date().addingTimeInterval(0.05))
  #expect(NSCursor.current === NSCursor.openHand)
}

@Test("キャンバス再進入なしのツール切替で開いた手へ更新する")
@MainActor
func appKit_cursor_updates_when_select_tool_changes_under_stationary_pointer() {
  let inputs = CanvasTestInputBuilder()
  inputs.entities = [
    lineEntity(
      id: "entity:cursor-tool-switch-line",
      start: .zero,
      end: ModelPoint(xMM: 20, yMM: 0)
    )
  ]
  inputs.layers = defaultLayers()
  inputs.selectedTool = .line

  let view = inputs.makeView(frame: NSRect(x: 0, y: 0, width: 520, height: 736))
  let window = NSWindow(
    contentRect: view.frame,
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
  )
  window.isReleasedWhenClosed = false
  window.contentView = view
  window.makeKeyAndOrderFront(nil)
  NSApp.activate(ignoringOtherApps: true)
  defer {
    window.orderOut(nil)
    window.close()
  }

  let pageRect = view.pageRect(in: view.bounds)
  let linePoint = view.canvasPoint(for: ModelPoint(xMM: 10, yMM: 0), in: pageRect)
  let event = NSEvent.mouseEvent(
    with: .mouseMoved,
    location: linePoint,
    modifierFlags: [],
    timestamp: 0,
    windowNumber: window.windowNumber,
    context: nil,
    eventNumber: 2,
    clickCount: 1,
    pressure: 1
  )
  #expect(event != nil)

  let previousCursor = NSCursor.current
  defer { previousCursor.set() }

  view.mouseMoved(with: event!)
  #expect(NSCursor.current === NSCursor.crosshair)

  inputs.selectedTool = .select
  RunLoop.main.run(until: Date().addingTimeInterval(0.05))
  #expect(NSCursor.current === NSCursor.openHand)

  window.invalidateCursorRects(for: view)
  RunLoop.main.run(until: Date().addingTimeInterval(0.05))
  #expect(NSCursor.current === NSCursor.openHand)
}
