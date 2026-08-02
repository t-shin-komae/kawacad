import { useEffect, type MutableRefObject } from "react";
import { appStrings } from "@/localization";
import { documentWindowPresentation, type State } from "@/shared/domain/workspaceState";
import { desktopAdapter } from "@/adapters/desktopAdapter";
import { dialogAdapter } from "@/adapters/dialogAdapter";
import { windowAdapter } from "@/adapters/windowAdapter";

type Props = {
  state: State | undefined;
  allowWindowClose: MutableRefObject<boolean>;
  saveBeforeDestructiveAction: () => Promise<boolean>;
};

/** Owns the native window title and close-confirmation boundary. */
export function useWindowLifecycle({ state, allowWindowClose, saveBeforeDestructiveAction }: Props) {
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
        const saveChanges = await dialogAdapter.confirm(appStrings.app.saveAndCloseQuestion, {
          title: appStrings.app.productName,
          kind: "warning",
          okLabel: appStrings.app.saveAndClose,
          cancelLabel: appStrings.app.discardChanges,
        });
        if (saveChanges) {
          if (!(await saveBeforeDestructiveAction())) return;
        } else {
          const discard = await dialogAdapter.confirm(appStrings.app.discardAndCloseQuestion, {
            title: appStrings.app.productName,
            kind: "warning",
            okLabel: appStrings.app.closeWithoutSaving,
            cancelLabel: appStrings.app.cancel,
          });
          if (!discard) return;
        }
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
  }, [allowWindowClose, saveBeforeDestructiveAction, state?.persistence.isDirty]);
}
