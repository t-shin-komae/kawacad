import { describe, expect, it } from "vitest";
import {
  a4GridBounds,
  arcPlacementEndPoint,
  allowsDerivedTarget,
  clampToA4Grid,
  constraintMarkerLabel,
  constraintMarkerIcon,
  coreConstraintTarget,
  controlPointsOf,
  defaultViewport,
  displayPointsPerMillimeter,
  geometryOf,
  hitConstraintTarget,
  hitConstraintMarker,
  hitEntity,
  hitFreeText,
  hitProjectedAnnotation,
  hitProjectedAnnotationDetail,
  hitProjectedPoint,
  hasMeaningfulModelMovement,
  modelPoint,
  modelPointInA4Grid,
  normalizedScreenRect,
  preferredConstraintTarget,
  preferredEntitySelectionHit,
  screenPoint,
  selectionInRect,
  snapToEntityPoint,
  snapToGrid,
  supportsOffsetTarget,
  type RawEntity,
} from "@/features/canvas/domain/cad";
import {
  annotationArcLayout,
  annotationLabelLayout,
  constraintMarkerLayout,
} from "@/features/canvas/domain/canvasLayout";
import { canvasMetrics } from "@/features/canvas/domain/canvasMetrics";

const line: RawEntity = { id: "line", kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 20, yMm: 0 } } } };
const circle: RawEntity = { id: "circle", kind: { circle: { center: { xMm: 30, yMm: 10 }, radiusMm: 5 } } };
const arc: RawEntity = {
  id: "arc",
  kind: { arc: { center: { xMm: -10, yMm: 0 }, radiusMm: 5, startAngleRad: 0, sweepAngleRad: Math.PI / 2 } },
};
const viewport = { zoom: 3, panX: 11, panY: -4 };

