import CoreGraphics
import Testing

@testable import KawaCADApp

@Test("WindowLayoutPolicy は左ドックを除いた workspace 幅で mode を切り替える")
func window_layout_policy_resolves_mode_from_workspace_width() {
  let toolWidth: CGFloat = 176
  let dockedWorkspaceOffset = toolWidth + WindowLayoutPolicy.panelResizeHandleWidth

  #expect(
    WindowLayoutPolicy.make(
      contentWidth: WindowLayoutPolicy.regularMinimumWorkspaceWidth + dockedWorkspaceOffset - 1,
      storedToolWidth: toolWidth,
      storedInspectorWidth: 440
    ).mode == .compact)

  #expect(
    WindowLayoutPolicy.make(
      contentWidth: WindowLayoutPolicy.regularMinimumWorkspaceWidth + dockedWorkspaceOffset
        + WindowLayoutPolicy.hysteresis,
      storedToolWidth: toolWidth,
      storedInspectorWidth: 440,
      previousMode: .compact
    ).mode == .regular)

  #expect(
    WindowLayoutPolicy.make(
      contentWidth: WindowLayoutPolicy.wideMinimumWorkspaceWidth + dockedWorkspaceOffset,
      storedToolWidth: toolWidth,
      storedInspectorWidth: 440
    ).mode == .wide)

  #expect(
    WindowLayoutPolicy.make(
      contentWidth: WindowLayoutPolicy.wideMinimumWorkspaceWidth + dockedWorkspaceOffset
        - 1,
      storedToolWidth: toolWidth,
      storedInspectorWidth: 440,
      previousMode: .wide
    ).mode == .regular)
}

@Test("WindowLayoutPolicy は保存された panel 幅を mode ごとの範囲へ clamp する")
func window_layout_policy_clamps_stored_panel_widths() {
  let wide = WindowLayoutPolicy.make(
    contentWidth: 1_800,
    storedToolWidth: 500,
    storedInspectorWidth: 100
  )
  #expect(wide.toolDockWidth == 260)
  #expect(wide.inspectorDockWidth == WindowLayoutPolicy.minimumInspectorContentWidth)

  let regular = WindowLayoutPolicy.make(
    contentWidth: 1_200,
    storedToolWidth: 176,
    storedInspectorWidth: 480
  )
  #expect(regular.mode == .regular)
  #expect(
    abs(
      regular.overlayInspectorWidth
        - min(
          WindowLayoutPolicy.maximumInspectorWidth,
          max(WindowLayoutPolicy.minimumInspectorContentWidth, regular.workspaceWidth * 0.36)
        )
    ) < 0.000_001)

  let compact = WindowLayoutPolicy.make(
    contentWidth: 1_024,
    storedToolWidth: 176,
    storedInspectorWidth: 368
  )
  #expect(compact.mode == .compact)
  #expect(!compact.toolDockVisible)
  #expect(compact.compactToolDrawerWidth == 260)
  #expect(compact.compactInspectorDrawerWidth == WindowLayoutPolicy.minimumInspectorContentWidth)
}

@Test("WindowLayoutPolicy は非表示のツールパレットを workspace 幅から除外する")
func window_layout_policy_omits_hidden_tool_palette_from_workspace() {
  let hidden = WindowLayoutPolicy.make(
    contentWidth: 1_600,
    storedToolWidth: 176,
    storedInspectorWidth: 440,
    toolPaletteVisible: false
  )

  #expect(!hidden.toolDockVisible)
  #expect(hidden.workspaceWidth == 1_600)
  #expect(hidden.mode == .wide)
}

@Test("WindowLayoutPolicy はツール幅を1列または2列の安定した幅へスナップする")
func window_layout_policy_snaps_tool_width_for_stable_palette_layout() {
  #expect(WindowLayoutPolicy.snappedToolWidth(200, for: .wide) == 176)
  #expect(WindowLayoutPolicy.snappedToolWidth(220, for: .wide) == 260)
  #expect(WindowLayoutPolicy.snappedToolWidth(200, for: .regular) == 176)
  #expect(WindowLayoutPolicy.snappedToolWidth(220, for: .regular) == 240)
}

