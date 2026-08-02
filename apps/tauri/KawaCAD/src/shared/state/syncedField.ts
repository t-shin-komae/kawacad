export type SyncedFieldPhase = "clean" | "editing" | "invalid" | "committing" | "conflict";
export type SyncedFieldMessage = { kind: "syntax" | "domain" | "conflict"; text: string };
export type SyncedFieldState = {
  sourceValue: string;
  draftValue: string;
  phase: SyncedFieldPhase;
  message?: SyncedFieldMessage;
  latestSourceValue?: string;
};
export type SyncedFieldCommitResult =
  { ok: true; canonicalValue?: string } | { ok: false; message: SyncedFieldMessage };

export function syncedField(sourceValue: string): SyncedFieldState {
  return { sourceValue, draftValue: sourceValue, phase: "clean" };
}
export function editSyncedField(state: SyncedFieldState, draftValue: string): SyncedFieldState {
  return {
    ...state,
    draftValue,
    phase: state.phase === "committing" ? "committing" : "editing",
    message: undefined,
    latestSourceValue: undefined,
  };
}
export function validateSyncedField(state: SyncedFieldState, message?: SyncedFieldMessage): SyncedFieldState {
  if (state.phase !== "editing" && state.phase !== "invalid") return state;
  return { ...state, phase: message ? "invalid" : "editing", message };
}
export function syncSyncedField(state: SyncedFieldState, sourceValue: string, whileFocused: boolean): SyncedFieldState {
  if (!whileFocused || state.phase === "clean" || state.draftValue === sourceValue) return syncedField(sourceValue);
  return {
    ...state,
    sourceValue,
    phase: "conflict",
    latestSourceValue: sourceValue,
    message: { kind: "conflict", text: appStrings.validation.externalUpdate },
  };
}
export function commitSyncedField(
  state: SyncedFieldState,
  perform: (value: string) => SyncedFieldCommitResult,
): { state: SyncedFieldState; didCommit: boolean } {
  const result = perform(state.draftValue);
  if (result.ok) {
    const accepted = result.canonicalValue ?? state.draftValue;
    return { state: syncedField(accepted), didCommit: true };
  }
  return {
    state: { ...state, phase: result.message.kind === "conflict" ? "conflict" : "invalid", message: result.message },
    didCommit: false,
  };
}
export function acceptLatestSyncedField(state: SyncedFieldState): SyncedFieldState {
  return syncedField(state.latestSourceValue ?? state.sourceValue);
}
export function revertSyncedField(state: SyncedFieldState): SyncedFieldState {
  return syncedField(state.latestSourceValue ?? state.sourceValue);
}

export function parseDecimal(
  value: string,
  decimalSeparator = ".",
): { ok: true; value: number } | { ok: false; message: SyncedFieldMessage } {
  const normalized = value
    .replace(/[０-９]/g, (character) => String.fromCharCode(character.charCodeAt(0) - 0xfee0))
    .replace(/－/g, "-")
    .replace(/．/g, decimalSeparator)
    .trim();
  if (/[eE]/.test(normalized))
    return { ok: false, message: { kind: "syntax", text: appStrings.validation.exponentNotAllowed } };
  const alternate = decimalSeparator === "." ? "," : ".";
  if (normalized.includes(decimalSeparator) && normalized.includes(alternate))
    return { ok: false, message: { kind: "syntax", text: appStrings.validation.ambiguousDecimal } };
  if (!normalized || normalized === "-" || normalized === decimalSeparator || normalized === `-${decimalSeparator}`)
    return { ok: false, message: { kind: "syntax", text: appStrings.validation.numberRequired } };
  const number = Number(normalized.replace(decimalSeparator, ".").replace(alternate, "."));
  return Number.isFinite(number)
    ? { ok: true, value: number }
    : { ok: false, message: { kind: "syntax", text: appStrings.validation.invalidNumber } };
}
export function positiveNumber(value: string, maximumFractionDigits = 2): SyncedFieldCommitResult {
  const parsed = parseDecimal(value);
  if (!parsed.ok) return { ok: false, message: parsed.message };
  if (parsed.value <= 0)
    return { ok: false, message: { kind: "domain", text: appStrings.validation.positiveNumberRequired } };
  const formatted = parsed.value.toFixed(maximumFractionDigits).replace(/\.?0+$/, "");
  return { ok: true, canonicalValue: Number(formatted) === parsed.value ? formatted : String(parsed.value) };
}
export function hexColor(value: string): SyncedFieldCommitResult {
  const canonical = (value.trim().startsWith("#") ? value.trim() : `#${value.trim()}`).toUpperCase();
  return /^#[0-9A-F]{6}$/.test(canonical)
    ? { ok: true, canonicalValue: canonical }
    : { ok: false, message: { kind: "domain", text: appStrings.validation.hexColorRequired } };
}
import { appStrings } from "@/localization";
