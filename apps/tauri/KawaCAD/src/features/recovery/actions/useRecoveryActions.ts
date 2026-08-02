import { useCallback } from "react";

type Props = {
  restoreRecoverySnapshot: () => void;
  discardRecoverySnapshot: () => void;
  postponeRecoverySnapshot: () => void;
};

/** Provides the recovery command surface while candidate state remains in the composition root. */
export function useRecoveryActions({
  restoreRecoverySnapshot,
  discardRecoverySnapshot,
  postponeRecoverySnapshot,
}: Props) {
  return {
    restoreRecoverySnapshot: useCallback(() => restoreRecoverySnapshot(), [restoreRecoverySnapshot]),
    discardRecoverySnapshot: useCallback(() => discardRecoverySnapshot(), [discardRecoverySnapshot]),
    postponeRecoverySnapshot: useCallback(() => postponeRecoverySnapshot(), [postponeRecoverySnapshot]),
  };
}
