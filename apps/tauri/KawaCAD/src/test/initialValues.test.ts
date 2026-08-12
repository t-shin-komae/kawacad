import { describe, expect, it } from "vitest";
import { derivedValueInitialText } from "@/features/constraints/domain/derivedValueDefaults";

describe("cross-platform initial values", () => {
  it("keeps derived element entry defaults stable", () => {
    expect(derivedValueInitialText("offset")).toBe("3.00");
    expect(derivedValueInitialText("fillet")).toBe("5.00");
  });
});
