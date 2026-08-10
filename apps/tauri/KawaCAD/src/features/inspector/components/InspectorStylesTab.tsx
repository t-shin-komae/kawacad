import { useState, type ReactNode } from "react";
import { Paintbrush } from "lucide-react";
import {
  matchesInspectorSearch,
  setInspectorSharedStyleSearchQuery,
  type InspectorFeatureState,
} from "@/features/inspector/selectors/inspectorFeature";
import { appStrings } from "@/localization";
import { type TextEntryField } from "@/shared/components/TextEntryDialog";
import type { Props, LineStyle } from "@/features/inspector/components/InspectorPanel";
import { InspectorDisclosureRow, InspectorSection } from "@/features/inspector/components/InspectorPrimitives";

type OpenTextEntry = (
  title: string,
  fields: TextEntryField[],
  onConfirm: (values: Record<string, string>) => void,
) => void;

type InspectorStylesTabProps = {
  props: Props;
  feature: InspectorFeatureState;
  updateFeature: (update: (state: InspectorFeatureState) => InspectorFeatureState) => void;
  defaultStyle: LineStyle;
  openTextEntry: OpenTextEntry;
  renderStyleFields: (style: LineStyle, onChange: (style: LineStyle) => void) => ReactNode;
};

export function InspectorStylesTab({
  props,
  feature,
  updateFeature,
  defaultStyle,
  openTextEntry,
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
              <span>{item.name}</span>
              <button
                onClick={() =>
                  openTextEntry(
                    appStrings.inspector.styleNameEdit,
                    [{ id: "name", label: appStrings.inspector.styleName, initialValue: item.name }],
                    (values) => {
                      const name = values.name.trim();
                      if (name)
                        props.onCommand(
                          "updateSharedStyle",
                          { ...item, name },
                          appStrings.inspector.operationMessage.sharedStyleUpdated,
                        );
                    },
                  )
                }
              >
                {appStrings.inspector.name}
              </button>
              <button
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
