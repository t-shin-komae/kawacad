import { beforeEach, describe, expect, it } from "vitest";
import { workspacePreferencesAdapter } from "@/adapters/workspacePreferencesAdapter";

describe("workspace tool palette visibility", () => {
  beforeEach(() => window.localStorage.clear());

  it("defaults to visible and persists a hidden palette", () => {
    expect(workspacePreferencesAdapter.loadToolPaletteVisible()).toBe(true);

    workspacePreferencesAdapter.saveToolPaletteVisible(false);

    expect(workspacePreferencesAdapter.loadToolPaletteVisible()).toBe(false);
    expect(window.localStorage.getItem("leather.layout.toolPaletteVisible")).toBe("false");
  });

  it("removes the preference when the palette is visible or reset", () => {
    workspacePreferencesAdapter.saveToolPaletteVisible(false);
    workspacePreferencesAdapter.saveToolPaletteVisible(true);
    expect(window.localStorage.getItem("leather.layout.toolPaletteVisible")).toBeNull();

    workspacePreferencesAdapter.saveToolPaletteVisible(false);
    workspacePreferencesAdapter.resetWorkspacePreferences();
    expect(workspacePreferencesAdapter.loadToolPaletteVisible()).toBe(true);
  });
});
