import { describe, expect, it } from "vitest";
import {
  acceptLatestSyncedField,
  commitSyncedField,
  editSyncedField,
  hexColor,
  parseDecimal,
  positiveNumber,
  syncSyncedField,
  syncedField,
} from "@/shared/state/syncedField";

describe("Synced text field parity", () => {
  it("reflects external values immediately while clean", () => {
    expect(syncSyncedField(syncedField("10.00"), "14.00", false)).toMatchObject({
      draftValue: "14.00",
      phase: "clean",
    });
  });
  it("adopts a canonical value after a successful commit", () => {
    const result = commitSyncedField(editSyncedField(syncedField("1.00"), "2.500"), (value) => {
      expect(value).toBe("2.500");
      return { ok: true, canonicalValue: "2.5" };
    });
    expect(result).toMatchObject({ didCommit: true, state: { draftValue: "2.5", phase: "clean" } });
  });
  it("retains invalid drafts and an error message after a failed commit", () => {
    const result = commitSyncedField(editSyncedField(syncedField("#111111"), "#22"), () => ({
      ok: false as const,
      message: { kind: "domain" as const, text: "#RRGGBB形式で入力してください" },
    }));
    expect(result).toMatchObject({ didCommit: false, state: { draftValue: "#22", phase: "invalid" } });
  });
  it("records a conflict when the source changes during editing", () => {
    const state = syncSyncedField(editSyncedField(syncedField("10.00"), "12.00"), "14.00", true);
    expect(state).toMatchObject({ phase: "conflict", draftValue: "12.00", latestSourceValue: "14.00" });
  });
  it("resolves a conflict by accepting the latest source value", () => {
    const conflict = syncSyncedField(editSyncedField(syncedField("10.00"), "12.00"), "14.00", true);
    expect(acceptLatestSyncedField(conflict)).toMatchObject({
      phase: "clean",
      draftValue: "14.00",
    });
  });
  it("accepts locale and ASCII decimal separators", () => {
    expect(parseDecimal("12,5", ",")).toMatchObject({ ok: true, value: 12.5 });
    expect(parseDecimal("12.5", ",")).toMatchObject({ ok: true, value: 12.5 });
  });
  it("rejects exponent notation and ambiguous separators", () => {
    expect(parseDecimal("1e3")).toMatchObject({ ok: false, message: { text: "指数表記は使用できません" } });
    expect(parseDecimal("1,2.3")).toMatchObject({ ok: false, message: { text: "小数点の書式が曖昧です" } });
  });
  it("canonicalizes positive numbers and hex colors", () => {
    expect(positiveNumber("１２.５")).toEqual({ ok: true, canonicalValue: "12.5" });
    expect(positiveNumber("0.004")).toEqual({ ok: true, canonicalValue: "0.004" });
    expect(hexColor("aabbcc")).toEqual({ ok: true, canonicalValue: "#AABBCC" });
  });
});
