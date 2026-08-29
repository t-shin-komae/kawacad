import { useState, type ReactNode } from "react";
import { Plus, SlidersHorizontal } from "lucide-react";
import {
  matchesInspectorSearch,
  setInspectorParameterSearchQuery,
  type ParametersTabState,
} from "@/features/inspector/selectors/inspectorFeature";
import { appStrings } from "@/localization";
import type { ParameterInspectorModel } from "@/features/inspector/domain/inspectorViewModel";
import { InspectorDisclosureRow, InspectorSection } from "@/shared/components/InspectorPrimitives";

type InspectorParametersTabProps = {
  model: ParameterInspectorModel;
  state: ParametersTabState;
  updateState: (update: (state: ParametersTabState) => ParametersTabState) => void;
  renderParameterEditor: (parameter: ParameterInspectorModel["parameters"][number]) => ReactNode;
};

export function InspectorParametersTab({
  model,
  state,
  updateState,
  renderParameterEditor,
}: InspectorParametersTabProps) {
  const [selectedParameterId, setSelectedParameterId] = useState<string>();
  const filteredParameters = model.parameters.filter((item) =>
    matchesInspectorSearch(`${item.name} ${item.memo} ${item.unit} ${item.valueMm}`, state.parameterSearchQuery),
  );
  return (
    <InspectorSection title={appStrings.inspector.parameters} icon={SlidersHorizontal}>
      {(model.parameters.length >= 8 || state.searchVisible || state.parameterSearchQuery) && (
        <label className="inspector-search">
          {appStrings.inspector.parameterSearch}
          <input
            type="search"
            value={state.parameterSearchQuery}
            onChange={(event) =>
              updateState((current) => setInspectorParameterSearchQuery(current, event.target.value))
            }
          />
        </label>
      )}
      {filteredParameters.length === 0 ? (
        <div className="inspector-editor-surface">
          <p>
            {model.parameters.length === 0
              ? appStrings.inspector.noNamedParameters
              : appStrings.inspector.noMatchingParameters}
          </p>
          {model.parameters.length === 0 ? (
            <>
              <p className="inspector-help">{appStrings.inspector.parameterEmptyHint}</p>
              <button type="button" className="inspector-add-button" onClick={model.actions.add}>
                <Plus aria-hidden="true" />
                {appStrings.inspector.add}
              </button>
            </>
          ) : null}
        </div>
      ) : (
        <>
          {filteredParameters.map((item) => {
            const usageCount =
              item.usageCount ??
              model.constraints.filter((constraint) => constraint.value?.parameter === item.id).length;
            return (
              <InspectorDisclosureRow
                key={item.id}
                title={item.name}
                subtitle={`${item.valueMm.toFixed(2)} ${item.unit === "millimeter" ? "mm" : item.unit}`}
                metadata={
                  usageCount === 0
                    ? appStrings.inspector.parameterUnused
                    : appStrings.inspector.parameterUsage(usageCount)
                }
                expanded={selectedParameterId === item.id}
                onToggle={() => setSelectedParameterId(item.id)}
              >
                {renderParameterEditor(item)}
              </InspectorDisclosureRow>
            );
          })}
          <button type="button" className="inspector-add-button" onClick={model.actions.add}>
            <Plus aria-hidden="true" />
            {appStrings.inspector.add}
          </button>
        </>
      )}
    </InspectorSection>
  );
}
