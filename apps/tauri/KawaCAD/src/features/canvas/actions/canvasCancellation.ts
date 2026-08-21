import type * as React from "react";
import { appStrings } from "@/localization";
import type { ConstraintTarget, PointMm, Viewport } from "@/features/canvas/domain/cad";
import type { EditControlTarget } from "@/shared/domain/coreWireTypes";
import type {
  PendingConstraintValue,
  PendingDerivedValue,
  PendingTextEntry,
  PasteOptions,
} from "@/features/canvas/state/useCanvasPresentation";

type Setter<T> = React.Dispatch<React.SetStateAction<T>>;

export type CanvasCancellationInput = {
  pasteOptions: PasteOptions | undefined;
  clearPastePlacement: () => void;
  setMessage: (message: string) => void;
  pan: React.MutableRefObject<{ screen: { x: number; y: number }; viewport: Viewport } | undefined>;
  marquee: React.MutableRefObject<PointMm | undefined>;
  move: React.MutableRefObject<{ start: PointMm; ids: string[]; partId?: string } | undefined>;
  controlMove: React.MutableRefObject<{ target: EditControlTarget } | undefined>;
  measurementMove: React.MutableRefObject<{ id: string; start: PointMm; labelOnly: boolean } | undefined>;
  dimensionMove: React.MutableRefObject<{ constraintId: string; start: PointMm; labelOnly: boolean } | undefined>;
  freeTextMove: React.MutableRefObject<{ id: string; start: PointMm } | undefined>;
  setSnapSuppressed: Setter<boolean>;
  setSnapActive: Setter<boolean>;
  setDragDuplicating: Setter<boolean>;
  setMarqueeCurrent: Setter<PointMm | undefined>;
  setHoveredTargetEntityId: Setter<string | undefined>;
  setPendingConstraintValue: Setter<PendingConstraintValue | undefined>;
  setPendingDerivedValue: Setter<PendingDerivedValue | undefined>;
  clearPendingTextEntry: () => void;
  clearCanvasPreview: () => void;
  previewActive: React.MutableRefObject<boolean>;
  pendingTargets: ConstraintTarget[];
  setPendingTargets: Setter<ConstraintTarget[]>;
  draft: PointMm[];
  setDraft: Setter<PointMm[]>;
  selectedMeasurementId: string | undefined;
  clearSelectedMeasurement: () => void;
  selectedConstraintId: string | undefined;
  clearSelectedConstraint: () => void;
  selectedFreeTextId: string | undefined;
  clearSelectedFreeText: () => void;
  selectedStitchStartPointId: string | undefined;
  clearSelectedStitchStartPoint: () => void;
  selected: Set<string>;
  clearEntitySelection: () => void;
  pendingConstraintValue: PendingConstraintValue | undefined;
  pendingDerivedValue: PendingDerivedValue | undefined;
  pendingTextEntry: PendingTextEntry | undefined;
  editingFreeTextId: string | undefined;
  clearFreeTextEdit: () => void;
  rewindFilletDraft: () => void;
  selectTool: (tool: "select") => void;
};

/** Applies Escape in priority order and reports whether an interaction ended. */
export function cancelCanvasInteraction(input: CanvasCancellationInput) {
  if (input.pasteOptions) {
    input.clearPastePlacement();
    input.setMessage(appStrings.status.pastePositionDismissed);
    return true;
  }
  input.pan.current = undefined;
  input.marquee.current = undefined;
  input.move.current = undefined;
  input.setSnapSuppressed(false);
  input.setSnapActive(false);
  input.setDragDuplicating(false);
  input.setMarqueeCurrent(undefined);
  input.setHoveredTargetEntityId(undefined);
  input.controlMove.current = undefined;
  input.measurementMove.current = undefined;
  input.dimensionMove.current = undefined;
  input.freeTextMove.current = undefined;
  if (input.editingFreeTextId) input.clearFreeTextEdit();
  else if (input.pendingConstraintValue) input.setPendingConstraintValue(undefined);
  else if (input.pendingDerivedValue?.candidate === "fillet") input.rewindFilletDraft();
  else if (input.pendingDerivedValue) input.setPendingDerivedValue(undefined);
  else if (input.pendingTextEntry) input.clearPendingTextEntry();
  else if (input.previewActive.current) {
    input.clearCanvasPreview();
    input.setMessage(appStrings.status.movePreviewCancelled);
  } else if (input.pendingTargets.length) input.setPendingTargets([]);
  else if (input.draft.length) input.setDraft([]);
  else if (input.selectedMeasurementId) input.clearSelectedMeasurement();
  else if (input.selectedConstraintId) input.clearSelectedConstraint();
  else if (input.selectedFreeTextId) input.clearSelectedFreeText();
  else if (input.selectedStitchStartPointId) input.clearSelectedStitchStartPoint();
  else if (input.selected.size) input.clearEntitySelection();
  else {
    input.selectTool("select");
    return false;
  }
  return true;
}
