import Combine
import CoreGraphics

enum CompactDrawer: String, Equatable {
  case tools
  case inspector
}

/// Ephemeral window arrangement state. This is the Swift counterpart of
/// `useWorkspaceLayout`; it never represents document content.
final class WorkspaceLayoutState: ObservableObject {
  @Published private(set) var toolPanelWidth: CGFloat = WorkspacePreferencesAdapter.toolPanelWidth()
  @Published private(set) var inspectorPanelWidth: CGFloat =
    WorkspacePreferencesAdapter.inspectorPanelWidth()
  @Published private(set) var toolPaletteVisible = WorkspacePreferencesAdapter.toolPaletteVisible()
  @Published private(set) var compactDrawer: CompactDrawer?
  @Published private(set) var windowLayoutMode: WindowLayoutMode = .wide

  func setCompactDrawer(_ drawer: CompactDrawer?) {
    compactDrawer = drawer
  }

  func setWindowLayoutMode(_ mode: WindowLayoutMode) {
    windowLayoutMode = mode
  }

  func setToolPanelWidth(_ width: CGFloat) {
    toolPanelWidth = width
    WorkspacePreferencesAdapter.setToolPanelWidth(width)
  }

  func setToolPaletteVisible(_ visible: Bool) {
    toolPaletteVisible = visible
    WorkspacePreferencesAdapter.setToolPaletteVisible(visible)
  }

  func setInspectorPanelWidth(_ width: CGFloat) {
    inspectorPanelWidth = width
    WorkspacePreferencesAdapter.setInspectorPanelWidth(width)
  }

  func resetStoredPanelWidths() {
    toolPanelWidth = WorkspacePreferencesAdapter.toolPanelWidth()
    inspectorPanelWidth = WorkspacePreferencesAdapter.inspectorPanelWidth()
    toolPaletteVisible = WorkspacePreferencesAdapter.toolPaletteVisible()
  }
}
