import type * as React from "react";
import type { DocumentHeaderHandle } from "@/features/document/domain/documentHeaderTypes";
import type { PointMm } from "@/features/canvas/domain/cad";
import type { State } from "@/shared/domain/coreWireTypes";
import type { PasteOptions, PendingTextEntry, SelectionExport } from "@/features/canvas/state/useCanvasPresentation";
import type { DocumentSaveChoice } from "@/features/document/state/useDocumentPresentation";

export type DocumentActionInput = {
  state: State | undefined;
  command: (kind: string, payload: unknown, success: string) => Promise<State | undefined>;
  presentOperationFailure: (error: unknown, operation: string, commandKind?: string) => void;
  run: (
    work: () => Promise<State>,
    success: string,
    operation?: string,
    commandKind?: string,
  ) => Promise<State | undefined>;
  onDocumentLoaded: (next: State) => void;
  onHistoryRestored: () => void;
  canvas: {
    cursorPoint: PointMm | undefined;
    activeStyle: string;
    startPastePlacement: (options: PasteOptions) => void;
    clearPastePlacement: () => void;
    clearFreeTextEdit: () => void;
  };
  layerDeletionConfirmation: { id: string; name: string; affectedCount: number } | undefined;
  showLayerDeletionConfirmation: (value: { id: string; name: string; affectedCount: number }) => void;
  clearLayerDeletionConfirmation: () => void;
  selection: {
    entityIDs: Set<string>;
    replaceEntitySelection: (ids: Set<string>) => void;
    annotation: { kind: "freeText" | "constraint" | "measurement" | "stitchStartPoint"; id: string } | undefined;
    clearAnnotationSelection: () => void;
  };
  presentTextEntry: (entry: PendingTextEntry) => void;
  clearPendingTextEntry: () => void;
  setMessage: (message: string) => void;
  documentHeader: React.MutableRefObject<DocumentHeaderHandle | null>;
  documentNameForFileDialog: React.MutableRefObject<string | undefined>;
  requestDocumentSaveConfirmation: (reason: string, documentName: string) => Promise<DocumentSaveChoice>;
  clipboard: SelectionExport | undefined;
  storeSelectionExport: (exported: SelectionExport) => void;
  pasteOptions: PasteOptions | undefined;
  pasteSequence: number;
  advancePasteSequence: () => void;
};
