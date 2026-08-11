import { useEffect, useState } from "react";
import { FileText } from "lucide-react";
import { geometryOf, type PointMm, type RawEntity } from "@/features/canvas/domain/cad";
import { appStrings } from "@/localization";
import { parseDecimal } from "@/shared/state/syncedField";
import {
  layerColorPresets,
  layerStrokeWidthPresets,
  matchingLayerColorPreset,
  matchingLayerStrokeWidthPreset,
} from "@/features/inspector/domain/stylePresets";
import type { TextEntryField } from "@/shared/components/TextEntryDialog";
import type {
  Constraint,
  DerivedElement,
  LineStyle,
  Measurement,
  Part,
  PendingTextEntry,
  Props,
} from "@/features/inspector/components/InspectorPanel";
import { InspectorSection } from "@/features/inspector/components/InspectorPrimitives";

export const defaultStyle: LineStyle = {
  stroke: { red: 0.07, green: 0.09, blue: 0.15, alpha: 1 },
  strokeWidthMm: 0.2,
  pattern: "solid",
};

export function DocumentOverview({ summary }: { summary: Props["documentSummary"] }) {
  const values: Array<[string, string | number]> = [
    [appStrings.inspector.viewMode, summary.viewMode],
    [appStrings.inspector.drawingLayer, summary.activeLayerName],
    [appStrings.inspector.visibleGeometry, summary.visibleEntityCount],
    [appStrings.inspector.constraintCount, summary.constraintCount],
    [appStrings.inspector.parameterCount, summary.parameterCount],
  ];
  return (
    <InspectorSection title={appStrings.inspector.document} icon={FileText} className="document-overview">
      {values.map(([label, value]) => (
        <div className="detail-row" key={label}>
          <span>{label}</span>
          <strong>{value}</strong>
        </div>
      ))}
    </InspectorSection>
  );
}
export function SelectedConstraintEditor({
  constraint,
  parameters,
  onCommand,
  onDelete,
}: {
  constraint: Constraint;
  parameters: Props["parameters"];
  onCommand: Props["onCommand"];
  onDelete: Props["onDeleteSelection"];
}) {
  const degrees = typeof constraint.value?.fixedDegrees === "number";
  const fixedValue = degrees ? constraint.value?.fixedDegrees : constraint.value?.fixedMm;
  const [draft, setDraft] = useState(typeof fixedValue === "number" ? String(fixedValue) : "");
  useEffect(() => setDraft(typeof fixedValue === "number" ? String(fixedValue) : ""), [fixedValue]);
  const commit = () => {
    const parsed = parseDecimal(draft);
    const value = parsed.ok ? parsed.value : undefined;
    const valid = value !== undefined && Number.isFinite(value) && (degrees ? true : value > 0);
    if (valid && value !== fixedValue)
      onCommand(
        "setConstraintValue",
        {
          constraintId: constraint.id,
          value: degrees ? { fixedDegrees: value as number } : { fixedMm: value as number },
        },
        appStrings.inspector.operationMessage.constraintUpdated,
      );
  };
  return (
    <div className="inspector-card constraint-editor">
      <strong>
        {appStrings.constraintKindNames[constraint.kind as keyof typeof appStrings.constraintKindNames] ??
          constraint.kind}
      </strong>
      <small>
        {appStrings.constraintStatusNames[constraint.status as keyof typeof appStrings.constraintStatusNames] ??
          constraint.status}
      </small>
      {constraint.value && (
        <label>
          {appStrings.inspector.constraintValue(degrees)}
          <input
            aria-label={appStrings.inspector.constraintValue(degrees)}
            type="number"
            step=".01"
            value={draft}
            onChange={(event) => setDraft(event.target.value)}
            onBlur={commit}
          />
        </label>
      )}
      {!degrees && parameters.length > 0 && (
        <label>
          {appStrings.inspector.parameter}
          <select
            value={typeof constraint.value?.parameter === "string" ? constraint.value.parameter : ""}
            onChange={(event) => {
              if (event.target.value)
                onCommand(
                  "setConstraintParameter",
                  { constraintId: constraint.id, parameterId: event.target.value },
                  appStrings.inspector.operationMessage.constraintParameterUpdated,
                );
              else commit();
            }}
          >
            <option value="">{appStrings.inspector.fixedValue}</option>
            {parameters.map((item) => (
              <option key={item.id} value={item.id}>
                {item.name}
              </option>
            ))}
          </select>
        </label>
      )}
      <button className="inspector-destructive-button" onClick={onDelete}>
        {appStrings.contextMenu.delete}
      </button>
    </div>
  );
}