describe("CAD geometry helpers", () => {
  it("shares marker placement metrics for short and long labels", () => {
    const short = constraintMarkerLayout({ positionMm: { xMm: 10, yMm: 5 }, label: "H", stackIndex: 2 });
    const long = constraintMarkerLayout({
      positionMm: { xMm: 10, yMm: 5 },
      label: "perpendicular",
      stackIndex: 2,
    });

    expect(short.offsetX).toBe(long.offsetX);
    expect(short.offsetY).toBe(long.offsetY);
    expect(long.width).toBeGreaterThan(short.width);
  });

  it("never lets a measured marker label shrink below its measured text", () => {
    const layout = constraintMarkerLayout({
      positionMm: { xMm: 10, yMm: 5 },
      label: "水平",
      measuredTextWidthPx: 80,
    });

    expect(layout.width).toBeGreaterThanOrEqual(90);
  });

  it("keeps annotation hit boxes centered while zoom changes their size", () => {
    const midpoint = { xMm: 20, yMm: 10 };
    const zoomedOut = annotationLabelLayout(midpoint, "1234.56 mm", undefined, 2);
    const zoomedIn = annotationLabelLayout(midpoint, "1234.56 mm", undefined, 8);

    expect((zoomedOut.centerMm.xMm - midpoint.xMm) * 2).toBeCloseTo((zoomedIn.centerMm.xMm - midpoint.xMm) * 8);
    expect((zoomedOut.centerMm.yMm - midpoint.yMm) * 2).toBeCloseTo((zoomedIn.centerMm.yMm - midpoint.yMm) * 8);
    expect(zoomedOut.halfWidthMm).toBeGreaterThan(zoomedIn.halfWidthMm);
    expect(zoomedOut.halfHeightMm).toBeGreaterThan(zoomedIn.halfHeightMm);
  });

  it("opens the drawing at the SwiftUI document scale", () => {
    expect(defaultViewport.zoom).toBe(1);
  });
  it("normalizes Rust externally-tagged entities", () => {
    expect(geometryOf(line)).toEqual({ tag: "lineSegment", start: { xMm: 0, yMm: 0 }, end: { xMm: 20, yMm: 0 } });
    expect(geometryOf(circle)?.tag).toBe("circle");
  });
  it("selects the topmost free-text model hit before geometry", () => {
    expect(
      hitFreeText({ xMm: 11, yMm: 9 }, [
        { id: "text:back", content: "Back", positionMm: { xMm: 10, yMm: 10 }, fontSizeMm: 3 },
        { id: "text:front", content: "Front", positionMm: { xMm: 10, yMm: 10 }, fontSizeMm: 3 },
      ]),
    ).toBe("text:front");
    expect(hitFreeText({ xMm: 0, yMm: 0 }, [])).toBeUndefined();
  });
  it("selects only visible projected constraint markers at canvas tolerance", () => {
    const markers = [
      { id: "hidden", positionMm: { xMm: 0, yMm: 0 }, visible: false },
      { id: "visible", positionMm: { xMm: 1, yMm: 0 }, visible: true },
    ];
    expect(hitProjectedPoint({ xMm: 1.5, yMm: 0 }, markers, { zoom: 4, panX: 0, panY: 0 })).toBe("visible");
    expect(hitProjectedPoint({ xMm: 10, yMm: 0 }, markers, { zoom: 4, panX: 0, panY: 0 })).toBeUndefined();
  });
  it("hits the SwiftUI-style marker label as well as its anchor", () => {
    const items = [{ id: "constraint:horizontal", positionMm: { xMm: 10, yMm: 0 }, label: "水平" }];
    const labelPoint = {
      xMm: 10 + 21 / displayPointsPerMillimeter,
      yMm: 15 / displayPointsPerMillimeter,
    };
    expect(hitConstraintMarker({ xMm: 10, yMm: 0 }, items, { zoom: 1, panX: 0, panY: 0 })).toBe(
      "constraint:horizontal",
    );
    expect(hitConstraintMarker(labelPoint, items, { zoom: 1, panX: 0, panY: 0 })).toBe("constraint:horizontal");
    expect(hitConstraintMarker({ xMm: -40, yMm: -40 }, items, { zoom: 1, panX: 0, panY: 0 })).toBeUndefined();
  });
  it("gives every SwiftUI-supported constraint kind a canvas marker label", () => {
    [
      "coincident",
      "horizontal",
      "vertical",
      "parallel",
      "perpendicular",
      "tangent",
      "equalLength",
      "equalSegmentLength",
      "symmetric",
      "pointOnLine",
      "fixed",
      "distance",
      "pointLineDistance",
      "horizontalDistance",
      "verticalDistance",
      "lineLineDistance",
      "segmentLength",
      "angle",
      "diameter",
      "radius",
    ].forEach((kind) => expect(constraintMarkerLabel(kind)).toBeTruthy());
    expect(constraintMarkerLabel("unsupported")).toBeUndefined();
  });
  it("gives supported constraint markers a stable cross-platform glyph", () => {
    expect(constraintMarkerIcon("horizontal")).toBe("—");
    expect(constraintMarkerIcon("vertical")).toBe("│");
    expect(constraintMarkerIcon("angle")).toBe("∠");
    expect(constraintMarkerIcon("unsupported")).toBeUndefined();
  });
  it("selects visible projected measurements by their displayed line", () => {
    const annotations = [
      { id: "hidden", visible: false, startMm: { xMm: 0, yMm: 0 }, endMm: { xMm: 20, yMm: 0 } },
      { id: "visible", visible: true, startMm: { xMm: 0, yMm: 10 }, endMm: { xMm: 20, yMm: 10 } },
    ];
    expect(hitProjectedAnnotation({ xMm: 10, yMm: 10.5 }, annotations, { zoom: 4, panX: 0, panY: 0 })).toBe("visible");
    expect(hitProjectedAnnotation({ xMm: 10, yMm: 0 }, annotations, { zoom: 4, panX: 0, panY: 0 })).toBeUndefined();
  });
  it("distinguishes a dimension label hit from a dimension line hit", () => {
    const annotations = [{ id: "dimension:1", visible: true, startMm: { xMm: 0, yMm: 0 }, endMm: { xMm: 20, yMm: 0 } }];
    const viewport = { zoom: 1, panX: 0, panY: 0 };
    const labelPoint = {
      xMm: 10 + 5 / displayPointsPerMillimeter,
      yMm: 5 / displayPointsPerMillimeter,
    };
    expect(hitProjectedAnnotationDetail(labelPoint, annotations, viewport, { "dimension:1": "20 mm" }, {})).toEqual({
      id: "dimension:1",
      labelOnly: true,
    });
    expect(hitProjectedAnnotationDetail({ xMm: 2, yMm: 0 }, annotations, viewport, {}, {})).toEqual({
      id: "dimension:1",
      labelOnly: false,
    });
  });
  it("hits an angular annotation on its arc rather than its chord", () => {
    const item = {
      id: "constraint:angle",
      visible: true,
      arc: true,
      centerMm: { xMm: 0, yMm: 0 },
      startMm: { xMm: 100, yMm: 0 },
      endMm: { xMm: 0, yMm: 100 },
    };
    expect(
      hitProjectedAnnotationDetail({ xMm: 70.71, yMm: 70.71 }, [item], { zoom: 1, panX: 0, panY: 0 }, {}, {}),
    ).toEqual({ id: "constraint:angle", labelOnly: false });
    expect(
      hitProjectedAnnotationDetail({ xMm: 50, yMm: 50 }, [item], { zoom: 1, panX: 0, panY: 0 }, {}, {}),
    ).toBeUndefined();
  });
  it("uses the rendered direction for clockwise and counterclockwise long-arc labels", () => {
    const center = { xMm: 0, yMm: 0 };
    const start = { xMm: 10, yMm: 0 };
    const end = { xMm: -9.396926207859085, yMm: -3.4202014332566866 };
    const viewport = { zoom: 1, panX: 0, panY: 0 };
    const counterclockwise = {
      id: "arc:ccw",
      visible: true,
      arc: true,
      centerMm: center,
      startMm: start,
      endMm: end,
      arcCounterclockwise: true,
    };
    const clockwise = { ...counterclockwise, id: "arc:cw", arcCounterclockwise: false };
    const counterMidpoint = annotationArcLayout({ ...counterclockwise, counterclockwise: true }).midpointMm;
    const clockwiseMidpoint = annotationArcLayout({ ...clockwise, counterclockwise: false }).midpointMm;
    const counterLabelCenter = annotationLabelLayout(
      counterMidpoint,
      "200°",
      undefined,
      displayPointsPerMillimeter,
    ).centerMm;
    const clockwiseLabelCenter = annotationLabelLayout(
      clockwiseMidpoint,
      "200°",
      undefined,
      displayPointsPerMillimeter,
    ).centerMm;

    expect(
      hitProjectedAnnotationDetail(counterLabelCenter, [counterclockwise], viewport, { "arc:ccw": "200°" }, {}),
    ).toEqual({ id: "arc:ccw", labelOnly: true });
    expect(hitProjectedAnnotationDetail(clockwiseLabelCenter, [clockwise], viewport, { "arc:cw": "200°" }, {})).toEqual(
      { id: "arc:cw", labelOnly: true },
    );
  });
  it("round-trips display and model coordinates", () => {
    const display = screenPoint({ xMm: 12, yMm: -7 }, 800, 600, viewport);
    const decoded = modelPoint(display, 800, 600, viewport);
    expect(decoded.xMm).toBeCloseTo(12);
    expect(decoded.yMm).toBeCloseTo(-7);
  });
  it("hits lines, circles and bounded arcs", () => {
    expect(hitEntity({ xMm: 10, yMm: 0.5 }, [line], viewport)).toBe("line");
    expect(hitEntity({ xMm: 35, yMm: 10 }, [circle], viewport)).toBe("circle");
    expect(hitEntity({ xMm: -10, yMm: 5 }, [arc], viewport)).toBe("arc");
    expect(hitEntity({ xMm: -10, yMm: -5 }, [arc], viewport)).toBeUndefined();
  });
  it("applies the entity line tolerance exactly once", () => {
    const viewport = { zoom: 1, panX: 0, panY: 0 };
    const toleranceMm = canvasMetrics.entityHitTolerancePx / displayPointsPerMillimeter;
    expect(hitEntity({ xMm: 10, yMm: toleranceMm }, [line], viewport)).toBe("line");
    expect(hitEntity({ xMm: 10, yMm: toleranceMm + 0.01 }, [line], viewport)).toBeUndefined();
  });

  it("uses the annotation tolerance boundary for a rendered dimension line", () => {
    const viewport = { zoom: 1, panX: 0, panY: 0 };
    const toleranceMm = canvasMetrics.annotationLineHitTolerancePx / displayPointsPerMillimeter;
    const item = [{ id: "dimension:boundary", visible: true, startMm: { xMm: 0, yMm: 0 }, endMm: { xMm: 20, yMm: 0 } }];
    expect(hitProjectedAnnotation({ xMm: 10, yMm: toleranceMm }, item, viewport)).toBe("dimension:boundary");
    expect(hitProjectedAnnotation({ xMm: 10, yMm: toleranceMm + 0.01 }, item, viewport)).toBeUndefined();
  });
  it("supports grid, entity-point and crossing-window selection", () => {
    expect(snapToGrid({ xMm: 7.4, yMm: -7.4 }, true)).toEqual({ xMm: 5, yMm: -5 });
    expect(snapToEntityPoint({ xMm: 0.4, yMm: 0.4 }, [line], viewport)).toEqual({ xMm: 0, yMm: 0 });
    expect(selectionInRect([line, circle], { xMm: 22, yMm: 20 }, { xMm: -2, yMm: -2 }, true)).toEqual(["line"]);
  });
  it("keeps clockwise arc sweeps over 180 degrees", () => {
    const center = { xMm: 0, yMm: 0 };
    const start = { xMm: 10, yMm: 0 };
    const first = arcPlacementEndPoint(center, start, { xMm: 0, yMm: 10 }, undefined, false)!;
    const second = arcPlacementEndPoint(center, start, { xMm: -10, yMm: 0 }, first.sweepAngleRad, false)!;
    const large = arcPlacementEndPoint(
      center,
      start,
      { xMm: -9.396926207859085, yMm: -3.4202014332566866 },
      second.sweepAngleRad,
      false,
    )!;
    expect(large.sweepAngleRad).toBeCloseTo((200 * Math.PI) / 180);
  });

  it("keeps counterclockwise arc sweeps over 180 degrees", () => {
    const center = { xMm: 0, yMm: 0 };
    const start = { xMm: 10, yMm: 0 };
    const first = arcPlacementEndPoint(center, start, { xMm: 0, yMm: -10 }, undefined, false)!;
    const second = arcPlacementEndPoint(center, start, { xMm: -10, yMm: 0 }, first.sweepAngleRad, false)!;
    const large = arcPlacementEndPoint(
      center,
      start,
      { xMm: -9.396926207859085, yMm: 3.4202014332566866 },
      second.sweepAngleRad,
      false,
    )!;
    expect(large.sweepAngleRad).toBeCloseTo((-200 * Math.PI) / 180);
  });

  it("snaps an arc end to a 15-degree increment while Shift is pressed", () => {
    const center = { xMm: 0, yMm: 0 };
    const start = { xMm: 10, yMm: 0 };
    const snapped = arcPlacementEndPoint(center, start, { xMm: 7, yMm: 7 }, undefined, true)!;
    expect(snapped.sweepAngleRad).toBeCloseTo(Math.PI / 4);
    expect(snapped.point.xMm).toBeCloseTo(7.0710678118654755);
    expect(snapped.point.yMm).toBeCloseTo(7.0710678118654755);
  });

  it("keeps an over-180-degree sweep after Shift angle snapping", () => {
    const center = { xMm: 0, yMm: 0 };
    const start = { xMm: 10, yMm: 0 };
    const first = arcPlacementEndPoint(center, start, { xMm: 0, yMm: 10 }, undefined, true)!;
    const second = arcPlacementEndPoint(center, start, { xMm: -10, yMm: 0 }, first.sweepAngleRad, true)!;
    const large = arcPlacementEndPoint(
      center,
      start,
      { xMm: -8.660254037844386, yMm: -5 },
      second.sweepAngleRad,
      true,
    )!;
    expect(large.sweepAngleRad).toBeCloseTo((210 * Math.PI) / 180);
  });
  it("prefers a source entity when a fillet result overlaps it", () => {
    const derived = { ...line, id: "derived:fillet-a:resolved:0" };
    expect(hitEntity({ xMm: 10, yMm: 0 }, [line, derived], viewport)).toBe("line");
  });
  it("uses a point control before an overlapping later line body for selection", () => {
    const point: RawEntity = { id: "point", kind: { point: { xMm: 4, yMm: 6 } } };
    const overlappingLine: RawEntity = {
      id: "line:later",
      kind: { lineSegment: { start: { xMm: 0, yMm: 6 }, end: { xMm: 20, yMm: 6 } } },
    };
    expect(preferredEntitySelectionHit({ xMm: 4, yMm: 6 }, [point, overlappingLine], viewport)).toBe("point");
    expect(
      preferredEntitySelectionHit({ xMm: 4, yMm: 6 }, [point, overlappingLine], viewport, new Set(["point"])),
    ).toBe("point");
  });
  it("exposes individual line controls to Core constraint commands", () => {
    expect(hitConstraintTarget({ xMm: 0, yMm: 0 }, [line], viewport)).toEqual({
      controlPoint: { entityId: "line", point: "start" },
    });
    expect(hitConstraintTarget({ xMm: 10, yMm: 0.5 }, [line], viewport)).toEqual({ entity: "line" });
  });
  it("exposes an arc center and endpoints as editable controls", () => {
    const controls = controlPointsOf(geometryOf(arc)!);
    expect(controls.map((item) => item.kind)).toEqual(["center", "start", "end"]);
    expect(controls[1].point).toEqual({ xMm: -5, yMm: 0 });
  });
  it("prefers a control point over the entity body for point-on-line", () => {
    expect(preferredConstraintTarget({ xMm: 0, yMm: 0 }, [line], viewport, "pointOnLine")).toEqual({
      controlPoint: { entityId: "line", point: "start" },
    });
  });
  it("uses the line body after point-on-line already has its point target", () => {
    expect(
      preferredConstraintTarget({ xMm: 0, yMm: 0 }, [line], viewport, "pointOnLine", [
        { controlPoint: { entityId: "other-point", point: "center" } },
      ]),
    ).toEqual({ entity: "line" });
  });
  it("uses the symmetry axis after its two point targets", () => {
    expect(
      preferredConstraintTarget({ xMm: 10, yMm: 0 }, [line], viewport, "symmetric", [
        { controlPoint: { entityId: "point:a", point: "center" } },
        { controlPoint: { entityId: "point:b", point: "center" } },
      ]),
    ).toEqual({ entity: "line" });
  });
  it("prefers a point control for distance and measurement distance", () => {
    expect(preferredConstraintTarget({ xMm: 0, yMm: 0 }, [line], viewport, "distance")).toEqual({
      controlPoint: { entityId: "line", point: "start" },
    });
    expect(preferredConstraintTarget({ xMm: 0, yMm: 0 }, [line], viewport, "measureDistance")).toEqual({
      controlPoint: { entityId: "line", point: "start" },
    });
  });
  it("uses line bodies for line-only constraint and measurement tools", () => {
    expect(preferredConstraintTarget({ xMm: 10, yMm: 0 }, [line], viewport, "parallel")).toEqual({ entity: "line" });
    expect(preferredConstraintTarget({ xMm: 10, yMm: 0 }, [line], viewport, "measureAngle")).toEqual({
      entity: "line",
    });
  });
  it("prefers a source line over an overlapping derived line for a line constraint", () => {
    const resolved = { ...line, id: "derived:fillet:resolved:0" };
    expect(preferredConstraintTarget({ xMm: 10, yMm: 0 }, [line, resolved], viewport, "segmentLength")).toEqual({
      entity: "line",
    });
  });
  it("selects an arc body only for arc-sweep measurement", () => {
    expect(preferredConstraintTarget({ xMm: -5, yMm: 0 }, [arc], viewport, "measureAngle")).toBeUndefined();
    expect(preferredConstraintTarget({ xMm: -5, yMm: 0 }, [arc], viewport, "measureArcSweepAngle")).toEqual({
      entity: "arc",
    });
  });
  it("matches SwiftUI target-kind restrictions for angle, diameter, radius, and point constraints", () => {
    expect(preferredConstraintTarget({ xMm: -5, yMm: 0 }, [arc], viewport, "angle")).toEqual({ entity: "arc" });
    expect(preferredConstraintTarget({ xMm: 35, yMm: 10 }, [circle], viewport, "diameter")).toEqual({
      entity: "circle",
    });
    expect(preferredConstraintTarget({ xMm: 35, yMm: 10 }, [circle], viewport, "measureDiameter")).toEqual({
      entity: "circle",
    });
    expect(preferredConstraintTarget({ xMm: 35, yMm: 10 }, [circle], viewport, "coincident")).toBeUndefined();
    expect(preferredConstraintTarget({ xMm: 35, yMm: 10 }, [circle], viewport, "tangent")).toBeUndefined();
  });
  it("allows radius selection to use an arc endpoint control", () => {
    expect(preferredConstraintTarget({ xMm: -5, yMm: 0 }, [arc], viewport, "radius")).toEqual({
      controlPoint: { entityId: "arc", point: "start" },
    });
  });
});

