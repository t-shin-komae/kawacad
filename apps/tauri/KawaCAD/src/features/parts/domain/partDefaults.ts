import { appStrings } from "@/localization";

export function partDefaultName(index: number): string {
  return `${appStrings.inspector.parts} ${index}`;
}

export function partLibraryPlacement(
  cursorPoint: { xMm: number; yMm: number } | undefined,
  existingOrigins: Array<{ xMm: number; yMm: number }>,
): { xMm: number; yMm: number } {
  if (cursorPoint) return cursorPoint;
  const maxY = existingOrigins.reduce((max, origin) => Math.max(max, origin.yMm), -Infinity);
  return {
    xMm: (existingOrigins.map((origin) => origin.xMm).reduce((max, value) => Math.max(max, value), -30) ?? -30) + 30,
    yMm: Number.isFinite(maxY) ? Math.max(maxY, 0) : 0,
  };
}
