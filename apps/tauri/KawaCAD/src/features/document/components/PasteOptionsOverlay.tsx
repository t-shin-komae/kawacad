import { accessibilityIdentifiers } from "@/shared/accessibility/accessibilityIdentifiers";
import { appStrings } from "@/localization";
import { Check, ChevronDown, ClipboardPaste, X } from "lucide-react";
import { useState } from "react";
import type { CSSProperties } from "react";
import type { PointMm, Viewport } from "@/features/canvas/domain/cad";

export type PastePlacementMode = "cursor" | "nearSource";

type Props = {
  activeMode: PastePlacementMode;
  canPlaceAtCursor: boolean;
  positionMm: PointMm;
  viewport: Viewport;
  onSelectMode: (mode: PastePlacementMode) => void;
  onDismiss: () => void;
};

/** Lets a pasted selection be repositioned once without duplicating the Core
 * clipboard or its ID namespace.  This mirrors SwiftUI's transient canvas
 * paste-placement control. */
export function PasteOptionsOverlay({
  activeMode,
  canPlaceAtCursor,
  positionMm,
  viewport,
  onSelectMode,
  onDismiss,
}: Props) {
  const [menuOpen, setMenuOpen] = useState(false);
  const scale = (72 / 25.4) * viewport.zoom;
  const positionStyle = {
    left: `clamp(82px, calc(50% + ${viewport.panX + positionMm.xMm * scale + 44}px), calc(100% - 82px))`,
    top: `clamp(24px, calc(50% + ${viewport.panY - positionMm.yMm * scale + 22}px), calc(100% - 24px))`,
  } satisfies CSSProperties;
  const selectMode = (mode: PastePlacementMode) => {
    setMenuOpen(false);
    onSelectMode(mode);
  };

  return (
    <div
      className="paste-options"
      style={positionStyle}
      data-testid={accessibilityIdentifiers.pasteOptions}
      aria-label={appStrings.accessibility.pastePosition}
      role="group"
    >
      <div className="paste-options-menu">
        <button
          className="paste-options-menu-button"
          type="button"
          aria-haspopup="menu"
          aria-expanded={menuOpen}
          onClick={() => setMenuOpen((open) => !open)}
        >
          <ClipboardPaste size={13} aria-hidden="true" />
          {appStrings.paste.position}
          <ChevronDown size={11} aria-hidden="true" />
        </button>
        {menuOpen && (
          <div className="paste-options-menu-popover" role="menu">
            <button type="button" role="menuitem" disabled={!canPlaceAtCursor} onClick={() => selectMode("cursor")}>
              {activeMode === "cursor" && <Check size={12} aria-hidden="true" />}
              {appStrings.paste.cursor}
            </button>
            <button type="button" role="menuitem" onClick={() => selectMode("nearSource")}>
              {activeMode === "nearSource" && <Check size={12} aria-hidden="true" />}
              {appStrings.paste.nearSource}
            </button>
          </div>
        )}
      </div>
      <button
        className="paste-options-dismiss"
        type="button"
        aria-label={appStrings.accessibility.dismissPastePosition}
        onClick={onDismiss}
      >
        <X size={14} aria-hidden="true" />
      </button>
    </div>
  );
}
