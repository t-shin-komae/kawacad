import { useCallback } from "react";
import type { Part } from "@/shared/domain/coreWireTypes";

/** Workspace-only adaptations applied when Inspector is shown as a drawer. */
export function useCompactInspectorActions(
  setPartOriginSelection: (id: string) => void,
  closeCompactDrawer: () => void,
) {
  const beginSetPartOrigin = useCallback(
    (part: Part) => {
      setPartOriginSelection(part.id);
      closeCompactDrawer();
    },
    [closeCompactDrawer, setPartOriginSelection],
  );
  return { beginSetPartOrigin };
}
