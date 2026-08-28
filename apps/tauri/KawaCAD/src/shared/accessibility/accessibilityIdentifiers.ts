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

  componentToolbar: "leather.component.toolbar",
  componentToolPalette: "leather.component.tool-palette",
  componentCanvasSurface: "leather.component.canvas-surface",
  componentInspector: "leather.component.inspector",
  componentSelectionInspector: "leather.component.selection-inspector",
  componentBottomWorkbench: "leather.component.bottom-workbench",
  componentConstraintHUD: "leather.component.constraint-hud",
  componentContextMenu: "leather.component.context-menu",
  componentLicensesDialog: "leather.component.licenses-dialog",
  componentRecoveryDialog: "leather.component.recovery-dialog",
  componentPDFDialog: "leather.component.pdf-dialog",
  componentLayerDeletionDialog: "leather.component.layer-deletion-dialog",

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

  statusBottomWorkbench: "leather.status.bottom-workbench",
  pasteOptions: "leather.paste-options",
  pdfExportDialog: "leather.pdf-export.dialog",
  pdfExportSave: "leather.pdf-export.save",
} as const;

export type AccessibilityIdentifier = (typeof accessibilityIdentifiers)[keyof typeof accessibilityIdentifiers];
