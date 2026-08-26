import Foundation
import Testing

@testable import KawaCADApp

@Test("ツールパレット表示設定は保存され、レイアウトリセットで既定値へ戻る")
func tool_palette_visibility_preference_persists_and_resets() throws {
  let suiteName = "KawaCADAppTests.WorkspacePreferencesTests"
  let userDefaults = try #require(UserDefaults(suiteName: suiteName))
  userDefaults.removePersistentDomain(forName: suiteName)
  defer { userDefaults.removePersistentDomain(forName: suiteName) }

  WorkspacePreferencesAdapter.setToolPaletteVisible(false, userDefaults: userDefaults)
  #expect(WorkspacePreferencesAdapter.toolPaletteVisible(userDefaults: userDefaults) == false)

  WorkspacePreferencesAdapter.resetLayoutPreferences(groupIDs: [], userDefaults: userDefaults)
  #expect(WorkspacePreferencesAdapter.toolPaletteVisible(userDefaults: userDefaults))
}
