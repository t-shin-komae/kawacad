import { describe, expect, it } from "vitest";
import { crossPlatformMenuActions } from "@/adapters/nativeMenuAdapter";

describe("cross-platform native menu", () => {
  it("keeps the desktop menu action set platform neutral", () => {
    expect(new Set(crossPlatformMenuActions).size).toBe(crossPlatformMenuActions.length);
    expect(crossPlatformMenuActions).toContain("new");
    expect(crossPlatformMenuActions).toContain("save");
    expect(crossPlatformMenuActions).toContain("line");
    expect(crossPlatformMenuActions).toContain("tangent");
    expect(crossPlatformMenuActions).toContain("outputPreview");
    expect(crossPlatformMenuActions).not.toContain("exportPDF");
    expect(crossPlatformMenuActions).not.toContain("print");
  });
});
