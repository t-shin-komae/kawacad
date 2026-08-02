import { useRef, useState } from "react";
import type { DocumentHeaderHandle } from "@/features/document/components/DocumentHeader";

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

  return {
    layerDeletionConfirmation,
    setLayerDeletionConfirmation,
    documentWarning,
    setDocumentWarning,
    allowWindowClose,
    documentHeader,
    documentNameForFileDialog,
  };
}
