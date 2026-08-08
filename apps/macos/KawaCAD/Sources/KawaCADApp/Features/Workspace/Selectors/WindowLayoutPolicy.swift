import CoreGraphics
import Foundation

enum WindowLayoutMode: Equatable {
  case compact
  case regular
  case wide
}

struct WindowLayoutPolicy: Equatable {
  static let minimumWindowWidth: CGFloat = 1024
  static let minimumInspectorContentWidth: CGFloat = 440
  static let maximumInspectorWidth: CGFloat = 520
  static let canvasMinimumWidth: CGFloat = 640
  static let panelResizeHandleWidth: CGFloat = 8
  static let regularMinimumWorkspaceWidth: CGFloat = 860
  // The toolbar chooses its own wide/regular presentation from the actual
  // available space, so this threshold only needs the docked workspace.
  static let wideMinimumWorkspaceWidth: CGFloat =
    canvasMinimumWidth + panelResizeHandleWidth + minimumInspectorContentWidth
  static let hysteresis: CGFloat = 24

  let mode: WindowLayoutMode
  let workspaceWidth: CGFloat
  let toolDockVisible: Bool
  let toolDockWidth: CGFloat
  let inspectorDockWidth: CGFloat
  let overlayInspectorWidth: CGFloat
  let compactToolDrawerWidth: CGFloat
  let compactInspectorDrawerWidth: CGFloat

  static func make(
    contentWidth: CGFloat,
    storedToolWidth: CGFloat,
    storedInspectorWidth: CGFloat,
    previousMode: WindowLayoutMode? = nil
  ) -> WindowLayoutPolicy {
    let potentialToolDockWidth = snappedToolWidth(storedToolWidth, for: .wide)
    let workspaceWidthWithToolDock = contentWidth - potentialToolDockWidth - panelResizeHandleWidth
    let mode = resolveMode(
      workspaceWidth: workspaceWidthWithToolDock,
      previousMode: previousMode
    )
    let toolDockWidth = snappedToolWidth(storedToolWidth, for: mode)
    let toolDockVisible = mode != .compact
    let workspaceWidth =
      contentWidth - (toolDockVisible ? toolDockWidth + panelResizeHandleWidth : 0)
    let inspectorDockRange = inspectorDockWidthRange
    let overlayMax = min(
      maximumInspectorWidth,
      max(minimumInspectorContentWidth, contentWidth * 0.36)
    )

    return WindowLayoutPolicy(
      mode: mode,
      workspaceWidth: workspaceWidth,
      toolDockVisible: toolDockVisible,
      toolDockWidth: toolDockWidth,
      inspectorDockWidth: clamp(
        storedInspectorWidth,
        within: inspectorDockRange,
        defaultValue: minimumInspectorContentWidth
      ),
      overlayInspectorWidth: min(
        clamp(
          storedInspectorWidth,
          within: minimumInspectorContentWidth...maximumInspectorWidth,
          defaultValue: minimumInspectorContentWidth
        ),
        overlayMax
      ),
      compactToolDrawerWidth: 260,
      compactInspectorDrawerWidth: minimumInspectorContentWidth
    )
  }

  static func toolWidthRange(for mode: WindowLayoutMode) -> ClosedRange<CGFloat> {
    switch mode {
    case .wide:
      return 176...260
    case .regular, .compact:
      return 176...240
    }
  }

  /// Keep the one-column palette at its stable minimum while resizing. The
  /// second column appears only after the fixed threshold, so SwiftUI does not
  /// repeatedly remeasure rows around the transition.
  static func snappedToolWidth(_ proposedWidth: CGFloat, for mode: WindowLayoutMode) -> CGFloat {
    let range = toolWidthRange(for: mode)
    let clampedWidth = clamp(proposedWidth, within: range, defaultValue: range.lowerBound)
    guard clampedWidth >= 220 else { return range.lowerBound }
    return range.upperBound
  }

  static let inspectorDockWidthRange: ClosedRange<CGFloat> =
    minimumInspectorContentWidth...maximumInspectorWidth

  static func constrainedWindowWidth(_ proposedWidth: CGFloat, visibleScreenWidth: CGFloat)
    -> CGFloat
  {
    guard proposedWidth.isFinite, visibleScreenWidth.isFinite, visibleScreenWidth > 0 else {
      return proposedWidth
    }
    let minimumWidth = min(minimumWindowWidth, visibleScreenWidth)
    return min(max(proposedWidth, minimumWidth), visibleScreenWidth)
  }

  private static func resolveMode(
    workspaceWidth: CGFloat,
    previousMode: WindowLayoutMode?
  ) -> WindowLayoutMode {
    guard let previousMode else {
      switch workspaceWidth {
      case ..<regularMinimumWorkspaceWidth:
        return .compact
      case ..<wideMinimumWorkspaceWidth:
        return .regular
      default:
        return .wide
      }
    }

    switch previousMode {
    case .compact:
      return workspaceWidth >= regularMinimumWorkspaceWidth + hysteresis ? .regular : .compact
    case .regular:
      if workspaceWidth < regularMinimumWorkspaceWidth - hysteresis {
        return .compact
      }
      if workspaceWidth >= wideMinimumWorkspaceWidth + hysteresis {
        return .wide
      }
      return .regular
    case .wide:
      // Never let hysteresis retain a docked layout below the hard
      // minimum needed by its canvas, resize handle, and inspector.
      return workspaceWidth < wideMinimumWorkspaceWidth ? .regular : .wide
    }
  }

  private static func clamp(
    _ value: CGFloat,
    within range: ClosedRange<CGFloat>,
    defaultValue: CGFloat
  ) -> CGFloat {
    guard value.isFinite else {
      return defaultValue
    }
    return min(max(value, range.lowerBound), range.upperBound)
  }
}
