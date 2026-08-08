import { useCallback } from "react";
import { appStrings } from "@/localization";
import { documentAdapter } from "@/adapters/documentAdapter";
import { dialogAdapter } from "@/adapters/dialogAdapter";
import type { PendingTextEntry } from "@/features/canvas/state/useCanvasPresentation";
import type { TextEntryField } from "@/shared/components/TextEntryDialog";
import type { State } from "@/shared/domain/workspaceState";
import type { DocumentActionContext } from "@/app/actions/useActionRuntime";

type DocumentActionDependencies = Pick<
  DocumentActionContext,
  "state" | "run" | "command" | "documentHeader" | "documentNameForFileDialog"
> & {
  clearTransientCanvasState: () => void;
  openTextEntry: (title: string, fields: TextEntryField[], onConfirm: PendingTextEntry["onConfirm"]) => void;
  resetLoadedDocumentPresentation: (next: State) => void;
};

export function useDocumentActionCallbacks(dependencies: DocumentActionDependencies) {
  const {
    state,
    run,
    command,
    documentHeader,
    documentNameForFileDialog,
    clearTransientCanvasState,
    openTextEntry,
    resetLoadedDocumentPresentation,
  } = dependencies;

  const renameDocument = useCallback(
    async (name: string) => {
      documentNameForFileDialog.current = name;
      return Boolean(await command("renameDocument", { name }, appStrings.app.documentNameUpdated));
    },
    [command],
  );
  const commitPendingDocumentName = useCallback(
    async () => (await documentHeader.current?.commit()) ?? true,
    [documentHeader],
  );
  const validatePendingDocumentName = useCallback(() => documentHeader.current?.validate() ?? true, [documentHeader]);
  const saveBeforeDestructiveAction = useCallback(async () => {
    if (!(await commitPendingDocumentName())) return false;
    const path =
      state?.persistence.path ??
      (await dialogAdapter.save({
        defaultPath: `${documentNameForFileDialog.current ?? state?.snapshot.name ?? appStrings.app.untitled}.kawa`,
        filters: [{ name: appStrings.app.fileFilterName, extensions: ["kawa"] }],
      }));
    if (!path) return false;
    return Boolean(await run(() => documentAdapter.command<State>("save_document", { path }), appStrings.app.saved));
  }, [commitPendingDocumentName, documentNameForFileDialog, run, state?.persistence.path, state?.snapshot.name]);
  const resolveDirtyReplacement = useCallback(
    async (actionLabel: string) => {
      if (!validatePendingDocumentName()) return false;
      if (!state?.persistence.isDirty) return true;
      const saveChanges = await dialogAdapter.confirm(appStrings.app.saveContinueQuestion(actionLabel), {
        title: appStrings.app.productName,
        kind: "warning",
        okLabel: appStrings.app.saveAndContinue,
        cancelLabel: appStrings.app.discardChanges,
      });
      if (saveChanges) return saveBeforeDestructiveAction();
      return dialogAdapter.confirm(appStrings.app.discardContinueQuestion(actionLabel), {
        title: appStrings.app.productName,
        kind: "warning",
        okLabel: appStrings.app.continueWithoutSaving,
        cancelLabel: appStrings.app.cancel,
      });
    },
    [saveBeforeDestructiveAction, state?.persistence.isDirty, validatePendingDocumentName],
  );
  const newDocument = useCallback(async () => {
    if (!(await resolveDirtyReplacement(appStrings.app.newProjectAction))) return;
    openTextEntry(
      appStrings.app.newProjectOpen,
      [{ id: "name", label: appStrings.header.projectName, initialValue: appStrings.app.untitled }],
      (values) => {
        const name = values.name.trim();
        if (!name) return;
        void run(() => documentAdapter.command<State>("new_document", { name }), appStrings.app.newProjectCreated).then(
          (next) => {
            if (next) resetLoadedDocumentPresentation(next);
          },
        );
      },
    );
  }, [openTextEntry, resetLoadedDocumentPresentation, resolveDirtyReplacement, run]);
  const openDocument = useCallback(async () => {
    if (!(await resolveDirtyReplacement(appStrings.app.openOtherProjectAction))) return;
    const path = await dialogAdapter.open({
      multiple: false,
      filters: [{ name: appStrings.app.fileFilterName, extensions: ["kawa"] }],
    });
    if (typeof path !== "string") return;
    const next = await run(
      () => documentAdapter.command<State>("open_document", { path }),
      appStrings.app.projectOpened,
    );
    if (next) resetLoadedDocumentPresentation(next);
  }, [resetLoadedDocumentPresentation, resolveDirtyReplacement, run]);
  const saveDocument = useCallback(async () => {
    if (!(await commitPendingDocumentName())) return;
    const path = await dialogAdapter.save({
      defaultPath: `${documentNameForFileDialog.current ?? state?.snapshot.name ?? appStrings.app.untitled}.kawa`,
      filters: [{ name: appStrings.app.fileFilterName, extensions: ["kawa"] }],
    });
    if (path) await run(() => documentAdapter.command<State>("save_document", { path }), appStrings.app.saved);
  }, [commitPendingDocumentName, documentNameForFileDialog, run, state?.snapshot.name]);
  const saveCurrentDocument = useCallback(async () => {
    if (!(await commitPendingDocumentName())) return;
    if (!state?.persistence.hasPath) return void saveDocument();
    await run(() => documentAdapter.command<State>("save_current_document"), appStrings.app.saved);
  }, [commitPendingDocumentName, run, saveDocument, state?.persistence.hasPath]);
  const reloadDocument = useCallback(() => {
    void run(() => documentAdapter.command<State>("reload_document"), appStrings.app.reloaded).then((next) => {
      if (next) resetLoadedDocumentPresentation(next);
    });
  }, [resetLoadedDocumentPresentation, run]);
  const restoreHistory = useCallback(
    (action: "undo" | "redo") => {
      void run(() => documentAdapter.command<State>(action), appStrings.app.undoRedo(action === "undo")).then(
        (next) => {
          if (next) clearTransientCanvasState();
        },
      );
    },
    [clearTransientCanvasState, run],
  );

  return {
    renameDocument,
    commitPendingDocumentName,
    validatePendingDocumentName,
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
