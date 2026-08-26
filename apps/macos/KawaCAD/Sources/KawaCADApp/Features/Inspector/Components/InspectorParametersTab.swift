import SwiftUI

struct InspectorParametersTab: View {
  let appState: ParameterInspectorModel

  var body: some View {
    InspectorSection(title: AppStrings.tr("inspector.parameters"), symbolName: "number") {
      if appState.data.shouldShowParameterInspectorSearch {
        TextField(
          AppStrings.tr("inspector.search_placeholder"),
          text: Binding(
            get: { appState.data.inspectorParameterSearchQuery },
            set: appState.actions.setInspectorParameterSearchQuery
          )
        )
        .textFieldStyle(.roundedBorder)
        .leatherControlHeight()
      }

      if appState.data.filteredInspectorParameters.isEmpty {
        InsetSurface {
          VStack(alignment: .leading, spacing: 8) {
            Text(
              AppStrings.tr(
                appState.data.shouldShowParameterInspectorSearch
                  ? "inspector.no_matching_parameters" : "inspector.no_named_parameters"
              )
            )
            .font(.system(size: 12))
            .foregroundStyle(LeatherColors.secondaryInk)

            if !appState.data.shouldShowParameterInspectorSearch {
              Text(AppStrings.tr("inspector.parameter_empty_hint"))
                .font(.system(size: 11))
                .foregroundStyle(LeatherColors.secondaryInk)

              Button {
                appState.actions.addParameter()
              } label: {
                Label(AppStrings.tr("inspector.add"), systemImage: "plus")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.bordered)
              .font(.system(size: 12, weight: .semibold))
              .leatherControlHeight()
            }
          }
        }
      } else {
        ForEach(appState.data.filteredInspectorParameters) { parameter in
          InspectorDisclosureRow(
            title: parameter.name,
            subtitle: String(format: "%.2f %@", parameter.valueMM, parameter.unitLabel),
            metadata: parameter.isUnused
              ? AppStrings.tr("inspector.parameter_unused")
              : AppStrings.tr("inspector.parameter_usage", parameter.usageCount),
            isSelected: appState.data.inspectorSelectedParameterID == parameter.id,
            onSelect: { appState.actions.setInspectorSelectedParameterID(parameter.id) }
          ) {
            ParameterEditor(parameter: parameter, appState: appState)
          }
        }
      }

      if !appState.data.filteredInspectorParameters.isEmpty {
        Button {
          appState.actions.addParameter()
        } label: {
          Label(AppStrings.tr("inspector.add"), systemImage: "plus")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .font(.system(size: 12, weight: .semibold))
        .leatherControlHeight()
      }
    }
  }
}
