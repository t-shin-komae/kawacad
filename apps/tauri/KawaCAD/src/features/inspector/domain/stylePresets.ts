export type LayerColorPreset = {
  displayName: string;
  colorHex: string;
};

export type LayerStrokeWidthPreset = {
  displayName: string;
  widthMm: number;
};

import { appStrings } from "@/localization";

export const layerColorPresets: readonly LayerColorPreset[] = [
  { displayName: appStrings.styles.black, colorHex: "#121826" },
  { displayName: appStrings.styles.gray, colorHex: "#6B7280" },
  { displayName: appStrings.styles.red, colorHex: "#DC2626" },
  { displayName: appStrings.styles.blue, colorHex: "#2563EB" },
  { displayName: appStrings.styles.green, colorHex: "#16A34A" },
  { displayName: appStrings.styles.orange, colorHex: "#EA580C" },
  { displayName: appStrings.styles.purple, colorHex: "#9333EA" },
];

export const layerStrokeWidthPresets: readonly LayerStrokeWidthPreset[] = [0.13, 0.18, 0.25, 0.35, 0.5, 0.7].map(
  (widthMm) => ({ displayName: `${widthMm.toFixed(2)} mm`, widthMm }),
);

export function matchingLayerColorPreset(colorHex: string): LayerColorPreset | undefined {
  return layerColorPresets.find((preset) => preset.colorHex.toUpperCase() === colorHex.toUpperCase());
}

export function matchingLayerStrokeWidthPreset(widthMm: number): LayerStrokeWidthPreset | undefined {
  return layerStrokeWidthPresets.find((preset) => preset.widthMm === widthMm);
}
