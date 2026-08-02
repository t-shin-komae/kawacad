import { useCallback } from "react";
import { useConstraintActionCallbacks } from "@/features/constraints/actions/useConstraintActionCallbacks";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
import { appStrings } from "@/localization";
import { selectedSourceArcId } from "@/shared/domain/workspaceState";
import { id } from "@/features/canvas/domain/workspaceTools";
import type { ConstraintActionContext } from "@/app/actions/useActionRuntime";

/** Constraint, measurement, and derived-element actions. */
export function useConstraintActions(context: ConstraintActionContext, selectTool: (tool: Tool) => void) {
  const callbacks = useConstraintActionCallbacks({ ...context, selectTool });
  const smoothSelectedArcTangencies = useCallback(() => {
    const arcEntityId = selectedSourceArcId(
      context.selected,
      context.state?.entities ?? [],
      context.state?.drawingEntityMetadata ?? [],
    );
    if (!arcEntityId) {
      context.setMessage(appStrings.status.selectSingleArcForTangency);
      return;
    }
    void context.command("smoothArcTangencies", { arcEntityId }, appStrings.app.smoothTangencies);
  }, [
    context.command,
    context.selected,
    context.setMessage,
    context.state?.drawingEntityMetadata,
    context.state?.entities,
  ]);
  const convertMeasurement = useCallback(
    (annotationId: string, success: string = appStrings.app.measurementConverted) =>
      void context.command(
        "convertMeasurementToConstraint",
        { annotationId, constraintId: id("constraint:measurement") },
        success,
      ),
    [context.command],
  );
  return { ...callbacks, smoothSelectedArcTangencies, convertMeasurement };
}
