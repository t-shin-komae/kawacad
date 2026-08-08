import { describe, expect, it } from "vitest";
import { productInfo } from "@/app/productInfo";
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

  it("uses the shared product metadata for the About item", () => {
    expect(productInfo.name).toBe("KawaCAD");
    expect(productInfo.displayVersion).toBe("0.1.0-dev");
    expect(productInfo.copyright).toBe("© 2026 t-shin-komae");
  });
});
