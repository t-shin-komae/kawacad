import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  CADCanvas,
  angleArcCounterclockwise,
  coincidentGroupIsVisible,
  displayStyleFor,
  entityIsVisible,
  lineDashPattern,
  outputPreviewPageRects,
} from "@/features/canvas/components/CadCanvas";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
import type { RawEntity } from "@/features/canvas/domain/cad";

afterEach(cleanup);

function canvas(
  tool: Tool,
  draftPoints: Array<{ xMm: number; yMm: number }> = [],
  pendingTargetCount = 0,
  options: {
    filletDraftEntityCount?: number;
    filletDraftClosed?: boolean;
    settingPartOrigin?: boolean;
    entities?: RawEntity[];
    layers?: Array<{
      id: string;
      visible: boolean;
      style: {
        stroke: { red: number; green: number; blue: number; alpha: number };
        strokeWidthMm: number;
        pattern: string;
      };
    }>;
    marqueeStart?: { xMm: number; yMm: number };
    marqueeCurrent?: { xMm: number; yMm: number };
  } = {},
) {
  return (
    <CADCanvas
      renderModel={{
        entities: options.entities ?? [],
        layers: options.layers ?? [],
        sharedStyles: [],
        freeTexts: [],
        editingFreeTextId: undefined,
        highlightedFreeTextIds: new Set(),
        highlightedMeasurementAnnotationIds: new Set(),
        highlightedStitchStartPointIds: new Set(),
        selectedIds: new Set(["selected"]),
        selectedMeasurementAnnotationId: undefined,
        selectedStitchStartPointId: undefined,
        viewport: { zoom: 1, panX: 0, panY: 0 },
        gridVisible: true,
        a4Visible: true,
        a4Landscape: false,
        outputPreview: false,
        outputPages: [],
        selectedPartOrigin: undefined,
        draftPoints,
        cursorPoint: undefined,
        arcSweepAngleRad: undefined,
        hoveredConstraintId: undefined,
        hoveredTargetEntityId: undefined,
        pendingTargetEntityIds: new Set(),
        marqueeStart: options.marqueeStart,
        marqueeCurrent: options.marqueeCurrent,
        dragDuplicating: false,
        dragging: false,
        snapActive: false,
        snapSuppressed: false,
        coincidentPointGroups: [],
        tool,
        projection: {
          stitchStartPoints: [],
          measurementAnnotations: [],
          dimensionConstraints: [],
          constraintMarkers: [],
        },
        measurementLabels: {},
        measurementLabelOffsets: {},
        measurementArcCounterclockwise: {},
        dimensionLabels: {},
        dimensionLabelOffsets: {},
        dimensionArcCounterclockwise: {},
      }}
      interactionModel={{
        pendingTargetCount,
        draftPointCount: draftPoints.length,
        settingPartOrigin: options.settingPartOrigin,
        filletDraftEntityCount: options.filletDraftEntityCount,
        filletDraftClosed: options.filletDraftClosed,
        toolName: tool === "line" ? "線分" : tool === "arc" ? "円弧" : "フィレット",
      }}
      events={{
        onPointerDown: vi.fn(),
        onPointerMove: vi.fn(),
        onPointerUp: vi.fn(),
        onDoubleClick: vi.fn(),
        onCommitFreeText: vi.fn(),
        onCancelFreeText: vi.fn(),
        onWheel: vi.fn(),
        onContextMenu: vi.fn(),
      }}
    />
  );
}

describe("Canvas accessibility parity", () => {
  it("exposes a stable canvas name and high-level interaction state", () => {
    render(canvas("line", [], 1));
    const element = screen.getByRole("application", { name: "型紙作図キャンバス" });
    expect(element).toHaveAttribute("aria-describedby", "cad-canvas-interaction-state");
    expect(screen.getByText(/線分、編集表示、選択 1 件、拘束対象 1 件、拘束対象を 1 件選択中/)).toBeInTheDocument();
    expect(screen.getByTestId("canvas-operation-guide")).toHaveTextContent("拘束対象を 1 件選択中");
  });

  it("hides the guide while the select tool is idle", () => {
    render(canvas("select"));
    expect(screen.queryByTestId("canvas-operation-guide")).not.toBeInTheDocument();
  });

  it("shows the selected drawing tool's next operation", () => {
    render(canvas("line"));
    expect(screen.getByTestId("canvas-operation-guide")).toHaveTextContent("線分の始点をクリックします");
  });
  it("reports arc drawing progress without exposing mutable canvas state", () => {
    render(
      canvas("arc", [
        { xMm: 0, yMm: 0 },
        { xMm: 10, yMm: 0 },
      ]),
    );
    expect(screen.getByTestId("canvas-operation-guide")).toHaveTextContent("円弧の終点を選択中");
  });
  it("reports drawing progress for a pending multi-reference tool", () => {
    render(canvas("fillet", [], 3));
    expect(
      screen.getByText(/フィレット、編集表示、選択 1 件、拘束対象 3 件、拘束対象を 3 件選択中/),
    ).toBeInTheDocument();
  });
  it("reports fillet draft references and part-origin placement as accessible state", () => {
    const { rerender } = render(canvas("fillet", [], 0, { filletDraftEntityCount: 3 }));
    expect(screen.getByTestId("canvas-operation-guide")).toHaveTextContent("フィレット対象 3 件、開いた輪郭");
    rerender(canvas("select", [], 0, { settingPartOrigin: true }));
    expect(screen.getByTestId("canvas-operation-guide")).toHaveTextContent("パーツ原点を選択中");
  });

  it("reports the same visible marquee candidates used by canvas selection", () => {
    const entities: RawEntity[] = [
      { id: "point:visible", layerId: "layer:visible", kind: { point: { xMm: 1, yMm: 1 } } },
      { id: "point:hidden", layerId: "layer:hidden", kind: { point: { xMm: 2, yMm: 2 } } },
    ];
    const layerStyle = {
      stroke: { red: 0, green: 0, blue: 0, alpha: 1 },
      strokeWidthMm: 0.2,
      pattern: "solid",
    };
    render(
      canvas("select", [], 0, {
        entities,
        layers: [
          { id: "layer:visible", visible: true, style: layerStyle },
          { id: "layer:hidden", visible: false, style: layerStyle },
        ],
        marqueeStart: { xMm: 0, yMm: 0 },
        marqueeCurrent: { xMm: 5, yMm: 5 },
      }),
    );
    expect(screen.getByTestId("canvas-operation-guide")).toHaveTextContent("完全に含まれる図形を選択: 1件");
  });
});

