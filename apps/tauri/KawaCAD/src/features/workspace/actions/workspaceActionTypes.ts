import type * as React from "react";
import type { Viewport } from "@/features/canvas/domain/cad";

export type WorkspaceActionInput = {
  setViewport: React.Dispatch<React.SetStateAction<Viewport>>;
  resetWorkspacePreferences: () => void;
  resetWorkspaceLayout: () => void;
  setMessage: (message: string) => void;
};
