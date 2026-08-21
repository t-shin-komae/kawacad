/// Inspector shell and independently constructible tab models.
/// The shell owns navigation only; each tab receives its focused model.
struct InspectorPanelModel {
  let inspectorTab: InspectorTab
  let inspectorHasPendingSelectionChange: Bool
  let setInspectorTab: (InspectorTab) -> Void
  let revealInspectorSelectionTab: () -> Void
  let selection: SelectionInspectorModel
  let layers: LayerInspectorModel
  let styles: StyleInspectorModel
  let parameters: ParameterInspectorModel
  let parts: PartInspectorModel

}
