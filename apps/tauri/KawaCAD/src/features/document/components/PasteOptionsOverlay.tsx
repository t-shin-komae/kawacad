import { accessibilityIdentifiers } from "@/shared/accessibility/accessibilityIdentifiers";
import { appStrings } from "@/localization";
import { ClipboardPaste, X } from "lucide-react";

export type PastePlacementMode = "cursor" | "nearSource";

type Props = {
  activeMode: PastePlacementMode;
  canPlaceAtCursor: boolean;
  onSelectMode: (mode: PastePlacementMode) => void;
  onDismiss: () => void;
};

/** Lets a pasted selection be repositioned once without duplicating the Core
 * clipboard or its ID namespace.  This mirrors SwiftUI's transient canvas
 * paste-placement control. */
export function PasteOptionsOverlay({ activeMode, canPlaceAtCursor, onSelectMode, onDismiss }: Props) {
  return (
    <div
      className="paste-options"
      data-testid={accessibilityIdentifiers.pasteOptions}
      aria-label={appStrings.accessibility.pastePosition}
      role="group"
    >
      <span>
        <ClipboardPaste size={13} aria-hidden="true" />
        {appStrings.paste.position}
      </span>
      <button
        type="button"
        aria-pressed={activeMode === "cursor"}
        disabled={!canPlaceAtCursor}
        onClick={() => onSelectMode("cursor")}
      >
        {appStrings.paste.cursor}
      </button>
      <button type="button" aria-pressed={activeMode === "nearSource"} onClick={() => onSelectMode("nearSource")}>
        {appStrings.paste.nearSource}
      </button>
      <button type="button" aria-label={appStrings.accessibility.dismissPastePosition} onClick={onDismiss}>
        <X size={14} aria-hidden="true" />
      </button>
    </div>
  );
}
