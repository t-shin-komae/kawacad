import {
  defaultCollapsedToolGroups,
  toolGroupPreferenceIds,
  toolPaletteWidthRange,
} from "@/features/canvas/domain/workspaceTools";

const detailedToolsPreferenceKey = "leather.toolPalette.showsDetailedTools";
const inspectorPreferenceKey = "leather.layout.inspectorPanelVisible";
const toolPanelWidthKey = "leather.layout.toolPanelWidth";

function storedBoolean(key: string, fallback: boolean) {
  const value = window.localStorage.getItem(key);
  return value === null ? fallback : value === "true";
}

function toolGroupPreferenceKey(title: string) {
  return `leather.toolPalette.groupCollapsed.v1.${toolGroupPreferenceIds[title]}`;
}

export const workspacePreferencesAdapter = {
  loadToolPaletteWidth() {
    const value = Number(window.localStorage.getItem(toolPanelWidthKey));
    return Number.isFinite(value)
      ? Math.min(toolPaletteWidthRange.max, Math.max(toolPaletteWidthRange.min, value))
      : toolPaletteWidthRange.min;
  },

  saveToolPaletteWidth(value: number) {
    if (value === toolPaletteWidthRange.min) window.localStorage.removeItem(toolPanelWidthKey);
    else window.localStorage.setItem(toolPanelWidthKey, String(value));
  },

  loadInspectorOpen() {
    return storedBoolean(inspectorPreferenceKey, true);
  },

  saveInspectorOpen(value: boolean) {
    if (value) window.localStorage.removeItem(inspectorPreferenceKey);
    else window.localStorage.setItem(inspectorPreferenceKey, "false");
  },

  loadDetailedToolsVisible() {
    return storedBoolean(detailedToolsPreferenceKey, false);
  },

  saveDetailedToolsVisible(value: boolean) {
    if (value) window.localStorage.setItem(detailedToolsPreferenceKey, "true");
    else window.localStorage.removeItem(detailedToolsPreferenceKey);
  },

  loadCollapsedToolGroups() {
    return new Set(
      Object.entries(toolGroupPreferenceIds)
        .filter(([title, id]) =>
          storedBoolean(`leather.toolPalette.groupCollapsed.v1.${id}`, defaultCollapsedToolGroups.has(title)),
        )
        .map(([title]) => title),
    );
  },

  saveCollapsedToolGroups(collapsedGroups: Set<string>) {
    Object.keys(toolGroupPreferenceIds).forEach((title) => {
      const key = toolGroupPreferenceKey(title);
      if (collapsedGroups.has(title)) window.localStorage.setItem(key, "true");
      else window.localStorage.removeItem(key);
    });
  },

  resetWorkspacePreferences() {
    window.localStorage.removeItem(detailedToolsPreferenceKey);
    window.localStorage.removeItem(inspectorPreferenceKey);
    Object.keys(toolGroupPreferenceIds).forEach((title) =>
      window.localStorage.removeItem(toolGroupPreferenceKey(title)),
    );
  },
};