export function SelectedMeasurementEditor({
  measurement,
  onConvert,
  onDelete,
}: {
  measurement: Measurement;
  onConvert?: (id: string) => void;
  onDelete: Props["onDeleteSelection"];
}) {
  return (
    <div className="inspector-card">
      <strong>
        {appStrings.measurementKindNames[measurement.kind as keyof typeof appStrings.measurementKindNames] ??
          measurement.kind}
      </strong>
      <button onClick={() => onConvert?.(measurement.id)}>{appStrings.inspector.measurementConstraint}</button>
      <button className="inspector-destructive-button" onClick={onDelete}>
        {appStrings.contextMenu.delete}
      </button>
    </div>
  );
}

export function SelectedStitchStartPointEditor({ targetEntity }: { targetEntity?: RawEntity }) {
  return (
    <div className="inspector-card">
      <strong>{appStrings.inspector.stitchStartPoint}</strong>
      <div className="detail-row">
        <span>{appStrings.inspector.targetGeometry}</span>
        <strong>{targetEntity ? geometryDisplayName(targetEntity) : appStrings.inspector.geometry}</strong>
      </div>
    </div>
  );
}

export function FreeTextEditor({
  freeText,
  onCommand,
  onDelete,
}: {
  freeText: NonNullable<Props["selectedFreeText"]>;
  onCommand: Props["onCommand"];
  onDelete: Props["onDeleteSelection"];
}) {
  const [draft, setDraft] = useState({
    content: freeText.content,
    xMm: String(freeText.positionMm.xMm),
    yMm: String(freeText.positionMm.yMm),
    fontSizeMm: String(freeText.fontSizeMm),
  });
  useEffect(
    () =>
      setDraft({
        content: freeText.content,
        xMm: String(freeText.positionMm.xMm),
        yMm: String(freeText.positionMm.yMm),
        fontSizeMm: String(freeText.fontSizeMm),
      }),
    [freeText],
  );
  const commit = () => {
    const xParsed = parseDecimal(draft.xMm);
    const yParsed = parseDecimal(draft.yMm);
    const fontParsed = parseDecimal(draft.fontSizeMm);
    const xMm = xParsed.ok ? xParsed.value : undefined;
    const yMm = yParsed.ok ? yParsed.value : undefined;
    const fontSizeMm = fontParsed.ok ? fontParsed.value : undefined;
    const content = draft.content.trim();
    if (
      !content ||
      typeof xMm !== "number" ||
      typeof yMm !== "number" ||
      typeof fontSizeMm !== "number" ||
      !Number.isFinite(xMm) ||
      !Number.isFinite(yMm) ||
      !Number.isFinite(fontSizeMm) ||
      fontSizeMm <= 0
    )
      return;
    if (
      content !== freeText.content ||
      xMm !== freeText.positionMm.xMm ||
      yMm !== freeText.positionMm.yMm ||
      fontSizeMm !== freeText.fontSizeMm
    )
      onCommand(
        "updateFreeText",
        { id: freeText.id, content, positionMm: { xMm, yMm }, fontSizeMm },
        appStrings.inspector.operationMessage.textUpdated,
      );
  };
  return (
    <div className="inspector-card free-text-editor">
      <label>
        {appStrings.inspector.content}
        <input
          aria-label={appStrings.inspector.textContent}
          value={draft.content}
          onChange={(event) => setDraft({ ...draft, content: event.target.value })}
          onBlur={commit}
        />
      </label>
      <button className="inspector-destructive-button" onClick={onDelete}>
        {appStrings.contextMenu.delete}
      </button>
      <div className="part-origin-fields">
        <label>
          X (mm)
          <input
            aria-label={appStrings.inspector.textX}
            type="number"
            step=".01"
            value={draft.xMm}
            onChange={(event) => setDraft({ ...draft, xMm: event.target.value })}
            onBlur={commit}
          />
        </label>
        <label>
          Y (mm)
          <input
            aria-label={appStrings.inspector.textY}
            type="number"
            step=".01"
            value={draft.yMm}
            onChange={(event) => setDraft({ ...draft, yMm: event.target.value })}
            onBlur={commit}
          />
        </label>
      </div>
      <label>
        {appStrings.inspector.fontSize}
        <input
          aria-label={appStrings.inspector.fontSize}
          type="number"
          min=".1"
          step=".1"
          value={draft.fontSizeMm}
          onChange={(event) => setDraft({ ...draft, fontSizeMm: event.target.value })}
          onBlur={commit}
        />
      </label>
    </div>
  );
}

