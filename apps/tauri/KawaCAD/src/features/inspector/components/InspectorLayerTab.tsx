import { useState, type ReactNode } from "react";
import { Layers3 } from "lucide-react";
import {
  matchesInspectorLayerSearch,
  setInspectorLayerSearchQuery,
  type InspectorFeatureState,
} from "@/features/inspector/selectors/inspectorFeature";
import { appStrings } from "@/localization";
import type { Props, LineStyle } from "@/features/inspector/components/InspectorPanel";
import { InspectorDisclosureRow, InspectorSection } from "@/features/inspector/components/InspectorPrimitives";

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
        .map((item) => (
          <InspectorDisclosureRow
            key={item.id}
            title={item.name}
            subtitle={
              appStrings.inspector.layerKinds[item.kind as keyof typeof appStrings.inspector.layerKinds] ?? item.kind
            }
            metadata={item.visible ? appStrings.inspector.visible : appStrings.inspector.hidden}
            expanded={selectedLayerId === item.id}
            onToggle={() => setSelectedLayerId(item.id)}
          >
            <div className="row inspector-editor-heading">
              <label>
                <input
                  type="checkbox"
                  checked={item.visible}
                  onChange={(event) =>
                    props.onCommand(
                      "setLayerVisibility",
                      { layerId: item.id, visible: event.target.checked },
                      appStrings.inspector.operationMessage.layerVisibleUpdated,
                    )
                  }
                />
                {item.name}
              </label>
              <button onClick={() => props.onRenameLayer(item.id, item.name)}>{appStrings.inspector.edit}</button>
            </div>
            <label>
              <input
                type="checkbox"
                aria-label={appStrings.inspector.includeInOutput(item.name)}
                checked={item.printable}
                onChange={(event) =>
                  props.onCommand(
                    "setLayerPrintable",
                    { layerId: item.id, printable: event.target.checked },
                    appStrings.inspector.operationMessage.layerOutputUpdated,
                  )
                }
              />
              {appStrings.inspector.outputTarget}
            </label>
            {renderStyleFields(item.style, (style) =>
              props.onCommand(
                "setLayerStyle",
                { layerId: item.id, style },
                appStrings.inspector.operationMessage.layerStyleUpdated,
              ),
            )}
            <button disabled={props.layers.length <= 1} onClick={() => props.onDeleteLayer(item)}>
              {appStrings.contextMenu.delete}
            </button>
          </InspectorDisclosureRow>
        ))}
      <button className="inspector-add-button" onClick={props.onAddLayer}>
        {appStrings.inspector.addLayer}
      </button>
    </InspectorSection>
  );
}
