import { describe, expect, it } from "vitest";
import { normalizeProjectSavePath, projectFileExtension } from "@/features/document/domain/projectFilePath";

describe("project file path", () => {
  it("normalizes extensionless POSIX and Windows save paths to .kawa", () => {
    expect(projectFileExtension).toBe("kawa");
    expect(normalizeProjectSavePath("/projects/wallet")).toBe("/projects/wallet.kawa");
    expect(normalizeProjectSavePath("C:\\projects\\wallet")).toBe("C:\\projects\\wallet.kawa");
  });

  it("does not duplicate or replace an existing extension", () => {
    expect(normalizeProjectSavePath("/projects/wallet.kawa")).toBe("/projects/wallet.kawa");
    expect(normalizeProjectSavePath("/projects/wallet.json")).toBe("/projects/wallet.json");
  });
});
