import { describe, expect, it } from "vitest";
import { formatInspectorNumber, resolveInspectorValue } from "@/features/inspector/domain/inspectorValueFormatting";

describe("inspector value formatting", () => {
  it("formats finite values and resolves parameter references", () => {
    const parameters = [{ id: "parameter:length", valueMm: 12.345 }];
    expect(formatInspectorNumber(12)).toBe("12.00");
    expect(resolveInspectorValue({ parameter: "parameter:length" }, parameters)).toBe(12.345);
    expect(formatInspectorNumber(resolveInspectorValue({ parameter: "missing" }, parameters))).toBe("");
  });
});
