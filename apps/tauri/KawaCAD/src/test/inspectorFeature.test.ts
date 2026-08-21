import { describe, expect, it } from "vitest";
import {
  initialInspectorShellState,
  initialLayerTabState,
  initialStylesTabState,
  initialParametersTabState,
  revealLayerSearch,
  revealStylesSearch,
  revealParametersSearch,
  revealInspectorSelectionTab,
  setInspectorLayerSearchQuery,
  setInspectorParameterSearchQuery,
  setInspectorSharedStyleSearchQuery,
  setInspectorTab,
} from "@/features/inspector/selectors/inspectorFeature";

describe("Inspector feature model", () => {
  it("keeps presentation state and inspector actions separate", () => {
    const stateWithSearch = setInspectorLayerSearchQuery(initialLayerTabState, "outline");
    expect(stateWithSearch).toMatchObject({ layerSearchQuery: "outline" });

    const stateWithLayers = setInspectorTab(initialInspectorShellState, "layers");
    expect(stateWithLayers.inspectorTab).toBe("layers");
    expect(revealLayerSearch(stateWithSearch).searchVisible).toBe(true);
    const stateWithStyles = setInspectorSharedStyleSearchQuery(initialStylesTabState, "stitch");
    expect(stateWithStyles.sharedStyleSearchQuery).toBe("stitch");
    expect(revealStylesSearch(stateWithStyles).searchVisible).toBe(true);
    const stateWithParameters = setInspectorParameterSearchQuery(initialParametersTabState, "width");
    expect(stateWithParameters.parameterSearchQuery).toBe("width");
    expect(revealParametersSearch(stateWithParameters).searchVisible).toBe(true);
    expect(revealInspectorSelectionTab(stateWithLayers).inspectorTab).toBe("selection");
  });
});
