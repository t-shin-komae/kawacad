import { describe, expect, it } from "vitest";
import { accessibilityIdentifiers } from "@/shared/accessibility/accessibilityIdentifiers";

describe("accessibilityIdentifiers", () => {
  it("keeps UI automation identifiers unique and namespaced", () => {
    const identifiers = Object.values(accessibilityIdentifiers);

    expect(new Set(identifiers).size).toBe(identifiers.length);
    identifiers.forEach((identifier) => expect(identifier).toMatch(/^leather\./));
  });

  it("matches the cross-platform workspace identifiers", () => {
    expect(accessibilityIdentifiers.workspaceCanvas).toBe("leather.workspace.canvas");
    expect(accessibilityIdentifiers.workspaceStatusBar).toBe("leather.workspace.status-bar");
  });
});
