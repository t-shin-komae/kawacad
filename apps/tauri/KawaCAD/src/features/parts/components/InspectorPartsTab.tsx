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
import { InspectorDisclosureRow, InspectorSection } from "@/shared/components/InspectorPrimitives";

type InspectorPartsTabProps = {
  selectedCount: number;
  parts: Part[];
  arrangementPartIds: Set<string>;
  partLibrary: PartLibraryEntry[];
  onCreatePart: () => void;
  onSelectPart: (part: Part) => void;
  onAlignParts: (alignment: string) => void;
  onDistributeParts: (axis: string) => void;
  onInsertPartFromLibrary: (entry: PartLibraryEntry) => void;
  onRemovePartFromLibrary: (entry: PartLibraryEntry) => void;
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

export function InspectorPartsTab({
  selectedCount,
  parts,
  arrangementPartIds,
  partLibrary,
  onCreatePart,
  onSelectPart,
  onAlignParts,
  onDistributeParts,
  onInsertPartFromLibrary,
  onRemovePartFromLibrary,
  renderPartEditor,
}: InspectorPartsTabProps) {
  const [selectedPartId, setSelectedPartId] = useState<string>();
  return (
    <>
      <InspectorSection title={appStrings.inspector.parts} icon={Package}>
        {parts.length ? (
          parts.map((part) => (
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
                onSelectPart(part);
                setSelectedPartId(part.id);
              }}
            >
              {renderPartEditor(part)}
            </InspectorDisclosureRow>
          ))
        ) : (
          <p>{appStrings.inspector.noParts}</p>
        )}
        {parts.length > 0 && (
          <div className="arrangement-controls">
            <div className="inspector-divider" />
            <small>{appStrings.inspector.alignDescription}</small>
            <div className="arrangement-align-buttons">
              {alignmentControls.map(([alignment, label, Icon]) => (
                <button
                  key={alignment}
                  aria-label={label}
                  disabled={arrangementPartIds.size < 2}
                  onClick={() => onAlignParts(alignment)}
                >
                  <Icon aria-hidden="true" />
                </button>
              ))}
            </div>
            <div className="arrangement-distribute-buttons">
              <button disabled={arrangementPartIds.size < 3} onClick={() => onDistributeParts("horizontal")}>
                {appStrings.inspector.distributeHorizontal}
              </button>
              <button disabled={arrangementPartIds.size < 3} onClick={() => onDistributeParts("vertical")}>
                {appStrings.inspector.distributeVertical}
              </button>
            </div>
          </div>
        )}
        <button
          className="inspector-add-button inspector-prominent-button"
          disabled={!selectedCount}
          onClick={onCreatePart}
        >
          <PackagePlus aria-hidden="true" />
          {appStrings.inspector.createPartFromSelection}
        </button>
      </InspectorSection>
      <InspectorSection title={appStrings.inspector.partLibrary} icon={BookOpen}>
        {partLibrary.length ? (
          partLibrary.map((item) => (
            <div className="part-library-row" key={item.id}>
              <span>
                <strong>{item.name}</strong>
                <small>{appStrings.inspector.partLibraryQuantity(item.sourcePart.quantity)}</small>
              </span>
              <div className="inspector-editor-actions">
                <button
                  className="inspector-icon-button"
                  aria-label={appStrings.inspector.place}
                  onClick={() => onInsertPartFromLibrary(item)}
                >
                  <CopyPlus aria-hidden="true" />
                </button>
                <button
                  className="inspector-icon-button inspector-icon-destructive-button"
                  aria-label={appStrings.contextMenu.delete}
                  onClick={() => onRemovePartFromLibrary(item)}
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
