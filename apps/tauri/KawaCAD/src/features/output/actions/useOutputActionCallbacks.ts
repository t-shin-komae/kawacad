import { useCallback } from "react";
import { appStrings } from "@/localization";
import { documentAdapter } from "@/adapters/documentAdapter";
import type { CanvasViewMode, Tool } from "@/features/canvas/domain/canvasDomainModels";
import type { State } from "@/shared/domain/workspaceState";
import type { OutputActionContext } from "@/app/actions/useActionRuntime";

type OutputActionDependencies = Pick<OutputActionContext, "state" | "a4Landscape" | "run" | "setTool"> & {
  clearTransientCanvasState: () => void;
};

export function useOutputActionCallbacks(dependencies: OutputActionDependencies) {
  const { state, a4Landscape, run, setTool, clearTransientCanvasState } = dependencies;
  const setDocumentViewMode = useCallback(
    (viewMode: CanvasViewMode, activeTool: Tool = "select") => {
      if (state?.viewMode === viewMode) return;
      void run(
        () => documentAdapter.command<State>("set_view_mode", { viewMode, outputLandscape: a4Landscape }),
        appStrings.app.viewModeChanged(viewMode === "outputPreview"),
      ).then((next) => {
        if (!next) return;
        clearTransientCanvasState();
        setTool(activeTool);
      });
    },
    [a4Landscape, clearTransientCanvasState, run, setTool, state?.viewMode],
  );

  const setOutputOrientation = useCallback(
    (landscape: boolean) => {
      if (state?.viewMode !== "outputPreview") return;
      void run(
        () =>
          documentAdapter.command<State>("set_view_mode", {
            viewMode: "outputPreview",
            outputLandscape: landscape,
          }),
        appStrings.app.viewModeChanged(true),
      );
    },
    [run, state?.viewMode],
  );

  return { setDocumentViewMode, setOutputOrientation };
}
