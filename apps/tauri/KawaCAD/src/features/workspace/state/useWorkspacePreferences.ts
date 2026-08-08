import { useCallback, useEffect, useState } from "react";
import { workspacePreferencesAdapter } from "@/adapters/workspacePreferencesAdapter";
import { defaultCollapsedToolGroups } from "@/features/canvas/domain/workspaceTools";

export function useWorkspacePreferences() {
  const [gridVisible, setGridVisible] = useState(true);
  const [a4Visible, setA4Visible] = useState(true);
  const [snapEnabled, setSnapEnabled] = useState(true);
  const [pointSnapEnabled, setPointSnapEnabled] = useState(true);
  const [inspectorOpen, setInspectorOpen] = useState(workspacePreferencesAdapter.loadInspectorOpen);
  const [paletteOpen, setPaletteOpen] = useState(true);
  const [bottomWorkbenchVisible, setBottomWorkbenchVisible] = useState(false);
  const [basicToolsOnly, setBasicToolsOnly] = useState(() => !workspacePreferencesAdapter.loadDetailedToolsVisible());
  const [collapsedToolGroups, setCollapsedToolGroups] = useState<Set<string>>(
    workspacePreferencesAdapter.loadCollapsedToolGroups,
  );

  useEffect(() => {
    workspacePreferencesAdapter.saveDetailedToolsVisible(!basicToolsOnly);
  }, [basicToolsOnly]);
  useEffect(() => {
    workspacePreferencesAdapter.saveCollapsedToolGroups(collapsedToolGroups);
  }, [collapsedToolGroups]);
  useEffect(() => {
    workspacePreferencesAdapter.saveInspectorOpen(inspectorOpen);
  }, [inspectorOpen]);

  const resetWorkspacePreferences = useCallback(() => {
    workspacePreferencesAdapter.resetWorkspacePreferences();
    setGridVisible(true);
    setA4Visible(true);
    setSnapEnabled(true);
    setPointSnapEnabled(true);
    setPaletteOpen(true);
    setBasicToolsOnly(true);
    setCollapsedToolGroups(new Set(defaultCollapsedToolGroups));
    setInspectorOpen(true);
  }, []);

  return {
    gridVisible,
    setGridVisible,
    a4Visible,
    setA4Visible,
    snapEnabled,
    setSnapEnabled,
    pointSnapEnabled,
    setPointSnapEnabled,
    inspectorOpen,
    setInspectorOpen,
    paletteOpen,
    setPaletteOpen,
    bottomWorkbenchVisible,
    setBottomWorkbenchVisible,
    basicToolsOnly,
    setBasicToolsOnly,
    collapsedToolGroups,
    setCollapsedToolGroups,
    resetWorkspacePreferences,
  };
}
