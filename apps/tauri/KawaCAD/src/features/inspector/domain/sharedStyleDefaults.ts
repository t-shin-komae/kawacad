import { appStrings } from "@/localization";
import type { LineStyle } from "@/shared/domain/coreWireTypes";

export const defaultSharedStyle: LineStyle = {
  stroke: { red: 17 / 255, green: 24 / 255, blue: 39 / 255, alpha: 1 },
  strokeWidthMm: 0.2,
  pattern: "solid",
};

export function sharedStyleDefaultName(index: number): string {
  return `${appStrings.inspector.sharedStyles} ${index}`;
}
