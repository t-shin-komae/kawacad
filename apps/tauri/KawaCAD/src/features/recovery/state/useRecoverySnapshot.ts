import { useCallback, useEffect, useState } from "react";
import { recoveryAdapter, type RecoveryCandidate } from "@/adapters/recoveryAdapter";
import type { State } from "@/shared/domain/coreWireTypes";
import { appStrings } from "@/localization";

type Props = {
  execute: (work: () => Promise<State>, success: string) => Promise<State | undefined>;
  report: (message: string) => void;
  onRestored: () => void;
};

export function useRecoverySnapshot({ execute, report, onRestored }: Props) {
  const [recoveryCandidates, setRecoveryCandidates] = useState<RecoveryCandidate[]>([]);

  useEffect(() => {
    void recoveryAdapter
      .candidates()
      .then(setRecoveryCandidates)
      .catch((error) => report(appStrings.error.recovery.candidateCheckFailed(error)));
  }, [report]);

  const restoreRecoverySnapshot = useCallback(
    (candidateId: string) => {
      void execute(() => recoveryAdapter.restore(candidateId), appStrings.error.recovery.restoreCompleted).then(
        (next) => {
          if (next) {
            setRecoveryCandidates([]);
            onRestored();
          }
        },
      );
    },
    [execute, onRestored],
  );
  const discardRecoverySnapshot = useCallback(
    (candidateId: string) => {
      void recoveryAdapter
        .discard(candidateId)
        .then(() => {
          setRecoveryCandidates((current) => current.filter((candidate) => candidate.id !== candidateId));
          report(appStrings.error.recovery.discardCompleted);
        })
        .catch((error) => report(appStrings.error.recovery.discardFailed(error)));
    },
    [report],
  );
  const postponeRecoverySnapshot = useCallback(() => {
    setRecoveryCandidates([]);
    report(appStrings.error.recovery.postponed);
  }, [report]);
  const revealRecoverySnapshot = useCallback(
    (candidateId: string) => {
      void recoveryAdapter.reveal(candidateId).catch((error) => report(appStrings.error.recovery.revealFailed(error)));
    },
    [report],
  );

  return {
    recoveryCandidates,
    restoreRecoverySnapshot,
    discardRecoverySnapshot,
    postponeRecoverySnapshot,
    revealRecoverySnapshot,
  };
}
