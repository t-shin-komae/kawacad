export type InspectorTab = "selection" | "layers" | "styles" | "parameters" | "parts";

export type InspectorFeatureState = {
  inspectorTab: InspectorTab;
  layerSearchQuery: string;
  sharedStyleSearchQuery: string;
  parameterSearchQuery: string;
  layerSearchVisible: boolean;
  sharedStyleSearchVisible: boolean;
  parameterSearchVisible: boolean;
};

export const initialInspectorFeatureState: InspectorFeatureState = {
  inspectorTab: "selection",
  layerSearchQuery: "",
  sharedStyleSearchQuery: "",
  parameterSearchQuery: "",
  layerSearchVisible: false,
  sharedStyleSearchVisible: false,
  parameterSearchVisible: false,
};

export function setInspectorTab(state: InspectorFeatureState, inspectorTab: InspectorTab): InspectorFeatureState {
  return { ...state, inspectorTab };
}

export function setInspectorLayerSearchQuery(
  state: InspectorFeatureState,
  layerSearchQuery: string,
): InspectorFeatureState {
  return { ...state, layerSearchQuery };
}

export function setInspectorSharedStyleSearchQuery(
  state: InspectorFeatureState,
  sharedStyleSearchQuery: string,
): InspectorFeatureState {
  return { ...state, sharedStyleSearchQuery };
}

export function setInspectorParameterSearchQuery(
  state: InspectorFeatureState,
  parameterSearchQuery: string,
): InspectorFeatureState {
  return { ...state, parameterSearchQuery };
}

export function revealInspectorSearchForCurrentTab(state: InspectorFeatureState): InspectorFeatureState {
  if (state.inspectorTab === "layers") return { ...state, layerSearchVisible: true };
  if (state.inspectorTab === "styles") return { ...state, sharedStyleSearchVisible: true };
  if (state.inspectorTab === "parameters") return { ...state, parameterSearchVisible: true };
  return state;
}

export function revealInspectorSelectionTab(state: InspectorFeatureState): InspectorFeatureState {
  return setInspectorTab(state, "selection");
}

export function matchesInspectorLayerSearch(layerName: string, query: string): boolean {
  return layerName.toLocaleLowerCase().includes(query.trim().toLocaleLowerCase());
}

export const matchesInspectorSearch = matchesInspectorLayerSearch;
