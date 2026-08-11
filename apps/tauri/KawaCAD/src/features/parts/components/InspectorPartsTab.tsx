import { useState, type ReactNode } from "react";
import { BookOpen, Package } from "lucide-react";
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
            <small>{appStrings.inspector.alignDescription}</small>
            <div className="button-row">
              {[
                ["left", appStrings.inspector.alignLeft],
                ["horizontalCenter", appStrings.inspector.alignCenter],
                ["right", appStrings.inspector.alignRight],
                ["bottom", appStrings.inspector.alignBottom],
                ["verticalCenter", appStrings.inspector.alignVerticalCenter],
                ["top", appStrings.inspector.alignTop],
              ].map(([alignment, label]) => (
                <button key={alignment} disabled={arrangementPartIds.size < 2} onClick={() => onAlignParts(alignment)}>
                  {label}
                </button>
              ))}
            </div>
            <div className="button-row">
              <button disabled={arrangementPartIds.size < 3} onClick={() => onDistributeParts("horizontal")}>
                {appStrings.inspector.distributeHorizontal}
              </button>
              <button disabled={arrangementPartIds.size < 3} onClick={() => onDistributeParts("vertical")}>
                {appStrings.inspector.distributeVertical}
              </button>
            </div>
          </div>
        )}
        <button className="inspector-add-button" disabled={!selectedCount} onClick={onCreatePart}>
          {appStrings.inspector.createPartFromSelection}
        </button>
      </InspectorSection>
      <InspectorSection title={appStrings.inspector.partLibrary} icon={BookOpen}>
        {partLibrary.length ? (
          partLibrary.map((item) => (
            <div className="row" key={item.id}>
              <span>
                {item.name}
                <small>{appStrings.inspector.partLibraryQuantity(item.sourcePart.quantity)}</small>
              </span>
              <div className="button-row">
                <button onClick={() => onInsertPartFromLibrary(item)}>{appStrings.inspector.place}</button>
                <button onClick={() => onRemovePartFromLibrary(item)}>{appStrings.contextMenu.delete}</button>
              </div>
            </div>
          ))
        ) : (
          <p>{appStrings.inspector.noRegisteredParts}</p>
        )}
      </InspectorSection>
    </>
  );
}
