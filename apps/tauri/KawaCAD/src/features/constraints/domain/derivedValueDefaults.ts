import type { Tool } from "@/features/canvas/domain/canvasDomainModels";

export function derivedValueInitialText(kind: Extract<Tool, "offset" | "fillet">): string {
  return kind === "offset" ? "3.00" : "5.00";
}
