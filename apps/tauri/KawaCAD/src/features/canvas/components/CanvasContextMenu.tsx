import type { PointMm } from "@/features/canvas/domain/cad";
import { appStrings } from "@/localization";

type Props = {
  position: { x: number; y: number; point: PointMm };
  selectionKind: "none" | "entity" | "constraint" | "measurement" | "freeText";
  hasSelection: boolean;
  canPaste: boolean;
  onCopy: () => void;
  onPaste: (point: PointMm) => void;
  onDuplicate: () => void;
  onDelete: () => void;
  onConvertMeasurement: () => void;
  onEditFreeText: () => void;
  canSmoothArcTangencies: boolean;
  onSmoothArcTangencies: () => void;
  onSelectAll: () => void;
  onDismiss: () => void;
};

/** Native-style canvas context actions stay separate from canvas rendering and
 * from the App's Core-command orchestration. */
export function CanvasContextMenu({
  position,
  selectionKind,
  hasSelection,
  canPaste,
  onCopy,
  onPaste,
  onDuplicate,
  onDelete,
  onConvertMeasurement,
  onEditFreeText,
  canSmoothArcTangencies,
  onSmoothArcTangencies,
  onSelectAll,
  onDismiss,
}: Props) {
  if (selectionKind === "measurement")
    return (
      <div
        className="canvas-context-menu"
        role="menu"
        style={{ left: position.x, top: position.y }}
        onMouseLeave={onDismiss}
      >
        <button
          role="menuitem"
          onClick={() => {
            onConvertMeasurement();
            onDismiss();
          }}
        >
          {appStrings.contextMenu.convertMeasurement}
        </button>
        <button
          className="destructive-action"
          role="menuitem"
          onClick={() => {
            onDelete();
            onDismiss();
          }}
        >
          {appStrings.contextMenu.delete}
        </button>
      </div>
    );
  if (selectionKind === "constraint" || selectionKind === "freeText")
    return (
      <div
        className="canvas-context-menu"
        role="menu"
        style={{ left: position.x, top: position.y }}
        onMouseLeave={onDismiss}
      >
        {selectionKind === "freeText" && (
          <button
            role="menuitem"
            onClick={() => {
              onEditFreeText();
              onDismiss();
            }}
          >
            {appStrings.contextMenu.editText}
          </button>
        )}
        <button
          className="destructive-action"
          role="menuitem"
          onClick={() => {
            onDelete();
            onDismiss();
          }}
        >
          {appStrings.contextMenu.delete}
        </button>
      </div>
    );
  if (selectionKind === "entity")
    return (
      <div
        className="canvas-context-menu"
        role="menu"
        style={{ left: position.x, top: position.y }}
        onMouseLeave={onDismiss}
      >
        <button
          role="menuitem"
          disabled={!hasSelection}
          onClick={() => {
            onCopy();
            onDismiss();
          }}
        >
          {appStrings.contextMenu.copy}
        </button>
        <button
          role="menuitem"
          disabled={!hasSelection}
          onClick={() => {
            onDuplicate();
            onDismiss();
          }}
        >
          {appStrings.contextMenu.duplicate}
        </button>
        {canSmoothArcTangencies && (
          <button
            role="menuitem"
            onClick={() => {
              onSmoothArcTangencies();
              onDismiss();
            }}
          >
            {appStrings.contextMenu.smoothArcTangencies}
          </button>
        )}
        <button
          className="destructive-action"
          role="menuitem"
          disabled={!hasSelection}
          onClick={() => {
            onDelete();
            onDismiss();
          }}
        >
          {appStrings.contextMenu.delete}
        </button>
      </div>
    );
  return (
    <div
      className="canvas-context-menu"
      role="menu"
      style={{ left: position.x, top: position.y }}
      onMouseLeave={onDismiss}
    >
      <button
        role="menuitem"
        disabled={!canPaste}
        onClick={() => {
          onPaste(position.point);
          onDismiss();
        }}
      >
        {appStrings.contextMenu.paste}
      </button>
      <button
        role="menuitem"
        onClick={() => {
          onSelectAll();
          onDismiss();
        }}
      >
        {appStrings.contextMenu.selectAll}
      </button>
    </div>
  );
}
