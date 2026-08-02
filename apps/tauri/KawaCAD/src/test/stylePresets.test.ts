import { describe, expect, it } from "vitest";
import {
  layerColorPresets,
  layerStrokeWidthPresets,
  matchingLayerColorPreset,
  matchingLayerStrokeWidthPreset,
} from "@/features/inspector/domain/stylePresets";

describe("layer style presets", () => {
  it("provides the SwiftUI representative colors and custom fallback", () => {
    expect(layerColorPresets.map((preset) => preset.displayName)).toEqual([
      "黒",
      "グレー",
      "赤",
      "青",
      "緑",
      "オレンジ",
      "紫",
    ]);
    expect(layerColorPresets.every((preset) => /^#[0-9A-F]{6}$/i.test(preset.colorHex))).toBe(true);
    expect(matchingLayerColorPreset("#2563EB")?.displayName).toBe("青");
    expect(matchingLayerColorPreset("#123456")).toBeUndefined();
  });

  it("provides the SwiftUI drafting widths and custom fallback", () => {
    expect(layerStrokeWidthPresets.map((preset) => preset.widthMm)).toEqual([0.13, 0.18, 0.25, 0.35, 0.5, 0.7]);
    expect(matchingLayerStrokeWidthPreset(0.35)?.displayName).toBe("0.35 mm");
    expect(matchingLayerStrokeWidthPreset(0.45)).toBeUndefined();
  });
});
