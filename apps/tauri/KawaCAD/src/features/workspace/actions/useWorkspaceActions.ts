import { useCallback } from "react";
import { defaultViewport } from "@/features/canvas/domain/cad";
import { appStrings } from "@/localization";
import type { WorkspaceActionContext } from "@/app/actions/useActionRuntime";

/** Workspace reset coordinates the two workspace state owners. */
export function useWorkspaceActions(context: WorkspaceActionContext) {
  const { setViewport, resetWorkspacePreferences, resetWorkspaceLayout, setMessage } = context;
  const resetWorkspace = useCallback(() => {
    setViewport(defaultViewport);
    resetWorkspacePreferences();
    resetWorkspaceLayout();
    setMessage(appStrings.status.workspaceReset);
  }, [resetWorkspaceLayout, resetWorkspacePreferences, setMessage, setViewport]);
  return { resetWorkspace };
}
