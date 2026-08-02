import CoreGraphics
import Foundation

enum WorkspacePreferencesAdapter {
  static let showsDetailedToolsKey = "leather.toolPalette.showsDetailedTools"
  static let toolPaletteLayoutVersion = 1
  static let inspectorPanelVisibleKey = "leather.layout.inspectorPanelVisible"
  static let toolPanelWidthKey = "leather.layout.toolPanelWidth"
  static let inspectorPanelWidthKey = "leather.layout.inspectorPanelWidth"
  static let defaultToolPanelWidth: CGFloat = 176
  static let defaultInspectorPanelWidth: CGFloat = WindowLayoutPolicy.minimumInspectorContentWidth

  static func showsDetailedTools(userDefaults: UserDefaults = .standard) -> Bool {
    userDefaults.object(forKey: showsDetailedToolsKey) as? Bool ?? false
  }

  static func setShowsDetailedTools(_ value: Bool, userDefaults: UserDefaults = .standard) {
    userDefaults.set(value, forKey: showsDetailedToolsKey)
  }

  static func inspectorPanelVisible(userDefaults: UserDefaults = .standard) -> Bool {
    userDefaults.object(forKey: inspectorPanelVisibleKey) as? Bool ?? true
  }

  static func setInspectorPanelVisible(_ value: Bool, userDefaults: UserDefaults = .standard) {
    userDefaults.set(value, forKey: inspectorPanelVisibleKey)
  }

  static func toolPanelWidth(userDefaults: UserDefaults = .standard) -> CGFloat {
    let value = userDefaults.double(forKey: toolPanelWidthKey)
    return value == 0 ? defaultToolPanelWidth : value
  }

  static func setToolPanelWidth(_ value: CGFloat, userDefaults: UserDefaults = .standard) {
    userDefaults.set(Double(value), forKey: toolPanelWidthKey)
  }

  static func inspectorPanelWidth(userDefaults: UserDefaults = .standard) -> CGFloat {
    let value = userDefaults.double(forKey: inspectorPanelWidthKey)
    return value == 0 ? defaultInspectorPanelWidth : value
  }

  static func setInspectorPanelWidth(_ value: CGFloat, userDefaults: UserDefaults = .standard) {
    userDefaults.set(Double(value), forKey: inspectorPanelWidthKey)
  }

  static func toolGroupCollapsedKey(_ groupID: String) -> String {
    "leather.toolPalette.groupCollapsed.v\(toolPaletteLayoutVersion).\(groupID)"
  }

  static func isToolGroupCollapsed(
    _ groupID: String,
    defaultExpanded: Bool,
    userDefaults: UserDefaults = .standard
  ) -> Bool {
    let key = toolGroupCollapsedKey(groupID)
    guard userDefaults.object(forKey: key) != nil else {
      return !defaultExpanded
    }
    return userDefaults.bool(forKey: key)
  }

  static func setToolGroupCollapsed(
    _ collapsed: Bool,
    groupID: String,
    userDefaults: UserDefaults = .standard
  ) {
    userDefaults.set(collapsed, forKey: toolGroupCollapsedKey(groupID))
  }

  static func resetLayoutPreferences(
    groupIDs: [String],
    userDefaults: UserDefaults = .standard
  ) {
    userDefaults.removeObject(forKey: inspectorPanelVisibleKey)
    userDefaults.removeObject(forKey: toolPanelWidthKey)
    userDefaults.removeObject(forKey: inspectorPanelWidthKey)
    for groupID in groupIDs {
      userDefaults.removeObject(forKey: toolGroupCollapsedKey(groupID))
    }
  }
}
