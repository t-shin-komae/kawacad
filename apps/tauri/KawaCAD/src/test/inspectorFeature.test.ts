import { describe, expect, it } from "vitest";
import {
  initialInspectorFeatureState,
  revealInspectorSelectionTab,
  revealInspectorSearchForCurrentTab,
  setInspectorLayerSearchQuery,
  setInspectorParameterSearchQuery,
  setInspectorSharedStyleSearchQuery,
  setInspectorTab,
} from "@/features/inspector/selectors/inspectorFeature";

describe("Inspector feature model", () => {
  it("keeps presentation state and inspector actions separate", () => {
    const stateWithSearch = setInspectorLayerSearchQuery(initialInspectorFeatureState, "outline");
    expect(stateWithSearch).toMatchObject({ inspectorTab: "selection", layerSearchQuery: "outline" });

    const stateWithLayers = setInspectorTab(stateWithSearch, "layers");
    expect(stateWithLayers.inspectorTab).toBe("layers");
    expect(revealInspectorSearchForCurrentTab(stateWithLayers).layerSearchVisible).toBe(true);
    const stateWithStyles = setInspectorSharedStyleSearchQuery(setInspectorTab(stateWithLayers, "styles"), "stitch");
    expect(stateWithStyles.sharedStyleSearchQuery).toBe("stitch");
    expect(revealInspectorSearchForCurrentTab(stateWithStyles).sharedStyleSearchVisible).toBe(true);
    const stateWithParameters = setInspectorParameterSearchQuery(
      setInspectorTab(stateWithStyles, "parameters"),
      "width",
    );
    expect(stateWithParameters.parameterSearchQuery).toBe("width");
    expect(revealInspectorSearchForCurrentTab(stateWithParameters).parameterSearchVisible).toBe(true);
    expect(revealInspectorSelectionTab(stateWithLayers).inspectorTab).toBe("selection");
  });
});
