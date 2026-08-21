import type * as React from "react";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
import type { State } from "@/shared/domain/coreWireTypes";

export type OutputActionInput = {
  state: State | undefined;
  a4Landscape: boolean;
  run: (
    work: () => Promise<State>,
    success: string,
    operation?: string,
    commandKind?: string,
  ) => Promise<State | undefined>;
  setTool: React.Dispatch<React.SetStateAction<Tool>>;
};
