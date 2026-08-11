import { useEffect, type MutableRefObject } from "react";
import { appStrings } from "@/localization";
import { documentWindowPresentation, type State } from "@/shared/domain/workspaceState";
import { desktopAdapter } from "@/adapters/desktopAdapter";
import { windowAdapter } from "@/adapters/windowAdapter";
import type { DocumentSaveChoice } from "@/features/document/state/useDocumentPresentation";

type Props = {
  state: State | undefined;
  allowWindowClose: MutableRefObject<boolean>;
  saveBeforeDestructiveAction: () => Promise<boolean>;
  requestDocumentSaveConfirmation: (reason: string) => Promise<DocumentSaveChoice>;
};

/** Owns the native window title and close-confirmation boundary. */
export function useWindowLifecycle({
  state,
  allowWindowClose,
  saveBeforeDestructiveAction,
  requestDocumentSaveConfirmation,
}: Props) {
  useEffect(() => {
    if (!state) return;
    const title = documentWindowPresentation(
      state.snapshot.name,
      state.persistence.path,
      state.persistence.isDirty,
    ).title;
    document.title = title;
    void windowAdapter.setTitle(title).catch(() => undefined);
  }, [state]);

  useEffect(() => {
    let disposed = false;
    let unlisten: (() => void) | undefined;
    void windowAdapter
      .onCloseRequested(async (event) => {
        if (allowWindowClose.current) return;
        event.preventDefault();
        if (!state?.persistence.isDirty) {
          allowWindowClose.current = true;
          await desktopAdapter.exitApplication();
          return;
        }
        const choice = await requestDocumentSaveConfirmation(appStrings.app.saveAndCloseQuestion);
        if (choice === "save") {
          if (!(await saveBeforeDestructiveAction())) return;
        } else if (choice === "cancel") return;
        allowWindowClose.current = true;
        await desktopAdapter.exitApplication();
      })
      .then((listener) => {
        if (disposed) listener();
        else unlisten = listener;
      })
      .catch(() => undefined);
    return () => {
      disposed = true;
      unlisten?.();
    };
  }, [allowWindowClose, requestDocumentSaveConfirmation, saveBeforeDestructiveAction, state?.persistence.isDirty]);
}
