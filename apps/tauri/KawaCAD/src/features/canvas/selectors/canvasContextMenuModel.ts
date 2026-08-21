import type { CanvasContextMenuProps } from "@/features/canvas/components/CanvasContextMenu";
import type { ContextMenu } from "@/features/canvas/state/useCanvasPresentation";
import type { PointMm } from "@/features/canvas/domain/cad";
import type { State } from "@/shared/domain/coreWireTypes";
import { selectedSourceArcId } from "@/features/canvas/selectors/canvasProjection";

type CanvasContextMenuModelInput = {
  contextMenu: ContextMenu | undefined;
  clipboardAvailable: boolean;
  state: State | undefined;
  selectedEntityIDs: Set<string>;
  selectedMeasurementID: string | undefined;
  selectedFreeTextID: string | undefined;
  copySelection: () => void;
  pasteSelection: (point: PointMm) => void;
  duplicateSelection: () => void;
  deleteSelection: () => void;
  convertMeasurement: (id: string) => void;
  beginFreeTextEdit: (id: string) => void;
  smoothSelectedArcTangencies: () => void;
  selectAllEntities: (ids: Set<string>) => void;
  dismiss: () => void;
};

/** Builds Canvas-only context-menu behavior outside the app composition root. */
export function canvasContextMenuModelFor(input: CanvasContextMenuModelInput): CanvasContextMenuProps | undefined {
  const { contextMenu } = input;
  if (!contextMenu) return undefined;
  return {
    position: contextMenu,
    selectionKind: contextMenu.selectionKind,
    hasSelection: contextMenu.selectionKind !== "none",
    canPaste: input.clipboardAvailable,
    onCopy: input.copySelection,
    onPaste: input.pasteSelection,
    onDuplicate: input.duplicateSelection,
    onDelete: input.deleteSelection,
    onConvertMeasurement: () => {
      if (input.selectedMeasurementID) input.convertMeasurement(input.selectedMeasurementID);
    },
    onEditFreeText: () => {
      if (input.selectedFreeTextID) input.beginFreeTextEdit(input.selectedFreeTextID);
    },
    canSmoothArcTangencies: Boolean(
      selectedSourceArcId(
        input.selectedEntityIDs,
        input.state?.entities ?? [],
        input.state?.drawingEntityMetadata ?? [],
      ),
    ),
    onSmoothArcTangencies: input.smoothSelectedArcTangencies,
    onSelectAll: () => input.selectAllEntities(new Set(input.state?.entities.map((entity) => entity.id) ?? [])),
    onDismiss: input.dismiss,
  };
}
