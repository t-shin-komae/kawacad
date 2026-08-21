import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { InspectorSelectionTab } from "@/features/inspector/components/InspectorSelectionTab";
import type { SelectionInspectorModel } from "@/features/inspector/domain/inspectorViewModel";

const style = {
  stroke: { red: 0.07, green: 0.09, blue: 0.15, alpha: 1 },
  strokeWidthMm: 0.2,
  pattern: "solid",
};

function selectionModel(): SelectionInspectorModel {
  return {
    selectedCount: 1,
    documentSummary: {
      viewMode: "編集表示",
      activeLayerName: "Outline",
      visibleEntityCount: 1,
      constraintCount: 0,
      parameterCount: 0,
    },
    selectedEntityIds: ["line:selection"],
    selectedEntity: {
      id: "line:selection",
      kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 20, yMm: 0 } } },
    },
    constraints: [],
    measurements: [],
    freeTexts: [],
    parameters: [],
    layers: [{ id: "layer:outline", name: "Outline", visible: true, printable: true, kind: "cutLine", style }],
    sharedStyles: [],
    roundHoles: [],
    actions: {
      setConstraintValue: vi.fn(),
      setConstraintParameter: vi.fn(),
      deleteConstraint: vi.fn(),
      deleteMeasurement: vi.fn(),
      deleteEntity: vi.fn(),
      updateFreeText: vi.fn(),
      deleteFreeText: vi.fn(),
      setDerivedDistance: vi.fn(),
      setDerivedRadius: vi.fn(),
      setDerivedDirection: vi.fn(),
      setEntityLayer: vi.fn(),
      setDerivedLayer: vi.fn(),
      setEntityStyle: vi.fn(),
      setDerivedStyle: vi.fn(),
      setRoundHoleDiameter: vi.fn(),
      setRoundHoleKind: vi.fn(),
      setEntityMetric: vi.fn(),
      applyStyle: vi.fn(),
      deleteSelection: vi.fn(),
      constrainSegmentLength: vi.fn(),
      selectConstraint: vi.fn(),
      selectFreeText: vi.fn(),
      selectMeasurement: vi.fn(),
      convertMeasurement: vi.fn(),
    },
  };
}

describe("InspectorSelectionTab", () => {
  afterEach(cleanup);

  it("renders from a selection-only model without constructing the inspector shell", () => {
    render(<InspectorSelectionTab model={selectionModel()} />);

    expect(screen.getByText("線分")).toBeInTheDocument();
    expect(screen.getByRole("spinbutton", { name: "線分長 (mm)" })).toBeInTheDocument();
  });
});
