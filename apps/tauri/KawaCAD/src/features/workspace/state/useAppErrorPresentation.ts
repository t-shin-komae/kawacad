import { useCallback, useState } from "react";
import {
  makeAppErrorPresentation,
  mergeAppErrorPresentation,
  type AppErrorPresentation,
} from "@/features/workspace/selectors/appErrorPresentation";

export function useAppErrorPresentation() {
  const [errorPresentation, setErrorPresentation] = useState<AppErrorPresentation>();

  const presentOperationFailure = useCallback((error: unknown, operation: string, commandKind?: string) => {
    const presentation = makeAppErrorPresentation(error, { operation, commandKind });
    setErrorPresentation((current) => mergeAppErrorPresentation(current, presentation));
  }, []);

  const dismissPresentedError = useCallback(() => setErrorPresentation(undefined), []);

  return {
    errorPresentation,
    presentOperationFailure,
    dismissPresentedError,
  };
}
