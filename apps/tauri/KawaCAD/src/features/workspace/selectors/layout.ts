export type WindowLayoutMode = "compact" | "regular" | "wide";
export type WindowLayout = {
  mode: WindowLayoutMode;
  workspaceWidth: number;
  toolDockVisible: boolean;
  toolDockWidth: number;
  inspectorDockWidth: number;
  overlayInspectorWidth: number;
  compactToolDrawerWidth: number;
  compactInspectorDrawerWidth: number;
};

export const windowLayout = {
  minimumWindowWidth: 1024,
  minimumInspectorContentWidth: 440,
  maximumInspectorWidth: 520,
  canvasMinimumWidth: 640,
  panelResizeHandleWidth: 8,
  regularMinimumWorkspaceWidth: 860,
  hysteresis: 24,
};
const wideMinimumWorkspaceWidth =
  windowLayout.canvasMinimumWidth + windowLayout.panelResizeHandleWidth + windowLayout.minimumInspectorContentWidth;
const clamp = (value: number, minimum: number, maximum: number, fallback: number) =>
  Number.isFinite(value) ? Math.min(maximum, Math.max(minimum, value)) : fallback;

export function makeWindowLayout(
  contentWidth: number,
  storedToolWidth: number,
  storedInspectorWidth: number,
  previousMode?: WindowLayoutMode,
  toolPaletteVisible = true,
): WindowLayout {
  const potentialToolWidth = clamp(storedToolWidth, 176, 260, 176);
  const candidateWidth = contentWidth - potentialToolWidth - windowLayout.panelResizeHandleWidth;
  const mode = resolveWindowLayoutMode(candidateWidth, previousMode);
  const toolMaximum = 260;
  const toolDockWidth = clamp(storedToolWidth, 176, toolMaximum, 176);
  const toolDockVisible = mode !== "compact" && toolPaletteVisible;
  const workspaceWidth = contentWidth - (toolDockVisible ? toolDockWidth + windowLayout.panelResizeHandleWidth : 0);
  const overlayMaximum = Math.min(
    windowLayout.maximumInspectorWidth,
    Math.max(windowLayout.minimumInspectorContentWidth, contentWidth * 0.36),
  );
  return {
    mode,
    workspaceWidth,
    toolDockVisible,
    toolDockWidth,
    inspectorDockWidth: clamp(
      storedInspectorWidth,
      windowLayout.minimumInspectorContentWidth,
      windowLayout.maximumInspectorWidth,
      windowLayout.minimumInspectorContentWidth,
    ),
    overlayInspectorWidth: Math.min(
      clamp(
        storedInspectorWidth,
        windowLayout.minimumInspectorContentWidth,
        windowLayout.maximumInspectorWidth,
        windowLayout.minimumInspectorContentWidth,
      ),
      overlayMaximum,
    ),
    compactToolDrawerWidth: 260,
    compactInspectorDrawerWidth: windowLayout.minimumInspectorContentWidth,
  };
}

export function resolveWindowLayoutMode(workspaceWidth: number, previousMode?: WindowLayoutMode): WindowLayoutMode {
  if (!previousMode)
    return workspaceWidth < windowLayout.regularMinimumWorkspaceWidth
      ? "compact"
      : workspaceWidth < wideMinimumWorkspaceWidth
        ? "regular"
        : "wide";
  if (previousMode === "compact")
    return workspaceWidth >= windowLayout.regularMinimumWorkspaceWidth + windowLayout.hysteresis
      ? "regular"
      : "compact";
  if (previousMode === "regular") {
    if (workspaceWidth < windowLayout.regularMinimumWorkspaceWidth - windowLayout.hysteresis) return "compact";
    return workspaceWidth >= wideMinimumWorkspaceWidth + windowLayout.hysteresis ? "wide" : "regular";
  }
  return workspaceWidth < wideMinimumWorkspaceWidth ? "regular" : "wide";
}

export function constrainedWindowWidth(proposedWidth: number, visibleScreenWidth: number) {
  if (!Number.isFinite(proposedWidth) || !Number.isFinite(visibleScreenWidth) || visibleScreenWidth <= 0)
    return proposedWidth;
  return Math.min(
    Math.max(proposedWidth, Math.min(windowLayout.minimumWindowWidth, visibleScreenWidth)),
    visibleScreenWidth,
  );
}
