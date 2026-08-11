import { useState, type ReactNode } from "react";
import { Paintbrush } from "lucide-react";
import {
  matchesInspectorSearch,
  setInspectorSharedStyleSearchQuery,
  type InspectorFeatureState,
} from "@/features/inspector/selectors/inspectorFeature";
import { appStrings } from "@/localization";
import type { Props, LineStyle } from "@/features/inspector/components/InspectorPanel";
import { InspectorDisclosureRow, InspectorSection } from "@/features/inspector/components/InspectorPrimitives";

type InspectorStylesTabProps = {
  props: Props;
  feature: InspectorFeatureState;
  updateFeature: (update: (state: InspectorFeatureState) => InspectorFeatureState) => void;
  defaultStyle: LineStyle;
  renderStyleFields: (style: LineStyle, onChange: (style: LineStyle) => void) => ReactNode;
};

export function InspectorStylesTab({
  props,
  feature,
  updateFeature,
  defaultStyle,
  renderStyleFields,
}: InspectorStylesTabProps) {
  const [selectedStyleId, setSelectedStyleId] = useState<string>();
  const filteredStyles = props.sharedStyles.filter((item) =>
    matchesInspectorSearch(item.name, feature.sharedStyleSearchQuery),
  );
  return (
    <InspectorSection title={appStrings.inspector.sharedStyles} icon={Paintbrush}>
      {(props.sharedStyles.length >= 8 || feature.sharedStyleSearchVisible || feature.sharedStyleSearchQuery) && (
        <label className="inspector-search">
          {appStrings.inspector.sharedStyleSearch}
          <input
            type="search"
            value={feature.sharedStyleSearchQuery}
            onChange={(event) =>
              updateFeature((state) => setInspectorSharedStyleSearchQuery(state, event.target.value))
            }
          />
        </label>
      )}
      {filteredStyles.length === 0 && <p>{appStrings.inspector.noSharedStyles}</p>}
      {filteredStyles.map((item) => {
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
              appStrings.inspector.lineStyles[item.style.pattern as keyof typeof appStrings.inspector.lineStyles] ??
              item.style.pattern
            }
            metadata={colorHex}
            expanded={selectedStyleId === item.id}
            onToggle={() => setSelectedStyleId(item.id)}
          >
            <div className="row inspector-editor-heading">
              <span className="style-color-swatch" style={{ backgroundColor: colorHex }} aria-hidden="true" />
              <input
                className="inspector-inline-name"
                aria-label={appStrings.inspector.nameOf(item.name)}
                defaultValue={item.name}
                onBlur={(event) => {
                  const name = event.target.value.trim();
                  if (name && name !== item.name)
                    props.onCommand(
                      "updateSharedStyle",
                      { ...item, name },
                      appStrings.inspector.operationMessage.sharedStyleUpdated,
                    );
                }}
              />
              <button
                className="inspector-icon-destructive-button"
                aria-label={appStrings.inspector.deleteStyle(item.name)}
                onClick={() =>
                  props.onCommand(
                    "deleteSharedStyle",
                    item.id,
                    appStrings.inspector.operationMessage.sharedStyleDeleted,
                  )
                }
              >
                {appStrings.contextMenu.delete}
              </button>
            </div>
            {renderStyleFields(item.style, (style) =>
              props.onCommand(
                "updateSharedStyle",
                { ...item, style },
                appStrings.inspector.operationMessage.sharedStyleUpdated,
              ),
            )}
          </InspectorDisclosureRow>
        );
      })}
      <button
        className="inspector-add-button"
        onClick={() =>
          props.onCommand(
            "addSharedStyle",
            { id: "style:" + crypto.randomUUID(), name: appStrings.inspector.newStyle, style: defaultStyle },
            appStrings.inspector.operationMessage.sharedStyleAdded,
          )
        }
      >
        {appStrings.inspector.addSharedStyle}
      </button>
    </InspectorSection>
  );
}
