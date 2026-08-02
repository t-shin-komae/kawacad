import { act, renderHook } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { useAppErrorPresentation } from "@/features/workspace/state/useAppErrorPresentation";

describe("useAppErrorPresentation", () => {
  it("owns structured errors independently from the CAD session", () => {
    const { result } = renderHook(() => useAppErrorPresentation());

    act(() => result.current.presentOperationFailure("保存できません", "saveDocument"));

    expect(result.current.errorPresentation).toMatchObject({
      message: "保存できません",
      identity: {
        category: "operationFailure",
        operation: "saveDocument",
      },
      occurrenceCount: 1,
    });
  });

  it("dismisses the current presentation", () => {
    const { result } = renderHook(() => useAppErrorPresentation());

    act(() => result.current.presentOperationFailure("保存できません", "saveDocument"));
    act(() => result.current.dismissPresentedError());

    expect(result.current.errorPresentation).toBeUndefined();
  });
});
