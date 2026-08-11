import SwiftUI

struct InspectorParametersTab: View {
  @EnvironmentObject private var appState: InspectorFeatureModel

  var body: some View {
    InspectorSection(title: AppStrings.tr("inspector.parameters"), symbolName: "number") {
      if appState.shouldShowParameterInspectorSearch {
        TextField(
          AppStrings.tr("inspector.search_placeholder"),
          text: Binding(
            get: { appState.inspectorParameterSearchQuery },
            set: appState.setInspectorParameterSearchQuery
          )
        )
        .textFieldStyle(.roundedBorder)
      }

      if appState.filteredInspectorParameters.isEmpty {
        Text(AppStrings.tr("inspector.no_named_parameters"))
          .font(.system(size: 12))
          .foregroundStyle(LeatherColors.secondaryInk)
      } else {
        ForEach(appState.filteredInspectorParameters) { parameter in
          InspectorDisclosureRow(
            title: parameter.name,
            subtitle: String(format: "%.2f %@", parameter.valueMM, parameter.unitLabel),
            metadata: parameter.isUnused
              ? AppStrings.tr("inspector.parameter_unused")
              : AppStrings.tr("inspector.parameter_usage", parameter.usageCount),
            isSelected: appState.inspectorSelectedParameterID == parameter.id,
            onSelect: { appState.setInspectorSelectedParameterID(parameter.id) }
          ) {
            ParameterEditor(parameter: parameter)
          }
        }
      }

      Button {
        appState.addParameter()
      } label: {
        Label(AppStrings.tr("inspector.add"), systemImage: "plus")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .font(.system(size: 12, weight: .semibold))
    }
  }
}
