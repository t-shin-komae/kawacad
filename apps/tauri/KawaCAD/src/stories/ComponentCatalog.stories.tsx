import type { Meta, StoryObj } from "@storybook/react-vite";
import { ComponentReference } from "./ComponentReference";
import { componentCatalog, componentReference } from "./componentCatalog";

const meta = {
  title: "Components/Reference",
  component: ComponentReference,
  tags: ["autodocs"],
  parameters: {
    docs: {
      description: {
        component:
          "A catalog that maps Swift/macOS and Tauri/React presentation responsibilities. Components that require Core or OS APIs show their responsibility and implementation entry point.",
      },
    },
  },
} satisfies Meta<typeof ComponentReference>;

export default meta;
type Story = StoryObj<typeof meta>;

export const MainWindowView: Story = { name: "MainWindowView", args: { reference: componentReference("main-window") } };
export const WorkspaceCanvasLayout: Story = {
  name: "WorkspaceCanvasLayout",
  args: { reference: componentReference("workspace-canvas-layout") },
};
export const DocumentHeader: Story = {
  name: "DocumentHeader",
  args: { reference: componentReference("document-header") },
};
export const CADToolbar: Story = { name: "CADToolbar", args: { reference: componentReference("cad-toolbar") } };
export const ToolPalette: Story = { name: "ToolPalette", args: { reference: componentReference("tool-palette") } };
export const ToolIcon: Story = {
  name: "ToolIcon / PaletteToolButton",
  args: { reference: componentReference("tool-icon") },
};
export const PanelResizeHandle: Story = {
  name: "PanelResizeHandle",
  args: { reference: componentReference("panel-resize-handle") },
};
export const WorkspaceCanvasSurface: Story = {
  name: "WorkspaceCanvasSurface",
  args: { reference: componentReference("workspace-canvas-surface") },
};
export const CADCanvas: Story = { name: "CADCanvas", args: { reference: componentReference("cad-canvas") } };
export const CanvasInlineTextEditor: Story = {
  name: "CanvasInlineTextEditor",
  args: { reference: componentReference("canvas-inline-text-editor") },
};
export const CanvasContextMenu: Story = {
  name: "CanvasContextMenu",
  args: { reference: componentReference("canvas-context-menu") },
};
export const PasteOptionsOverlay: Story = {
  name: "PasteOptionsOverlay",
  args: { reference: componentReference("paste-options-overlay") },
};
export const BottomWorkbench: Story = {
  name: "BottomWorkbench",
  args: { reference: componentReference("bottom-workbench") },
};
export const CanvasStatusBar: Story = {
  name: "CanvasStatusBar",
  args: { reference: componentReference("canvas-status-bar") },
};
export const WorkspaceInspector: Story = {
  name: "WorkspaceInspector / InspectorPanel",
  args: { reference: componentReference("workspace-inspector") },
};
export const InspectorPrimitives: Story = {
  name: "InspectorSection / InspectorDisclosureRow",
  args: { reference: componentReference("inspector-primitives") },
};
export const InspectorSelectionTab: Story = {
  name: "InspectorSelectionTab",
  args: { reference: componentReference("inspector-selection-tab") },
};
export const InspectorSelectionEditors: Story = {
  name: "Selection editors",
  args: { reference: componentReference("inspector-selection-editors") },
};
export const InspectorLayerTab: Story = {
  name: "InspectorLayerTab / LayerEditorRow",
  args: { reference: componentReference("inspector-layer-tab") },
};
export const InspectorStylesTab: Story = {
  name: "InspectorStylesTab",
  args: { reference: componentReference("inspector-styles-tab") },
};
export const InspectorParametersTab: Story = {
  name: "InspectorParametersTab / ParameterEditor",
  args: { reference: componentReference("inspector-parameters-tab") },
};
export const InspectorPartsTab: Story = {
  name: "InspectorPartsTab / PartEditor",
  args: { reference: componentReference("inspector-parts-tab") },
};
export const ConstraintValueDialog: Story = {
  name: "ConstraintValueDialog / DerivedValueDialog",
  args: { reference: componentReference("constraint-value-dialog") },
};
export const DocumentSaveConfirmationDialog: Story = {
  name: "DocumentSaveConfirmationDialog",
  args: { reference: componentReference("document-save-confirmation") },
};
export const LayerDeletionDialog: Story = {
  name: "LayerDeletionDialog",
  args: { reference: componentReference("layer-deletion-dialog") },
};
export const RecoveryChooserDialog: Story = {
  name: "RecoveryChooserDialog",
  args: { reference: componentReference("recovery-chooser-dialog") },
};
export const RecoverySaveFailureBanner: Story = {
  name: "RecoverySaveFailureBanner",
  args: { reference: componentReference("recovery-save-failure") },
};
export const WorkspaceBanners: Story = {
  name: "WorkspaceBanners / AppErrorBanner",
  args: { reference: componentReference("workspace-banners") },
};
export const OutputDialog: Story = { name: "OutputDialog", args: { reference: componentReference("output-dialog") } };
export const OpenSourceLicensesDialog: Story = {
  name: "OpenSourceLicensesDialog",
  args: { reference: componentReference("open-source-licenses") },
};
export const KawaCADAboutPanel: Story = {
  name: "KawaCADAboutPanel",
  args: { reference: componentReference("about-panel") },
};
export const TextEntryDialog: Story = {
  name: "TextEntryDialog",
  args: { reference: componentReference("text-entry-dialog") },
};

export const AllComponents: Story = {
  name: "All components",
  args: { reference: componentCatalog[0] },
  render: () => (
    <div style={{ display: "grid", gap: 16 }}>
      {componentCatalog.map((reference) => (
        <ComponentReference key={reference.id} reference={reference} />
      ))}
    </div>
  ),
};
