import { useState, type ReactNode } from "react";
import { Paintbrush, Plus, Trash2 } from "lucide-react";
import {
  matchesInspectorSearch,
  setInspectorSharedStyleSearchQuery,
  type StylesTabState,
} from "@/features/inspector/selectors/inspectorFeature";
import { appStrings } from "@/localization";
import type { StyleInspectorModel } from "@/features/inspector/domain/inspectorViewModel";
import type { LineStyle } from "@/shared/domain/coreWireTypes";
import { sharedStyleDefaultName } from "@/features/inspector/domain/sharedStyleDefaults";
import {
  InspectorDisclosureRow,
  InspectorEditorSurface,
  InspectorSection,
} from "@/shared/components/InspectorPrimitives";

type InspectorStylesTabProps = {
  model: StyleInspectorModel;
  state: StylesTabState;
  updateState: (update: (state: StylesTabState) => StylesTabState) => void;
  defaultStyle: LineStyle;
  renderStyleFields: (style: LineStyle, onChange: (style: LineStyle) => void) => ReactNode;
};

export function InspectorStylesTab({
  model,
  state,
  updateState,
  defaultStyle,
  renderStyleFields,
}: InspectorStylesTabProps) {
  const [selectedStyleId, setSelectedStyleId] = useState<string>();
  const filteredStyles = model.sharedStyles.filter((item) =>
    matchesInspectorSearch(item.name, state.sharedStyleSearchQuery),
  );
  return (
    <InspectorSection title={appStrings.inspector.sharedStyles} icon={Paintbrush}>
      {(model.sharedStyles.length >= 8 || state.searchVisible || state.sharedStyleSearchQuery) && (
        <label className="inspector-search">
          {appStrings.inspector.sharedStyleSearch}
          <input
            type="search"
            value={state.sharedStyleSearchQuery}
            onChange={(event) =>
              updateState((current) => setInspectorSharedStyleSearchQuery(current, event.target.value))
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
            <InspectorEditorSurface>
              <div className="inspector-editor-heading">
                <span className="style-color-swatch compact" style={{ backgroundColor: colorHex }} aria-hidden="true" />
                <input
                  className="inspector-inline-name"
                  aria-label={appStrings.inspector.nameOf(item.name)}
                  defaultValue={item.name}
                  onBlur={(event) => {
                    const name = event.target.value.trim();
                    if (name && name !== item.name)
                      model.actions.update(
                        { styleId: item.id, name, style: item.style },
                        appStrings.inspector.operationMessage.sharedStyleUpdated,
                      );
                  }}
                />
                <button
                  type="button"
                  className="inspector-icon-button inspector-icon-destructive-button"
                  aria-label={appStrings.inspector.deleteStyle(item.name)}
                  onClick={() =>
                    model.actions.delete(item.id, appStrings.inspector.operationMessage.sharedStyleDeleted)
                  }
                >
                  <Trash2 aria-hidden="true" />
                </button>
              </div>
              {renderStyleFields(item.style, (style) =>
                model.actions.update(
                  { styleId: item.id, name: item.name, style: { ...style } },
                  appStrings.inspector.operationMessage.sharedStyleUpdated,
                ),
              )}
            </InspectorEditorSurface>
          </InspectorDisclosureRow>
        );
      })}
      <button className="inspector-add-button" onClick={() => model.actions.add()}>
        <Plus aria-hidden="true" />
        {appStrings.inspector.addSharedStyle}
      </button>
    </InspectorSection>
  );
}
