import { describe, expect, it } from "vitest";
import { canvasCursorClass } from "@/features/canvas/selectors/canvasCursor";

const base = {
  outputPreview: false,
  hasTarget: false,
  editingFreeText: false,
  settingPartOrigin: false,
  movingContent: false,
};

describe("canvasCursorClass", () => {
  it("uses an arrow for selection and an open hand over an entity", () => {
    expect(canvasCursorClass({ ...base, tool: "select" })).toBe("canvas-cursor-arrow");
    expect(canvasCursorClass({ ...base, tool: "select", hasTarget: true })).toBe("canvas-cursor-open-hand");
  });

  it("distinguishes placement, text editing, and dragging", () => {
    expect(canvasCursorClass({ ...base, tool: "line" })).toBe("canvas-cursor-crosshair");
    expect(canvasCursorClass({ ...base, tool: "freeText" })).toBe("canvas-cursor-crosshair");
    expect(canvasCursorClass({ ...base, tool: "select", editingFreeText: true })).toBe("canvas-cursor-ibeam");
    expect(canvasCursorClass({ ...base, tool: "select", movingContent: true })).toBe("canvas-cursor-closed-hand");
  });

  it("shows target availability for constraint and measurement tools", () => {
    expect(canvasCursorClass({ ...base, tool: "distance" })).toBe("canvas-cursor-operation-not-allowed");
    expect(canvasCursorClass({ ...base, tool: "distance", hasTarget: true })).toBe("canvas-cursor-pointing-hand");
  });

  it("does not advertise editing in output preview", () => {
    expect(canvasCursorClass({ ...base, tool: "line", outputPreview: true })).toBe("canvas-cursor-arrow");
  });
});
