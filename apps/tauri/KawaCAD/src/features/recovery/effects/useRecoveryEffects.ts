import { useCallback, useEffect, useState } from "react";
import { appStrings } from "@/localization";
import { recoveryAdapter } from "@/adapters/recoveryAdapter";
import type { State } from "@/shared/domain/coreWireTypes";

type Props = {
  state: State | undefined;
};

/** Persists recovery snapshots without owning the recovery candidate state. */
export function useRecoveryEffects({ state }: Props) {
  const [saveFailure, setSaveFailure] = useState<string>();
  const saveRecoverySnapshot = useCallback(async () => {
    try {
      await recoveryAdapter.save();
      setSaveFailure(undefined);
    } catch (error) {
      setSaveFailure(appStrings.status.recoverySnapshotSaveFailed(error));
    }
  }, []);
  useEffect(() => {
    if (!state) return;
    const timer = window.setTimeout(
      () => {
        void saveRecoverySnapshot();
      },
      state.persistence.isDirty ? 2_000 : 0,
    );
    return () => window.clearTimeout(timer);
  }, [saveRecoverySnapshot, state]);
  return {
    saveFailure,
    retry: saveRecoverySnapshot,
    dismiss: () => setSaveFailure(undefined),
  };
}