export function ParameterEditor({
  parameter,
  onCommand,
}: {
  parameter: Props["parameters"][number];
  onCommand: Props["onCommand"];
}) {
  const [draft, setDraft] = useState({ name: parameter.name, value: String(parameter.valueMm), memo: parameter.memo });
  useEffect(
    () => setDraft({ name: parameter.name, value: String(parameter.valueMm), memo: parameter.memo }),
    [parameter],
  );
  const commit = () => {
    const name = draft.name.trim();
    const parsed = parseDecimal(draft.value);
    const valueMm = parsed.ok ? parsed.value : undefined;
    if (!name || typeof valueMm !== "number" || !Number.isFinite(valueMm) || valueMm < 0) return;
    if (name !== parameter.name || valueMm !== parameter.valueMm || draft.memo !== parameter.memo)
      onCommand(
        "updateParameter",
        { id: parameter.id, name, valueMm, unit: parameter.unit, memo: draft.memo },
        appStrings.inspector.parameterUpdated(name),
      );
  };
  return (
    <div className="inspector-card parameter-editor">
      <div className="row">
        <label>
          {appStrings.inspector.name}
          <input
            aria-label={appStrings.inspector.nameOf(parameter.name)}
            value={draft.name}
            onChange={(event) => setDraft({ ...draft, name: event.target.value })}
            onBlur={commit}
          />
        </label>
        <label>
          {appStrings.inspector.millimeters}
          <input
            aria-label={appStrings.inspector.valueOf(parameter.name)}
            type="number"
            min="0"
            step=".01"
            value={draft.value}
            onChange={(event) => setDraft({ ...draft, value: event.target.value })}
            onBlur={commit}
          />
        </label>
        <button
          className="inspector-icon-destructive-button"
          aria-label={appStrings.inspector.deleteParameter(parameter.name)}
          onClick={() =>
            onCommand(
              "deleteParameter",
              { parameterId: parameter.id, replacementValueMm: parameter.valueMm },
              appStrings.inspector.operationMessage.parameterDeleted(parameter.name),
            )
          }
        >
          {appStrings.contextMenu.delete}
        </button>
      </div>
      <label>
        {appStrings.inspector.parameterMemo}
        <input
          aria-label={appStrings.inspector.memoOf(parameter.name)}
          value={draft.memo}
          onChange={(event) => setDraft({ ...draft, memo: event.target.value })}
          onBlur={commit}
        />
      </label>
      <small className={parameterUsageCount(parameter) === 0 ? "parameter-usage-warning" : "inspector-help"}>
        {parameterUsageCount(parameter) === 0
          ? appStrings.inspector.parameterUnusedHint
          : appStrings.inspector.parameterUsedHint(parameterUsageCount(parameter))}
      </small>
    </div>
  );
}

function parameterUsageCount(parameter: Props["parameters"][number]) {
  return parameter.usageCount ?? parameter.usedConstraintIds?.length ?? 0;
}

