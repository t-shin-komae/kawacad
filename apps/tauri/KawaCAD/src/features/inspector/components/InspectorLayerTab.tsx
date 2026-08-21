import { useState, type ReactNode } from "react";
import { Eye, EyeOff, Layers3, Plus, Printer, Trash2 } from "lucide-react";
import {
  matchesInspectorLayerSearch,
  setInspectorLayerSearchQuery,
  type LayerTabState,
} from "@/features/inspector/selectors/inspectorFeature";
import { appStrings } from "@/localization";
import type { InspectorLayer, LayerInspectorModel } from "@/features/inspector/domain/inspectorViewModel";
import type { LineStyle } from "@/shared/domain/coreWireTypes";
import {
  InspectorDisclosureRow,
  InspectorEditorSurface,
  InspectorSection,
} from "@/shared/components/InspectorPrimitives";

type InspectorLayerTabProps = {
  model: LayerInspectorModel;
  state: LayerTabState;
  updateState: (update: (state: LayerTabState) => LayerTabState) => void;
  renderStyleFields: (style: LineStyle, onChange: (style: LineStyle) => void) => ReactNode;
};

export function InspectorLayerTab({ model, state, updateState, renderStyleFields }: InspectorLayerTabProps) {
  const [selectedLayerId, setSelectedLayerId] = useState<string>();
  return (
    <InspectorSection title={appStrings.inspector.layer} icon={Layers3}>
      <label>
        {appStrings.inspector.drawingLayer}
        <select value={model.activeLayerId} onChange={(event) => model.actions.changeActiveLayer(event.target.value)}>
          {model.layers.map((layer) => (
            <option key={layer.id} value={layer.id}>
              {layer.name}
            </option>
          ))}
        </select>
      </label>
      {(model.layers.length >= 8 || state.searchVisible || state.layerSearchQuery) && (
        <label className="inspector-search">
          {appStrings.inspector.layerSearch}
          <input
            type="search"
            value={state.layerSearchQuery}
            onChange={(event) => updateState((current) => setInspectorLayerSearchQuery(current, event.target.value))}
          />
        </label>
      )}
      {model.layers
        .filter((item) => matchesInspectorLayerSearch(item.name, state.layerSearchQuery))
        .map((item) => {
          const colorHex =
            "#" +
            [item.style.stroke.red, item.style.stroke.green, item.style.stroke.blue]
              .map((component) =>
                Math.round(component * 255)
                  .toString(16)
                  .padStart(2, "0"),
              )
              .join("")
              .toUpperCase();
          return (
            <InspectorDisclosureRow
              key={item.id}
              title={item.name}
              subtitle={
                appStrings.inspector.layerKinds[item.kind as keyof typeof appStrings.inspector.layerKinds] ?? item.kind
              }
              metadata={item.visible ? appStrings.inspector.layerVisible : appStrings.inspector.hidden}
              expanded={selectedLayerId === item.id}
              onToggle={() => {
                setSelectedLayerId(item.id);
                model.actions.changeActiveLayer(item.id);
              }}
            >
              <InspectorEditorSurface>
                <div className="inspector-editor-heading">
                  <span
                    className="style-color-swatch compact"
                    style={{ backgroundColor: colorHex }}
                    aria-hidden="true"
                  />
                  <input
                    className="inspector-inline-name"
                    aria-label={appStrings.inspector.nameOf(item.name)}
                    defaultValue={item.name}
                    onBlur={(event) => {
                      const name = event.target.value.trim();
                      if (name && name !== item.name) model.actions.renameLayer(item.id, name);
                    }}
                  />
                  <div className="inspector-editor-actions">
                    <button
                      type="button"
                      className="inspector-icon-button"
                      aria-label={item.visible ? appStrings.inspector.layerVisible : appStrings.inspector.hidden}
                      aria-pressed={item.visible}
                      onClick={() =>
                        model.actions.setVisibility(
                          { layerId: item.id, visible: !item.visible },
                          appStrings.inspector.operationMessage.layerVisibleUpdated,
                        )
                      }
                    >
                      {item.visible ? <Eye aria-hidden="true" /> : <EyeOff aria-hidden="true" />}
                    </button>
                    <button
                      type="button"
                      className="inspector-icon-button"
                      aria-label={appStrings.inspector.includeInOutput(item.name)}
                      aria-pressed={item.printable}
                      onClick={() =>
                        model.actions.setPrintable(
                          { layerId: item.id, printable: !item.printable },
                          appStrings.inspector.operationMessage.layerOutputUpdated,
                        )
                      }
                    >
                      <Printer className={item.printable ? "filled-icon" : undefined} aria-hidden="true" />
                    </button>
                    <button
                      type="button"
                      className="inspector-icon-button inspector-icon-destructive-button"
                      aria-label={appStrings.contextMenu.delete}
                      disabled={model.layers.length <= 1}
                      onClick={() => model.actions.deleteLayer(item)}
                    >
                      <Trash2 aria-hidden="true" />
                    </button>
                  </div>
                </div>
                {renderStyleFields(item.style, (style) =>
                  model.actions.setStyle(
                    { layerId: item.id, style },
                    appStrings.inspector.operationMessage.layerStyleUpdated,
                  ),
                )}
              </InspectorEditorSurface>
            </InspectorDisclosureRow>
          );
        })}
      <button className="inspector-add-button" onClick={model.actions.addLayer}>
        <Plus aria-hidden="true" />
        {appStrings.inspector.addLayer}
      </button>
    </InspectorSection>
  );
}