describe("Canvas line-style parity", () => {
  const baseStyle = {
    stroke: { red: 0.1, green: 0.2, blue: 0.3, alpha: 1 },
    strokeWidthMm: 2,
    pattern: "solid",
  };
  it("distinguishes center lines from ordinary line segments", () => {
    const regular = displayStyleFor(
      { id: "line", kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 10, yMm: 0 } } } },
      [],
      [{ id: "shared", style: baseStyle }],
    );
    const center = displayStyleFor(
      {
        id: "center",
        styleId: "shared",
        kind: { centerLine: { start: { xMm: 0, yMm: 0 }, end: { xMm: 10, yMm: 0 } } },
      },
      [],
      [{ id: "shared", style: baseStyle }],
    );

    expect(regular.pattern).toBe("solid");
    expect(lineDashPattern(regular.pattern, 2)).toBeUndefined();
    expect(center.pattern).toBe("construction");
    expect(lineDashPattern(center.pattern, 2)).toHaveLength(4);
    expect(center.stroke).not.toEqual(regular.stroke);
  });
});

describe("Angle constraint overlay", () => {
  it("uses the signed model angle to choose the Canvas arc direction", () => {
    expect(angleArcCounterclockwise(90)).toBe(true);
    expect(angleArcCounterclockwise(-90)).toBe(false);
    expect(angleArcCounterclockwise(0)).toBe(false);
    expect(angleArcCounterclockwise(undefined)).toBeUndefined();
  });
});

describe("Canvas coincident-group and layer-visibility parity", () => {
  it("shows a Core coincident-point group only when every target entity is visible", () => {
    const group = {
      id: "coincident-group:line-a",
      representative: { xMm: 4, yMm: 5 },
      targets: [{ entity: "line:a" }, { controlPoint: { entityId: "point:b", point: "center" } }],
    };
    expect(coincidentGroupIsVisible(group, new Set(["line:a", "point:b"]))).toBe(true);
    expect(coincidentGroupIsVisible(group, new Set(["line:a"]))).toBe(false);
  });
  it("does not render entities on a hidden layer", () => {
    const layers = [
      {
        id: "layer:hidden",
        visible: false,
        style: { stroke: { red: 0, green: 0, blue: 0, alpha: 1 }, strokeWidthMm: 0.2, pattern: "solid" },
      },
    ];
    expect(entityIsVisible({ id: "line:hidden", layerId: "layer:hidden", kind: {} }, layers)).toBe(false);
    expect(entityIsVisible({ id: "line:default", kind: {} }, layers)).toBe(true);
  });
});

describe("Canvas output-preview parity", () => {
  it("places Core output pages according to their A4 grid positions", () => {
    const pages = outputPreviewPageRects(
      [
        { widthMm: 210, heightMm: 297, gridColumn: -1, gridRow: 1 },
        { widthMm: 210, heightMm: 297, gridColumn: 1, gridRow: -1 },
      ],
      520,
      736,
      { zoom: 1, panX: 0, panY: 0 },
    );
    expect(pages).toHaveLength(2);
    expect(pages[0].x).toBeLessThan(pages[1].x);
    expect(pages[0].y).toBeLessThan(pages[1].y);
    expect(pages[0].width).toBe(pages[1].width);
    expect(pages[0].height).toBe(pages[1].height);
  });
  it("has no page rectangles outside output-preview state", () => {
    expect(outputPreviewPageRects([], 520, 736, { zoom: 1, panX: 0, panY: 0 })).toEqual([]);
  });
});
