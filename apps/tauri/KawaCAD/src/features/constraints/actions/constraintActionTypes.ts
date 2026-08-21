import type { CanvasPresentation } from "@/features/canvas/state/useCanvasPresentation";
import type { State } from "@/shared/domain/coreWireTypes";

export type ConstraintActionInput = Pick<
  CanvasPresentation,
  | "setPendingConstraintValue"
  | "setPendingDerivedValue"
  | "setSelected"
  | "activeLayer"
  | "activeStyle"
  | "selected"
  | "tool"
  | "pendingDerivedValue"
> & {
  state: State | undefined;
  command: (kind: string, payload: unknown, success: string) => Promise<State | undefined>;
  applyState: (next: State) => State;
  presentOperationFailure: (error: unknown, operation: string, commandKind?: string) => void;
  setMessage: (message: string) => void;
};
