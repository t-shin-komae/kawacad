import { describe, expect, it } from "vitest";
import { defaultSharedStyle, sharedStyleDefaultName } from "@/features/inspector/domain/sharedStyleDefaults";

describe("shared style defaults", () => {
  it("matches the Swift default name and style", () => {
    expect(sharedStyleDefaultName(3)).toBe("共有スタイル 3");
    expect(defaultSharedStyle).toEqual({
      stroke: { red: 17 / 255, green: 24 / 255, blue: 39 / 255, alpha: 1 },
      strokeWidthMm: 0.2,
      pattern: "solid",
    });
  });
});
