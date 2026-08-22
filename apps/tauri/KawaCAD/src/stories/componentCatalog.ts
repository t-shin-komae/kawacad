export type ComponentReference = {
  id: string;
  name: string;
  area: "app" | "canvas" | "document" | "inspector" | "output" | "recovery" | "workspace" | "shared";
  role: "container" | "canvas" | "editor" | "dialog" | "feedback" | "primitive";
  summary: string;
  inputs: string;
  swiftSource: string;
  tauriSource: string;
};

/**
 * The catalog is kept at the logical-component level. A logical component
 * can be split across Swift files or React helpers while keeping one
 * user-visible responsibility. Keep this list in sync with
 * docs/design/ui-architecture/component-correspondence.md.
 */
export const componentCatalog = [
  {
    id: "main-window",
    name: "MainWindowView",
    area: "app",
    role: "container",
    summary:
      "The application-wide presentation root. Composes features and adapters and passes Core snapshots to the screen.",
    inputs: "Application presentation model, session state, and feature actions",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/App/MainWindowView.swift",
    tauriSource: "apps/tauri/KawaCAD/src/app/MainWindowView.tsx",
  },
  {
    id: "workspace-canvas-layout",
    name: "WorkspaceCanvasLayout",
    area: "workspace",
    role: "container",
    summary: "Arranges the canvas and Inspector columns for the available width and display mode.",
    inputs: "Canvas column, Inspector column, and presentation state",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Workspace/Components/WorkspaceCanvasLayout.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/workspace/components/WorkspaceCanvasLayout.tsx",
  },
  {
    id: "document-header",
    name: "DocumentHeader",
    area: "document",
    role: "editor",
    summary: "Displays the project name, .kawa information, and paper information, and commits renames.",
    inputs: "documentName, paperLabel, and onRename",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Document/Components/DocumentHeader.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/document/components/DocumentHeader.tsx",
  },
  {
    id: "cad-toolbar",
    name: "CADToolbar",
    area: "canvas",
    role: "primitive",
    summary: "Combines the current tool, layers, display aids, zoom controls, and selection editing.",
    inputs: "tool, layers, viewport, display toggles, and editing actions",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Canvas/Components/CADToolbar.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/canvas/components/CadToolbar.tsx",
  },
  {
    id: "tool-palette",
    name: "ToolPalette",
    area: "canvas",
    role: "primitive",
    summary: "Groups drawing, derived, constraint, dimension, and measurement tools.",
    inputs: "activeTool, group collapse state, line style, round-hole settings, and tool actions",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Canvas/Components/ToolPalette.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/canvas/components/ToolPalette.tsx",
  },
  {
    id: "tool-icon",
    name: "ToolIcon / PaletteToolButton",
    area: "canvas",
    role: "primitive",
    summary: "Shares tool icon rendering and selection behavior in the palette.",
    inputs: "tool, selected state, and onSelect",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Shared/Components/DesignSystem.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/canvas/components/ToolIcon.tsx / ToolPalette.tsx",
  },
  {
    id: "panel-resize-handle",
    name: "PanelResizeHandle",
    area: "workspace",
    role: "primitive",
    summary: "Changes panel width with pointer or keyboard input.",
    inputs: "Current value, minimum and maximum values, and onChange",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Workspace/Components/PanelResizeHandle.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/workspace/components/PanelResizeHandle.tsx",
  },
  {
    id: "workspace-canvas-surface",
    name: "WorkspaceCanvasSurface",
    area: "workspace",
    role: "container",
    summary: "Manages the stacking order of the canvas and transient overlays.",
    inputs: "Canvas, HUD, paste candidates, and context menu",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Workspace/Components/WorkspaceCanvasSurface.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/workspace/components/WorkspaceCanvasSurface.tsx",
  },
  {
    id: "cad-canvas",
    name: "CADCanvas",
    area: "canvas",
    role: "canvas",
    summary: "Renders committed Core state and transient UI state, and maps pointer and keyboard input to actions.",
    inputs: "Document display, selection, draft, viewport, and canvas actions",
    swiftSource:
      "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Canvas/Components/CADCanvas.swift / LeatherCanvasView*.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/canvas/components/CadCanvas.tsx",
  },
  {
    id: "canvas-inline-text-editor",
    name: "CanvasInlineTextEditor",
    area: "canvas",
    role: "editor",
    summary: "Edits free text temporarily on the canvas and calls a Core action only on commit.",
    inputs: "Edit position, initial text, and commit/cancel actions",
    swiftSource:
      "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Canvas/Components/CanvasInlineTextEditorController.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/canvas/components/CadCanvas.tsx (canvas-inline-text-editor)",
  },
  {
    id: "canvas-context-menu",
    name: "CanvasContextMenu",
    area: "canvas",
    role: "primitive",
    summary: "Presents actions for the canvas location and current selection.",
    inputs: "Context menu model, selection state, and onAction",
    swiftSource:
      "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Canvas/Components/CanvasContextMenu.swift / LeatherCanvasView.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/canvas/components/CanvasContextMenu.tsx",
  },
  {
    id: "paste-options-overlay",
    name: "PasteOptionsOverlay",
    area: "document",
    role: "primitive",
    summary: "Selects a paste position at the cursor or near the original position.",
    inputs: "activeMode, cursor placement, viewport, onSelectMode, and onDismiss",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Document/Components/PasteOptionsOverlay.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/document/components/PasteOptionsOverlay.tsx",
  },
  {
    id: "bottom-workbench",
    name: "BottomWorkbench",
    area: "workspace",
    role: "feedback",
    summary: "Displays a summary of selected entities, constraints, layers, and parameters.",
    inputs: "selectedEntity、layers、constraints、parameters",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Workspace/Components/BottomWorkbench.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/workspace/components/BottomWorkbench.tsx",
  },
  {
    id: "canvas-status-bar",
    name: "CanvasStatusBar",
    area: "canvas",
    role: "feedback",
    summary: "Displays cursor position, zoom, grid, snapping, and related state.",
    inputs: "Cursor, viewport, display aids, and snapping state",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Canvas/Components/CanvasStatusBar.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/canvas/components/CanvasStatusBar.tsx",
  },
  {
    id: "workspace-inspector",
    name: "WorkspaceInspector / InspectorPanel",
    area: "inspector",
    role: "container",
    summary: "Provides docked and compact Inspector layouts and their tab content.",
    inputs: "InspectorViewModel, display mode, and revision",
    swiftSource:
      "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/WorkspaceInspector.swift / InspectorPanel.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/inspector/components/WorkspaceInspector.tsx / InspectorPanel.tsx",
  },
  {
    id: "inspector-primitives",
    name: "InspectorSection / InspectorDisclosureRow",
    area: "shared",
    role: "primitive",
    summary: "Standardizes Inspector section headers, disclosure rows, and editor surfaces.",
    inputs: "title、subtitle、metadata、expanded、children",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Shared/Components/DesignSystem.swift",
    tauriSource: "apps/tauri/KawaCAD/src/shared/components/InspectorPrimitives.tsx",
  },
  {
    id: "inspector-selection-tab",
    name: "InspectorSelectionTab",
    area: "inspector",
    role: "editor",
    summary: "Displays selected entities, constraints, measurements, free text, and stitch start points.",
    inputs: "selection inspector model",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorSelectionTab.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/inspector/components/InspectorSelectionTab.tsx",
  },
  {
    id: "inspector-selection-editors",
    name: "Selection editors",
    area: "inspector",
    role: "editor",
    summary:
      "Edits selected constraints, measurements, stitch start points, free text, multi-selection, entities, derived elements, and round holes.",
    inputs: "selection model、style、parameters、feature action",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorSelectionEditors.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/inspector/components/InspectorSelectionEditors.tsx",
  },
  {
    id: "inspector-layer-tab",
    name: "InspectorLayerTab / LayerEditorRow",
    area: "inspector",
    role: "editor",
    summary: "Edits layer selection, visibility, printability, names, and styles.",
    inputs: "layers、layer tab state、layer actions、style renderer",
    swiftSource:
      "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorLayerTab.swift / LayerEditorRow.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/inspector/components/InspectorLayerTab.tsx",
  },
  {
    id: "inspector-styles-tab",
    name: "InspectorStylesTab",
    area: "inspector",
    role: "editor",
    summary: "Edits the shared line-style list and each style field.",
    inputs: "shared styles、styles tab state、style actions",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorStylesTab.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/inspector/components/InspectorStylesTab.tsx",
  },
  {
    id: "inspector-parameters-tab",
    name: "InspectorParametersTab / ParameterEditor",
    area: "inspector",
    role: "editor",
    summary: "Edits parameter values and their sources.",
    inputs: "parameters、search state、parameter action",
    swiftSource:
      "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorParametersTab.swift / InspectorEditors.swift",
    tauriSource:
      "apps/tauri/KawaCAD/src/features/inspector/components/InspectorParametersTab.tsx / InspectorSelectionEditors.tsx",
  },
  {
    id: "inspector-parts-tab",
    name: "InspectorPartsTab / PartEditor",
    area: "inspector",
    role: "editor",
    summary: "Edits part placement, alignment, and library registration.",
    inputs: "parts、arrangement selection、part actions",
    swiftSource:
      "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorPartsTab.swift / InspectorSelectionEditors.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/parts/components/InspectorPartsTab.tsx / InspectorPartEditors.tsx",
  },
  {
    id: "constraint-value-dialog",
    name: "ConstraintValueDialog / DerivedValueDialog",
    area: "output",
    role: "dialog",
    summary: "Enters fixed values or parameter references for constraints, offsets, and fillets.",
    inputs: "Initial value, parameters, input mode, onConfirm, and onCancel",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Constraints/Components/ValueEntryDialogs.swift",
    tauriSource:
      "apps/tauri/KawaCAD/src/features/constraints/components/ConstraintValueDialog.tsx / DerivedValueDialog.tsx",
  },
  {
    id: "document-save-confirmation",
    name: "DocumentSaveConfirmationDialog",
    area: "document",
    role: "dialog",
    summary: "Offers save, discard, and cancel choices.",
    inputs: "reason、documentName、onChoose",
    swiftSource:
      "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Document/Components/DocumentSaveConfirmationDialog.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/document/components/DocumentSaveConfirmationDialog.tsx",
  },
  {
    id: "layer-deletion-dialog",
    name: "LayerDeletionDialog",
    area: "document",
    role: "dialog",
    summary: "Shows the deletion target and impact count and requests explicit confirmation.",
    inputs: "layerName、affectedCount、onConfirm、onCancel",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Document/Components/LayerDeletionDialog.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/document/components/LayerDeletionDialog.tsx",
  },
  {
    id: "recovery-chooser-dialog",
    name: "RecoveryChooserDialog",
    area: "recovery",
    role: "dialog",
    summary: "Recovers, discards, reveals, or postpones recovery candidates.",
    inputs: "candidates、onRestore、onDiscard、onReveal、onPostpone",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Recovery/Components/RecoveryChooserDialog.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/recovery/components/RecoveryChooserDialog.tsx",
  },
  {
    id: "recovery-save-failure",
    name: "RecoverySaveFailureBanner",
    area: "recovery",
    role: "feedback",
    summary: "Reports recovery-save failures with retry, details, and dismiss actions.",
    inputs: "details、onRetry、onDismiss",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Recovery/Components/RecoverySaveFailureBanner.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/recovery/components/RecoverySaveFailureBanner.tsx",
  },
  {
    id: "workspace-banners",
    name: "WorkspaceBanners / AppErrorBanner",
    area: "workspace",
    role: "feedback",
    summary: "Reports application errors and recovery-save failures at the top of the workspace.",
    inputs: "error presentation、recovery failure、dismiss / retry action",
    swiftSource:
      "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Workspace/Components/WorkspaceBanners.swift / AppErrorBanner.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/workspace/components/WorkspaceBanners.tsx / AppErrorBanner.tsx",
  },
  {
    id: "output-dialog",
    name: "OutputDialog",
    area: "output",
    role: "dialog",
    summary: "Handles PDF export and direct-print settings, warnings, and completion notices.",
    inputs: "documentName、orientation、destination、onSaved、onPrinted",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/Features/Output/Components/OutputDialog.swift",
    tauriSource:
      "apps/tauri/KawaCAD/src/features/output/components/OutputDialog.tsx / PDFExportDialog.tsx / DirectPrintDialog.tsx",
  },
  {
    id: "open-source-licenses",
    name: "OpenSourceLicensesDialog",
    area: "app",
    role: "dialog",
    summary: "Displays bundled dependency license notices.",
    inputs: "onClose、ThirdPartyNotices",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/App/KawaCADLicensesPanel.swift",
    tauriSource: "apps/tauri/KawaCAD/src/features/licenses/components/OpenSourceLicensesDialog.tsx",
  },
  {
    id: "about-panel",
    name: "KawaCADAboutPanel",
    area: "app",
    role: "dialog",
    summary: "Displays the standard OS About UI.",
    inputs: "Application menu and product information",
    swiftSource: "apps/macos/KawaCAD/Sources/KawaCADApp/App/KawaCADAboutPanel.swift",
    tauriSource: "apps/tauri/KawaCAD/src/adapters/nativeMenuAdapter.ts (About item)",
  },
  {
    id: "text-entry-dialog",
    name: "TextEntryDialog",
    area: "shared",
    role: "dialog",
    summary: "A generic text-entry dialog shared by multiple features.",
    inputs: "title、fields、onConfirm、onCancel",
    swiftSource: "SyncedTextField or a feature-specific view at the editing site",
    tauriSource: "apps/tauri/KawaCAD/src/shared/components/TextEntryDialog.tsx",
  },
] as const satisfies readonly ComponentReference[];

export function componentReference(id: string) {
  const reference = componentCatalog.find((item) => item.id === id);
  if (!reference) throw new Error(`Unknown component reference: ${id}`);
  return reference;
}
