import { describe, expect, it } from "vitest";
import { constrainedWindowWidth, makeWindowLayout, windowLayout } from "@/features/workspace/selectors/layout";

describe("Window layout policy parity", () => {
  it("resolves modes from workspace width with hysteresis", () => {
    const offset = 176 + windowLayout.panelResizeHandleWidth;
    expect(makeWindowLayout(windowLayout.regularMinimumWorkspaceWidth + offset - 1, 176, 440).mode).toBe("compact");
    expect(
      makeWindowLayout(
        windowLayout.regularMinimumWorkspaceWidth + offset + windowLayout.hysteresis,
        176,
        440,
        "compact",
      ).mode,
    ).toBe("regular");
    const wide =
      windowLayout.canvasMinimumWidth + windowLayout.panelResizeHandleWidth + windowLayout.minimumInspectorContentWidth;
    expect(makeWindowLayout(wide + offset, 176, 440).mode).toBe("wide");
    expect(makeWindowLayout(wide + offset - 1, 176, 440, "wide").mode).toBe("regular");
  });
  it("clamps stored panel widths by layout mode", () => {
    const wide = makeWindowLayout(1800, 500, 100);
    expect(wide.toolDockWidth).toBe(260);
    expect(wide.inspectorDockWidth).toBe(windowLayout.minimumInspectorContentWidth);
    const regular = makeWindowLayout(1200, 176, 480);
    expect(regular.mode).toBe("regular");
    expect(regular.overlayInspectorWidth).toBeGreaterThanOrEqual(windowLayout.minimumInspectorContentWidth);
    const compact = makeWindowLayout(1024, 176, 368);
    expect(compact).toMatchObject({
      mode: "compact",
      toolDockVisible: false,
      compactToolDrawerWidth: 260,
      compactInspectorDrawerWidth: 440,
    });
  });
  it("omits the docked tool palette while preserving the workspace width", () => {
    const hidden = makeWindowLayout(1600, 176, 440, undefined, false);
    expect(hidden.toolDockVisible).toBe(false);
    expect(hidden.workspaceWidth).toBe(1600);
    expect(hidden.mode).toBe("wide");
  });
  it("constrains a requested window to the visible screen", () => {
    expect(constrainedWindowWidth(1280, 1352)).toBe(1280);
    expect(constrainedWindowWidth(1520, 1352)).toBe(1352);
  });
  it("keeps the wide layout reachable at the 1352pt screen width", () => {
    expect(makeWindowLayout(1352, 176, 440).mode).toBe("wide");
  });
  it("keeps a reachable canvas and inspector across repeated resize widths", () => {
    let previous: "compact" | "regular" | "wide" | undefined;
    [900, 1024, 1060, 1220, 1400, 1600, 1020].forEach((requested) => {
      const contentWidth = constrainedWindowWidth(requested, 1600);
      const policy = makeWindowLayout(contentWidth, 220, 300, previous);
      expect(policy.workspaceWidth).toBeGreaterThan(0);
      expect(policy.workspaceWidth).toBeLessThanOrEqual(contentWidth);
      if (policy.mode === "wide") {
        expect(
          policy.workspaceWidth - windowLayout.panelResizeHandleWidth - policy.inspectorDockWidth,
        ).toBeGreaterThanOrEqual(windowLayout.canvasMinimumWidth);
      } else if (policy.mode === "regular")
        expect(policy.overlayInspectorWidth).toBeLessThanOrEqual(policy.workspaceWidth);
      else expect(policy.compactInspectorDrawerWidth).toBeLessThanOrEqual(policy.workspaceWidth);
      previous = policy.mode;
    });
  });
  it("keeps inspector content wide enough in every mode", () => {
    [1600, 1300, 1024].forEach((width) => {
      const policy = makeWindowLayout(width, 176, 300);
      const inspectorWidth =
        policy.mode === "wide"
          ? policy.inspectorDockWidth
          : policy.mode === "regular"
            ? policy.overlayInspectorWidth
            : policy.compactInspectorDrawerWidth;
      expect(inspectorWidth).toBeGreaterThanOrEqual(windowLayout.minimumInspectorContentWidth);
    });
  });
});
