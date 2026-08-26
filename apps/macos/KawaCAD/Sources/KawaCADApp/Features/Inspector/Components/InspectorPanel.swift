import SwiftUI

struct InspectorPanel: View {
  let model: InspectorPanelModel

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 10) {
        Picker(
          AppStrings.tr("accessibility.inspector_tabs"),
          selection: Binding(
            get: { model.inspectorTab },
            set: model.setInspectorTab
          )
        ) {
          ForEach(InspectorTab.allCases) { tab in
            Text(tab.title).tag(tab)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .leatherControlHeight()
        .accessibilityLabel(Text(AppStrings.tr("accessibility.inspector_tabs")))

        if model.inspectorHasPendingSelectionChange {
          Button {
            model.revealInspectorSelectionTab()
          } label: {
            HStack(spacing: 8) {
              Text(AppStrings.tr("inspector.selection_changed"))
              Spacer(minLength: 8)
              Text(AppStrings.tr("inspector.show_selection"))
            }
            .font(.system(size: 11, weight: .semibold))
          }
          .buttonStyle(.bordered)
          .leatherControlHeight()
        }
      }
      .padding(16)
      .background {
        MacVisualEffectBackground(style: .content)
      }

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          switch model.inspectorTab {
          case .selection:
            InspectorSelectionTab(model: model.selection)
          case .layers:
            InspectorLayerTab(appState: model.layers)
          case .sharedStyles:
            InspectorStylesTab(appState: model.styles)
          case .parameters:
            InspectorParametersTab(appState: model.parameters)
          case .parts:
            InspectorPartsTab(appState: model.parts)
          }
        }
        .padding(16)
      }
    }
    .background {
      MacVisualEffectBackground(style: .content)
    }
  }
}
