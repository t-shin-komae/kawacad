/** Canvas interaction values are screen pixels unless the name says zoom. */
export const canvasMetrics = {
  entityHitTolerancePx: 8,
  entityDerivedHitTolerancePx: 7,
  constraintTargetHitTolerancePx: 9,
  annotationLineHitTolerancePx: 8,
  annotationArcHitTolerancePx: 8,
  constraintMarkerHitTolerancePx: 8,
  stitchStartPointHitTolerancePx: 8,
  zoomMinimum: 0.5,
  zoomMaximum: 3,
  zoomWheelFactor: 1.12,
} as const;
