import { invokeCommand } from "@/adapters/tauriCommandAdapter";
import type { State } from "@/shared/domain/workspaceState";

export type RecoveryCandidate = { displayName: string; originalDocumentPath?: string };

export const recoveryAdapter = {
  candidate: () => invokeCommand<RecoveryCandidate | null>("recovery_candidate"),
  restore: () => invokeCommand<State>("restore_recovery_snapshot"),
  discard: () => invokeCommand<void>("discard_recovery_snapshot"),
  save: () => invokeCommand<void>("save_recovery_snapshot"),
};
