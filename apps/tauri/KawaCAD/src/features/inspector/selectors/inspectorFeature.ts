export type InspectorTab = "selection" | "layers" | "styles" | "parameters" | "parts";

export type InspectorShellState = { inspectorTab: InspectorTab };
export type LayerTabState = {
  layerSearchQuery: string;
  searchVisible: boolean;
};
export type StylesTabState = {
  sharedStyleSearchQuery: string;
  searchVisible: boolean;
};
export type ParametersTabState = {
  parameterSearchQuery: string;
  searchVisible: boolean;
};

export const initialInspectorShellState: InspectorShellState = {
  inspectorTab: "selection",
};
export const initialLayerTabState: LayerTabState = {
  layerSearchQuery: "",
  searchVisible: false,
};
export const initialStylesTabState: StylesTabState = {
  sharedStyleSearchQuery: "",
  searchVisible: false,
};
export const initialParametersTabState: ParametersTabState = {
  parameterSearchQuery: "",
  searchVisible: false,
};

export function setInspectorTab(state: InspectorShellState, inspectorTab: InspectorTab): InspectorShellState {
  return { ...state, inspectorTab };
}

export function setInspectorLayerSearchQuery(state: LayerTabState, layerSearchQuery: string): LayerTabState {
  return { ...state, layerSearchQuery };
}

export function setInspectorSharedStyleSearchQuery(
  state: StylesTabState,
  sharedStyleSearchQuery: string,
): StylesTabState {
  return { ...state, sharedStyleSearchQuery };
}

export function setInspectorParameterSearchQuery(
  state: ParametersTabState,
  parameterSearchQuery: string,
): ParametersTabState {
  return { ...state, parameterSearchQuery };
}

export function revealLayerSearch(state: LayerTabState): LayerTabState {
  return { ...state, searchVisible: true };
}

export function revealStylesSearch(state: StylesTabState): StylesTabState {
  return { ...state, searchVisible: true };
}

export function revealParametersSearch(state: ParametersTabState): ParametersTabState {
  return { ...state, searchVisible: true };
}

export function revealInspectorSelectionTab(state: InspectorShellState): InspectorShellState {
  return setInspectorTab(state, "selection");
}

export function matchesInspectorLayerSearch(layerName: string, query: string): boolean {
  return layerName.toLocaleLowerCase().includes(query.trim().toLocaleLowerCase());
}

export const matchesInspectorSearch = matchesInspectorLayerSearch;
