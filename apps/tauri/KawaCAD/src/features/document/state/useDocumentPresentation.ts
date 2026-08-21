import { useCallback, useRef, useState } from "react";
import type { DocumentHeaderHandle } from "@/features/document/domain/documentHeaderTypes";

/** Owns document-level presentation drafts and transition guards. */
export function useDocumentPresentation() {
  const [layerDeletionConfirmation, setLayerDeletionConfirmation] = useState<{
    id: string;
    name: string;
    affectedCount: number;
  }>();
  const [documentWarning, setDocumentWarning] = useState<string>();
  const allowWindowClose = useRef(false);
  const documentHeader = useRef<DocumentHeaderHandle>(null);
  const documentNameForFileDialog = useRef<string>();
  const confirmationResolver = useRef<(choice: DocumentSaveChoice) => void>();
  const [documentSaveConfirmation, setDocumentSaveConfirmation] = useState<{ reason: string; documentName: string }>();
  const requestDocumentSaveConfirmation = useCallback((reason: string, documentName: string) => {
    confirmationResolver.current?.("cancel");
    setDocumentSaveConfirmation({ reason, documentName });
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
    documentHeader,
    documentNameForFileDialog,
    documentSaveConfirmation,
    requestDocumentSaveConfirmation,
    resolveDocumentSaveConfirmation,
  };
}

export type DocumentSaveChoice = "save" | "discard" | "cancel";
