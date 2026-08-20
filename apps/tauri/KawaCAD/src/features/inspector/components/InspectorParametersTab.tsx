import { useState, type ReactNode } from "react";
import { Plus, SlidersHorizontal } from "lucide-react";
import {
  matchesInspectorSearch,
  setInspectorParameterSearchQuery,
  type InspectorFeatureState,
} from "@/features/inspector/selectors/inspectorFeature";
import { appStrings } from "@/localization";
import type { Props } from "@/features/inspector/components/InspectorPanel";
import { InspectorDisclosureRow, InspectorSection } from "@/shared/components/InspectorPrimitives";

type InspectorParametersTabProps = {
  props: Props;
  feature: InspectorFeatureState;
  updateFeature: (update: (state: InspectorFeatureState) => InspectorFeatureState) => void;
  renderParameterEditor: (parameter: Props["parameters"][number]) => ReactNode;
};

export function InspectorParametersTab({
  props,
  feature,
  updateFeature,
  renderParameterEditor,
}: InspectorParametersTabProps) {
  const [selectedParameterId, setSelectedParameterId] = useState<string>();
  const filteredParameters = props.parameters.filter((item) =>
    matchesInspectorSearch(`${item.name} ${item.memo} ${item.unit} ${item.valueMm}`, feature.parameterSearchQuery),
  );
  return (
    <InspectorSection title={appStrings.inspector.parameters} icon={SlidersHorizontal}>
      {(props.parameters.length >= 8 || feature.parameterSearchVisible || feature.parameterSearchQuery) && (
        <label className="inspector-search">
          {appStrings.inspector.parameterSearch}
          <input
            type="search"
            value={feature.parameterSearchQuery}
            onChange={(event) => updateFeature((state) => setInspectorParameterSearchQuery(state, event.target.value))}
          />
        </label>
      )}
      {filteredParameters.length === 0 && <p>{appStrings.inspector.noParameters}</p>}
      {filteredParameters.map((item) => {
        const usageCount =
          item.usageCount ?? props.constraints.filter((constraint) => constraint.value?.parameter === item.id).length;
        return (
          <InspectorDisclosureRow
            key={item.id}
            title={item.name}
            subtitle={`${item.valueMm.toFixed(2)} ${item.unit === "millimeter" ? "mm" : item.unit}`}
            metadata={
              usageCount === 0 ? appStrings.inspector.parameterUnused : appStrings.inspector.parameterUsage(usageCount)
            }
            expanded={selectedParameterId === item.id}
            onToggle={() => setSelectedParameterId(item.id)}
          >
            {renderParameterEditor(item)}
          </InspectorDisclosureRow>
        );
      })}
      <button className="inspector-add-button" onClick={props.onAddParameter}>
        <Plus aria-hidden="true" />
        {appStrings.inspector.add}
      </button>
    </InspectorSection>
  );
}
