import { describe, expect, it } from "vitest";
import { productInfo } from "@/app/productInfo";
import { aboutMetadataForPlatform, crossPlatformMenuActions } from "@/adapters/nativeMenuAdapter";

describe("cross-platform native menu", () => {
  it("keeps the desktop menu action set platform neutral", () => {
    expect(new Set(crossPlatformMenuActions).size).toBe(crossPlatformMenuActions.length);
    expect(crossPlatformMenuActions).toContain("new");
    expect(crossPlatformMenuActions).toContain("save");
    expect(crossPlatformMenuActions).toContain("line");
    expect(crossPlatformMenuActions).toContain("tangent");
    expect(crossPlatformMenuActions).toContain("outputPreview");
    expect(crossPlatformMenuActions).toContain("openLicenses");
    expect(crossPlatformMenuActions).toContain("exportPDF");
    expect(crossPlatformMenuActions).not.toContain("print");
  });

  it("uses the shared product metadata for the About item", () => {
    expect(productInfo.name).toBe("KawaCAD");
    expect(productInfo.displayVersion).toBe("0.2.0-dev");
    expect(productInfo.copyright).toBe("© 2026 t-shin-komae");
  });

  it("suppresses macOS's bundle build-version fallback", () => {
    expect(aboutMetadataForPlatform("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0)")).toMatchObject({
      version: "0.2.0-dev",
      shortVersion: "",
    });
    expect(aboutMetadataForPlatform("Mozilla/5.0 (X11; Linux x86_64)")).not.toHaveProperty("shortVersion");
  });
});
