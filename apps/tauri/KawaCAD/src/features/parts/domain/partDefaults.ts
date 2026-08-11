export function partDefaultName(index: number): string {
  return `パーツ ${index}`;
}

export function partLibraryPlacement(
  cursorPoint: { xMm: number; yMm: number } | undefined,
  existingOrigins: Array<{ xMm: number; yMm: number }>,
): { xMm: number; yMm: number } {
  if (cursorPoint) return cursorPoint;
  return {
    xMm: (existingOrigins.map((origin) => origin.xMm).reduce((max, value) => Math.max(max, value), -30) ?? -30) + 30,
    yMm: existingOrigins.map((origin) => origin.yMm).reduce((max, value) => Math.max(max, value), 0),
  };
}
