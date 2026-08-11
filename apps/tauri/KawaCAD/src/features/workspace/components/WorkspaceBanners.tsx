import type { AppErrorPresentation } from "@/features/workspace/selectors/appErrorPresentation";
import { AppErrorBanner } from "@/features/workspace/components/AppErrorBanner";
import { RecoverySaveFailureBanner } from "@/features/recovery/components/RecoverySaveFailureBanner";

type Props = {
  errorPresentation?: AppErrorPresentation;
  recoverySaveFailure?: string;
  onDismissError: () => void;
  onRetryRecovery: () => void;
  onDismissRecovery: () => void;
};

export function WorkspaceBanners({
  errorPresentation,
  recoverySaveFailure,
  onDismissError,
  onRetryRecovery,
  onDismissRecovery,
}: Props) {
  return (
    <>
      {errorPresentation && <AppErrorBanner presentation={errorPresentation} onDismiss={onDismissError} />}
      {recoverySaveFailure && (
        <RecoverySaveFailureBanner
          details={recoverySaveFailure}
          onRetry={onRetryRecovery}
          onDismiss={onDismissRecovery}
        />
      )}
    </>
  );
}