describe("Canvas coordinate space parity", () => {
  it("maps the model origin to the center of the drawing surface", () => {
    expect(screenPoint({ xMm: 0, yMm: 0 }, 520, 736, defaultViewport)).toEqual({ x: 260, y: 368 });
  });
  it("maps positive model y upward on the canvas", () => {
    const origin = screenPoint({ xMm: 0, yMm: 0 }, 520, 736, defaultViewport);
    const above = screenPoint({ xMm: 0, yMm: 25 }, 520, 736, defaultViewport);
    expect(above.y).toBeLessThan(origin.y);
  });
  it("round-trips centered model coordinates", () => {
    const point = { xMm: -42.5, yMm: 63.25 };
    expect(modelPoint(screenPoint(point, 520, 736, defaultViewport), 520, 736, defaultViewport)).toEqual(point);
  });
  it("round-trips model coordinates while the view is panned", () => {
    const point = { xMm: 32.25, yMm: -47.5 };
    const panned = { zoom: 1.4, panX: 36, panY: -28 };
    const decoded = modelPoint(screenPoint(point, 650, 920, panned), 650, 920, panned);
    expect(decoded.xMm).toBeCloseTo(point.xMm);
    expect(decoded.yMm).toBeCloseTo(point.yMm);
  });
  it("round-trips coordinates outside the central A4 page before input clamping", () => {
    const point = { xMm: 320, yMm: -410 };
    const decoded = modelPoint(screenPoint(point, 520, 736, defaultViewport), 520, 736, defaultViewport);
    expect(decoded.xMm).toBeCloseTo(point.xMm);
    expect(decoded.yMm).toBeCloseTo(point.yMm);
  });
  it("clamps pointer input to the centered portrait A4 grid", () => {
    expect(modelPointInA4Grid({ x: -5_000, y: 5_000 }, 520, 736, defaultViewport)).toEqual({
      xMm: -525,
      yMm: -742.5,
    });
  });
  it("describes bounds spanning five centered portrait A4 pages", () => {
    expect(a4GridBounds()).toMatchObject({
      pageWidthMm: 210,
      pageHeightMm: 297,
      minXmm: -525,
      maxXmm: 525,
      minYmm: -742.5,
      maxYmm: 742.5,
    });
  });
  it("uses landscape A4 bounds for pointer input", () => {
    expect(clampToA4Grid({ xMm: 5_000, yMm: -1_000 }, "landscape")).toEqual({ xMm: 742.5, yMm: -525 });
  });
  it("keeps the same PDF-point display scale across A4 orientations", () => {
    const point = { xMm: 120, yMm: -80 };
    const portrait = screenPoint(point, 520, 736, defaultViewport);
    const landscape = screenPoint(point, 736, 520, defaultViewport);
    expect(portrait.x - 260).toBe(landscape.x - 368);
    expect(portrait.y - 368).toBe(landscape.y - 260);

    const enlarged = screenPoint(point, 520, 736, { ...defaultViewport, zoom: 2.5 });
    expect(enlarged.x - 260).toBeCloseTo(point.xMm * displayPointsPerMillimeter * 2.5);
    expect(enlarged.y - 368).toBeCloseTo(-point.yMm * displayPointsPerMillimeter * 2.5);
  });
  it("keeps arc endpoint coordinates aligned after model-to-screen conversion", () => {
    const arcEnd = { xMm: 0, yMm: 20 };
    const endpoint = screenPoint(arcEnd, 520, 736, defaultViewport);
    const decoded = modelPoint(endpoint, 520, 736, defaultViewport);
    expect(decoded.xMm).toBeCloseTo(arcEnd.xMm);
    expect(decoded.yMm).toBeCloseTo(arcEnd.yMm);
  });
});

