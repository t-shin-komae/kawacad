import { useCallback, useRef, useState } from "react";
import { documentAdapter } from "@/adapters/documentAdapter";
import { appStrings } from "@/localization";
import type { State } from "@/shared/domain/coreWireTypes";

type Props = {
  onDocumentState: (state: State) => void;
  reportError: (error: unknown, operation: string, commandKind?: string) => void;
};

export function useCadSession({ onDocumentState, reportError }: Props) {
  const [state, setState] = useState<State>();
  const [previewState, setPreviewState] = useState<State>();
  const [message, setMessage] = useState<string>(appStrings.status.loading);
  const previewRequest = useRef(0);
  const previewActive = useRef(false);

  const applyState = useCallback(
    (next: State) => {
      setState(next);
      onDocumentState(next);
      return next;
    },
    [onDocumentState],
  );
  const clearCanvasPreview = useCallback(() => {
    previewRequest.current += 1;
    previewActive.current = false;
    setPreviewState(undefined);
  }, []);
  const previewCommand = useCallback(
    (command: unknown, success: string) => {
      const request = ++previewRequest.current;
      previewActive.current = true;
      void documentAdapter
        .preview(command)
        .then((next) => {
          if (request !== previewRequest.current) return;
          setPreviewState(next);
          setMessage(success);
        })
        .catch((error) => {
          if (request === previewRequest.current) reportError(error, "previewCommand");
        });
    },
    [reportError],
  );
  const refresh = useCallback(async () => applyState(await documentAdapter.state()), [applyState]);
  const run = useCallback(
    async (work: () => Promise<State>, success: string, operation = "documentOperation", commandKind?: string) => {
      try {
        clearCanvasPreview();
        const next = applyState(await work());
        setMessage(success);
        return next;
      } catch (error) {
        reportError(error, operation, commandKind);
        return undefined;
      }
    },
    [applyState, clearCanvasPreview, reportError],
  );
  const command = useCallback(
    (kind: string, payload: unknown, success: string) =>
      run(() => documentAdapter.apply(kind, payload), success, "applyCommand", kind),
    [run],
  );

  return {
    state,
    previewState,
    message,
    setMessage,
    previewActive,
    applyState,
    clearCanvasPreview,
    previewCommand,
    refresh,
    run,
    command,
  };
}
