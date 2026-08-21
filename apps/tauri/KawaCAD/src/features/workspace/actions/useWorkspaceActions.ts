import { useCallback } from "react";
import { defaultViewport } from "@/features/canvas/domain/cad";
import { appStrings } from "@/localization";
import type { WorkspaceActionInput } from "@/features/workspace/actions/workspaceActionTypes";

/** Workspace reset coordinates the two workspace state owners. */
export function useWorkspaceActions(context: WorkspaceActionInput) {
  const { setViewport, resetWorkspacePreferences, resetWorkspaceLayout, setMessage } = context;
  const resetWorkspace = useCallback(() => {
    setViewport(defaultViewport);
    resetWorkspacePreferences();
    resetWorkspaceLayout();
    setMessage(appStrings.status.workspaceReset);
  }, [resetWorkspaceLayout, resetWorkspacePreferences, setMessage, setViewport]);
  return { resetWorkspace };
}
