import { useEffect } from "react";
import { appStrings } from "@/localization";
import { recoveryAdapter } from "@/adapters/recoveryAdapter";
import type { State } from "@/shared/domain/workspaceState";

type Props = {
  state: State | undefined;
  presentOperationFailure: (error: unknown, operation: string, commandKind?: string) => void;
};

/** Persists recovery snapshots without owning the recovery candidate state. */
export function useRecoveryEffects({ state, presentOperationFailure }: Props) {
  useEffect(() => {
    if (!state) return;
    const timer = window.setTimeout(
      () => {
        void recoveryAdapter
          .save()
          .catch((error) =>
            presentOperationFailure(
              new Error(appStrings.status.recoverySnapshotSaveFailed(error)),
              "saveRecoverySnapshot",
            ),
          );
      },
      state.persistence.isDirty ? 2_000 : 0,
    );
    return () => window.clearTimeout(timer);
  }, [presentOperationFailure, state]);
}
