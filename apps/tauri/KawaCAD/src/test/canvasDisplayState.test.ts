import { describe, expect, it } from "vitest";
import { canvasDisplayStateFor, visibleEntitiesFor } from "@/features/canvas/selectors/canvasDisplayState";
import type { State } from "@/shared/domain/coreWireTypes";

describe("canvas display state", () => {
  it("keeps only entities from visible layers", () => {
    const state = {
      layers: [
        { id: "layer:visible", visible: true },
        { id: "layer:hidden", visible: false },
      ],
      entities: [
        { id: "entity:visible", layerId: "layer:visible", kind: {} },
        { id: "entity:hidden", layerId: "layer:hidden", kind: {} },
        { id: "entity:unlayered", kind: {} },
      ],
    } as unknown as State;

    expect(visibleEntitiesFor(state).map((entity) => entity.id)).toEqual(["entity:visible", "entity:unlayered"]);
  });

  it("applies persisted annotation offsets while deriving display values", () => {
    const state = {
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [
          { id: "measurement:distance", startMm: { xMm: 0, yMm: 0 }, endMm: { xMm: 10, yMm: 0 }, visible: true },
        ],
        dimensionConstraints: [],
        constraintMarkers: [],
      },
      constraints: [],
      measurementAnnotations: [
        {
          id: "measurement:distance",
          kind: "distance",
          targets: [],
          labelOffsetMm: { xMm: 0, yMm: 0 },
          overallOffsetMm: { xMm: 2, yMm: 3 },
          visible: true,
        },
      ],
      measurementEvaluations: [{ annotationId: "measurement:distance", value: { fixedMm: 10 } }],
    } as unknown as State;

    const display = canvasDisplayStateFor(state);
    expect(display.projection.measurementAnnotations[0]).toMatchObject({
      startMm: { xMm: 2, yMm: 3 },
      endMm: { xMm: 12, yMm: 3 },
    });
    expect(display.measurementLabels["measurement:distance"]).toContain("10");
  });
});
