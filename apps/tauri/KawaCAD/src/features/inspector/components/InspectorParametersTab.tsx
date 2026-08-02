import type { ReactNode } from "react";
import {
  matchesInspectorSearch,
  setInspectorParameterSearchQuery,
  type InspectorFeatureState,
} from "@/features/inspector/selectors/inspectorFeature";
import { appStrings } from "@/localization";
import type { Props } from "@/features/inspector/components/InspectorPanel";

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
  return (
    <section>
      <h2>{appStrings.inspector.parameters}</h2>
      <button onClick={props.onAddParameter}>{appStrings.inspector.add}</button>
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
      {props.parameters
        .filter((item) =>
          matchesInspectorSearch(
            `${item.name} ${item.memo} ${item.unit} ${item.valueMm}`,
            feature.parameterSearchQuery,
          ),
        )
        .map((item) => (
          <div key={item.id}>{renderParameterEditor(item)}</div>
        ))}
    </section>
  );
}