describe("Canvas marquee and interaction parity", () => {
  const centerLine: RawEntity = {
    id: "center-line",
    kind: { centerLine: { start: { xMm: -20, yMm: 0 }, end: { xMm: 20, yMm: 0 } } },
  };
  const largeCircle: RawEntity = { id: "circle-10", kind: { circle: { center: { xMm: 0, yMm: 0 }, radiusMm: 10 } } };
  const quarterArc: RawEntity = {
    id: "arc-quarter",
    kind: { arc: { center: { xMm: 0, yMm: 0 }, radiusMm: 10, startAngleRad: 0, sweepAngleRad: Math.PI / 2 } },
  };
  it("requires the whole logical shape for contained marquee selection", () => {
    const containedLine: RawEntity = {
      id: "contained-line",
      kind: { lineSegment: { start: { xMm: -10, yMm: 0 }, end: { xMm: 10, yMm: 0 } } },
    };
    expect(
      selectionInRect([containedLine, centerLine, largeCircle], { xMm: -12, yMm: -6 }, { xMm: 12, yMm: 6 }, false),
    ).toEqual(["contained-line"]);
  });
  it("uses geometry intersections rather than only bounding endpoints for crossing selection", () => {
    expect(
      selectionInRect([centerLine, largeCircle, quarterArc], { xMm: -1, yMm: -1 }, { xMm: 1, yMm: 1 }, true),
    ).toEqual(["center-line"]);
  });
  it("uses the actual arc sweep for contained and crossing selection", () => {
    expect(selectionInRect([quarterArc], { xMm: -1, yMm: -1 }, { xMm: 11, yMm: 11 }, false)).toEqual(["arc-quarter"]);
    expect(selectionInRect([quarterArc], { xMm: 6, yMm: 6 }, { xMm: 8, yMm: 8 }, true)).toEqual(["arc-quarter"]);
  });
  it("applies the same contained and crossing rules to circles and center lines", () => {
    expect(selectionInRect([largeCircle, centerLine], { xMm: -11, yMm: -11 }, { xMm: 11, yMm: 11 }, false)).toEqual([
      "circle-10",
    ]);
    expect(selectionInRect([largeCircle, centerLine], { xMm: 9, yMm: -2 }, { xMm: 11, yMm: 2 }, true)).toEqual([
      "circle-10",
      "center-line",
    ]);
  });
  it("keeps only wholly contained adjacent top elements", () => {
    const top = [
      { id: "top-left", kind: { lineSegment: { start: { xMm: -12, yMm: 20 }, end: { xMm: -4, yMm: 20 } } } },
      { id: "top-center", kind: { lineSegment: { start: { xMm: -4, yMm: 20 }, end: { xMm: 4, yMm: 20 } } } },
      { id: "top-right", kind: { lineSegment: { start: { xMm: 4, yMm: 20 }, end: { xMm: 12, yMm: 20 } } } },
      { id: "side", kind: { lineSegment: { start: { xMm: 8, yMm: 8 }, end: { xMm: 16, yMm: 20 } } } },
    ] satisfies RawEntity[];
    expect(selectionInRect(top, { xMm: -13, yMm: 18 }, { xMm: 13, yMm: 22 }, false)).toEqual([
      "top-left",
      "top-center",
      "top-right",
    ]);
  });
  it("excludes resolved fillet results from marquee selection while keeping offset results", () => {
    const filletResult = { ...centerLine, id: "derived:fillet-a:resolved:0" };
    const offsetResult = { ...centerLine, id: "derived:offset-a:resolved:0" };
    expect(selectionInRect([filletResult, offsetResult], { xMm: -25, yMm: -5 }, { xMm: 25, yMm: 5 }, false)).toEqual([
      "derived:offset-a:resolved:0",
    ]);
  });
  it("normalizes marquee screen rectangles independently of drag direction", () => {
    expect(normalizedScreenRect({ x: 30, y: 10 }, { x: 5, y: 40 })).toEqual({ x: 5, y: 10, width: 25, height: 30 });
  });
  it("uses the SwiftUI drag tolerance for meaningful model movement", () => {
    expect(hasMeaningfulModelMovement({ xMm: 0, yMm: 0 }, { xMm: 0.00005, yMm: 0 })).toBe(false);
    expect(hasMeaningfulModelMovement({ xMm: 0, yMm: 0 }, { xMm: 0.001, yMm: 0 })).toBe(true);
  });
});

