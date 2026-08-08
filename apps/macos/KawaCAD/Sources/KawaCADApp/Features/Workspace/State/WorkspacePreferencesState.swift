import Combine
import KawaCADOutput

/// Persistent workspace display choices. These are independent of the Core
/// document and are the Swift counterpart of `useWorkspacePreferences`.
final class WorkspacePreferencesState: ObservableObject {
  @Published private(set) var gridVisible = true
  @Published private(set) var a4ReferenceVisible = true
  @Published private(set) var a4ReferenceOrientation: OutputPrintOrientation = .portrait
  @Published private(set) var gridSnapEnabled = true
  @Published private(set) var pointSnapEnabled = true
  @Published private(set) var inspectorPanelVisible =
    WorkspacePreferencesAdapter.inspectorPanelVisible()
  @Published private(set) var detailedToolsVisible =
    WorkspacePreferencesAdapter.showsDetailedTools()
  @Published private(set) var collapsedToolGroupIDs: Set<String> = []
  @Published private(set) var bottomWorkbenchVisible = false
  init() {
    collapsedToolGroupIDs = Set(
      ProjectSidebar.allToolGroups.compactMap { group in
        WorkspacePreferencesAdapter.isToolGroupCollapsed(
          group.id,
          defaultExpanded: group.defaultExpanded
        ) ? group.id : nil
      })
  }

  func setGridVisible(_ visible: Bool) { gridVisible = visible }
  func setA4ReferenceVisible(_ visible: Bool) { a4ReferenceVisible = visible }
  func setA4ReferenceOrientation(_ orientation: OutputPrintOrientation) {
    a4ReferenceOrientation = orientation
  }

  @discardableResult
  func syncLoadedPrintOrientation(_ orientation: OutputPrintOrientation) -> Bool {
    let changed = a4ReferenceOrientation != orientation
    a4ReferenceOrientation = orientation
    return changed
  }
  func setGridSnapEnabled(_ enabled: Bool) { gridSnapEnabled = enabled }
  func setPointSnapEnabled(_ enabled: Bool) { pointSnapEnabled = enabled }
  func setBottomWorkbenchVisible(_ visible: Bool) {
    bottomWorkbenchVisible = visible
  }

  func setInspectorPanelVisible(_ visible: Bool) {
    inspectorPanelVisible = visible
    WorkspacePreferencesAdapter.setInspectorPanelVisible(visible)
  }

  func setDetailedToolsVisible(_ visible: Bool) {
    detailedToolsVisible = visible
    WorkspacePreferencesAdapter.setShowsDetailedTools(visible)
  }

  func setToolGroupCollapsed(_ collapsed: Bool, groupID: String) {
    if collapsed {
      collapsedToolGroupIDs.insert(groupID)
    } else {
      collapsedToolGroupIDs.remove(groupID)
    }
    WorkspacePreferencesAdapter.setToolGroupCollapsed(collapsed, groupID: groupID)
  }

  func resetStoredPreferences(groupDefaults: [String: Bool]) {
    WorkspacePreferencesAdapter.resetLayoutPreferences(groupIDs: Array(groupDefaults.keys))
    inspectorPanelVisible = WorkspacePreferencesAdapter.inspectorPanelVisible()
    detailedToolsVisible = WorkspacePreferencesAdapter.showsDetailedTools()
    collapsedToolGroupIDs = Set(
      groupDefaults.compactMap { groupID, defaultExpanded in
        WorkspacePreferencesAdapter.isToolGroupCollapsed(
          groupID,
          defaultExpanded: defaultExpanded
        ) ? groupID : nil
      })
  }
}
