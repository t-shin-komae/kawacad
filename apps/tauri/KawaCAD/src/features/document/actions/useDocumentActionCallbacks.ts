import { useCallback } from "react";
import { appStrings } from "@/localization";
import { documentAdapter } from "@/adapters/documentAdapter";
import { dialogAdapter } from "@/adapters/dialogAdapter";
import type { State } from "@/shared/domain/coreWireTypes";
import type { DocumentActionInput } from "@/features/document/actions/documentActionTypes";
import { normalizeProjectSavePath } from "@/features/document/domain/projectFilePath";
import { documentDisplayName } from "@/features/workspace/selectors/documentWindowPresentation";

type DocumentActionDependencies = Pick<DocumentActionInput, "state" | "run" | "requestDocumentSaveConfirmation"> & {
  onHistoryRestored: () => void;
  resetLoadedDocumentPresentation: (next: State) => void;
};

export function useDocumentActionCallbacks(dependencies: DocumentActionDependencies) {
  const { state, run, requestDocumentSaveConfirmation, onHistoryRestored, resetLoadedDocumentPresentation } =
    dependencies;
  const fileName = (path: string) => path.split(/[\\/]/).pop() ?? path;

  const saveBeforeDestructiveAction = useCallback(async () => {
    const path =
      state?.persistence.path ??
      (await dialogAdapter.save({
        defaultPath: `${appStrings.app.untitled}.kawa`,
        filters: [{ name: appStrings.app.fileFilterName, extensions: ["kawa"] }],
      }));
    if (!path) return false;
    const normalizedPath = normalizeProjectSavePath(path);
    return Boolean(
      await run(
        () => documentAdapter.command<State>("save_document", { path: normalizedPath }),
        appStrings.app.saved(fileName(normalizedPath)),
      ),
    );
  }, [run, state?.persistence.path]);
  const resolveDirtyReplacement = useCallback(
    async (actionLabel: string) => {
      if (!state?.persistence.isDirty) return true;
      const choice = await requestDocumentSaveConfirmation(actionLabel, documentDisplayName(state?.persistence.path));
      if (choice === "save") return saveBeforeDestructiveAction();
      return choice === "discard";
    },
    [requestDocumentSaveConfirmation, saveBeforeDestructiveAction, state?.persistence.isDirty, state?.persistence.path],
  );
  const newDocument = useCallback(async () => {
    if (!(await resolveDirtyReplacement(appStrings.app.newProjectAction))) return;
    const next = await run(() => documentAdapter.command<State>("new_document"), appStrings.app.newProjectCreated);
    if (next) resetLoadedDocumentPresentation(next);
  }, [resetLoadedDocumentPresentation, resolveDirtyReplacement, run]);
  const openDocument = useCallback(async () => {
    if (!(await resolveDirtyReplacement(appStrings.app.openOtherProjectAction))) return;
    const path = await dialogAdapter.open({
      multiple: false,
      filters: [{ name: appStrings.app.fileFilterName, extensions: ["kawa"] }],
    });
    if (typeof path !== "string") return;
    const next = await run(
      () => documentAdapter.command<State>("open_document", { path }),
      appStrings.app.projectOpened(fileName(path)),
    );
    if (next) resetLoadedDocumentPresentation(next);
  }, [resetLoadedDocumentPresentation, resolveDirtyReplacement, run]);
  const saveDocument = useCallback(async () => {
    const path = await dialogAdapter.save({
      defaultPath: state?.persistence.path ?? `${appStrings.app.untitled}.kawa`,
      filters: [{ name: appStrings.app.fileFilterName, extensions: ["kawa"] }],
    });
    if (path) {
      const normalizedPath = normalizeProjectSavePath(path);
      await run(
        () => documentAdapter.command<State>("save_document", { path: normalizedPath }),
        appStrings.app.saved(fileName(normalizedPath)),
      );
    }
  }, [run, state?.persistence.path]);
  const saveCurrentDocument = useCallback(async () => {
    if (!state?.persistence.hasPath) return void saveDocument();
    await run(
      () => documentAdapter.command<State>("save_current_document"),
      appStrings.app.saved(fileName(state.persistence.path ?? appStrings.app.untitled)),
    );
  }, [run, saveDocument, state?.persistence.hasPath, state?.persistence.path]);
  const reloadDocument = useCallback(() => {
    void run(() => documentAdapter.command<State>("reload_document"), appStrings.app.reloaded).then((next) => {
      if (next) resetLoadedDocumentPresentation(next);
    });
  }, [resetLoadedDocumentPresentation, run]);
  const restoreHistory = useCallback(
    (action: "undo" | "redo") => {
      void run(() => documentAdapter.command<State>(action), appStrings.app.undoRedo(action === "undo")).then(
        (next) => {
          if (next) onHistoryRestored();
        },
      );
    },
    [onHistoryRestored, run],
  );

  return {
    saveBeforeDestructiveAction,
    resolveDirtyReplacement,
    newDocument,
    openDocument,
    saveDocument,
    saveCurrentDocument,
    reloadDocument,
    restoreHistory,
  };
}
