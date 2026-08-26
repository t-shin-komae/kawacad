import SwiftUI

struct InspectorLayerTab: View {
  let appState: LayerInspectorModel

  var body: some View {
    InspectorSection(title: AppStrings.tr("inspector.layer"), symbolName: "square.3.layers.3d") {
      Picker(
        AppStrings.tr("toolbar.drawing_layer"),
        selection: Binding(
          get: { appState.data.activeLayerID },
          set: { appState.actions.setActiveLayer($0) }
        )
      ) {
        ForEach(appState.data.layers) { layer in
          Text(layer.name).tag(layer.id)
        }
      }
      .font(.system(size: 12))
      .leatherControlHeight()

      if appState.data.shouldShowLayerInspectorSearch {
        TextField(
          AppStrings.tr("inspector.search_placeholder"),
          text: Binding(
            get: { appState.data.inspectorLayerSearchQuery },
            set: appState.actions.setInspectorLayerSearchQuery
          )
        )
        .textFieldStyle(.roundedBorder)
        .leatherControlHeight()
      }

      ForEach(appState.data.filteredInspectorLayers) { layer in
        InspectorDisclosureRow(
          title: layer.name,
          subtitle: layer.kind.displayName,
          metadata: layer.visible
            ? AppStrings.tr("inspector.layer_visible") : AppStrings.tr("inspector.layer_hidden"),
          isSelected: appState.data.inspectorSelectedLayerID == layer.id,
          onSelect: { appState.actions.setInspectorSelectedLayerID(layer.id) }
        ) {
          LayerEditorRow(
            layer: layer,
            canDelete: appState.data.layers.count > 1,
            onRename: { newName in appState.actions.renameLayer(layer, newName) },
            onToggleVisibility: {
              appState.actions.setLayerVisibility(layer, !layer.visible)
            },
            onTogglePrintable: {
              appState.actions.setLayerPrintable(layer, !layer.printable)
            },
            onStyleChange: { updatedLayer in appState.actions.setLayerStyle(updatedLayer) },
            onDelete: { appState.actions.deleteLayer(layer) }
          )
        }
      }

      Button {
        appState.actions.addLayer()
      } label: {
        Label(AppStrings.tr("inspector.add_layer"), systemImage: "plus")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .font(.system(size: 12, weight: .semibold))
      .leatherControlHeight()
    }
  }
}
