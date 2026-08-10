import { describe, expect, it } from "vitest";
import { productInfo } from "@/app/productInfo";
import { aboutMetadataForPlatform, crossPlatformMenuActions } from "@/adapters/nativeMenuAdapter";
import { nativeMenuAvailability } from "@/app/domain/nativeMenuState";

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

  it("does not expose a tool palette toggle in the native menu", () => {
    expect(crossPlatformMenuActions as readonly string[]).not.toContain("toggleTools");
  });

  it("uses the shared product metadata for the About item", () => {
    expect(productInfo.name).toBe("KawaCAD");
    expect(productInfo.displayVersion).toBe("0.3.0-dev");
    expect(productInfo.copyright).toBe("© 2026 t-shin-komae");
  });

  it("suppresses macOS's bundle build-version fallback", () => {
    expect(aboutMetadataForPlatform("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0)")).toMatchObject({
      version: "0.3.0-dev",
      shortVersion: "",
    });
    expect(aboutMetadataForPlatform("Mozilla/5.0 (X11; Linux x86_64)")).not.toHaveProperty("shortVersion");
  });

  it("tracks document, selection, view, and panel state for native menu availability", () => {
    expect(
      nativeMenuAvailability({
        hasDocument: true,
        viewMode: "editDisplay",
        canUndo: true,
        canRedo: false,
        hasSelection: true,
        canPaste: true,
        canEditLayers: true,
        canExportPDF: true,
        canDirectPrint: true,
        canSmoothArcTangencies: true,
        inspectorOpen: true,
        bottomWorkbenchVisible: false,
      }),
    ).toMatchObject({
      save: true,
      undo: true,
      duplicate: true,
      paste: true,
      directPrint: true,
      inspectorLabel: "インスペクタを隠す",
      bottomWorkbenchLabel: "サマリーを表示",
    });
    expect(
      nativeMenuAvailability({
        hasDocument: true,
        viewMode: "outputPreview",
        canUndo: true,
        canRedo: true,
        hasSelection: true,
        canPaste: true,
        canEditLayers: true,
        canExportPDF: true,
        canDirectPrint: true,
        canSmoothArcTangencies: true,
        inspectorOpen: false,
        bottomWorkbenchVisible: true,
      }),
    ).toMatchObject({
      exportPDF: true,
      directPrint: true,
      undo: true,
      duplicate: false,
      delete: false,
      paste: false,
      addLayer: false,
      inspectorLabel: "インスペクタを表示",
      bottomWorkbenchLabel: "サマリーを隠す",
    });
  });
});
