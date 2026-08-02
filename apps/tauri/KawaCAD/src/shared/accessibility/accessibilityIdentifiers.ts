/**
 * Stable identifiers for UI automation.
 *
 * Accessible names continue to come from semantic HTML and `aria-label`.
 * These values are deliberately separate because user-facing wording may
 * change or be localized without breaking UI automation.
 */
export const accessibilityIdentifiers = {
  workspaceCanvas: "leather.workspace.canvas",
  workspaceStatusBar: "leather.workspace.status-bar",

  toolbarDrawingLayer: "leather.toolbar.drawing-layer",
  toolbarZoomToFit: "leather.toolbar.zoom-to-fit",
  toolbarZoomOut: "leather.toolbar.zoom-out",
  toolbarZoomIn: "leather.toolbar.zoom-in",
  toolbarGrid: "leather.toolbar.grid",
  toolbarA4Reference: "leather.toolbar.a4-reference",
  toolbarPortraitOrientation: "leather.toolbar.orientation.portrait",
  toolbarLandscapeOrientation: "leather.toolbar.orientation.landscape",
  toolbarGridSnap: "leather.toolbar.grid-snap",
  toolbarPointSnap: "leather.toolbar.point-snap",
  toolbarTools: "leather.toolbar.tools",
  toolbarInspector: "leather.toolbar.inspector",
  toolbarViewMode: "leather.toolbar.view-mode",
  toolbarOverflow: "leather.toolbar.overflow",
  toolbarCopySelection: "leather.toolbar.copy-selection",
  toolbarPasteSelection: "leather.toolbar.paste-selection",
  toolbarDuplicateSelection: "leather.toolbar.duplicate-selection",

  statusBottomWorkbench: "leather.status.bottom-workbench",
  pasteOptions: "leather.paste-options",
} as const;

export type AccessibilityIdentifier = (typeof accessibilityIdentifiers)[keyof typeof accessibilityIdentifiers];
