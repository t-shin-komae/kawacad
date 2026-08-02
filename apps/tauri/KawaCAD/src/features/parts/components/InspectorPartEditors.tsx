import { useEffect, useState } from "react";
import { geometryOf, type PointMm, type RawEntity } from "@/features/canvas/domain/cad";
import { appStrings } from "@/localization";
import { parseDecimal } from "@/shared/state/syncedField";
import {
  layerColorPresets,
  layerStrokeWidthPresets,
  matchingLayerColorPreset,
  matchingLayerStrokeWidthPreset,
} from "@/features/inspector/domain/stylePresets";
import type { Constraint, Part, PendingTextEntry, Props } from "@/features/inspector/components/InspectorPanel";
import type { TextEntryField } from "@/shared/components/TextEntryDialog";
export function PartEditor({
  part,
  arrangementSelected,
  onCommand,
  onSetQuantity,
  onSelect,
  onToggleArrangement,
  onAddToLibrary,
  onBeginSetOrigin,
  selectedEntityIds,
}: {
  part: Part;
  arrangementSelected: boolean;
  onCommand: Props["onCommand"];
  onSetQuantity: Props["onSetPartQuantity"];
  onSelect: () => void;
  onToggleArrangement: () => void;
  onAddToLibrary: () => void;
  onBeginSetOrigin: () => void;
  selectedEntityIds: string[];
}) {
  const [draftName, setDraftName] = useState(part.name);
  const [draftOrigin, setDraftOrigin] = useState({ xMm: String(part.originMm.xMm), yMm: String(part.originMm.yMm) });
  useEffect(() => setDraftName(part.name), [part.id, part.name]);
  useEffect(
    () => setDraftOrigin({ xMm: String(part.originMm.xMm), yMm: String(part.originMm.yMm) }),
    [part.id, part.originMm.xMm, part.originMm.yMm],
  );
  const commitName = () => {
    const name = draftName.trim();
    if (name && name !== part.name)
      onCommand("renamePart", { partId: part.id, name }, appStrings.inspector.operationMessage.partNameUpdated);
  };
  const commitOrigin = () => {
    const xParsed = parseDecimal(draftOrigin.xMm);
    const yParsed = parseDecimal(draftOrigin.yMm);
    const xMm = xParsed.ok ? xParsed.value : undefined;
    const yMm = yParsed.ok ? yParsed.value : undefined;
    if (
      typeof xMm === "number" &&
      typeof yMm === "number" &&
      Number.isFinite(xMm) &&
      Number.isFinite(yMm) &&
      (xMm !== part.originMm.xMm || yMm !== part.originMm.yMm)
    )
      onCommand(
        "setPartPosition",
        { partId: part.id, position: { xMm, yMm } },
        appStrings.inspector.operationMessage.partOriginUpdated,
      );
  };
  const selectedNormalEntityIds = selectedEntityIds.filter((id) => !id.startsWith("derived:"));
  const addableEntityIds = selectedNormalEntityIds.filter((id) => !part.entityIds.includes(id));
  const removableEntityIds = selectedNormalEntityIds.filter((id) => part.entityIds.includes(id));
  return (
    <div className="inspector-card">
      <div className="row">
        <label>
          {appStrings.inspector.partNameField}
          <input
            aria-label={appStrings.inspector.nameOf(part.name)}
            value={draftName}
            onChange={(event) => setDraftName(event.target.value)}
            onBlur={commitName}
          />
        </label>
        <button onClick={() => onSetQuantity(part.id, part.quantity)}>{appStrings.inspector.quantity}</button>
      </div>
      <label>
        <input type="checkbox" checked={arrangementSelected} onChange={onToggleArrangement} />
        {appStrings.inspector.arrangementTarget}
      </label>
      <label>
        <input
          type="checkbox"
          checked={part.visible}
          onChange={(event) =>
            onCommand(
              "setPartVisibility",
              { partId: part.id, visible: event.target.checked },
              appStrings.inspector.operationMessage.partVisibilityUpdated,
            )
          }
        />
        {appStrings.inspector.display}
      </label>
      <label>
        <input
          type="checkbox"
          aria-label={appStrings.inspector.outputOf(part.name)}
          checked={part.printable}
          onChange={(event) =>
            onCommand(
              "setPartPrintable",
              { partId: part.id, printable: event.target.checked },
              appStrings.inspector.operationMessage.partOutputUpdated,
            )
          }
        />
        {appStrings.inspector.outputTarget}
      </label>
      <div className="part-origin-fields">
        <label>
          {appStrings.inspector.originX}
          <input
            aria-label={appStrings.inspector.originXOf(part.name)}
            type="number"
            step=".01"
            value={draftOrigin.xMm}
            onChange={(event) => setDraftOrigin({ ...draftOrigin, xMm: event.target.value })}
            onBlur={commitOrigin}
          />
        </label>
        <label>
          {appStrings.inspector.originY}
          <input
            aria-label={appStrings.inspector.originYOf(part.name)}
            type="number"
            step=".01"
            value={draftOrigin.yMm}
            onChange={(event) => setDraftOrigin({ ...draftOrigin, yMm: event.target.value })}
            onBlur={commitOrigin}
          />
        </label>
      </div>
      <div className="detail-list" aria-label={appStrings.inspector.configurationOf(part.name)}>
        <span>{appStrings.inspector.geometryCount.outline(part.outlineEntityIds.length)}</span>
        <span>{appStrings.inspector.geometryCount.holes(part.holeEntityIdGroups.length)}</span>
        <span>{appStrings.inspector.geometryCount.derived(part.derivedElementIds.length)}</span>
        <span>{appStrings.inspector.geometryCount.text(part.freeTextIds.length)}</span>
        <span>{appStrings.inspector.geometryCount.measurement(part.measurementAnnotationIds.length)}</span>
      </div>
      <div className="button-row">
        <button onClick={onSelect}>{appStrings.inspector.selectContents}</button>
        <button onClick={onBeginSetOrigin}>{appStrings.inspector.specifyOrigin}</button>
        <button
          onClick={() =>
            onCommand(
              "movePart",
              { partId: part.id, delta: { xMm: -10, yMm: 0 } },
              appStrings.inspector.operationMessage.partMoved,
            )
          }
        >
          ←
        </button>
        <button
          onClick={() =>
            onCommand(
              "movePart",
              { partId: part.id, delta: { xMm: 0, yMm: 10 } },
              appStrings.inspector.operationMessage.partMoved,
            )
          }
        >
          ↑
        </button>
        <button
          onClick={() =>
            onCommand(
              "movePart",
              { partId: part.id, delta: { xMm: 0, yMm: -10 } },
              appStrings.inspector.operationMessage.partMoved,
            )
          }
        >
          ↓
        </button>
        <button
          onClick={() =>
            onCommand(
              "movePart",
              { partId: part.id, delta: { xMm: 10, yMm: 0 } },
              appStrings.inspector.operationMessage.partMoved,
            )
          }
        >
          →
        </button>
        <button
          onClick={() =>
            onCommand(
              "duplicatePart",
              {
                partId: part.id,
                newPartId: "part:" + crypto.randomUUID(),
                newName: appStrings.inspector.copyOf(part.name),
                idNamespace: crypto.randomUUID(),
                delta: { xMm: 10, yMm: -10 },
              },
              appStrings.inspector.operationMessage.partDuplicated,
            )
          }
        >
          {appStrings.contextMenu.duplicate}
        </button>
        <button onClick={onAddToLibrary}>{appStrings.inspector.libraryAdd}</button>
        <button onClick={() => onCommand("deletePart", part.id, appStrings.inspector.operationMessage.partDetached)}>
          {appStrings.inspector.detach}
        </button>
      </div>
      <div className="button-row">
        <button
          disabled={!addableEntityIds.length}
          onClick={() =>
            onCommand(
              "addEntitiesToPart",
              { partId: part.id, entityIds: addableEntityIds },
              appStrings.inspector.operationMessage.partAdded,
            )
          }
        >
          {appStrings.inspector.addSelection}
        </button>
        <button
          disabled={!removableEntityIds.length}
          onClick={() =>
            onCommand(
              "removeEntitiesFromPart",
              { partId: part.id, entityIds: removableEntityIds },
              appStrings.inspector.operationMessage.partRemoved,
            )
          }
        >
          {appStrings.inspector.removeSelection}
        </button>
        <button
          disabled={!selectedNormalEntityIds.length}
          onClick={() =>
            onCommand(
              "setPartBoundary",
              { partId: part.id, entityIds: selectedNormalEntityIds },
              appStrings.inspector.operationMessage.outlineUpdated,
            )
          }
        >
          {appStrings.inspector.setSelectionAsOutline}
        </button>
      </div>
    </div>
  );
}

export function openConstraintValueEntry(
  item: Constraint,
  onCommand: Props["onCommand"],
  openTextEntry: (title: string, fields: TextEntryField[], onConfirm: PendingTextEntry["onConfirm"]) => void,
) {
  const degrees = typeof item.value?.fixedDegrees === "number";
  const current = degrees ? item.value?.fixedDegrees : item.value?.fixedMm;
  openTextEntry(
    degrees ? appStrings.inspector.operationMessage.changeAngle : appStrings.inspector.operationMessage.changeDimension,
    [
      {
        id: "value",
        label: degrees
          ? appStrings.inspector.operationMessage.angleDegrees
          : appStrings.inspector.operationMessage.dimensionMillimeters,
        initialValue: typeof current === "number" ? String(current) : "10",
        inputMode: "decimal",
      },
    ],
    (values) => {
      const value = Number(values.value.replace(",", "."));
      if (Number.isFinite(value) && value > 0)
        onCommand(
          "setConstraintValue",
          { constraintId: item.id, value: degrees ? { fixedDegrees: value } : { fixedMm: value } },
          appStrings.inspector.operationMessage.constraintUpdated,
        );
    },
  );
}
