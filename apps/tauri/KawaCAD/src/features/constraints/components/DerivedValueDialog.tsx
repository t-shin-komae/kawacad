import { useState } from "react";
import { parseDecimal } from "@/shared/state/syncedField";
import { appStrings } from "@/localization";

export type DerivedValue = { fixedMm: number } | { parameter: string };
export type OffsetSourceOption = {
  scope: "singleElement" | "selectedRange" | "closedContour";
  sourceEntityIds: string[];
  sourceResolvedEntityIds?: string[];
  direction: string;
};

type Props = {
  kind: "offset" | "fillet";
  offsetOptions?: OffsetSourceOption[];
  sourceCount?: number;
  parameters: Array<{ id: string; name: string; valueMm: number }>;
  floating?: boolean;
  valueText?: string;
  entryMode?: "fixed" | "parameter";
  parameterId?: string;
  onValueTextChange?: (value: string) => void;
  onEntryModeChange?: (mode: "fixed" | "parameter") => void;
  onParameterIdChange?: (id: string) => void;
  onConfirm: (value: DerivedValue, option?: OffsetSourceOption) => void;
  onCancel: () => void;
};

const scopeLabels = appStrings.dialog.derived.scopeNames;

export function DerivedValueDialog({
  kind,
  offsetOptions = [],
  sourceCount = 0,
  parameters,
  floating = false,
  valueText: controlledValueText,
  entryMode: controlledEntryMode,
  parameterId: controlledParameterId,
  onValueTextChange,
  onEntryModeChange,
  onParameterIdChange,
  onConfirm,
  onCancel,
}: Props) {
  const [localEntryMode, setLocalEntryMode] = useState<"fixed" | "parameter">("fixed");
  const [localValueText, setLocalValueText] = useState(kind === "offset" ? "3" : "2");
  const [localParameterId, setLocalParameterId] = useState(parameters[0]?.id ?? "");
  const [scope, setScope] = useState(offsetOptions[0]?.scope ?? "singleElement");
  const entryMode = controlledEntryMode ?? localEntryMode;
  const valueText = controlledValueText ?? localValueText;
  const parameterId = controlledParameterId ?? localParameterId;
  const setEntryMode = onEntryModeChange ?? setLocalEntryMode;
  const setValueText = onValueTextChange ?? setLocalValueText;
  const setParameterId = onParameterIdChange ?? setLocalParameterId;
  const option = offsetOptions.find((item) => item.scope === scope) ?? offsetOptions[0];
  const parsedValue = parseDecimal(valueText);
  const value = parsedValue.ok ? parsedValue.value : undefined;
  const canConfirm =
    entryMode === "parameter" ? Boolean(parameterId) : Boolean(parsedValue.ok && parsedValue.value > 0);

  return (
    <div className={`constraint-value-backdrop${floating ? " derived-value-floating" : ""}`} role="presentation">
      <section
        className="constraint-value-dialog"
        role="dialog"
        aria-modal="true"
        aria-label={appStrings.dialog.value.ariaLabel(appStrings.dialog.derived.value(kind))}
      >
        <h2>{appStrings.dialog.derived.value(kind)}</h2>
        {kind === "fillet" && <p>{appStrings.dialog.derived.filletDescription(sourceCount)}</p>}
        {kind === "offset" && offsetOptions.length > 1 && (
          <label>
            {appStrings.dialog.derived.offsetSource}
            <select value={scope} onChange={(event) => setScope(event.target.value as keyof typeof scopeLabels)}>
              {offsetOptions.map((item) => (
                <option key={item.scope} value={item.scope}>
                  {scopeLabels[item.scope]}
                </option>
              ))}
            </select>
          </label>
        )}
        {kind === "offset" && offsetOptions.length === 1 && option?.scope === "selectedRange" && (
          <p>{appStrings.dialog.derived.selectedRange(option.sourceEntityIds.length)}</p>
        )}
        {parameters.length > 0 && (
          <fieldset>
            <legend>{appStrings.dialog.derived.inputMethod}</legend>
            <label>
              <input type="radio" checked={entryMode === "fixed"} onChange={() => setEntryMode("fixed")} />
              {appStrings.dialog.value.fixed}
            </label>
            <label>
              <input type="radio" checked={entryMode === "parameter"} onChange={() => setEntryMode("parameter")} />
              {appStrings.dialog.derived.parameterReference}
            </label>
          </fieldset>
        )}
        {entryMode === "parameter" && parameters.length > 0 ? (
          <label>
            {appStrings.dialog.value.parameter}
            <select value={parameterId} onChange={(event) => setParameterId(event.target.value)}>
              {parameters.map((parameter) => (
                <option key={parameter.id} value={parameter.id}>
                  {appStrings.dialog.derived.parameterValue(parameter.name, parameter.valueMm)}
                </option>
              ))}
            </select>
          </label>
        ) : (
          <label>
            {appStrings.dialog.derived.millimeters}
            <input
              aria-label={appStrings.dialog.derived.millimeters}
              value={valueText}
              onChange={(event) => setValueText(event.target.value)}
              autoFocus
            />
          </label>
        )}
        <div className="button-row">
          <button type="button" onClick={onCancel}>
            {appStrings.dialog.value.cancel}
          </button>
          <button
            type="button"
            disabled={!canConfirm}
            onClick={() =>
              onConfirm(entryMode === "parameter" ? { parameter: parameterId } : { fixedMm: value as number }, option)
            }
          >
            {appStrings.dialog.derived.apply}
          </button>
        </div>
      </section>
    </div>
  );
}
