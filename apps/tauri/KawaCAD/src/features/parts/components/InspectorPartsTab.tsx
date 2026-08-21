import { useState, type ReactNode } from "react";
import {
  AlignHorizontalJustifyCenter,
  AlignHorizontalJustifyEnd,
  AlignHorizontalJustifyStart,
  AlignVerticalJustifyCenter,
  AlignVerticalJustifyEnd,
  AlignVerticalJustifyStart,
  BookOpen,
  CopyPlus,
  Package,
  PackagePlus,
  Trash2,
} from "lucide-react";
import { appStrings } from "@/localization";
import type { Part, PartLibraryEntry } from "@/shared/domain/coreWireTypes";
import type { PartInspectorModel } from "@/features/inspector/domain/inspectorViewModel";
import { InspectorDisclosureRow, InspectorSection } from "@/shared/components/InspectorPrimitives";

type InspectorPartsTabProps = {
  model: PartInspectorModel;
  renderPartEditor: (part: Part) => ReactNode;
};

const alignmentControls = [
  ["left", appStrings.inspector.alignLeft, AlignHorizontalJustifyStart],
  ["horizontalCenter", appStrings.inspector.alignCenter, AlignHorizontalJustifyCenter],
  ["right", appStrings.inspector.alignRight, AlignHorizontalJustifyEnd],
  ["bottom", appStrings.inspector.alignBottom, AlignVerticalJustifyEnd],
  ["verticalCenter", appStrings.inspector.alignVerticalCenter, AlignVerticalJustifyCenter],
  ["top", appStrings.inspector.alignTop, AlignVerticalJustifyStart],
] as const;

export function InspectorPartsTab({ model, renderPartEditor }: InspectorPartsTabProps) {
  const [selectedPartId, setSelectedPartId] = useState<string>();
  return (
    <>
      <InspectorSection title={appStrings.inspector.parts} icon={Package}>
        {model.parts.length ? (
          model.parts.map((part) => (
            <InspectorDisclosureRow
              key={part.id}
              title={part.name}
              subtitle={appStrings.inspector.partStructure(
                part.outlineEntityIds.length,
                part.holeEntityIdGroups.length,
              )}
              metadata={appStrings.inspector.partQuantityMembers(part.quantity, part.entityIds.length)}
              expanded={selectedPartId === part.id}
              onToggle={() => {
                model.actions.select(part);
                setSelectedPartId(part.id);
              }}
            >
              {renderPartEditor(part)}
            </InspectorDisclosureRow>
          ))
        ) : (
          <p>{appStrings.inspector.noParts}</p>
        )}
        {model.parts.length > 0 && (
          <div className="arrangement-controls">
            <div className="inspector-divider" />
            <small>{appStrings.inspector.alignDescription}</small>
            <div className="arrangement-align-buttons">
              {alignmentControls.map(([alignment, label, Icon]) => (
                <button
                  key={alignment}
                  aria-label={label}
                  disabled={model.arrangementPartIds.size < 2}
                  onClick={() => model.actions.align(alignment)}
                >
                  <Icon aria-hidden="true" />
                </button>
              ))}
            </div>
            <div className="arrangement-distribute-buttons">
              <button
                disabled={model.arrangementPartIds.size < 3}
                onClick={() => model.actions.distribute("horizontal")}
              >
                {appStrings.inspector.distributeHorizontal}
              </button>
              <button disabled={model.arrangementPartIds.size < 3} onClick={() => model.actions.distribute("vertical")}>
                {appStrings.inspector.distributeVertical}
              </button>
            </div>
          </div>
        )}
        <button
          className="inspector-add-button inspector-prominent-button"
          disabled={!model.selectedCount}
          onClick={model.actions.create}
        >
          <PackagePlus aria-hidden="true" />
          {appStrings.inspector.createPartFromSelection}
        </button>
      </InspectorSection>
      <InspectorSection title={appStrings.inspector.partLibrary} icon={BookOpen}>
        {model.partLibrary.length ? (
          model.partLibrary.map((item) => (
            <div className="part-library-row" key={item.id}>
              <span>
                <strong>{item.name}</strong>
                <small>{appStrings.inspector.partLibraryQuantity(item.sourcePart.quantity)}</small>
              </span>
              <div className="inspector-editor-actions">
                <button
                  className="inspector-icon-button"
                  aria-label={appStrings.inspector.place}
                  onClick={() => model.actions.insertFromLibrary(item)}
                >
                  <CopyPlus aria-hidden="true" />
                </button>
                <button
                  className="inspector-icon-button inspector-icon-destructive-button"
                  aria-label={appStrings.contextMenu.delete}
                  onClick={() => model.actions.removeFromLibrary(item)}
                >
                  <Trash2 aria-hidden="true" />
                </button>
              </div>
            </div>
          ))
        ) : (
          <p>{appStrings.inspector.partLibraryEmpty}</p>
        )}
      </InspectorSection>
    </>
  );
}
