import { describe, expect, it } from "vitest";
import { partDefaultName, partLibraryPlacement } from "@/features/parts/domain/partDefaults";

describe("part defaults", () => {
  it("uses the numbered name and matches Swift automatic placement", () => {
    expect(partDefaultName(3)).toBe("パーツ 3");
    expect(
      partLibraryPlacement(undefined, [
        { xMm: -10, yMm: 2 },
        { xMm: 20, yMm: 8 },
      ]),
    ).toEqual({ xMm: 50, yMm: 8 });
  });

  it("preserves an explicitly selected canvas position", () => {
    expect(partLibraryPlacement({ xMm: 12, yMm: -4 }, [{ xMm: 20, yMm: 8 }])).toEqual({ xMm: 12, yMm: -4 });
  });
});
