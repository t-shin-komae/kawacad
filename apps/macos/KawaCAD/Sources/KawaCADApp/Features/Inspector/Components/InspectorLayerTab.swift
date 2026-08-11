import SwiftUI

struct InspectorLayerTab: View {
  @EnvironmentObject private var appState: InspectorFeatureModel

  var body: some View {
    InspectorSection(title: AppStrings.tr("inspector.layer"), symbolName: "square.3.layers.3d") {
      Picker(
        AppStrings.tr("toolbar.drawing_layer"),
        selection: Binding(
          get: { appState.activeLayerID },
          set: { appState.setActiveLayer($0) }
        )
      ) {
        ForEach(appState.layers) { layer in
          Text(layer.name).tag(layer.id)
        }
      }
      .font(.system(size: 12))

      if appState.shouldShowLayerInspectorSearch {
        TextField(
          AppStrings.tr("inspector.search_placeholder"),
          text: Binding(
            get: { appState.inspectorLayerSearchQuery },
            set: appState.setInspectorLayerSearchQuery
          )
        )
        .textFieldStyle(.roundedBorder)
      }

      ForEach(appState.filteredInspectorLayers) { layer in
        InspectorDisclosureRow(
          title: layer.name,
          subtitle: layer.kind.displayName,
          metadata: layer.visible
            ? AppStrings.tr("inspector.layer_visible") : AppStrings.tr("inspector.layer_hidden"),
          isSelected: appState.inspectorSelectedLayerID == layer.id,
          onSelect: { appState.setInspectorSelectedLayerID(layer.id) }
        ) {
          LayerEditorRow(
            layer: layer,
            canDelete: appState.layers.count > 1,
            onRename: { newName in appState.renameLayer(layer, newName) },
            onToggleVisibility: { appState.setLayerVisibility(layer, !layer.visible) },
            onTogglePrintable: { appState.setLayerPrintable(layer, !layer.printable) },
            onStyleChange: { updatedLayer in appState.setLayerStyle(updatedLayer) },
            onDelete: { appState.deleteLayer(layer) }
          )
        }
      }

      Button {
        appState.addLayer()
      } label: {
        Label(AppStrings.tr("inspector.add_layer"), systemImage: "plus")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .font(.system(size: 12, weight: .semibold))
    }
  }
}