describe("Constraint target preflight parity", () => {
  const derivedLine: RawEntity = {
    id: "derived:offset-a:resolved:0",
    kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 10, yMm: 0 } } },
  };
  const derivedFilletArc: RawEntity = {
    id: "derived:fillet-a:resolved:1",
    kind: { arc: { center: { xMm: 0, yMm: 0 }, radiusMm: 2, startAngleRad: 0, sweepAngleRad: Math.PI / 2 } },
  };
  it("preserves circle entity intent for Core normalization", () => {
    expect(hitConstraintTarget({ xMm: 35, yMm: 10 }, [circle], viewport)).toEqual({ entity: "circle" });
  });
  it("preserves line entity targets for Core point-or-line normalization", () => {
    expect(hitConstraintTarget({ xMm: 10, yMm: 0.5 }, [line], viewport)).toEqual({ entity: "line" });
  });
  it("serializes control-point targets using Core's stable wire key", () => {
    expect(coreConstraintTarget({ controlPoint: { entityId: "line", point: "end" } })).toEqual({
      controlPoint: { entity_id: "line", point: "end" },
    });
    expect(coreConstraintTarget({ entity: "line" })).toEqual({ entity: "line" });
    expect(coreConstraintTarget({ controlPoint: { entity_id: "line", point: "start" } })).toEqual({
      controlPoint: { entity_id: "line", point: "start" },
    });
  });
  it("supports lines, circles, arcs, and center lines as offset inputs", () => {
    expect(supportsOffsetTarget(line)).toBe(true);
    expect(supportsOffsetTarget(circle)).toBe(true);
    expect(supportsOffsetTarget(arc)).toBe(true);
    expect(supportsOffsetTarget({ ...line, id: "center", kind: { centerLine: line.kind.lineSegment } })).toBe(true);
  });
  it("allows offset and fillet tools to operate on derived geometry", () => {
    expect(allowsDerivedTarget("offset", derivedLine)).toBe(true);
    expect(allowsDerivedTarget("fillet", derivedLine)).toBe(true);
  });
  it("allows measurement tools to normalize derived targets while rejecting ordinary constraints", () => {
    expect(allowsDerivedTarget("measureSegmentLength", derivedLine)).toBe(true);
    expect(allowsDerivedTarget("measureDistance", derivedLine)).toBe(true);
    expect(allowsDerivedTarget("segmentLength", derivedLine)).toBe(false);
  });
  it("allows radius editing only for a derived fillet arc", () => {
    expect(allowsDerivedTarget("radius", derivedFilletArc)).toBe(true);
    expect(allowsDerivedTarget("radius", derivedLine)).toBe(false);
  });
  it("rejects ordinary constraint tools on derived geometry before Core preflight", () => {
    expect(allowsDerivedTarget("segmentLength", derivedLine)).toBe(false);
  });
});