export function StyleFields({
  style = defaultStyle,
  onChange,
}: {
  style?: LineStyle;
  onChange: (style: LineStyle) => void;
}) {
  const color =
    "#" +
    [style.stroke.red, style.stroke.green, style.stroke.blue]
      .map((item) =>
        Math.round(item * 255)
          .toString(16)
          .padStart(2, "0"),
      )
      .join("");
  const [customEditor, setCustomEditor] = useState<"color" | "width">();
  const [customColorDraft, setCustomColorDraft] = useState(color.toUpperCase());
  useEffect(() => setCustomColorDraft(color.toUpperCase()), [color]);
  return (
    <div className="style-fields">
      <label className="style-field">
        <span>{appStrings.inspector.lineStyle}</span>
        <span className={`line-style-preview ${style.pattern}`} aria-hidden="true" />
        <select
          aria-label={appStrings.inspector.lineStyle}
          value={style.pattern}
          onChange={(event) => onChange({ ...style, pattern: event.target.value })}
        >
          <option value="solid">{appStrings.inspector.lineStyles.solid}</option>
          <option value="dashed">{appStrings.inspector.lineStyles.dashed}</option>
          <option value="dotted">{appStrings.inspector.lineStyles.dotted}</option>
          <option value="construction">{appStrings.inspector.lineStyles.construction}</option>
        </select>
      </label>
      <label className="style-field">
        <span>{appStrings.inspector.color}</span>
        <span className="style-color-swatch" style={{ backgroundColor: color }} aria-hidden="true" />
        <select
          aria-label={appStrings.inspector.colorPreset}
          value={matchingLayerColorPreset(color)?.colorHex ?? "custom"}
          onChange={(event) => {
            const preset = layerColorPresets.find((item) => item.colorHex === event.target.value);
            if (!preset) {
              setCustomEditor("color");
              return;
            }
            setCustomEditor(undefined);
            onChange({ ...style, stroke: colorFromHex(preset.colorHex, style.stroke.alpha) });
          }}
        >
          <option value="custom">{appStrings.inspector.custom}</option>
          {layerColorPresets.map((preset) => (
            <option key={preset.colorHex} value={preset.colorHex}>
              {preset.displayName}
            </option>
          ))}
        </select>
      </label>
      <label className="style-field">
        <span>{appStrings.inspector.lineWidth}</span>
        <span
          className="line-width-preview"
          style={{ borderTopWidth: `${Math.max(1, style.strokeWidthMm * 5)}px`, borderTopColor: color }}
          aria-hidden="true"
        />
        <select
          aria-label={appStrings.inspector.lineWidthPreset}
          value={matchingLayerStrokeWidthPreset(style.strokeWidthMm)?.widthMm ?? "custom"}
          onChange={(event) => {
            if (event.target.value === "custom") {
              setCustomEditor("width");
              return;
            }
            setCustomEditor(undefined);
            onChange({ ...style, strokeWidthMm: Number(event.target.value) });
          }}
        >
          <option value="custom">{appStrings.inspector.custom}</option>
          {layerStrokeWidthPresets.map((preset) => (
            <option key={preset.widthMm} value={preset.widthMm}>
              {preset.displayName}
            </option>
          ))}
        </select>
      </label>
      {customEditor === "color" && (
        <label className="style-custom-field">
          {appStrings.inspector.customColor}
          <input
            aria-label={appStrings.inspector.customColor}
            value={customColorDraft}
            pattern="#[0-9A-Fa-f]{6}"
            onChange={(event) => {
              const draft = event.target.value;
              setCustomColorDraft(draft);
              if (/^#[0-9A-Fa-f]{6}$/.test(draft))
                onChange({ ...style, stroke: colorFromHex(draft, style.stroke.alpha) });
            }}
          />
        </label>
      )}
      {customEditor === "width" && (
        <label className="style-custom-field">
          {appStrings.inspector.customLineWidth}
          <input
            aria-label={appStrings.inspector.customLineWidth}
            type="number"
            min=".05"
            max="2"
            step=".01"
            value={style.strokeWidthMm}
            onChange={(event) => onChange({ ...style, strokeWidthMm: Number(event.target.value) })}
          />
        </label>
      )}
    </div>
  );
}

export function colorFromHex(color: string, alpha: number): LineStyle["stroke"] {
  return {
    red: Number.parseInt(color.slice(1, 3), 16) / 255,
    green: Number.parseInt(color.slice(3, 5), 16) / 255,
    blue: Number.parseInt(color.slice(5, 7), 16) / 255,
    alpha,
  };
}

export function DerivedElementEditor({
  derivedElement,
  layers,
  sharedStyles,
  parameters,
  onCommand,
}: {
  derivedElement: DerivedElement;
  layers: Props["layers"];
  sharedStyles: Props["sharedStyles"];
  parameters: Props["parameters"];
  onCommand: Props["onCommand"];
}) {
  const offset = derivedElement.kind.offsetCurve;
  const fillet = derivedElement.kind.fillet;
  const kind = offset ? appStrings.inspector.offsetElement : appStrings.inspector.filletElement;
  const sourceEntityIds = offset?.sourceEntityIds ?? fillet?.sourceEntityIds ?? [];
  const value = offset?.distance ?? fillet?.radius ?? {};
  const commandKind = offset ? "setDerivedDistance" : "setDerivedRadius";
  const label = offset ? appStrings.inspector.distance : appStrings.inspector.radius;
  const [draftValue, setDraftValue] = useState(String(value.fixedMm ?? ""));
  useEffect(() => setDraftValue(String(value.fixedMm ?? "")), [value.fixedMm]);
  const commit = () => {
    const parsed = parseDecimal(draftValue);
    const fixedMm = parsed.ok ? parsed.value : undefined;
    if (typeof fixedMm === "number" && Number.isFinite(fixedMm) && fixedMm > 0 && fixedMm !== value.fixedMm)
      onCommand(
        commandKind,
        { derivedElementId: derivedElement.id, value: { fixedMm } },
        appStrings.inspector.operationUpdated(kind),
      );
  };
  return (
    <div className="inspector-card derived-element-editor">
      <strong>{kind}</strong>
      <div className="detail-list">
        <span>{appStrings.inspector.sourceElements(sourceEntityIds.length)}</span>
      </div>
      <label>
        {appStrings.inspector.layer}
        <select
          value={derivedElement.layerId ?? ""}
          onChange={(event) =>
            onCommand(
              "setDerivedLayer",
              { derivedElementId: derivedElement.id, layerId: event.target.value || null },
              appStrings.inspector.operationMessage.derivedLayerUpdated,
            )
          }
        >
          <option value="">{appStrings.inspector.noValue}</option>
          {layers.map((item) => (
            <option key={item.id} value={item.id}>
              {item.name}
            </option>
          ))}
        </select>
      </label>
      <label>
        {appStrings.inspector.sharedStyles}
        <select
          value={derivedElement.styleId ?? ""}
          onChange={(event) =>
            onCommand(
              "setDerivedSharedStyle",
              { derivedElementId: derivedElement.id, styleId: event.target.value || null },
              appStrings.inspector.operationMessage.derivedStyleUpdated,
            )
          }
        >
          <option value="">{appStrings.inspector.noValue}</option>
          {sharedStyles.map((item) => (
            <option key={item.id} value={item.id}>
              {item.name}
            </option>
          ))}
        </select>
      </label>
      <label>
        {label}
        <input
          aria-label={appStrings.inspector.derivedValue(kind, label)}
          type="number"
          min=".01"
          step=".01"
          value={draftValue}
          onChange={(event) => setDraftValue(event.target.value)}
          onBlur={commit}
        />
      </label>
      {parameters.length > 0 && (
        <label>
          {appStrings.inspector.parameter}
          <select
            value={value.parameter ?? ""}
            onChange={(event) => {
              const parameter = event.target.value;
              if (parameter)
                onCommand(
                  commandKind,
                  { derivedElementId: derivedElement.id, value: { parameter } },
                  appStrings.inspector.parameterLinked(kind),
                );
              else commit();
            }}
          >
            <option value="">{appStrings.inspector.fixedValue}</option>
            {parameters.map((item) => (
              <option key={item.id} value={item.id}>
                {item.name}
              </option>
            ))}
          </select>
        </label>
      )}
      {offset && (
        <>
          <label>
            {appStrings.inspector.direction}
            <select
              value={offset.direction}
              onChange={(event) =>
                onCommand(
                  "setDerivedDirection",
                  { derivedElementId: derivedElement.id, direction: event.target.value },
                  appStrings.inspector.operationMessage.offsetDirectionUpdated,
                )
              }
            >
              <option value="left">{appStrings.inspector.directions.left}</option>
              <option value="right">{appStrings.inspector.directions.right}</option>
              <option value="inward">{appStrings.inspector.directions.inward}</option>
              <option value="outward">{appStrings.inspector.directions.outward}</option>
            </select>
          </label>
          <button
            onClick={() =>
              onCommand(
                "setDerivedDirection",
                { derivedElementId: derivedElement.id, direction: reverseOffsetDirection(offset.direction) },
                appStrings.inspector.operationMessage.offsetDirectionUpdated,
              )
            }
          >
            {appStrings.inspector.reverseDirection}
          </button>
        </>
      )}
    </div>
  );
}

export function reverseOffsetDirection(direction: string) {
  if (direction === "left") return "right";
  if (direction === "right") return "left";
  if (direction === "inward") return "outward";
  if (direction === "outward") return "inward";
  return direction;
}

export function EntityEditor({
  entity,
  derivedElement,
  layers,
  sharedStyles,
  parameters,
  roundHole,
  onCommand,
  onConstrainSegmentLength,
}: {
  entity: RawEntity;
  derivedElement?: DerivedElement;
  layers: Props["layers"];
  sharedStyles: Props["sharedStyles"];
  parameters: Props["parameters"];
  roundHole?: Props["roundHoles"][number];
  onCommand: Props["onCommand"];
  onConstrainSegmentLength?: Props["onConstrainSegmentLength"];
}) {
  if (derivedElement)
    return (
      <DerivedElementEditor
        derivedElement={derivedElement}
        layers={layers}
        sharedStyles={sharedStyles}
        parameters={parameters}
        onCommand={onCommand}
      />
    );
  const geometry = geometryOf(entity);
  return (
    <div className="inspector-card">
      <strong>{geometryDisplayName(entity)}</strong>
      <label>
        {appStrings.inspector.layer}
        <select
          value={entity.layerId ?? ""}
          onChange={(event) =>
            onCommand(
              "setEntityLayer",
              { entityId: entity.id, layerId: event.target.value || null },
              appStrings.inspector.operationMessage.geometryLayerUpdated,
            )
          }
        >
          <option value="">{appStrings.inspector.noValue}</option>
          {layers.map((item) => (
            <option key={item.id} value={item.id}>
              {item.name}
            </option>
          ))}
        </select>
      </label>
      <label>
        {appStrings.inspector.sharedStyles}
        <select
          value={entity.styleId ?? ""}
          onChange={(event) =>
            onCommand(
              "setEntitySharedStyle",
              { entityId: entity.id, styleId: event.target.value || null },
              appStrings.inspector.operationMessage.geometryStyleUpdated,
            )
          }
        >
          <option value="">{appStrings.inspector.noValue}</option>
          {sharedStyles.map((item) => (
            <option key={item.id} value={item.id}>
              {item.name}
            </option>
          ))}
        </select>
      </label>
      {geometry && geometry.tag !== "point" && (
        <EntityGeometryFields
          entityId={entity.id}
          geometry={geometry}
          onCommand={onCommand}
          onConstrainSegmentLength={onConstrainSegmentLength}
        />
      )}
      {geometry?.tag === "arc" && (
        <button
          onClick={() =>
            onCommand(
              "smoothArcTangencies",
              { arcEntityId: entity.id },
              appStrings.inspector.operationMessage.arcTangenciesUpdated,
            )
          }
        >
          {appStrings.inspector.smoothArcTangencies}
        </button>
      )}
      {roundHole && <RoundHoleFields entity={entity} roundHole={roundHole} onCommand={onCommand} />}
    </div>
  );
}

export function geometryDisplayName(entity: RawEntity) {
  switch (geometryOf(entity)?.tag) {
    case "point":
      return appStrings.toolNames.point;
    case "lineSegment":
      return appStrings.toolNames.line;
    case "centerLine":
      return appStrings.toolNames.centerLine;
    case "circle":
      return appStrings.toolNames.circle;
    case "arc":
      return appStrings.toolNames.arc;
    default:
      return appStrings.inspector.geometry;
  }
}

export function RoundHoleFields({
  entity,
  roundHole,
  onCommand,
}: {
  entity: RawEntity;
  roundHole: NonNullable<Props["roundHoles"]>[number];
  onCommand: Props["onCommand"];
}) {
  const geometry = geometryOf(entity);
  const diameter = geometry?.tag === "circle" ? geometry.radiusMm * 2 : undefined;
  const [draft, setDraft] = useState(diameter === undefined ? "" : String(diameter));
  useEffect(() => setDraft(diameter === undefined ? "" : String(diameter)), [diameter]);
  const commit = () => {
    const parsed = parseDecimal(draft);
    const value = parsed.ok ? parsed.value : undefined;
    if (typeof value === "number" && Number.isFinite(value) && value > 0 && value !== diameter)
      onCommand(
        "setRoundHoleDiameter",
        { roundHoleId: roundHole.id, diameterMm: value },
        appStrings.inspector.operationMessage.roundHoleDiameterUpdated,
      );
  };
  return (
    <>
      <label>
        {appStrings.inspector.roundHoleKind}
        <select
          value={roundHole.kind}
          onChange={(event) =>
            onCommand(
              "setRoundHoleKind",
              { roundHoleId: roundHole.id, kind: event.target.value },
              appStrings.inspector.operationMessage.roundHoleKindUpdated,
            )
          }
        >
          <option value="keyRing">{appStrings.palette.roundHoleKinds.keyRing}</option>
          <option value="rivet">{appStrings.palette.roundHoleKinds.rivet}</option>
          <option value="snapFastener">{appStrings.palette.roundHoleKinds.snapFastener}</option>
          <option value="decorative">{appStrings.palette.roundHoleKinds.decorative}</option>
        </select>
      </label>
      <label>
        {appStrings.inspector.diameter}
        <input
          aria-label={appStrings.palette.roundHoleDiameter}
          type="number"
          min=".01"
          step=".01"
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          onBlur={commit}
        />
      </label>
    </>
  );
}

export function EntityGeometryFields({
  entityId,
  geometry,
  onCommand,
  onConstrainSegmentLength,
}: {
  entityId: string;
  geometry: NonNullable<ReturnType<typeof geometryOf>>;
  onCommand: Props["onCommand"];
  onConstrainSegmentLength?: Props["onConstrainSegmentLength"];
}) {
  const initial = geometryFields(geometry);
  const [draft, setDraft] = useState(initial);
  useEffect(() => setDraft(geometryFields(geometry)), [geometry]);
  const commit = () => {
    const values = Object.fromEntries(
      Object.entries(draft).map(([key, value]) => {
        const parsed = parseDecimal(value);
        return [key, parsed.ok ? parsed.value : undefined];
      }),
    ) as Record<string, number | undefined>;
    if (Object.values(values).some((value) => typeof value !== "number" || !Number.isFinite(value))) return;
    if (geometry.tag === "lineSegment" || geometry.tag === "centerLine") {
      const valueMm = values.lengthMm;
      if (typeof valueMm === "number" && valueMm > 0 && valueMm !== Number(initial.lengthMm))
        onCommand(
          "setEntityMetric",
          { entityId, metric: { kind: "segmentLength", valueMm } },
          appStrings.inspector.operationMessage.segmentLengthUpdated,
        );
      return;
    }
    if (geometry.tag === "circle") {
      const valueMm = values.radiusMm;
      if (typeof valueMm === "number" && valueMm > 0 && valueMm !== Number(initial.radiusMm))
        onCommand(
          "setEntityMetric",
          { entityId, metric: { kind: "circleRadius", valueMm } },
          appStrings.inspector.operationMessage.circleRadiusUpdated,
        );
      return;
    }
    const radiusMm = values.radiusMm;
    const startDegrees = values.startDegrees;
    const sweepDegrees = values.sweepDegrees;
    if (typeof radiusMm !== "number" || typeof startDegrees !== "number" || typeof sweepDegrees !== "number") return;
    const startAngleRad = (startDegrees * Math.PI) / 180;
    const sweepAngleRad = (sweepDegrees * Math.PI) / 180;
    const radiusChanged = radiusMm !== Number(initial.radiusMm);
    const startChanged = values.startDegrees !== Number(initial.startDegrees);
    const sweepChanged = values.sweepDegrees !== Number(initial.sweepDegrees);
    if (radiusMm > 0 && Math.abs(sweepAngleRad) > 0.0001 && (radiusChanged || startChanged || sweepChanged))
      onCommand(
        "setEntityMetric",
        {
          entityId,
          metric: {
            kind: "arcUpdate",
            ...(radiusChanged ? { radiusMm } : {}),
            ...(startChanged ? { startAngleRad } : {}),
            ...(sweepChanged ? { sweepAngleRad } : {}),
          },
        },
        appStrings.inspector.operationMessage.arcUpdated,
      );
  };
  return (
    <div className="geometry-fields">
      {(geometry.tag === "lineSegment" || geometry.tag === "centerLine") && (
        <>
          <NumericField
            label={appStrings.inspector.segmentLength}
            value={draft.lengthMm}
            onChange={(lengthMm) => setDraft({ ...draft, lengthMm })}
            onBlur={commit}
          />
          <button onClick={() => onConstrainSegmentLength?.(entityId)}>
            {appStrings.inspector.setCurrentLengthConstraint}
          </button>
        </>
      )}
      {geometry.tag === "circle" && (
        <NumericField
          label={appStrings.inspector.radius}
          value={draft.radiusMm}
          onChange={(radiusMm) => setDraft({ ...draft, radiusMm })}
          onBlur={commit}
        />
      )}
      {geometry.tag === "arc" && (
        <>
          <NumericField
            label={appStrings.inspector.radius}
            value={draft.radiusMm}
            onChange={(radiusMm) => setDraft({ ...draft, radiusMm })}
            onBlur={commit}
          />
          <NumericField
            label={appStrings.inspector.startAngle}
            value={draft.startDegrees}
            onChange={(startDegrees) => setDraft({ ...draft, startDegrees })}
            onBlur={commit}
          />
          <NumericField
            label={appStrings.inspector.sweepAngle}
            value={draft.sweepDegrees}
            onChange={(sweepDegrees) => setDraft({ ...draft, sweepDegrees })}
            onBlur={commit}
          />
        </>
      )}
    </div>
  );
}

type GeometryFieldDraft = {
  lengthMm?: string;
  radiusMm?: string;
  startDegrees?: string;
  sweepDegrees?: string;
};

export function geometryFields(geometry: NonNullable<ReturnType<typeof geometryOf>>): GeometryFieldDraft {
  if (geometry.tag === "lineSegment" || geometry.tag === "centerLine")
    return {
      lengthMm: String(Math.hypot(geometry.end.xMm - geometry.start.xMm, geometry.end.yMm - geometry.start.yMm)),
    };
  if (geometry.tag === "circle") return { radiusMm: String(geometry.radiusMm) };
  if (geometry.tag === "arc")
    return {
      radiusMm: String(geometry.radiusMm),
      startDegrees: String((geometry.startAngleRad * 180) / Math.PI),
      sweepDegrees: String((geometry.sweepAngleRad * 180) / Math.PI),
    };
  return {};
}

export function NumericField({
  label,
  value,
  onChange,
  onBlur,
}: {
  label: string;
  value?: string;
  onChange: (value: string) => void;
  onBlur: () => void;
}) {
  return (
    <label>
      {label}
      <input
        aria-label={label}
        type="number"
        step=".01"
        value={value ?? ""}
        onChange={(event) => onChange(event.target.value)}
        onBlur={onBlur}
      />
    </label>
  );
}
