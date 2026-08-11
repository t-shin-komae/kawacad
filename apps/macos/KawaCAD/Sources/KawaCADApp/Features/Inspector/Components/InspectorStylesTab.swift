import SwiftUI

struct InspectorStylesTab: View {
  @EnvironmentObject private var appState: InspectorFeatureModel

  var body: some View {
    InspectorSection(title: AppStrings.tr("inspector.shared_styles"), symbolName: "paintbrush") {
      if appState.shouldShowSharedStyleInspectorSearch {
        TextField(
          AppStrings.tr("inspector.search_placeholder"),
          text: Binding(
            get: { appState.inspectorSharedStyleSearchQuery },
            set: appState.setInspectorSharedStyleSearchQuery
          )
        )
        .textFieldStyle(.roundedBorder)
      }

      if appState.filteredInspectorSharedStyles.isEmpty {
        Text(AppStrings.tr("inspector.no_shared_styles"))
          .font(.system(size: 12))
          .foregroundStyle(LeatherColors.secondaryInk)
      } else {
        ForEach(appState.filteredInspectorSharedStyles) { style in
          InspectorDisclosureRow(
            title: style.name,
            subtitle: style.linePattern.displayName,
            metadata: style.colorHex,
            isSelected: appState.inspectorSelectedSharedStyleID == style.id,
            onSelect: { appState.setInspectorSelectedSharedStyleID(style.id) }
          ) {
            StyleEditorRow(
              style: style,
              namePlaceholder: AppStrings.tr("inspector.shared_style_name_placeholder"),
              onChange: { appState.updateSharedStyle($0) },
              accessoryButtons: EmptyView(),
              deleteButton: Button(action: { appState.deleteSharedStyle(style) }) {
                Image(systemName: "trash")
                  .frame(width: 24, height: 24)
              }
              .buttonStyle(.borderless)
              .foregroundStyle(LeatherColors.destructive)
            )
          }
        }
      }

      Button {
        appState.addSharedStyle()
      } label: {
        Label(AppStrings.tr("inspector.add_shared_style"), systemImage: "plus")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .font(.system(size: 12, weight: .semibold))
    }
  }
}
