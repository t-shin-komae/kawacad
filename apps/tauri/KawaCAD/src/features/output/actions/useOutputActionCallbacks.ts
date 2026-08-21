import { useCallback } from "react";
import { appStrings } from "@/localization";
import { documentAdapter } from "@/adapters/documentAdapter";
import type { CanvasViewMode, Tool } from "@/features/canvas/domain/canvasDomainModels";
import type { State } from "@/shared/domain/coreWireTypes";
import type { OutputActionInput } from "@/features/output/actions/outputActionTypes";

type OutputActionDependencies = Pick<OutputActionInput, "state" | "a4Landscape" | "run" | "setTool"> & {
  clearTransientCanvasState: () => void;
};

export function useOutputActionCallbacks(dependencies: OutputActionDependencies) {
  const { state, run, setTool, clearTransientCanvasState } = dependencies;
  const setDocumentViewMode = useCallback(
    (viewMode: CanvasViewMode, activeTool: Tool = "select") => {
      if (state?.viewMode === viewMode) return;
      void run(
        () => documentAdapter.command<State>("set_view_mode", { viewMode }),
        appStrings.app.viewModeChanged(viewMode === "outputPreview"),
      ).then((next) => {
        if (!next) return;
        clearTransientCanvasState();
        setTool(activeTool);
      });
    },
    [clearTransientCanvasState, run, setTool, state?.viewMode],
  );

  const setOutputOrientation = useCallback(
    (landscape: boolean) => {
      void run(
        () =>
          documentAdapter.command<State>("apply_command", {
            command: {
              kind: "setPrintOrientation",
              payload: { orientation: landscape ? "landscape" : "portrait" },
            },
          }),
        appStrings.app.a4OrientationChanged(landscape),
      );
    },
    [run],
  );

  return { setDocumentViewMode, setOutputOrientation };
}
