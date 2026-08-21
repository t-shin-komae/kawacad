import type { PointMm } from "@/features/canvas/domain/cad";

export const canvasLayoutMetrics = {
  constraintMarkerAnchorX: 10,
  constraintMarkerAnchorY: -20,
  constraintMarkerStackOffset: 5,
  constraintMarkerHeightPx: 16,
  constraintMarkerMinimumWidthPx: 22,
  fallbackCharacterWidthPx: 6,
  constraintMarkerHorizontalPaddingPx: 10,
  annotationLabelOffsetPx: 5,
  annotationLabelHalfHeightPx: 8,
  annotationLabelHorizontalPaddingPx: 4,
};

const canvasLabelFont = "600 10px -apple-system, BlinkMacSystemFont, sans-serif";

/** Measures the same canvas font used by the renderer. The fallback keeps
 * geometry tests deterministic in environments without a canvas context. */
export function measureCanvasTextWidth(text: string) {
  if (typeof document !== "undefined") {
    try {
      const canvas = document.createElement("canvas");
      const context = canvas.getContext("2d");
      if (context) {
        context.font = canvasLabelFont;
        return context.measureText(text).width;
      }
    } catch {
      // Use the deterministic fallback outside a browser canvas.
    }
  }
  return Array.from(text).reduce(
    (width, character) =>
      width + (character.charCodeAt(0) > 0x3000 ? 10 : canvasLayoutMetrics.fallbackCharacterWidthPx),
    0,
  );
}

export type ConstraintMarkerLayoutInput = {
  positionMm: PointMm;
  label?: string;
  icon?: string;
  stackIndex?: number;
  measuredTextWidthPx?: number;
};

export type AnnotationArcLayoutInput = {
  centerMm: PointMm;
  startMm: PointMm;
  endMm: PointMm;
  counterclockwise?: boolean;
};

/** Geometry shared by annotation drawing and annotation hit testing. */
export function annotationArcLayout(arc: AnnotationArcLayoutInput) {
  const radius = Math.hypot(arc.startMm.xMm - arc.centerMm.xMm, arc.startMm.yMm - arc.centerMm.yMm);
  if (radius <= 0.0001) {
    return {
      radius,
      startAngleRad: 0,
      sweepAngleRad: 0,
      midpointMm: arc.startMm,
    };
  }
  const startAngleRad = Math.atan2(arc.startMm.yMm - arc.centerMm.yMm, arc.startMm.xMm - arc.centerMm.xMm);
  const endAngleRad = Math.atan2(arc.endMm.yMm - arc.centerMm.yMm, arc.endMm.xMm - arc.centerMm.xMm);
  const fullTurn = Math.PI * 2;
  let sweepAngleRad = endAngleRad - startAngleRad;
  if (arc.counterclockwise === true) {
    while (sweepAngleRad < 0) sweepAngleRad += fullTurn;
  } else if (arc.counterclockwise === false) {
    while (sweepAngleRad > 0) sweepAngleRad -= fullTurn;
  } else {
    while (sweepAngleRad <= -Math.PI) sweepAngleRad += fullTurn;
    while (sweepAngleRad > Math.PI) sweepAngleRad -= fullTurn;
  }
  const midpointAngleRad = startAngleRad + sweepAngleRad / 2;
  return {
    radius,
    startAngleRad,
    sweepAngleRad,
    midpointMm: {
      xMm: arc.centerMm.xMm + radius * Math.cos(midpointAngleRad),
      yMm: arc.centerMm.yMm + radius * Math.sin(midpointAngleRad),
    },
  };
}

export function constraintMarkerLayout(marker: ConstraintMarkerLayoutInput) {
  const stackIndex = marker.stackIndex ?? 0;
  const text = [marker.icon, marker.label].filter(Boolean).join(" ");
  const measuredTextWidthPx = marker.measuredTextWidthPx ?? measureCanvasTextWidth(text);
  const measuredWidth = measuredTextWidthPx + canvasLayoutMetrics.constraintMarkerHorizontalPaddingPx;
  const width = Math.max(canvasLayoutMetrics.constraintMarkerMinimumWidthPx, measuredWidth);
  return {
    text,
    width,
    height: canvasLayoutMetrics.constraintMarkerHeightPx,
    offsetX: canvasLayoutMetrics.constraintMarkerAnchorX + stackIndex * canvasLayoutMetrics.constraintMarkerStackOffset,
    offsetY: canvasLayoutMetrics.constraintMarkerAnchorY - stackIndex * canvasLayoutMetrics.constraintMarkerStackOffset,
  };
}

export function annotationLabelLayout(
  midpointMm: PointMm,
  label: string,
  labelOffsetMm: PointMm | undefined,
  displayScalePxPerMm: number,
  measuredTextWidthPx = measureCanvasTextWidth(label),
) {
  const offset = labelOffsetMm ?? { xMm: 0, yMm: 0 };
  const centerMm = {
    xMm: midpointMm.xMm + offset.xMm + canvasLayoutMetrics.annotationLabelOffsetPx / displayScalePxPerMm,
    yMm: midpointMm.yMm + offset.yMm + canvasLayoutMetrics.annotationLabelOffsetPx / displayScalePxPerMm,
  };
  return {
    centerMm,
    halfWidthMm:
      (measuredTextWidthPx / 2 + canvasLayoutMetrics.annotationLabelHorizontalPaddingPx) / displayScalePxPerMm,
    halfHeightMm: canvasLayoutMetrics.annotationLabelHalfHeightPx / displayScalePxPerMm,
  };
}
