import { useState, type ReactNode } from "react";
import { Eye, EyeOff, Layers3, Plus, Printer, Trash2 } from "lucide-react";
import {
  matchesInspectorLayerSearch,
  setInspectorLayerSearchQuery,
  type InspectorFeatureState,
} from "@/features/inspector/selectors/inspectorFeature";
import { appStrings } from "@/localization";
import type { Props, LineStyle } from "@/features/inspector/components/InspectorPanel";
import {
  InspectorDisclosureRow,
  InspectorEditorSurface,
  InspectorSection,
} from "@/shared/components/InspectorPrimitives";

type InspectorLayerTabProps = {
  props: Props;
  feature: InspectorFeatureState;
  updateFeature: (update: (state: InspectorFeatureState) => InspectorFeatureState) => void;
  renderStyleFields: (style: LineStyle, onChange: (style: LineStyle) => void) => ReactNode;
};

export function InspectorLayerTab({ props, feature, updateFeature, renderStyleFields }: InspectorLayerTabProps) {
  const [selectedLayerId, setSelectedLayerId] = useState<string>();
  return (
    <InspectorSection title={appStrings.inspector.layers} icon={Layers3}>
      <label>
        {appStrings.inspector.drawingLayer}
        <select value={props.activeLayerId} onChange={(event) => props.onActiveLayerChange(event.target.value)}>
          {props.layers.map((layer) => (
            <option key={layer.id} value={layer.id}>
              {layer.name}
            </option>
          ))}
        </select>
      </label>
      {(props.layers.length >= 8 || feature.layerSearchVisible || feature.layerSearchQuery) && (
        <label className="inspector-search">
          {appStrings.inspector.layerSearch}
          <input
            type="search"
            value={feature.layerSearchQuery}
            onChange={(event) => updateFeature((state) => setInspectorLayerSearchQuery(state, event.target.value))}
          />
        </label>
      )}
      {props.layers
        .filter((item) => matchesInspectorLayerSearch(item.name, feature.layerSearchQuery))
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
              metadata={item.visible ? appStrings.inspector.visible : appStrings.inspector.hidden}
              expanded={selectedLayerId === item.id}
              onToggle={() => {
                setSelectedLayerId(item.id);
                props.onActiveLayerChange(item.id);
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
                      if (name && name !== item.name) props.onRenameLayer(item.id, name);
                    }}
                  />
                  <div className="inspector-editor-actions">
                    <button
                      type="button"
                      className="inspector-icon-button"
                      aria-label={item.visible ? appStrings.inspector.visible : appStrings.inspector.hidden}
                      aria-pressed={item.visible}
                      onClick={() =>
                        props.onCommand(
                          "setLayerVisibility",
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
                        props.onCommand(
                          "setLayerPrintable",
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
                      disabled={props.layers.length <= 1}
                      onClick={() => props.onDeleteLayer(item)}
                    >
                      <Trash2 aria-hidden="true" />
                    </button>
                  </div>
                </div>
                {renderStyleFields(item.style, (style) =>
                  props.onCommand(
                    "setLayerStyle",
                    { layerId: item.id, style },
                    appStrings.inspector.operationMessage.layerStyleUpdated,
                  ),
                )}
              </InspectorEditorSurface>
            </InspectorDisclosureRow>
          );
        })}
      <button className="inspector-add-button" onClick={props.onAddLayer}>
        <Plus aria-hidden="true" />
        {appStrings.inspector.addLayer}
      </button>
    </InspectorSection>
  );
}
