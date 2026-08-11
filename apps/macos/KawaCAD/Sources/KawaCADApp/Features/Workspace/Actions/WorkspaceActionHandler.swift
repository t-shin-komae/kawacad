import AppKit
import KawaCADOutput
import SwiftUI

/// Workspace preferences and responsive layout actions.
extension WorkspaceActionHandler {
  func setGridSnapEnabled(_ enabled: Bool) {
    workspacePreferences.setGridSnapEnabled(enabled)
    statusMessage = AppStrings.tr(
      "status.grid_snap_enabled",
      enabled ? AppStrings.tr("status.enabled") : AppStrings.tr("status.disabled"))
  }

  func setGridVisible(_ visible: Bool) {
    workspacePreferences.setGridVisible(visible)
    statusMessage = AppStrings.tr(
      "status.grid_visible_enabled",
      visible ? AppStrings.tr("status.enabled") : AppStrings.tr("status.disabled"))
  }

  func setA4ReferenceVisible(_ visible: Bool) {
    workspacePreferences.setA4ReferenceVisible(visible)
    statusMessage = AppStrings.tr(
      "status.a4_reference_visible",
      visible ? AppStrings.tr("status.enabled") : AppStrings.tr("status.disabled"))
  }

  func setA4ReferenceOrientation(_ orientation: OutputPrintOrientation) {
    guard workspacePreferences.a4ReferenceOrientation != orientation else {
      return
    }
    guard
      actions.document.executeDocumentCommand(
        commandFactory.makeSetPrintOrientationCommand(orientation)
      )
    else {
      return
    }
    statusMessage = AppStrings.tr("status.a4_reference_orientation", orientation.displayName)
  }

  @discardableResult
  func syncPrintOrientation(_ orientation: OutputPrintOrientation) -> Bool {
    let changed = workspacePreferences.syncLoadedPrintOrientation(orientation)
    if var draft = outputPresentation.requestDraft,
      draft.options.orientation != orientation
    {
      draft.options = OutputPresentationOptions(
        orientation: orientation,
        includeDimensionLabels: draft.options.includeDimensionLabels,
        includeScaleGuide: draft.options.includeScaleGuide,
        rotationDeg: draft.options.rotationDeg
      )
      outputPresentation.setRequestDraft(draft)
    }
    return changed
  }

  func setLayerPanelVisible(_ visible: Bool) {
    canvasPresentation.setLayerPanelVisible(visible)
    statusMessage = AppStrings.tr(
      "status.layer_panel_visible",
      visible ? AppStrings.tr("status.visible") : AppStrings.tr("status.hidden"))
  }

  func setParameterPanelVisible(_ visible: Bool) {
    canvasPresentation.setParameterPanelVisible(visible)
    statusMessage = AppStrings.tr(
      "status.parameter_panel_visible",
      visible ? AppStrings.tr("status.visible") : AppStrings.tr("status.hidden"))
  }

  func setInspectorPanelVisible(_ visible: Bool) {
    workspacePreferences.setInspectorPanelVisible(visible)
    statusMessage = AppStrings.tr(
      "status.inspector_panel_visible",
      visible ? AppStrings.tr("status.visible") : AppStrings.tr("status.hidden"))
  }

  func setToolPanelWidth(_ width: CGFloat) {
    workspaceLayout.setToolPanelWidth(width)
  }

  func setInspectorPanelWidth(_ width: CGFloat) {
    workspaceLayout.setInspectorPanelWidth(width)
  }

  func setDetailedToolsVisible(_ visible: Bool) {
    workspacePreferences.setDetailedToolsVisible(visible)
  }

  func setToolGroupCollapsed(_ collapsed: Bool, groupID: String) {
    workspacePreferences.setToolGroupCollapsed(collapsed, groupID: groupID)
  }

  func showCompactDrawer(_ drawer: CompactDrawer?) {
    workspaceLayout.setCompactDrawer(
      workspaceLayout.compactDrawer == drawer ? nil : drawer
    )
  }

  func updateWindowLayoutMode(_ mode: WindowLayoutMode) {
    guard workspaceLayout.windowLayoutMode != mode else {
      return
    }
    let previousMode = workspaceLayout.windowLayoutMode
    workspaceLayout.setWindowLayoutMode(mode)
    if mode == .compact || previousMode == .compact {
      workspaceLayout.setCompactDrawer(nil)
    }
  }

  func resetLayoutPreferences() {
    workspacePreferences.resetStoredPreferences(
      groupDefaults: Dictionary(
        uniqueKeysWithValues: ToolPalette.allToolGroups.map { ($0.id, $0.defaultExpanded) }
      )
    )
    workspaceLayout.resetStoredPanelWidths()
    workspaceLayout.setCompactDrawer(nil)
    statusMessage = AppStrings.tr("status.layout_reset")
  }

  func setBottomWorkbenchVisible(_ visible: Bool) {
    workspacePreferences.setBottomWorkbenchVisible(visible)
    statusMessage = AppStrings.tr(
      "status.bottom_workbench_visible",
      visible ? AppStrings.tr("status.visible") : AppStrings.tr("status.hidden"))
  }

}
