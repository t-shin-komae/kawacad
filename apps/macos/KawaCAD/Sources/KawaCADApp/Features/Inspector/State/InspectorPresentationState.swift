import Combine

enum InspectorTab: String, CaseIterable, Identifiable {
  case selection
  case layers
  case sharedStyles
  case parameters
  case parts

  var id: String { rawValue }

  var title: String {
    switch self {
    case .selection:
      return AppStrings.tr("inspector.tab.selection")
    case .layers:
      return AppStrings.tr("inspector.tab.layers")
    case .sharedStyles:
      return AppStrings.tr("inspector.tab.shared_styles")
    case .parameters:
      return AppStrings.tr("inspector.tab.parameters")
    case .parts:
      return AppStrings.tr("inspector.tab.parts")
    }
  }
}

/// Inspector-owned UI state, corresponding to the local feature state in
/// React's `InspectorPanel`.
final class InspectorPresentationState: ObservableObject {
  @Published private(set) var tab: InspectorTab = .selection
  @Published private(set) var selectedLayerID: String?
  @Published private(set) var selectedSharedStyleID: String?
  @Published private(set) var selectedParameterID: String?
  @Published private(set) var selectedPartID: String?
  @Published private(set) var arrangementSelectedPartIDs: Set<String> = []
  @Published private(set) var isSettingPartOrigin = false
  @Published private(set) var layerSearchQuery = ""
  @Published private(set) var sharedStyleSearchQuery = ""
  @Published private(set) var parameterSearchQuery = ""
  @Published private(set) var layerSearchVisible = false
  @Published private(set) var sharedStyleSearchVisible = false
  @Published private(set) var parameterSearchVisible = false

  func setSelectedLayerID(_ id: String?) { selectedLayerID = id }
  func setSelectedSharedStyleID(_ id: String?) { selectedSharedStyleID = id }
  func setSelectedParameterID(_ id: String?) { selectedParameterID = id }
  func setSelectedPartID(_ id: String?) { selectedPartID = id }
  func setArrangementSelectedPartIDs(_ ids: Set<String>) {
    arrangementSelectedPartIDs = ids
  }
  func toggleArrangementSelection(for partID: String) {
    if arrangementSelectedPartIDs.contains(partID) {
      arrangementSelectedPartIDs.remove(partID)
    } else {
      arrangementSelectedPartIDs.insert(partID)
    }
  }
  func removeArrangementSelection(for partID: String) {
    arrangementSelectedPartIDs.remove(partID)
  }
  func togglePartOriginSetting() {
    isSettingPartOrigin.toggle()
  }
  func setIsSettingPartOrigin(_ active: Bool) { isSettingPartOrigin = active }
  func setLayerSearchQuery(_ query: String) { layerSearchQuery = query }
  func setSharedStyleSearchQuery(_ query: String) { sharedStyleSearchQuery = query }
  func setParameterSearchQuery(_ query: String) { parameterSearchQuery = query }
  func setLayerSearchVisible(_ visible: Bool) { layerSearchVisible = visible }
  func setSharedStyleSearchVisible(_ visible: Bool) { sharedStyleSearchVisible = visible }
  func setParameterSearchVisible(_ visible: Bool) { parameterSearchVisible = visible }

  private(set) var acknowledgedSelectionSignature = ""

  func setTab(_ next: InspectorTab, selectionSignature: String) {
    if tab == .selection, next != .selection {
      acknowledgedSelectionSignature = selectionSignature
    }
    tab = next
    if next == .selection {
      acknowledgedSelectionSignature = selectionSignature
    }
  }

  func revealSearchForCurrentTab() {
    switch tab {
    case .selection, .parts:
      break
    case .layers:
      layerSearchVisible = true
    case .sharedStyles:
      sharedStyleSearchVisible = true
    case .parameters:
      parameterSearchVisible = true
    }
  }

  func reset() {
    tab = .selection
    selectedLayerID = nil
    selectedSharedStyleID = nil
    selectedParameterID = nil
    selectedPartID = nil
    arrangementSelectedPartIDs = []
    isSettingPartOrigin = false
    layerSearchQuery = ""
    sharedStyleSearchQuery = ""
    parameterSearchQuery = ""
    layerSearchVisible = false
    sharedStyleSearchVisible = false
    parameterSearchVisible = false
    acknowledgedSelectionSignature = ""
  }
}
