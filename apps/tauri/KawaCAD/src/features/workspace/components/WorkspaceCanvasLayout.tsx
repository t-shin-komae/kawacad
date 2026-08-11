import type { ReactNode } from "react";
import type { WindowLayoutMode } from "@/features/workspace/selectors/layout";
import { appStrings } from "@/localization";

type Props = {
  mode: WindowLayoutMode;
  inspectorOpen: boolean;
  compactDrawer?: "tools" | "inspector";
  canvas: ReactNode;
  dockedInspector: ReactNode;
  compactToolDrawer: ReactNode;
  compactInspectorDrawer: ReactNode;
  onDismissCompactDrawer: () => void;
};

export function WorkspaceCanvasLayout({
  mode,
  inspectorOpen,
  compactDrawer,
  canvas,
  dockedInspector,
  compactToolDrawer,
  compactInspectorDrawer,
  onDismissCompactDrawer,
}: Props) {
  const compactInspectorVisible = mode === "compact" && compactDrawer === "inspector" && inspectorOpen;

  return (
    <section className="workspace">
      {canvas}
      {inspectorOpen && mode !== "compact" && dockedInspector}
      {mode === "compact" && compactDrawer === "tools" && (
        <aside className="compact-drawer compact-tools-drawer" aria-label={appStrings.app.toolDrawer}>
          {compactToolDrawer}
        </aside>
      )}
      {mode === "compact" && (compactDrawer === "tools" || compactInspectorVisible) && (
        <button
          type="button"
          className="compact-drawer-backdrop"
          aria-label={appStrings.accessibility.dismissDrawer}
          onClick={onDismissCompactDrawer}
        />
      )}
      {compactInspectorVisible && compactInspectorDrawer}
    </section>
  );
}
