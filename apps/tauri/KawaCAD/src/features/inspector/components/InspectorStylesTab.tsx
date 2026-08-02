import type { ReactNode } from "react";
import {
  matchesInspectorSearch,
  setInspectorSharedStyleSearchQuery,
  type InspectorFeatureState,
} from "@/features/inspector/selectors/inspectorFeature";
import { appStrings } from "@/localization";
import { type TextEntryField } from "@/shared/components/TextEntryDialog";
import type { Props, LineStyle } from "@/features/inspector/components/InspectorPanel";

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
  return (
    <section>
      <h2>{appStrings.inspector.sharedStyles}</h2>
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
      {props.sharedStyles
        .filter((item) => matchesInspectorSearch(item.name, feature.sharedStyleSearchQuery))
        .map((item) => (
          <div className="inspector-card" key={item.id}>
            <div className="row">
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
          </div>
        ))}
      <button
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
    </section>
  );
}
