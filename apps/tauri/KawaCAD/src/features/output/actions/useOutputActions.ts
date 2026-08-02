import { useOutputActionCallbacks } from "@/features/output/actions/useOutputActionCallbacks";
import type { OutputActionContext } from "@/app/actions/useActionRuntime";

/** Output-preview actions are composed from the output adapter boundary. */
export function useOutputActions(context: OutputActionContext, clearTransientCanvasState: () => void) {
  return useOutputActionCallbacks({ ...context, clearTransientCanvasState });
}
