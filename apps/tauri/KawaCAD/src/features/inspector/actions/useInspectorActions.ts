import { useCallback } from "react";
import type { InspectorActionInput } from "@/features/inspector/actions/inspectorActionTypes";

/** Inspector presentation state is owned by its feature hook; actions only invalidate it. */
export function useInspectorActions(context: InspectorActionInput) {
  const { invalidate, selection, clearInspectorSelectedPart } = context;
  const resetInspectorPresentation = useCallback(() => invalidate(), [invalidate]);
  const selectMeasurement = useCallback(
    (measurementId: string) => {
      selection.clearEntities();
      selection.selectConstraint(undefined);
      selection.selectFreeText(undefined);
      selection.selectStitchStartPoint(undefined);
      selection.selectMeasurement(measurementId);
      clearInspectorSelectedPart();
    },
    [clearInspectorSelectedPart, selection],
  );
  const selectConstraint = useCallback(
    (constraintId: string) => {
      selection.clearEntities();
      selection.selectFreeText(undefined);
      selection.selectMeasurement(undefined);
      selection.selectStitchStartPoint(undefined);
      selection.selectConstraint(constraintId);
      clearInspectorSelectedPart();
    },
    [clearInspectorSelectedPart, selection],
  );
  const selectFreeText = useCallback(
    (freeTextId: string) => {
      selection.clearEntities();
      selection.selectConstraint(undefined);
      selection.selectMeasurement(undefined);
      selection.selectStitchStartPoint(undefined);
      selection.selectFreeText(freeTextId);
      clearInspectorSelectedPart();
    },
    [clearInspectorSelectedPart, selection],
  );
  return { resetInspectorPresentation, selectConstraint, selectFreeText, selectMeasurement };
}
