import { act, renderHook } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { useAnnotationSelection } from "@/features/canvas/state/useAnnotationSelection";

describe("useAnnotationSelection", () => {
  it("keeps annotation selections mutually exclusive", () => {
    const { result } = renderHook(() => useAnnotationSelection());

    act(() => result.current.setSelectedFreeTextId("text:note"));
    expect(result.current.selectedFreeTextId).toBe("text:note");

    act(() => result.current.setSelectedMeasurementId("measurement:width"));
    expect(result.current).toMatchObject({
      selectedFreeTextId: undefined,
      selectedMeasurementId: "measurement:width",
      selectedConstraintId: undefined,
      selectedStitchStartPointId: undefined,
    });
  });

  it("only clears the matching selection kind", () => {
    const { result } = renderHook(() => useAnnotationSelection());

    act(() => result.current.setSelectedConstraintId("constraint:width"));
    act(() => result.current.setSelectedFreeTextId(undefined));
    expect(result.current.selectedConstraintId).toBe("constraint:width");

    act(() => result.current.clearAnnotationSelection());
    expect(result.current).toMatchObject({
      selectedConstraintId: undefined,
      selectedFreeTextId: undefined,
      selectedMeasurementId: undefined,
      selectedStitchStartPointId: undefined,
    });
  });
});
