import { describe, expect, it } from "vitest";
import {
  appErrorCategoryTitle,
  makeAppErrorPresentation,
  mergeAppErrorPresentation,
} from "@/features/workspace/selectors/appErrorPresentation";

describe("AppErrorPresentation", () => {
  it("preserves structured Core failure identity", () => {
    const presentation = makeAppErrorPresentation(
      {
        code: "invalidTargets",
        message: "対象を選択してください",
        details: {
          commandKind: "addConstraint",
          constraintKind: "parallel",
          targetIds: ["entity:2", "entity:1"],
        },
      },
      { operation: "applyCommand" },
    );

    expect(presentation.identity).toEqual({
      category: "operationFailure",
      code: "invalidTargets",
      operation: "applyCommand",
      commandKind: "addConstraint",
      constraintKind: "parallel",
      targetIds: ["entity:1", "entity:2"],
    });
    expect(presentation.message).toBe("対象を選択してください");
  });

  it("accepts JSON encoded Tauri errors", () => {
    const presentation = makeAppErrorPresentation(
      JSON.stringify({ code: "transportError", message: "接続できません" }),
      { operation: "connectCore" },
    );

    expect(presentation.identity.code).toBe("transportError");
    expect(presentation.message).toBe("接続できません");
  });

  it("counts repeated errors with the same identity", () => {
    const first = makeAppErrorPresentation("失敗", { operation: "save" });
    const second = makeAppErrorPresentation("再び失敗", { operation: "save" });

    expect(mergeAppErrorPresentation(first, second).occurrenceCount).toBe(2);
  });

  it("replaces errors with a different identity", () => {
    const first = makeAppErrorPresentation("失敗", { operation: "save" });
    const second = makeAppErrorPresentation("失敗", { operation: "open" });

    expect(mergeAppErrorPresentation(first, second).occurrenceCount).toBe(1);
  });

  it("uses the centralized category title", () => {
    expect(appErrorCategoryTitle("systemInternal")).toBe("アプリ内部で問題が発生しました");
  });
});
