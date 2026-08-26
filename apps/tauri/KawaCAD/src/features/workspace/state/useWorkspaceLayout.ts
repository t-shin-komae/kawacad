import { useCallback, useEffect, useRef, useState } from "react";
import { makeWindowLayout } from "@/features/workspace/selectors/layout";
import { workspacePreferencesAdapter } from "@/adapters/workspacePreferencesAdapter";
import { toolPaletteWidthRange } from "@/features/canvas/domain/workspaceTools";

export function useWorkspaceLayout() {
  const [contentWidth, setContentWidth] = useState(() => window.innerWidth);
  const [toolPaletteWidth, setToolPaletteWidth] = useState(workspacePreferencesAdapter.loadToolPaletteWidth);
  const [toolPaletteVisible, setToolPaletteVisible] = useState(workspacePreferencesAdapter.loadToolPaletteVisible);
  const [compactDrawer, setCompactDrawer] = useState<"tools" | "inspector">();
  const previousLayoutMode = useRef<ReturnType<typeof makeWindowLayout>["mode"]>();
  const layout = makeWindowLayout(contentWidth, toolPaletteWidth, 440, previousLayoutMode.current, toolPaletteVisible);

  useEffect(() => {
    workspacePreferencesAdapter.saveToolPaletteWidth(toolPaletteWidth);
  }, [toolPaletteWidth]);
  useEffect(() => {
    workspacePreferencesAdapter.saveToolPaletteVisible(toolPaletteVisible);
  }, [toolPaletteVisible]);
  useEffect(() => {
    previousLayoutMode.current = layout.mode;
    if (layout.mode !== "compact") setCompactDrawer(undefined);
  }, [layout.mode]);
  useEffect(() => {
    const onResize = () => setContentWidth(window.innerWidth);
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);

  const resetWorkspaceLayout = useCallback(() => {
    setToolPaletteWidth(toolPaletteWidthRange.min);
    setToolPaletteVisible(true);
    setCompactDrawer(undefined);
  }, []);
  const closeCompactDrawer = useCallback(() => setCompactDrawer(undefined), []);

  return {
    layout,
    toolPaletteWidth,
    setToolPaletteWidth,
    toolPaletteVisible,
    setToolPaletteVisible,
    compactDrawer,
    setCompactDrawer,
    closeCompactDrawer,
    resetWorkspaceLayout,
  };
}