describe("Canvas constraint selection priority parity", () => {
  const selectionViewport = { zoom: 1, panX: 0, panY: 0 };
  const pointAtOrigin: RawEntity = { id: "point", kind: { point: { xMm: 0, yMm: 0 } } };
  const lineAtOrigin: RawEntity = {
    id: "line",
    kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 20, yMm: 0 } } },
  };
  it("prefers point controls over a line body for distance tools", () => {
    expect(preferredConstraintTarget({ xMm: 0, yMm: 0 }, [lineAtOrigin], selectionViewport, "distance")).toEqual({
      controlPoint: { entityId: "line", point: "start" },
    });
    expect(preferredConstraintTarget({ xMm: 10, yMm: 0 }, [lineAtOrigin], selectionViewport, "distance")).toEqual({
      entity: "line",
    });
  });
  it("switches point-on-line from a point control to a line body after its first target", () => {
    const first = preferredConstraintTarget({ xMm: 0, yMm: 0 }, [lineAtOrigin], selectionViewport, "pointOnLine");
    expect(first).toEqual({ controlPoint: { entityId: "line", point: "start" } });
    expect(
      preferredConstraintTarget({ xMm: 0, yMm: 0 }, [lineAtOrigin], selectionViewport, "pointOnLine", [
        pointAtOriginTarget(),
      ]),
    ).toEqual({
      entity: "line",
    });
  });
  it("uses only line bodies for line-based measurements and constraints", () => {
    expect(preferredConstraintTarget({ xMm: 0, yMm: 0 }, [lineAtOrigin], selectionViewport, "measureAngle")).toEqual({
      entity: "line",
    });
    expect(preferredConstraintTarget({ xMm: 0, yMm: 0 }, [lineAtOrigin], selectionViewport, "parallel")).toEqual({
      entity: "line",
    });
  });
  it("uses the arc body only for arc-sweep measurement", () => {
    const arcAtOrigin: RawEntity = {
      id: "arc",
      kind: { arc: { center: { xMm: 0, yMm: 0 }, radiusMm: 10, startAngleRad: 0, sweepAngleRad: Math.PI / 2 } },
    };
    expect(
      preferredConstraintTarget({ xMm: 10, yMm: 0 }, [arcAtOrigin], selectionViewport, "measureAngle"),
    ).toBeUndefined();
    expect(
      preferredConstraintTarget({ xMm: 10, yMm: 0 }, [arcAtOrigin], selectionViewport, "measureArcSweepAngle"),
    ).toEqual({
      entity: "arc",
    });
  });
  it("prefers source geometry over overlapping derived controls", () => {
    const derived = { ...lineAtOrigin, id: "derived:fillet:resolved:0" };
    expect(
      preferredConstraintTarget({ xMm: 0, yMm: 0 }, [derived, lineAtOrigin], selectionViewport, "distance"),
    ).toEqual({
      controlPoint: { entityId: "line", point: "start" },
    });
  });
  it("prefers a resolved fillet arc for an offset over nearby source lines", () => {
    const source: RawEntity = {
      id: "source",
      kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 20, yMm: 0 } } },
    };
    const filletArc: RawEntity = {
      id: "derived:fillet-a:resolved:1",
      kind: {
        arc: { center: { xMm: 18, yMm: 2 }, radiusMm: 2, startAngleRad: -Math.PI / 2, sweepAngleRad: Math.PI / 2 },
      },
    };
    expect(preferredConstraintTarget({ xMm: 19, yMm: 1 }, [source, filletArc], selectionViewport, "offset")).toEqual({
      entity: "derived:fillet-a:resolved:1",
    });
  });
});

function pointAtOriginTarget() {
  return { controlPoint: { entityId: "point", point: "center" as const } };
}