@Test("WindowLayoutPolicy はキーボードの幅調整でも2段階の幅を維持する")
func window_layout_policy_snaps_keyboard_tool_width_adjustments() {
  #expect(
    WindowLayoutPolicy.toolWidthAfterKeyboardAdjustment(
      currentWidth: 176,
      delta: 8,
      for: .wide
    ) == 260
  )
  #expect(
    WindowLayoutPolicy.toolWidthAfterKeyboardAdjustment(
      currentWidth: 260,
      delta: -8,
      for: .wide
    ) == 176
  )
}

@Test("WindowLayoutPolicy は画面より広いウィンドウを画面幅へ収める")
func window_layout_policy_constrains_window_width_to_visible_screen() {
  #expect(WindowLayoutPolicy.constrainedWindowWidth(1280, visibleScreenWidth: 1352) == 1280)
  #expect(WindowLayoutPolicy.constrainedWindowWidth(1520, visibleScreenWidth: 1352) == 1352)
}

@Test("WindowLayoutPolicy は 1352pt の画面幅でも wide を選択できる")
func window_layout_policy_keeps_wide_mode_available_at_1352_points() {
  #expect(
    WindowLayoutPolicy.make(
      contentWidth: 1352,
      storedToolWidth: 176,
      storedInspectorWidth: 440
    ).mode == .wide)
}

@Test("WindowLayoutPolicy は連続リサイズ中に実配置可能な inspector frame を返す")
func window_layout_policy_keeps_inspector_frame_inside_workspace_during_resize() {
  let visibleScreenWidth: CGFloat = 1_600
  let requestedWidths: [CGFloat] = [900, 1_024, 1_060, 1_220, 1_400, 1_600, 1_020]
  var previousMode: WindowLayoutMode?

  for requestedWidth in requestedWidths {
    let contentWidth = WindowLayoutPolicy.constrainedWindowWidth(
      requestedWidth,
      visibleScreenWidth: visibleScreenWidth
    )
    let policy = WindowLayoutPolicy.make(
      contentWidth: contentWidth,
      storedToolWidth: 260,
      storedInspectorWidth: 300,
      previousMode: previousMode
    )

    #expect(policy.workspaceWidth > 0)
    #expect(policy.workspaceWidth <= contentWidth)

    switch policy.mode {
    case .wide:
      let canvasWidth =
        policy.workspaceWidth
        - WindowLayoutPolicy.panelResizeHandleWidth
        - policy.inspectorDockWidth
      #expect(canvasWidth >= WindowLayoutPolicy.canvasMinimumWidth)
      #expect(policy.inspectorDockWidth >= WindowLayoutPolicy.minimumInspectorContentWidth)
    case .regular:
      #expect(policy.overlayInspectorWidth >= WindowLayoutPolicy.minimumInspectorContentWidth)
      #expect(policy.overlayInspectorWidth <= policy.workspaceWidth)
    case .compact:
      #expect(policy.compactInspectorDrawerWidth >= WindowLayoutPolicy.minimumInspectorContentWidth)
      #expect(policy.compactInspectorDrawerWidth <= policy.workspaceWidth)
    }
    previousMode = policy.mode
  }
}

@Test("WindowLayoutPolicy はインスペクタのタブ列と値列を表示できる幅を全 mode で確保する")
func window_layout_policy_keeps_inspector_content_unclipped_at_resize_breakpoints() {
  let requiredInspectorContentWidth = WindowLayoutPolicy.minimumInspectorContentWidth
  let cases: [(width: CGFloat, previousMode: WindowLayoutMode)] = [
    (1_600, .wide),
    (1_300, .wide),
    (1_024, .regular),
  ]

  for testCase in cases {
    let policy = WindowLayoutPolicy.make(
      contentWidth: testCase.width,
      storedToolWidth: 176,
      storedInspectorWidth: 300,
      previousMode: testCase.previousMode
    )

    switch policy.mode {
    case .wide:
      #expect(policy.inspectorDockWidth >= requiredInspectorContentWidth)
    case .regular:
      #expect(policy.overlayInspectorWidth >= requiredInspectorContentWidth)
    case .compact:
      #expect(policy.compactInspectorDrawerWidth >= requiredInspectorContentWidth)
    }
  }
}
