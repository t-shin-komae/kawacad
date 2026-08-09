import { useState } from "react";
import { parseDecimal } from "@/shared/state/syncedField";
import { appStrings } from "@/localization";

type Value = { fixedMm?: number; fixedDegrees?: number; parameter?: string };

type Props = {
  label: string;
  initialValue?: Record<string, number | string | undefined>;
  parameters: Array<{ id: string; name: string }>;
  degrees: boolean;
  floating?: boolean;
  floatingPosition?: { x: number; y: number };
  onConfirm: (value: Value) => void;
  onCancel: () => void;
};

/** SwiftUI-equivalent value entry keeps parameter references available at the
 * same moment a dimensional constraint is created. */
export function ConstraintValueDialog({
  label,
  initialValue,
  parameters,
  degrees,
  floating = false,
  floatingPosition,
  onConfirm,
  onCancel,
}: Props) {
  const initialFixed = degrees ? initialValue?.fixedDegrees : initialValue?.fixedMm;
  const initialParameter = typeof initialValue?.parameter === "string" ? initialValue.parameter : undefined;
  const [mode, setMode] = useState<"fixed" | "parameter">(initialParameter ? "parameter" : "fixed");
  const [draft, setDraft] = useState(String(typeof initialFixed === "number" ? initialFixed : 10));
  const [parameter, setParameter] = useState(initialParameter ?? parameters[0]?.id ?? "");
  const parsedValue = parseDecimal(draft);
  const numericValue = parsedValue.ok ? parsedValue.value : undefined;
  const canConfirm =
    mode === "parameter" ? Boolean(parameter) : Boolean(parsedValue.ok && (degrees || parsedValue.value > 0));
  const positionStyle =
    floating && floatingPosition
      ? {
          left: `${Math.max(16, Math.min(floatingPosition.x + 16, window.innerWidth - 296))}px`,
          top: `${Math.max(16, Math.min(floatingPosition.y + 16, window.innerHeight - 196))}px`,
          right: "auto",
          bottom: "auto",
        }
      : undefined;

  return (
    <div
      className={`constraint-value-backdrop${floating ? " floating-value-backdrop" : ""}`}
      role="presentation"
      style={positionStyle}
    >
      <section
        className="constraint-value-dialog"
        role="dialog"
        aria-modal="true"
        aria-label={appStrings.dialog.value.ariaLabel(label)}
      >
        <h2>{label}</h2>
        <div className="segmented-control" role="group" aria-label={appStrings.dialog.value.inputMethod}>
          <button type="button" aria-pressed={mode === "fixed"} onClick={() => setMode("fixed")}>
            {appStrings.dialog.value.fixed}
          </button>
          <button
            type="button"
            disabled={!parameters.length}
            aria-pressed={mode === "parameter"}
            onClick={() => setMode("parameter")}
          >
            {appStrings.dialog.value.parameter}
          </button>
        </div>
        {mode === "fixed" ? (
          <label>
            {degrees ? appStrings.dialog.value.degrees : appStrings.dialog.value.millimeters}
            <input
              aria-label={degrees ? appStrings.dialog.value.degrees : appStrings.dialog.value.millimeters}
              autoFocus
              inputMode="decimal"
              value={draft}
              onChange={(event) => setDraft(event.target.value)}
            />
          </label>
        ) : (
          <label>
            {appStrings.dialog.value.parameter}
            <select
              aria-label={appStrings.dialog.value.parameter}
              value={parameter}
              onChange={(event) => setParameter(event.target.value)}
            >
              {parameters.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.name}
                </option>
              ))}
            </select>
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
              onConfirm(
                mode === "parameter"
                  ? { parameter }
                  : degrees
                    ? { fixedDegrees: numericValue as number }
                    : { fixedMm: numericValue as number },
              )
            }
          >
            {appStrings.dialog.value.confirm}
          </button>
        </div>
      </section>
    </div>
  );
}
