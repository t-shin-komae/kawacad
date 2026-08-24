import AppKit
import Testing

@testable import KawaCADApp

@Suite(.serialized)
struct CanvasCursorInteractionTests {
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

  @Test("キャンバスを収容するウィンドウはマウス移動イベントを受け付ける")
  @MainActor
  func appKit_canvas_window_accepts_mouse_moved_events() {
    let inputs = CanvasTestInputBuilder()
    let view = inputs.makeView(frame: NSRect(x: 0, y: 0, width: 520, height: 736))
    let window = NSWindow(
      contentRect: view.frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.isReleasedWhenClosed = false
    defer { window.close() }

    #expect(window.acceptsMouseMovedEvents == false)
    window.contentView = view

    #expect(window.acceptsMouseMovedEvents)
  }

  @Test("同じ図形上の移動ではカーソル領域を繰り返し再構築しない")
  @MainActor
  func appKit_cursor_rects_are_invalidated_only_when_cursor_kind_changes() {
    let inputs = CanvasTestInputBuilder()
    inputs.entities = [
      lineEntity(
        id: "entity:stable-cursor-line",
        start: .zero,
        end: ModelPoint(xMM: 20, yMM: 0)
      )
    ]
    inputs.layers = defaultLayers()
    inputs.selectedTool = .select

    let view = inputs.makeView(frame: NSRect(x: 0, y: 0, width: 520, height: 736))
    let window = CursorInvalidationCountingWindow(
      contentRect: view.frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.isReleasedWhenClosed = false
    window.contentView = view
    defer { window.close() }

    let pageRect = view.pageRect(in: view.bounds)
    let firstLinePoint = view.canvasPoint(for: ModelPoint(xMM: 9, yMM: 0), in: pageRect)
    let firstEvent = NSEvent.mouseEvent(
      with: .mouseMoved,
      location: firstLinePoint,
      modifierFlags: [],
      timestamp: 0,
      windowNumber: window.windowNumber,
      context: nil,
      eventNumber: 3,
      clickCount: 1,
      pressure: 1
    )
    let secondLinePoint = view.canvasPoint(for: ModelPoint(xMM: 11, yMM: 0), in: pageRect)
    let secondEvent = NSEvent.mouseEvent(
      with: .mouseMoved,
      location: secondLinePoint,
      modifierFlags: [],
      timestamp: 0.1,
      windowNumber: window.windowNumber,
      context: nil,
      eventNumber: 4,
      clickCount: 1,
      pressure: 1
    )
    #expect(firstEvent != nil)
    #expect(secondEvent != nil)

    inputs.onCursorPoint = { _, _ in
      inputs.syncForTest()
    }
    window.cursorRectInvalidationCount = 0

    let previousCursor = NSCursor.current
    defer { previousCursor.set() }

    view.mouseMoved(with: firstEvent!)
    let invalidationCountAfterEnteringTarget = window.cursorRectInvalidationCount
    view.mouseMoved(with: secondEvent!)
    let invalidationCountAfterMovingWithinTarget = window.cursorRectInvalidationCount
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))

    #expect(invalidationCountAfterEnteringTarget > 0)
    #expect(invalidationCountAfterMovingWithinTarget == invalidationCountAfterEnteringTarget)
    #expect(NSCursor.current === NSCursor.openHand)
  }

  @Test("範囲選択は矢印のまま、図形移動中だけ閉じた手になる")
  @MainActor
  func appKit_cursor_closes_only_while_moving_canvas_content() {
    let inputs = CanvasTestInputBuilder()
    inputs.entities = [
      lineEntity(
        id: "entity:cursor-drag-line",
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
    defer { window.close() }

    let pageRect = view.pageRect(in: view.bounds)
    let blankPoint = view.canvasPoint(for: ModelPoint(xMM: 40, yMM: 40), in: pageRect)
    let linePoint = view.canvasPoint(for: ModelPoint(xMM: 10, yMM: 0), in: pageRect)
    let previousCursor = NSCursor.current
    defer { previousCursor.set() }

    view.mouseMoved(with: mouseEvent(.mouseMoved, at: blankPoint, in: window, eventNumber: 5))
    view.mouseDown(with: mouseEvent(.leftMouseDown, at: blankPoint, in: window, eventNumber: 6))
    #expect(NSCursor.current === NSCursor.arrow)

    view.interactionController.clearDragState()
    view.mouseMoved(with: mouseEvent(.mouseMoved, at: linePoint, in: window, eventNumber: 7))
    view.mouseDown(with: mouseEvent(.leftMouseDown, at: linePoint, in: window, eventNumber: 8))
    #expect(NSCursor.current === NSCursor.closedHand)
  }
}

@MainActor
private func mouseEvent(
  _ type: NSEvent.EventType,
  at point: CGPoint,
  in window: NSWindow,
  eventNumber: Int
) -> NSEvent {
  NSEvent.mouseEvent(
    with: type,
    location: point,
    modifierFlags: [],
    timestamp: 0,
    windowNumber: window.windowNumber,
    context: nil,
    eventNumber: eventNumber,
    clickCount: 1,
    pressure: 1
  )!
}

@MainActor
private final class CursorInvalidationCountingWindow: NSWindow {
  var cursorRectInvalidationCount = 0

  override func invalidateCursorRects(for view: NSView) {
    cursorRectInvalidationCount += 1
    super.invalidateCursorRects(for: view)
  }
}
