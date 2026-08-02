import { invokeCommand } from "@/adapters/tauriCommandAdapter";
import type { State } from "@/shared/domain/workspaceState";

export const documentAdapter = {
  command: <T>(name: string, args?: Record<string, unknown>) => invokeCommand<T>(name, args),
  state: () => invokeCommand<State>("document_state"),
  preview: (command: unknown) => invokeCommand<State>("preview_command", { command }),
  apply: (kind: string, payload: unknown) => invokeCommand<State>("apply_command", { command: { kind, payload } }),
  restoreRecoverySnapshot: () => invokeCommand<State>("restore_recovery_snapshot"),
};
