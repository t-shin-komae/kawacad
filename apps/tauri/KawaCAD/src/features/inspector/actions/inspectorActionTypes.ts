export type InspectorActionInput = {
  invalidate: () => void;
  selection: {
    clearEntities: () => void;
    selectConstraint: (id: string | undefined) => void;
    selectFreeText: (id: string | undefined) => void;
    selectStitchStartPoint: (id: string | undefined) => void;
    selectMeasurement: (id: string | undefined) => void;
  };
  clearInspectorSelectedPart: () => void;
};
