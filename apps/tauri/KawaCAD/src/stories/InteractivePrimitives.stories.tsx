import { useState } from "react";
import type { Meta, StoryObj } from "@storybook/react-vite";
import { Circle } from "lucide-react";
import { DocumentSaveConfirmationDialog } from "@/features/document/components/DocumentSaveConfirmationDialog";
import { PaletteToolButton } from "@/features/canvas/components/ToolPalette";
import { ToolIcon } from "@/features/canvas/components/ToolIcon";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
import { PanelResizeHandle } from "@/features/workspace/components/PanelResizeHandle";
import {
  InspectorDisclosureRow,
  InspectorEditorSurface,
  InspectorSection,
} from "@/shared/components/InspectorPrimitives";
import { TextEntryDialog } from "@/shared/components/TextEntryDialog";

const meta = {
  title: "Components/Interactive primitives",
  tags: ["autodocs"],
  parameters: {
    docs: {
      description: {
        component: "Live examples of components that do not require Core snapshots or OS services.",
      },
    },
  },
} satisfies Meta;

export default meta;
type Story = StoryObj<typeof meta>;

export const ToolIcons: Story = {
  render: () => {
    const tools: Tool[] = ["select", "line", "circle", "arc", "roundHole", "measureDistance"];
    return (
      <div style={{ display: "flex", gap: 18, alignItems: "center" }}>
        {tools.map((tool) => (
          <span key={tool} style={{ display: "grid", gap: 6, justifyItems: "center" }}>
            <ToolIcon tool={tool} size={24} />
            <code>{tool}</code>
          </span>
        ))}
      </div>
    );
  },
};

export const PaletteToolButtonExample: Story = {
  render: () => {
    const [selected, setSelected] = useState<Tool>("line");
    return (
      <div style={{ width: 176 }}>
        <PaletteToolButton tool="line" isSelected={selected === "line"} onSelect={setSelected} />
        <PaletteToolButton tool="circle" isSelected={selected === "circle"} onSelect={setSelected} />
      </div>
    );
  },
};

export const InspectorPrimitivesExample: Story = {
  render: () => {
    const [expanded, setExpanded] = useState(false);
    return (
      <div style={{ maxWidth: 360 }}>
        <InspectorSection title="Layer" icon={Circle}>
          <InspectorDisclosureRow
            title="Outer"
            subtitle="drawing"
            metadata="Visible"
            expanded={expanded}
            onToggle={() => setExpanded((value) => !value)}
          >
            <InspectorEditorSurface>
              <p style={{ margin: 0 }}>Editor content</p>
            </InspectorEditorSurface>
          </InspectorDisclosureRow>
        </InspectorSection>
      </div>
    );
  },
};

export const TextEntryDialogExample: Story = {
  render: () => (
    <TextEntryDialog
      title="Rename parameter"
      fields={[{ id: "name", label: "Name", initialValue: "width" }]}
      onConfirm={() => undefined}
      onCancel={() => undefined}
    />
  ),
};

export const DocumentSaveConfirmationExample: Story = {
  render: () => (
    <DocumentSaveConfirmationDialog
      reason="The document has unsaved changes."
      documentName="Sample pattern"
      onChoose={() => undefined}
    />
  ),
};

export const PanelResizeHandleExample: Story = {
  render: () => {
    const [value, setValue] = useState(176);
    return (
      <div style={{ width: 260 }}>
        <p>Width: {Math.round(value)} pt</p>
        <PanelResizeHandle value={value} min={140} max={300} ariaLabel="Resize panel" onChange={setValue} />
      </div>
    );
  },
};
