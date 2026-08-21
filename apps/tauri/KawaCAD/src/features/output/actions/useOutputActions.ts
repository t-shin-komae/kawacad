import { useOutputActionCallbacks } from "@/features/output/actions/useOutputActionCallbacks";
import type { OutputActionInput } from "@/features/output/actions/outputActionTypes";

/** Output-preview actions are composed from the output adapter boundary. */
export function useOutputActions(context: OutputActionInput, clearTransientCanvasState: () => void) {
  return useOutputActionCallbacks({ ...context, clearTransientCanvasState });
}
