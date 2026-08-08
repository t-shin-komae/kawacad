import { forwardRef, useCallback, useEffect, useImperativeHandle, useRef, useState } from "react";
import {
  acceptLatestSyncedField,
  commitSyncedField,
  editSyncedField,
  revertSyncedField,
  syncSyncedField,
  syncedField,
} from "@/shared/state/syncedField";
import { appStrings } from "@/localization";

type Props = {
  documentName: string;
  paperLabel: string;
  onRename: (name: string) => void | Promise<boolean | void>;
};
export type DocumentHeaderHandle = { commit: () => Promise<boolean>; validate: () => boolean };

/** Mirrors the SwiftUI DocumentHeader: a plain editable project name and file metadata. */
export const DocumentHeader = forwardRef<DocumentHeaderHandle, Props>(function DocumentHeader(
  { documentName, paperLabel, onRename },
  ref,
) {
  const [field, setField] = useState(() => syncedField(documentName));
  const focused = useRef(false);
  useEffect(() => {
    setField((current) => syncSyncedField(current, documentName, focused.current));
  }, [documentName]);
  const commit = useCallback(async () => {
    const result = commitSyncedField(field, (value) => {
      const name = value.trim();
      return name
        ? { ok: true as const, canonicalValue: name }
        : { ok: false as const, message: { kind: "domain" as const, text: appStrings.header.projectNameRequired } };
    });
    setField(result.state);
    if (!result.didCommit) return false;
    if (result.state.sourceValue === documentName) return true;
    return (await onRename(result.state.sourceValue)) !== false;
  }, [documentName, field, onRename]);
  const validate = useCallback(() => {
    if (field.phase === "conflict") return false;
    const result = commitSyncedField(field, (value) => {
      const name = value.trim();
      return name
        ? { ok: true as const, canonicalValue: name }
        : { ok: false as const, message: { kind: "domain" as const, text: appStrings.header.projectNameRequired } };
    });
    if (result.didCommit) return true;
    setField(result.state);
    return false;
  }, [field]);
  useImperativeHandle(ref, () => ({ commit, validate }), [commit, validate]);
  return (
    <header className="document-header">
      <div className="document-name-field">
        <input
          className="document-name"
          aria-label={appStrings.header.projectName}
          aria-invalid={field.phase === "invalid" || field.phase === "conflict"}
          value={field.draftValue}
          onFocus={() => {
            focused.current = true;
          }}
          onChange={(event) => setField((current) => editSyncedField(current, event.target.value))}
          onBlur={() => {
            focused.current = false;
            if (field.phase !== "conflict") void commit();
          }}
          onKeyDown={(event) => {
            if (event.key === "Enter") event.currentTarget.blur();
            if (event.key === "Escape") {
              setField((current) => revertSyncedField(current));
              event.currentTarget.blur();
            }
          }}
        />
        {field.message && <span className="field-message">{field.message.text}</span>}
        {field.phase === "conflict" && (
          <span className="field-conflict-actions">
            <button
              type="button"
              onMouseDown={(event) => event.preventDefault()}
              onClick={() => setField(acceptLatestSyncedField)}
            >
              {appStrings.header.useLatestValue}
            </button>
            <button type="button" onMouseDown={(event) => event.preventDefault()} onClick={() => void commit()}>
              {appStrings.header.applyInput}
            </button>
          </span>
        )}
      </div>
      <span className="document-file-info">.kawa 0.1.0 / mm / {paperLabel}</span>
    </header>
  );
});
