import { useCallback, useRef, useState } from "react";

/** Owns document-level presentation drafts and transition guards. */
export function useDocumentPresentation() {
  const [layerDeletionConfirmation, setLayerDeletionConfirmation] = useState<{
    id: string;
    name: string;
    affectedCount: number;
  }>();
  const [documentWarning, setDocumentWarning] = useState<string>();
  const allowWindowClose = useRef(false);
  const confirmationResolver = useRef<(choice: DocumentSaveChoice) => void>();
  const [documentSaveConfirmation, setDocumentSaveConfirmation] = useState<{ reason: string; displayName: string }>();
  const requestDocumentSaveConfirmation = useCallback((reason: string, displayName: string) => {
    confirmationResolver.current?.("cancel");
    setDocumentSaveConfirmation({ reason, displayName });
    return new Promise<DocumentSaveChoice>((resolve) => {
      confirmationResolver.current = resolve;
    });
  }, []);
  const resolveDocumentSaveConfirmation = useCallback((choice: DocumentSaveChoice) => {
    confirmationResolver.current?.(choice);
    confirmationResolver.current = undefined;
    setDocumentSaveConfirmation(undefined);
  }, []);
  const clearLayerDeletionConfirmation = useCallback(() => setLayerDeletionConfirmation(undefined), []);

  return {
    layerDeletionConfirmation,
    setLayerDeletionConfirmation,
    clearLayerDeletionConfirmation,
    documentWarning,
    setDocumentWarning,
    allowWindowClose,
    documentSaveConfirmation,
    requestDocumentSaveConfirmation,
    resolveDocumentSaveConfirmation,
  };
}

export type DocumentSaveChoice = "save" | "discard" | "cancel";
