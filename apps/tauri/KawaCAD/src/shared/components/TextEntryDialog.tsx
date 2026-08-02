import { useState } from "react";
import { appStrings } from "@/localization";

export type TextEntryField = {
  id: string;
  label: string;
  initialValue: string;
  inputMode?: "decimal" | "numeric" | "text";
};

type Props = {
  title: string;
  fields: TextEntryField[];
  onConfirm: (values: Record<string, string>) => void;
  onCancel: () => void;
};

export function TextEntryDialog({ title, fields, onConfirm, onCancel }: Props) {
  const [values, setValues] = useState(() => Object.fromEntries(fields.map((field) => [field.id, field.initialValue])));
  const firstField = fields[0];
  return (
    <div className="constraint-value-backdrop" role="presentation">
      <section className="constraint-value-dialog" role="dialog" aria-modal="true" aria-label={title}>
        <h2>{title}</h2>
        {fields.map((field, index) => (
          <label key={field.id}>
            {field.label}
            <input
              aria-label={field.label}
              autoFocus={field.id === firstField?.id}
              inputMode={field.inputMode ?? "text"}
              value={values[field.id] ?? ""}
              onChange={(event) => setValues((current) => ({ ...current, [field.id]: event.target.value }))}
            />
          </label>
        ))}
        <div className="button-row">
          <button type="button" onClick={onCancel}>
            {appStrings.dialog.textEntry.cancel}
          </button>
          <button type="button" onClick={() => onConfirm(values)}>
            {appStrings.dialog.textEntry.apply}
          </button>
        </div>
      </section>
    </div>
  );
}
