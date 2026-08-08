import type { ReactNode } from "react";
import { BookOpen, Package } from "lucide-react";
import { appStrings } from "@/localization";
import type { Part, PartLibraryEntry, Props } from "@/features/inspector/components/InspectorPanel";

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
  return (
    <>
      <section>
        <h2>
          <Package aria-hidden="true" />
          {appStrings.inspector.parts}
        </h2>
        {props.parts.length ? (
          props.parts.map((part) => <div key={part.id}>{renderPartEditor(part)}</div>)
        ) : (
          <p>{appStrings.inspector.noParts}</p>
        )}
        {props.parts.length > 1 && (
          <div className="arrangement-controls">
            <small>{appStrings.inspector.alignDescription}</small>
            <div className="button-row">
              {[
                ["left", appStrings.inspector.alignLeft],
                ["horizontalCenter", appStrings.inspector.alignCenter],
                ["right", appStrings.inspector.alignRight],
                ["top", appStrings.inspector.alignTop],
                ["bottom", appStrings.inspector.alignBottom],
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
        <button disabled={!props.selectedCount} onClick={props.onCreatePart}>
          {appStrings.inspector.createPartFromSelection}
        </button>
      </section>
      <section>
        <h2>
          <BookOpen aria-hidden="true" />
          {appStrings.inspector.partLibrary}
        </h2>
        {partLibrary.length ? (
          partLibrary.map((item) => (
            <div className="row" key={item.id}>
              <span>
                {item.name}
                <small>×{item.sourcePart.quantity}</small>
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
      </section>
    </>
  );
}
