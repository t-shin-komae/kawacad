import { useCallback, useState } from "react";

type AnnotationSelection =
  | { kind: "freeText"; id: string }
  | { kind: "constraint"; id: string }
  | { kind: "measurement"; id: string }
  | { kind: "stitchStartPoint"; id: string };

type AnnotationKind = AnnotationSelection["kind"];

function selectionId(selection: AnnotationSelection | undefined, kind: AnnotationKind) {
  return selection?.kind === kind ? selection.id : undefined;
}

export function useAnnotationSelection() {
  const [selection, setSelection] = useState<AnnotationSelection>();
  const setSelectionId = useCallback((kind: AnnotationKind, id: string | undefined) => {
    setSelection((current) => {
      if (id) return { kind, id };
      return current?.kind === kind ? undefined : current;
    });
  }, []);
  const setSelectedFreeTextId = useCallback(
    (id: string | undefined) => setSelectionId("freeText", id),
    [setSelectionId],
  );
  const setSelectedConstraintId = useCallback(
    (id: string | undefined) => setSelectionId("constraint", id),
    [setSelectionId],
  );
  const setSelectedMeasurementId = useCallback(
    (id: string | undefined) => setSelectionId("measurement", id),
    [setSelectionId],
  );
  const setSelectedStitchStartPointId = useCallback(
    (id: string | undefined) => setSelectionId("stitchStartPoint", id),
    [setSelectionId],
  );
  const clearSelectedFreeText = useCallback(() => setSelectedFreeTextId(undefined), [setSelectedFreeTextId]);
  const clearSelectedConstraint = useCallback(() => setSelectedConstraintId(undefined), [setSelectedConstraintId]);
  const clearSelectedMeasurement = useCallback(() => setSelectedMeasurementId(undefined), [setSelectedMeasurementId]);
  const clearSelectedStitchStartPoint = useCallback(
    () => setSelectedStitchStartPointId(undefined),
    [setSelectedStitchStartPointId],
  );
  const clearAnnotationSelection = useCallback(() => setSelection(undefined), []);

  return {
    selectedFreeTextId: selectionId(selection, "freeText"),
    setSelectedFreeTextId,
    clearSelectedFreeText,
    selectedConstraintId: selectionId(selection, "constraint"),
    setSelectedConstraintId,
    clearSelectedConstraint,
    selectedMeasurementId: selectionId(selection, "measurement"),
    setSelectedMeasurementId,
    clearSelectedMeasurement,
    selectedStitchStartPointId: selectionId(selection, "stitchStartPoint"),
    setSelectedStitchStartPointId,
    clearSelectedStitchStartPoint,
    clearAnnotationSelection,
  };
}

export type AnnotationSelectionPresentation = ReturnType<typeof useAnnotationSelection>;
