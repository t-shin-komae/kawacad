import { useCallback, type Dispatch, type SetStateAction } from "react";
import type { State } from "@/shared/domain/workspaceState";

/** Keeps the presentation-only active layer/style selection valid after a Core snapshot changes. */
export function useActiveDrawingOptions(
  setActiveLayer: Dispatch<SetStateAction<string>>,
  setActiveStyle: Dispatch<SetStateAction<string>>,
) {
  return useCallback(
    (next: State) => {
      setActiveLayer((current) =>
        next.layers.some((layer) => layer.id === current) ? current : (next.layers[0]?.id ?? ""),
      );
      setActiveStyle((current) =>
        next.sharedStyles.some((style) => style.id === current) ? current : (next.sharedStyles[0]?.id ?? ""),
      );
    },
    [setActiveLayer, setActiveStyle],
  );
}
