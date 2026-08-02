import { useCallback, useEffect, useState } from "react";
import { recoveryAdapter, type RecoveryCandidate } from "@/adapters/recoveryAdapter";
import type { State } from "@/shared/domain/workspaceState";
import { appStrings } from "@/localization";

type Props = {
  execute: (work: () => Promise<State>, success: string) => Promise<State | undefined>;
  report: (message: string) => void;
  onRestored: () => void;
};

export function useRecoverySnapshot({ execute, report, onRestored }: Props) {
  const [recoveryCandidate, setRecoveryCandidate] = useState<RecoveryCandidate>();

  useEffect(() => {
    void recoveryAdapter
      .candidate()
      .then((candidate) => setRecoveryCandidate(candidate ?? undefined))
      .catch((error) => report(appStrings.error.recovery.candidateCheckFailed(error)));
  }, [report]);

  const restoreRecoverySnapshot = useCallback(() => {
    void execute(() => recoveryAdapter.restore(), appStrings.error.recovery.restoreCompleted).then((next) => {
      if (next) onRestored();
    });
    setRecoveryCandidate(undefined);
  }, [execute, onRestored]);
  const discardRecoverySnapshot = useCallback(() => {
    void recoveryAdapter
      .discard()
      .then(() => {
        setRecoveryCandidate(undefined);
        report(appStrings.error.recovery.discardCompleted);
      })
      .catch((error) => report(appStrings.error.recovery.discardFailed(error)));
  }, [report]);
  const postponeRecoverySnapshot = useCallback(() => {
    setRecoveryCandidate(undefined);
    report(appStrings.error.recovery.postponed);
  }, [report]);

  return { recoveryCandidate, restoreRecoverySnapshot, discardRecoverySnapshot, postponeRecoverySnapshot };
}
