import { invokeCommand } from "@/adapters/tauriCommandAdapter";
import type { State } from "@/shared/domain/workspaceState";

export type RecoveryCandidate = {
  id: string;
  displayName: string;
  originalDocumentPath?: string;
  updatedAtMs: number;
  status: "recoverable" | "broken";
  details?: string;
};

export const recoveryAdapter = {
  candidates: () => invokeCommand<RecoveryCandidate[]>("recovery_candidates"),
  restore: (candidateId: string) => invokeCommand<State>("restore_recovery_snapshot", { candidateId }),
  discard: (candidateId: string) => invokeCommand<void>("discard_recovery_snapshot", { candidateId }),
  reveal: (candidateId: string) => invokeCommand<void>("reveal_recovery_snapshot", { candidateId }),
  save: () => invokeCommand<void>("save_recovery_snapshot"),
};
