import { useEffect, useState } from "react";
import {
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  ArrowUp,
  BookPlus,
  CopyPlus,
  Crosshair,
  MousePointer2,
  Ungroup,
} from "lucide-react";
import { geometryOf, type PointMm, type RawEntity } from "@/features/canvas/domain/cad";
import { appStrings } from "@/localization";
import { parseDecimal } from "@/shared/state/syncedField";
import {
  layerColorPresets,
  layerStrokeWidthPresets,
  matchingLayerColorPreset,
  matchingLayerStrokeWidthPreset,
} from "@/features/inspector/domain/stylePresets";
import type { Constraint, Part } from "@/shared/domain/coreWireTypes";
import type { TextEntryField } from "@/shared/components/TextEntryDialog";
import { formatInspectorNumber } from "@/features/inspector/domain/inspectorValueFormatting";

type CommandHandler = (kind: string, payload: unknown, success: string) => void;
type OpenTextEntry = (
  title: string,
  fields: TextEntryField[],
  onConfirm: (values: Record<string, string>) => void,
) => void;
export function PartEditor({
  part,
  arrangementSelected,
  onCommand,
  onSelect,
  onToggleArrangement,
  onAddToLibrary,
  onBeginSetOrigin,
}: {
  part: Part;
  arrangementSelected: boolean;
  onCommand: CommandHandler;
  onSelect: () => void;
  onToggleArrangement: () => void;
  onAddToLibrary: () => void;
  onBeginSetOrigin: () => void;
}) {
  const [draftName, setDraftName] = useState(part.name);
  const [draftOrigin, setDraftOrigin] = useState({
    xMm: formatInspectorNumber(part.originMm.xMm),
    yMm: formatInspectorNumber(part.originMm.yMm),
  });
  useEffect(() => setDraftName(part.name), [part.id, part.name]);
  useEffect(
    () =>
      setDraftOrigin({
        xMm: formatInspectorNumber(part.originMm.xMm),
        yMm: formatInspectorNumber(part.originMm.yMm),
      }),
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
  return (
    <div className="inspector-card part-editor">
      <label>
        <input type="checkbox" checked={arrangementSelected} onChange={onToggleArrangement} />
        {appStrings.inspector.arrangementTarget}
      </label>
      <div className="part-toggle-row">
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
          {appStrings.inspector.partPrintable}
        </label>
      </div>
      <label className="part-quantity-field">
        <span>{appStrings.inspector.partQuantity(part.quantity)}</span>
        <input
          aria-label={appStrings.inspector.quantityOf(part.name)}
          type="number"
          min="1"
          max="999"
          step="1"
          value={part.quantity}
          onChange={(event) => {
            const quantity = Number(event.target.value);
            if (Number.isInteger(quantity) && quantity >= 1 && quantity <= 999)
              onCommand("setPartQuantity", { partId: part.id, quantity }, appStrings.app.partQuantityUpdated);
          }}
        />
      </label>
      <input
        className="part-name-field"
        aria-label={appStrings.inspector.nameOf(part.name)}
        placeholder={appStrings.inspector.partNameField}
        value={draftName}
        onChange={(event) => setDraftName(event.target.value)}
        onBlur={commitName}
      />
      <div className="part-origin-fields">
        <input
          aria-label={appStrings.inspector.originXOf(part.name)}
          placeholder={appStrings.inspector.originX}
          type="number"
          step=".01"
          value={draftOrigin.xMm}
          onChange={(event) => setDraftOrigin({ ...draftOrigin, xMm: event.target.value })}
          onBlur={commitOrigin}
        />
        <input
          aria-label={appStrings.inspector.originYOf(part.name)}
          placeholder={appStrings.inspector.originY}
          type="number"
          step=".01"
          value={draftOrigin.yMm}
          onChange={(event) => setDraftOrigin({ ...draftOrigin, yMm: event.target.value })}
          onBlur={commitOrigin}
        />
      </div>
      <button className="inspector-wide-button" onClick={onBeginSetOrigin}>
        <Crosshair aria-hidden="true" />
        {appStrings.inspector.specifyOrigin}
      </button>
      <div className="part-detail-list" aria-label={appStrings.inspector.configurationOf(part.name)}>
        <div className="detail-row">
          <span>{appStrings.inspector.partDerivedMembers}</span>
          <strong>{part.derivedElementIds.length}</strong>
        </div>
        <div className="detail-row">
          <span>{appStrings.inspector.partTextMembers}</span>
          <strong>{part.freeTextIds.length}</strong>
        </div>
        <div className="detail-row">
          <span>{appStrings.inspector.partMeasurementMembers}</span>
          <strong>{part.measurementAnnotationIds.length}</strong>
        </div>
      </div>
      <button className="inspector-wide-button" onClick={onSelect}>
        <MousePointer2 aria-hidden="true" />
        {appStrings.inspector.selectContents}
      </button>
      <div className="part-move-buttons">
        <button
          aria-label="←"
          onClick={() =>
            onCommand(
              "movePart",
              { partId: part.id, delta: { xMm: -10, yMm: 0 } },
              appStrings.inspector.operationMessage.partMoved,
            )
          }
        >
          <ArrowLeft aria-hidden="true" />
        </button>
        <button
          aria-label="↑"
          onClick={() =>
            onCommand(
              "movePart",
              { partId: part.id, delta: { xMm: 0, yMm: 10 } },
              appStrings.inspector.operationMessage.partMoved,
            )
          }
        >
          <ArrowUp aria-hidden="true" />
        </button>
        <button
          aria-label="↓"
          onClick={() =>
            onCommand(
              "movePart",
              { partId: part.id, delta: { xMm: 0, yMm: -10 } },
              appStrings.inspector.operationMessage.partMoved,
            )
          }
        >
          <ArrowDown aria-hidden="true" />
        </button>
        <button
          aria-label="→"
          onClick={() =>
            onCommand(
              "movePart",
              { partId: part.id, delta: { xMm: 10, yMm: 0 } },
              appStrings.inspector.operationMessage.partMoved,
            )
          }
        >
          <ArrowRight aria-hidden="true" />
        </button>
      </div>
      <button
        className="inspector-wide-button inspector-prominent-button"
        aria-label={appStrings.contextMenu.duplicate}
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
        <CopyPlus aria-hidden="true" />
        {appStrings.inspector.duplicatePart}
      </button>
      <button className="inspector-wide-button" onClick={onAddToLibrary}>
        <BookPlus aria-hidden="true" />
        {appStrings.inspector.libraryAdd}
      </button>
      <div className="inspector-divider" />
      <small className="inspector-help">{appStrings.inspector.partFixedHelp}</small>
      <button
        className="inspector-destructive-button"
        aria-label={appStrings.inspector.detach}
        onClick={() => onCommand("deletePart", part.id, appStrings.inspector.operationMessage.partDetached)}
      >
        <Ungroup aria-hidden="true" />
        {appStrings.inspector.detachPart}
      </button>
    </div>
  );
}

export function openConstraintValueEntry(
  item: Constraint,
  onCommand: CommandHandler,
  openTextEntry: OpenTextEntry,
  parameters: readonly { id: string; valueMm: number }[] = [],
) {
  const degrees = typeof item.value?.fixedDegrees === "number";
  const fixedValue = degrees ? item.value?.fixedDegrees : item.value?.fixedMm;
  const parameterID = typeof item.value?.parameter === "string" ? item.value.parameter : undefined;
  const current =
    typeof fixedValue === "number" ? fixedValue : parameters.find((parameter) => parameter.id === parameterID)?.valueMm;
  openTextEntry(
    degrees ? appStrings.inspector.operationMessage.changeAngle : appStrings.inspector.operationMessage.changeDimension,
    [
      {
        id: "value",
        label: degrees
          ? appStrings.inspector.operationMessage.angleDegrees
          : appStrings.inspector.operationMessage.dimensionMillimeters,
        initialValue: formatInspectorNumber(current),
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
