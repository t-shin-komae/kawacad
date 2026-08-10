import { useState, type ReactNode } from "react";
import { BookOpen, Package } from "lucide-react";
import { appStrings } from "@/localization";
import type { Part, PartLibraryEntry, Props } from "@/features/inspector/components/InspectorPanel";
import { InspectorDisclosureRow, InspectorSection } from "@/features/inspector/components/InspectorPrimitives";

type InspectorPartsTabProps = {
  props: Props;
  arrangementPartIds: Set<string>;
  partLibrary: PartLibraryEntry[];
  renderPartEditor: (part: Part) => ReactNode;
};

export function InspectorPartsTab({
  props,
  arrangementPartIds,
  partLibrary,
  renderPartEditor,
}: InspectorPartsTabProps) {
  const [selectedPartId, setSelectedPartId] = useState<string>();
  return (
    <>
      <InspectorSection title={appStrings.inspector.parts} icon={Package}>
        {props.parts.length ? (
          props.parts.map((part) => (
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
                props.onSelectPart(part);
                setSelectedPartId(part.id);
              }}
            >
              {renderPartEditor(part)}
            </InspectorDisclosureRow>
          ))
        ) : (
          <p>{appStrings.inspector.noParts}</p>
        )}
        {props.parts.length > 0 && (
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
                <button
                  key={alignment}
                  disabled={arrangementPartIds.size < 2}
                  onClick={() => props.onAlignParts(alignment)}
                >
                  {label}
                </button>
              ))}
            </div>
            <div className="button-row">
              <button disabled={arrangementPartIds.size < 3} onClick={() => props.onDistributeParts("horizontal")}>
                {appStrings.inspector.distributeHorizontal}
              </button>
              <button disabled={arrangementPartIds.size < 3} onClick={() => props.onDistributeParts("vertical")}>
                {appStrings.inspector.distributeVertical}
              </button>
            </div>
          </div>
        )}
        <button className="inspector-add-button" disabled={!props.selectedCount} onClick={props.onCreatePart}>
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
                <button onClick={() => props.onInsertPartFromLibrary(item)}>{appStrings.inspector.place}</button>
                <button onClick={() => props.onRemovePartFromLibrary(item)}>{appStrings.contextMenu.delete}</button>
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
