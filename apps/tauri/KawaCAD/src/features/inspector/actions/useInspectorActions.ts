import { useCallback } from "react";
import type { InspectorActionContext } from "@/app/actions/useActionRuntime";

/** Inspector presentation state is owned by its feature hook; actions only invalidate it. */
export function useInspectorActions(context: InspectorActionContext) {
  const { setInspectorRevision } = context;
  const resetInspectorPresentation = useCallback(
    () => setInspectorRevision((revision) => revision + 1),
    [setInspectorRevision],
  );
  const selectMeasurement = useCallback(
    (measurementId: string) => {
      context.setSelected(new Set());
      context.setSelectedConstraintId(undefined);
      context.setSelectedFreeTextId(undefined);
      context.setSelectedStitchStartPointId(undefined);
      context.setSelectedMeasurementId(measurementId);
      context.setInspectorSelectedPartId(undefined);
    },
    [
      context.setInspectorSelectedPartId,
      context.setSelected,
      context.setSelectedConstraintId,
      context.setSelectedFreeTextId,
      context.setSelectedMeasurementId,
      context.setSelectedStitchStartPointId,
    ],
  );
  return { resetInspectorPresentation, selectMeasurement };
}
