import { cleanup, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { App } from "@/app/App";
import {
  canvasProjectionFor,
  documentWindowPresentation,
  hitDerivedRadiusControl,
  partCanvasHighlights,
  selectedSourceArcId,
} from "@/shared/domain/workspaceState";
import { screenPoint, type Viewport } from "@/features/canvas/domain/cad";

const defaultTestViewport: Viewport = { zoom: 1, panX: 0, panY: 0 };

function canvasClientPoint(pointMm: { xMm: number; yMm: number }, width = 100, height = 100) {
  const point = screenPoint(pointMm, width, height, defaultTestViewport);
  return { clientX: point.x, clientY: point.y };
}

function showDetailedTools() {
  fireEvent.click(screen.getByRole("button", { name: "詳細ツールを表示" }));
  fireEvent.click(screen.getByRole("button", { name: "派生" }));
}

const state = {
  snapshot: { name: "Test project", statistics: {} },
  history: { canUndo: false, canRedo: false },
  persistence: { isDirty: false },
  settings: { orientation: "portrait" },
  entities: [{ id: "point-1", kind: { point: { xMm: 0, yMm: 0 } } }],
  layers: [
    {
      id: "layer:cut-line",
      name: "Cut Line",
      visible: true,
      printable: true,
      kind: "cutLine",
      style: { stroke: { red: 0, green: 0, blue: 0, alpha: 1 }, strokeWidthMm: 0.2, pattern: "solid" },
    },
  ],
  sharedStyles: [
    {
      id: "style:outer-cut-line",
      name: "外形カット線",
      style: { stroke: { red: 0, green: 0, blue: 0, alpha: 1 }, strokeWidthMm: 0.2, pattern: "solid" },
    },
  ],
  parameters: [],
  parts: [],
  constraints: [],
  freeTexts: [],
  derivedElements: [],
  roundHoles: [],
  stitchStartPoints: [],
  measurementAnnotations: [],
  measurementEvaluations: [],
  warnings: [],
};
const mocks = vi.hoisted(() => ({
  invoke: vi.fn(),
  confirm: vi.fn(),
  open: vi.fn(),
  save: vi.fn(),
  setTitle: vi.fn(),
  close: vi.fn(),
  destroy: vi.fn(),
  onCloseRequested: vi.fn(async () => () => undefined),
}));
const defaultInvoke = async (command: string) => {
  if (command === "document_state") return state;
  if (command === "recovery_candidate") return null;
  if (command === "export_selection")
    return { clipboardJson: "opaque-core-selection", anchorPoint: { xMm: 0, yMm: 0 } };
  if (command === "load_part_library") return [];
  return state;
};

vi.mock("@tauri-apps/api/core", () => ({ invoke: mocks.invoke }));
vi.mock("@tauri-apps/api/window", () => ({
  getCurrentWindow: () => ({
    setTitle: mocks.setTitle,
    close: mocks.close,
    destroy: mocks.destroy,
    onCloseRequested: mocks.onCloseRequested,
  }),
}));
vi.mock("@tauri-apps/plugin-dialog", () => ({ open: mocks.open, save: mocks.save, confirm: mocks.confirm }));

describe("React workspace shortcuts", () => {
  beforeEach(() => {
    Object.defineProperty(window, "innerWidth", { configurable: true, writable: true, value: 1600 });
    mocks.invoke.mockReset();
    mocks.invoke.mockImplementation(defaultInvoke);
    mocks.confirm.mockReset();
    mocks.open.mockReset();
    mocks.save.mockReset();
    mocks.setTitle.mockReset();
    mocks.close.mockReset();
    mocks.destroy.mockReset();
    mocks.onCloseRequested.mockReset();
    mocks.setTitle.mockResolvedValue(undefined);
    mocks.close.mockResolvedValue(undefined);
    mocks.onCloseRequested.mockResolvedValue(() => undefined);
    mocks.open.mockResolvedValue(undefined);
    mocks.save.mockResolvedValue(undefined);
    window.localStorage.clear();
  });
  afterEach(() => {
    cleanup();
    vi.unstubAllGlobals();
  });
  it("applies Core-persisted annotation offsets to canvas projection geometry", () => {
    const projection = canvasProjectionFor({
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [
          { id: "measurement:1", startMm: { xMm: 0, yMm: 0 }, endMm: { xMm: 10, yMm: 0 }, visible: true },
        ],
        dimensionConstraints: [
          { id: "constraint:1", startMm: { xMm: 0, yMm: 0 }, endMm: { xMm: 10, yMm: 0 }, visible: true },
        ],
        constraintMarkers: [],
      },
      constraints: [],
      measurementAnnotations: [
        {
          id: "measurement:1",
          kind: "distance",
          targets: [],
          labelOffsetMm: { xMm: 0, yMm: 0 },
          overallOffsetMm: { xMm: 2, yMm: 3 },
          visible: true,
        },
      ],
      dimensionConstraintAnnotations: [
        {
          constraintId: "constraint:1",
          labelOffsetMm: { xMm: 0, yMm: 0 },
          overallOffsetMm: { xMm: -1, yMm: 4 },
          visible: true,
        },
      ],
    });
    expect(projection.measurementAnnotations[0]).toMatchObject({
      startMm: { xMm: 2, yMm: 3 },
      endMm: { xMm: 12, yMm: 3 },
    });
    expect(projection.dimensionConstraints[0]).toMatchObject({
      startMm: { xMm: -1, yMm: 4 },
      endMm: { xMm: 9, yMm: 4 },
    });
  });
  it("adds SwiftUI constraint labels and stacks nearby canvas markers", () => {
    const projection = canvasProjectionFor({
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [],
        dimensionConstraints: [],
        constraintMarkers: [
          { id: "constraint:horizontal", positionMm: { xMm: 10, yMm: 0 }, visible: true },
          { id: "constraint:length", positionMm: { xMm: 10, yMm: 0 }, visible: true },
          { id: "constraint:unsupported", positionMm: { xMm: 10, yMm: 0 }, visible: true },
        ],
      },
      constraints: [
        { id: "constraint:horizontal", kind: "horizontal", status: "satisfied" },
        { id: "constraint:length", kind: "segmentLength", status: "satisfied" },
        { id: "constraint:unsupported", kind: "unsupported", status: "satisfied" },
      ],
      measurementAnnotations: [],
      dimensionConstraintAnnotations: [],
    });
    expect(projection.constraintMarkers).toEqual([
      expect.objectContaining({ id: "constraint:horizontal", label: "水平", stackIndex: 0 }),
      expect.objectContaining({ id: "constraint:length", label: "線分長", stackIndex: 1 }),
    ]);
  });
  it("only enables smooth arc tangencies for one non-derived arc", () => {
    const arc = {
      id: "arc:source",
      kind: { arc: { center: { xMm: 0, yMm: 0 }, radiusMm: 5, startAngleRad: 0, sweepAngleRad: 1 } },
    };
    expect(selectedSourceArcId(new Set(["arc:source"]), [arc], [])).toBe("arc:source");
    expect(
      selectedSourceArcId(
        new Set(["arc:source"]),
        [arc],
        [{ entityId: "arc:source", derivedElementId: "derived:fillet" }],
      ),
    ).toBeUndefined();
    expect(selectedSourceArcId(new Set(), [arc], [])).toBeUndefined();
  });
  it("expands a selected SwiftUI part into its entities and related canvas annotations", () => {
    const part = {
      id: "part:highlight",
      name: "Highlight",
      quantity: 1,
      visible: true,
      printable: true,
      originMm: { xMm: 2, yMm: 3 },
      entityIds: ["entity:base"],
      outlineEntityIds: ["entity:base"],
      holeEntityIdGroups: [],
      derivedElementIds: ["derived:stitch"],
      freeTextIds: ["free-text:note"],
      measurementAnnotationIds: ["measurement:width"],
    };
    expect(
      partCanvasHighlights(
        part,
        [{ entityId: "derived:stitch:resolved:0", derivedElementId: "derived:stitch" }],
        [{ id: "stitch:1", targetEntityId: "derived:stitch" }],
      ),
    ).toEqual({
      entityIds: new Set(["entity:base", "derived:stitch:resolved:0"]),
      freeTextIds: new Set(["free-text:note"]),
      measurementAnnotationIds: new Set(["measurement:width"]),
      stitchStartPointIds: new Set(["stitch:1"]),
    });
  });
  it("loads Core state and exposes the SwiftUI drawing shortcuts", async () => {
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.keyDown(window, { key: "3", metaKey: true });
    expect(screen.getByText("線分", { selector: ".toolbar-tool" })).toBeInTheDocument();
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    await waitFor(() => expect(screen.getAllByText(/1 選択/).length).toBeGreaterThan(0));
  });
  it("opens PDF output from the native File menu action", async () => {
    render(<App />);
    await screen.findByDisplayValue("Test project");
    window.dispatchEvent(new CustomEvent("kawa-cad-menu", { detail: "exportPDF" }));
    expect(await screen.findByRole("dialog", { name: "PDF出力" })).toBeInTheDocument();
  });
  it("uses unmodified V to return to Select", async () => {
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.keyDown(window, { key: "3", metaKey: true });
    expect(screen.getByText("線分", { selector: ".toolbar-tool" })).toBeInTheDocument();
    fireEvent.keyDown(window, { key: "v" });
    expect(screen.getByText("選択", { selector: ".toolbar-tool" })).toBeInTheDocument();
  });
  it("clears SwiftUI transient selection and drawing state after undo", async () => {
    const historyState = { ...state, history: { canUndo: true, canRedo: false } };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state" || command === "undo") return historyState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return historyState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    await waitFor(() => expect(screen.getAllByText(/1 選択/).length).toBeGreaterThan(0));
    fireEvent.click(screen.getByRole("button", { name: "線分" }));
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    fireEvent.keyDown(window, { key: "z", metaKey: true });
    await waitFor(() => expect(mocks.invoke).toHaveBeenCalledWith("undo"));
    expect(screen.queryByText(/1 選択/)).not.toBeInTheDocument();
    expect(screen.getByText("取り消しました。")).toBeInTheDocument();
  });
  it("clears SwiftUI transient selection and resets to Select when changing display modes", async () => {
    const previewState = {
      ...state,
      viewMode: "outputPreview",
      outputPreview: { pages: [], warnings: [] },
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return state;
      if (command === "set_view_mode") return previewState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return state;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.keyDown(window, { key: "3", metaKey: true });
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    await waitFor(() => expect(screen.getAllByText(/1 選択/).length).toBeGreaterThan(0));
    fireEvent.click(screen.getByRole("button", { name: "出力プレビュー" }));
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith("set_view_mode", {
        viewMode: "outputPreview",
      }),
    );
    expect(screen.queryByText(/1 選択/)).not.toBeInTheDocument();
    expect(screen.getByText("選択", { selector: ".toolbar-tool" })).toBeInTheDocument();
    expect(screen.getByText("出力プレビューに切り替えました。")).toBeInTheDocument();
  });
  it("uses a SwiftUI preselection as the initial fillet draft without another canvas click", async () => {
    const filletState = {
      ...state,
      entities: [
        { id: "line:1", kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 10, yMm: 0 } } } },
        { id: "line:2", kind: { lineSegment: { start: { xMm: 10, yMm: 0 }, end: { xMm: 10, yMm: 10 } } } },
        { id: "line:3", kind: { lineSegment: { start: { xMm: 10, yMm: 10 }, end: { xMm: 20, yMm: 10 } } } },
      ],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return filletState;
      if (command === "preflight_derived_element")
        return { offsetOptions: [], sourceEntityIds: ["line:1", "line:2", "line:3"], closed: false };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return filletState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    showDetailedTools();
    fireEvent.click(screen.getByRole("button", { name: "フィレット" }));
    expect(await screen.findByRole("dialog", { name: "フィレットの値" })).toHaveTextContent(
      "選択した 3 件の連続する要素にフィレットを作成します。",
    );
    expect(mocks.invoke).toHaveBeenCalledWith(
      "preflight_derived_element",
      expect.objectContaining({ kind: "fillet", selectedEntityIds: ["line:1", "line:2", "line:3"] }),
    );
    fireEvent.click(screen.getByRole("button", { name: "キャンセル" }));
    await waitFor(() => expect(screen.queryByRole("dialog", { name: "フィレットの値" })).not.toBeInTheDocument());
  });
  it("passes the offset click position to Core preflight for contour selection", async () => {
    const offsetState = {
      ...state,
      entities: [
        {
          id: "line:offset",
          kind: { lineSegment: { start: { xMm: -10, yMm: 0 }, end: { xMm: 10, yMm: 0 } } },
        },
      ],
      drawingEntityMetadata: [{ entityId: "line:offset" }],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return offsetState;
      if (command === "preflight_derived_element")
        return {
          offsetOptions: [
            { scope: "singleElement", sourceEntityIds: ["line:offset"], direction: "left" },
            { scope: "closedContour", sourceEntityIds: ["line:offset"], direction: "inward" },
          ],
          sourceEntityIds: ["line:offset"],
          closed: false,
        };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return offsetState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "offset" }));
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "preflight_derived_element",
        expect.objectContaining({
          kind: "offsetCurve",
          clickPoint: expect.objectContaining({ xMm: 0 }),
        }),
      ),
    );
  });
  it("keeps a fillet draft value while adding a source and rewinding it with Escape", async () => {
    const filletState = {
      ...state,
      entities: [
        { id: "line:1", kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 10, yMm: 0 } } } },
        { id: "line:2", kind: { lineSegment: { start: { xMm: 30, yMm: 0 }, end: { xMm: 30, yMm: 10 } } } },
        { id: "line:3", kind: { lineSegment: { start: { xMm: 50, yMm: 10 }, end: { xMm: 60, yMm: 10 } } } },
      ],
    };
    mocks.invoke.mockImplementation(async (command: string, args?: { selectedEntityIds?: string[] }) => {
      if (command === "document_state") return filletState;
      if (command === "preflight_derived_element")
        return { offsetOptions: [], sourceEntityIds: args?.selectedEntityIds ?? [], closed: false };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return filletState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    showDetailedTools();
    fireEvent.click(screen.getByRole("button", { name: "フィレット" }));
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 200, height: 100 }),
    });

    fireEvent.pointerDown(canvas, {
      ...canvasClientPoint({ xMm: 5, yMm: 0 }, 200),
      button: 0,
      ctrlKey: true,
      pointerId: 1,
    });
    fireEvent.pointerDown(canvas, {
      ...canvasClientPoint({ xMm: 30, yMm: 5 }, 200),
      button: 0,
      ctrlKey: true,
      pointerId: 2,
    });
    const dialog = await screen.findByRole("dialog", { name: "フィレットの値" });
    fireEvent.change(within(dialog).getByRole("textbox", { name: "値 (mm)" }), { target: { value: "6.5" } });

    fireEvent.pointerDown(canvas, {
      ...canvasClientPoint({ xMm: 55, yMm: 10 }, 200),
      button: 0,
      ctrlKey: true,
      pointerId: 3,
    });
    await waitFor(() => expect(dialog).toHaveTextContent("選択した 3 件の連続する要素にフィレットを作成します。"));
    expect(within(dialog).getByRole("textbox", { name: "値 (mm)" })).toHaveValue("6.5");

    fireEvent.keyDown(window, { key: "Escape" });
    await waitFor(() => expect(dialog).toHaveTextContent("選択した 2 件の連続する要素にフィレットを作成します。"));
    expect(within(dialog).getByRole("textbox", { name: "値 (mm)" })).toHaveValue("6.5");
    expect(mocks.invoke).toHaveBeenCalledWith(
      "preflight_derived_element",
      expect.objectContaining({ kind: "fillet", selectedEntityIds: ["line:1", "line:2"] }),
    );
  });
  it("updates an existing fillet radius when Core keeps its normalized sources", async () => {
    const filletState = {
      ...state,
      entities: [
        { id: "line:1", kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 10, yMm: 0 } } } },
        { id: "line:2", kind: { lineSegment: { start: { xMm: 10, yMm: 0 }, end: { xMm: 10, yMm: 10 } } } },
      ],
      derivedElements: [
        {
          id: "derived:fillet",
          kind: { fillet: { sourceEntityIds: ["line:1", "line:2"], radius: { fixedMm: 2 }, closed: false } },
        },
      ],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return filletState;
      if (command === "preflight_derived_element")
        return {
          offsetOptions: [],
          sourceEntityIds: ["line:1", "line:2"],
          updateDerivedElementId: "derived:fillet",
          closed: false,
        };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return filletState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    showDetailedTools();
    fireEvent.click(screen.getByRole("button", { name: "フィレット" }));
    await screen.findByRole("dialog", { name: "フィレットの値" });
    fireEvent.change(screen.getByRole("textbox", { name: "値 (mm)" }), { target: { value: "3.5" } });
    fireEvent.click(screen.getByRole("button", { name: "適用" }));
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({
          command: {
            kind: "setDerivedRadius",
            payload: { derivedElementId: "derived:fillet", value: { fixedMm: 3.5 } },
          },
        }),
      ),
    );
  });
  it("updates fillet sources and radius atomically when Core expands an existing fillet", async () => {
    const filletState = {
      ...state,
      entities: [
        { id: "line:1", kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 10, yMm: 0 } } } },
        { id: "line:2", kind: { lineSegment: { start: { xMm: 10, yMm: 0 }, end: { xMm: 10, yMm: 10 } } } },
        { id: "line:3", kind: { lineSegment: { start: { xMm: 10, yMm: 10 }, end: { xMm: 20, yMm: 10 } } } },
      ],
      derivedElements: [
        {
          id: "derived:fillet",
          kind: { fillet: { sourceEntityIds: ["line:1", "line:2"], radius: { fixedMm: 2 }, closed: false } },
        },
      ],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return filletState;
      if (command === "preflight_derived_element")
        return {
          offsetOptions: [],
          sourceEntityIds: ["line:1", "line:2", "line:3"],
          updateDerivedElementId: "derived:fillet",
          closed: false,
        };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return filletState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    showDetailedTools();
    fireEvent.click(screen.getByRole("button", { name: "フィレット" }));
    await screen.findByRole("dialog", { name: "フィレットの値" });
    fireEvent.click(screen.getByRole("button", { name: "適用" }));
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({
          command: {
            kind: "compound",
            payload: [
              {
                kind: "setFilletSources",
                payload: {
                  derivedElementId: "derived:fillet",
                  sourceEntityIds: ["line:1", "line:2", "line:3"],
                  closed: false,
                },
              },
              { kind: "setDerivedRadius", payload: { derivedElementId: "derived:fillet", value: { fixedMm: 2 } } },
            ],
          },
        }),
      ),
    );
  });
  it("duplicates a selected drawing with SwiftUI's five-millimetre offset", async () => {
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    fireEvent.keyDown(window, { key: "d", metaKey: true });
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({
          command: expect.objectContaining({
            kind: "duplicateSelection",
            payload: expect.objectContaining({ delta: { xMm: 5, yMm: 5 } }),
          }),
        }),
      ),
    );
  });
  it("creates a clockwise-over-180-degree arc with the SwiftUI sweep reference", async () => {
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.click(screen.getByRole("button", { name: "円弧" }));
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });

    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, ctrlKey: true, pointerId: 1 });
    fireEvent.pointerDown(canvas, { clientX: 60, clientY: 50, button: 0, ctrlKey: true, pointerId: 1 });
    fireEvent.pointerMove(canvas, { clientX: 50, clientY: 40, ctrlKey: true, pointerId: 1 });
    fireEvent.pointerMove(canvas, { clientX: 40, clientY: 50, ctrlKey: true, pointerId: 1 });
    fireEvent.pointerMove(canvas, { clientX: 40.603, clientY: 53.42, ctrlKey: true, pointerId: 1 });
    fireEvent.pointerDown(canvas, { clientX: 40.603, clientY: 53.42, button: 0, ctrlKey: true, pointerId: 1 });

    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({
          command: expect.objectContaining({
            kind: "createEntityFromGesture",
            payload: expect.objectContaining({
              gesture: expect.objectContaining({
                kind: "arc",
                sweepReferenceRad: expect.closeTo((200 * Math.PI) / 180, 3),
              }),
            }),
          }),
        }),
      ),
    );
  });
  it("makes the canvas and primary controls accessible by name", async () => {
    render(<App />);
    await screen.findByDisplayValue("Test project");
    expect(screen.getByRole("application", { name: "型紙作図キャンバス" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "インスペクタを表示" })).toBeInTheDocument();
    expect(screen.getByRole("status")).toBeInTheDocument();
  });
  it("confirms deletion when a SwiftUI layer still owns drawing data", async () => {
    const layeredState = {
      ...state,
      layers: [
        ...state.layers,
        {
          id: "layer:construction",
          name: "補助線",
          visible: true,
          printable: false,
          kind: "construction",
          style: { stroke: { red: 0.4, green: 0.4, blue: 0.4, alpha: 1 }, strokeWidthMm: 0.13, pattern: "dashed" },
        },
      ],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return layeredState;
      if (command === "layer_deletion_impact") return { entityCount: 1, derivedElementCount: 1 };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return layeredState;
    });

    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.click(screen.getByRole("tab", { name: "レイヤー" }));
    fireEvent.click(screen.getAllByRole("button", { name: "削除" })[0]);

    const dialog = await screen.findByRole("alertdialog", { name: "レイヤー削除の確認" });
    expect(dialog).toHaveTextContent("2 件の図形または派生要素がこのレイヤーを参照しています。");
    expect(mocks.invoke).not.toHaveBeenCalledWith(
      "apply_command",
      expect.objectContaining({ command: expect.objectContaining({ kind: "deleteLayer" }) }),
    );
    fireEvent.click(screen.getByRole("button", { name: "キャンセル" }));
    expect(screen.queryByRole("alertdialog", { name: "レイヤー削除の確認" })).not.toBeInTheDocument();
  });
  it("selects a free text on the canvas before underlying geometry and exposes its editor", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state")
        return {
          ...state,
          freeTexts: [{ id: "text:note", content: "注記", positionMm: { xMm: 0, yMm: 0 }, fontSizeMm: 3.2 }],
        };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return state;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    expect(screen.getByRole("textbox", { name: "テキスト内容" })).toHaveValue("注記");
  });
  it("ignores canvas selection and inline text interactions in output preview", async () => {
    const previewState = {
      ...state,
      viewMode: "outputPreview",
      outputPreview: { pages: [], warnings: [] },
      freeTexts: [{ id: "text:note", content: "注記", positionMm: { xMm: 0, yMm: 0 }, fontSizeMm: 3.2 }],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return previewState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return previewState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    expect(screen.queryByRole("textbox", { name: "テキスト内容" })).not.toBeInTheDocument();
    expect(mocks.invoke).not.toHaveBeenCalledWith("apply_command", expect.anything());
  });
  it("excludes hidden-layer entities from canvas selection", async () => {
    const hiddenState = {
      ...state,
      entities: [{ id: "point:hidden", layerId: "layer:hidden", kind: { point: { xMm: 0, yMm: 0 } } }],
      layers: [
        {
          ...state.layers[0],
          id: "layer:hidden",
          name: "Hidden",
          visible: false,
        },
      ],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return hiddenState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return hiddenState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    expect(screen.queryByText(/1 選択/)).not.toBeInTheDocument();
    expect(screen.getByText(/0 図形/)).toBeInTheDocument();
    fireEvent.contextMenu(canvas, { clientX: 50, clientY: 50, offsetX: 50, offsetY: 50 });
    expect(screen.queryByRole("menuitem", { name: "コピー" })).not.toBeInTheDocument();
    expect(screen.getByRole("menuitem", { name: "すべてを選択" })).toBeInTheDocument();
  });
  it("constrains the selected line length from the Inspector with Core's initial value", async () => {
    const lineState = {
      ...state,
      entities: [{ id: "line:1", kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 20, yMm: 0 } } } }],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return lineState;
      if (command === "preflight_constraint")
        return { kind: "segmentLength", normalizedTargets: [{ entity: "line:1" }], value: { fixedMm: 20 } };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return lineState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    fireEvent.click(screen.getByRole("button", { name: "現在の長さを拘束" }));
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({
          command: expect.objectContaining({
            kind: "addConstraint",
            payload: expect.objectContaining({ kind: "segmentLength", value: { fixedMm: 20 } }),
          }),
        }),
      ),
    );
  });
  it("offers a parameter reference while entering a dimensional constraint", async () => {
    const lineState = {
      ...state,
      entities: [{ id: "line:1", kind: { lineSegment: { start: { xMm: -10, yMm: 0 }, end: { xMm: 10, yMm: 0 } } } }],
      parameters: [{ id: "parameter:width", name: "幅", valueMm: 20, unit: "millimeter", memo: "" }],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return lineState;
      if (command === "preflight_constraint")
        return { kind: "segmentLength", normalizedTargets: [{ entity: "line:1" }], value: { fixedMm: 20 } };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return lineState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.click(screen.getByRole("button", { name: "線分長" }));
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, ctrlKey: true, pointerId: 1 });
    const dialog = await screen.findByRole("dialog", { name: "線分長の値" });
    fireEvent.click(screen.getByRole("button", { name: "パラメータ" }));
    fireEvent.change(screen.getByRole("combobox", { name: "パラメータ" }), { target: { value: "parameter:width" } });
    fireEvent.click(screen.getByRole("button", { name: "確定" }));
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({
          command: expect.objectContaining({
            kind: "addConstraint",
            payload: expect.objectContaining({ value: { parameter: "parameter:width" } }),
          }),
        }),
      ),
    );
    await waitFor(() => expect(dialog).not.toBeInTheDocument());
  });
  it("cancels a pending dimensional value entry before it changes Core", async () => {
    const lineState = {
      ...state,
      entities: [{ id: "line:1", kind: { lineSegment: { start: { xMm: -10, yMm: 0 }, end: { xMm: 10, yMm: 0 } } } }],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return lineState;
      if (command === "preflight_constraint")
        return { kind: "segmentLength", normalizedTargets: [{ entity: "line:1" }], value: { fixedMm: 20 } };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return lineState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.click(screen.getByRole("button", { name: "線分長" }));
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, ctrlKey: true, pointerId: 1 });
    await screen.findByRole("dialog", { name: "線分長の値" });
    fireEvent.keyDown(window, { key: "Escape" });
    await waitFor(() => expect(screen.queryByRole("dialog", { name: "線分長の値" })).not.toBeInTheDocument());
    expect(mocks.invoke).not.toHaveBeenCalledWith(
      "apply_command",
      expect.objectContaining({ command: expect.objectContaining({ kind: "addConstraint" }) }),
    );
  });
  it("selects a visible canvas constraint marker and opens its Inspector editor", async () => {
    const markerState = {
      ...state,
      constraints: [{ id: "constraint:length", kind: "segmentLength", status: "satisfied", value: { fixedMm: 20 } }],
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [],
        dimensionConstraints: [],
        constraintMarkers: [{ id: "constraint:length", positionMm: { xMm: 0, yMm: 0 }, visible: true }],
      },
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return markerState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return markerState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    expect(screen.getByRole("spinbutton", { name: "拘束値 (mm)" })).toHaveValue(20);
  });
  it("selects a constraint by clicking its SwiftUI marker label", async () => {
    const markerState = {
      ...state,
      constraints: [{ id: "constraint:length", kind: "segmentLength", status: "satisfied", value: { fixedMm: 20 } }],
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [],
        dimensionConstraints: [],
        constraintMarkers: [{ id: "constraint:length", positionMm: { xMm: 0, yMm: 0 }, visible: true }],
      },
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return markerState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return markerState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    // The marker is drawn above/right of the origin anchor (10px, -20px).
    fireEvent.pointerDown(canvas, { clientX: 71, clientY: 31, button: 0, pointerId: 1 });
    expect(screen.getByRole("spinbutton", { name: "拘束値 (mm)" })).toHaveValue(20);
  });
  it("selects a visible stitch-start point from the canvas", async () => {
    const stitchState = {
      ...state,
      stitchStartPoints: [{ id: "stitch:1", targetEntityId: "line:1" }],
      canvasProjection: {
        stitchStartPoints: [{ id: "stitch:1", positionMm: { xMm: 0, yMm: 0 }, visible: true }],
        measurementAnnotations: [],
        dimensionConstraints: [],
        constraintMarkers: [],
      },
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return stitchState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return stitchState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    expect(screen.getByText("縫い始め点", { selector: "strong" })).toBeInTheDocument();
    expect(screen.getByText("line:1")).toBeInTheDocument();
  });
  it("selects a visible measurement annotation from the canvas", async () => {
    const measurementState = {
      ...state,
      measurementAnnotations: [
        {
          id: "measurement:1",
          kind: "distance",
          targets: [],
          labelOffsetMm: { xMm: 0, yMm: 0 },
          overallOffsetMm: { xMm: 0, yMm: 0 },
          visible: true,
        },
      ],
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [
          { id: "measurement:1", startMm: { xMm: -10, yMm: 0 }, endMm: { xMm: 10, yMm: 0 }, visible: true },
        ],
        dimensionConstraints: [],
        constraintMarkers: [],
      },
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return measurementState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return measurementState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    expect(screen.getByText("計測表示を選択中")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "寸法拘束へ変換" })).toBeInTheDocument();
  });
  it("moves a selected measurement annotation with a canvas drag", async () => {
    const measurementState = {
      ...state,
      measurementAnnotations: [
        {
          id: "measurement:1",
          kind: "distance",
          targets: [],
          labelOffsetMm: { xMm: 0, yMm: 0 },
          overallOffsetMm: { xMm: 2, yMm: 3 },
          visible: true,
        },
      ],
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [
          { id: "measurement:1", startMm: { xMm: -10, yMm: 0 }, endMm: { xMm: 10, yMm: 0 }, visible: true },
        ],
        dimensionConstraints: [],
        constraintMarkers: [],
      },
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return measurementState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return measurementState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, {
      ...canvasClientPoint({ xMm: 2, yMm: 3 }),
      button: 0,
      ctrlKey: true,
      pointerId: 1,
    });
    fireEvent.pointerUp(canvas, { ...canvasClientPoint({ xMm: 12, yMm: 3 }), button: 0, pointerId: 1 });
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({
          command: {
            kind: "moveMeasurementAnnotation",
            payload: expect.objectContaining({
              annotationId: "measurement:1",
              delta: expect.objectContaining({ xMm: expect.closeTo(10) }),
              labelOnly: false,
            }),
          },
        }),
      ),
    );
  });
  it("selects and moves free text from the canvas", async () => {
    const freeTextState = {
      ...state,
      freeTexts: [{ id: "text:1", content: "A", positionMm: { xMm: 0, yMm: 0 }, fontSizeMm: 3 }],
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [],
        dimensionConstraints: [],
        constraintMarkers: [],
      },
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return freeTextState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return freeTextState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    expect(screen.getByText("テキストを選択中")).toBeInTheDocument();
    fireEvent.pointerUp(canvas, { ...canvasClientPoint({ xMm: 10, yMm: 0 }), button: 0, pointerId: 1 });
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({
          command: {
            kind: "updateFreeText",
            payload: expect.objectContaining({
              id: "text:1",
              positionMm: expect.objectContaining({ xMm: expect.closeTo(10), yMm: expect.closeTo(0) }),
            }),
          },
        }),
      ),
    );
  });
  it("edits free text inline after a canvas double click", async () => {
    const freeTextState = {
      ...state,
      freeTexts: [{ id: "text:1", content: "Before", positionMm: { xMm: 0, yMm: 0 }, fontSizeMm: 3 }],
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [],
        dimensionConstraints: [],
        constraintMarkers: [],
      },
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return freeTextState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return freeTextState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.doubleClick(canvas, { clientX: 50, clientY: 50 });
    const input = screen.getByRole("textbox", { name: "テキストを編集" });
    fireEvent.change(input, { target: { value: "After" } });
    fireEvent.keyDown(input, { key: "Enter" });
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({
          command: { kind: "updateFreeText", payload: expect.objectContaining({ id: "text:1", content: "After" }) },
        }),
      ),
    );
  });
  it("cancels special canvas selections before returning to the select tool", async () => {
    const freeTextState = {
      ...state,
      freeTexts: [{ id: "text:1", content: "A", positionMm: { xMm: 0, yMm: 0 }, fontSizeMm: 3 }],
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [],
        dimensionConstraints: [],
        constraintMarkers: [],
      },
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return freeTextState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return freeTextState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    expect(screen.getByText("テキストを選択中")).toBeInTheDocument();
    fireEvent.keyDown(window, { key: "Escape" });
    expect(screen.getAllByText("選択なし").length).toBeGreaterThan(0);
  });
  it("duplicates selected geometry when an Option drag is dropped", async () => {
    const canvasState = {
      ...state,
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [],
        dimensionConstraints: [],
        constraintMarkers: [],
      },
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return canvasState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return canvasState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    fireEvent.pointerUp(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 2 });
    fireEvent.pointerUp(canvas, {
      ...canvasClientPoint({ xMm: 10, yMm: 0 }),
      button: 0,
      altKey: true,
      pointerId: 2,
    });
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({
          command: expect.objectContaining({
            kind: "duplicateSelection",
            payload: expect.objectContaining({
              selection: { entityIds: ["point-1"] },
              delta: expect.objectContaining({ xMm: expect.closeTo(10) }),
            }),
          }),
        }),
      ),
    );
  });
  it("duplicates the whole part when an Option drag starts from a part member", async () => {
    const part = {
      id: "part:dragged",
      name: "Dragged part",
      quantity: 1,
      visible: true,
      printable: true,
      originMm: { xMm: 0, yMm: 0 },
      entityIds: ["point-1"],
      outlineEntityIds: ["point-1"],
      holeEntityIdGroups: [],
      derivedElementIds: [],
      freeTextIds: [],
      measurementAnnotationIds: [],
    };
    const partState = {
      ...state,
      parts: [part],
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [],
        dimensionConstraints: [],
        constraintMarkers: [],
      },
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return partState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return partState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    fireEvent.pointerUp(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 2 });
    fireEvent.pointerUp(canvas, {
      ...canvasClientPoint({ xMm: 10, yMm: 0 }),
      button: 0,
      altKey: true,
      pointerId: 2,
    });

    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({
          command: {
            kind: "duplicatePart",
            payload: expect.objectContaining({
              partId: "part:dragged",
              newPartId: expect.stringMatching(/^part:/),
              newName: "Dragged part のコピー",
              idNamespace: expect.any(String),
              delta: expect.objectContaining({ xMm: expect.closeTo(10) }),
            }),
          },
        }),
      ),
    );
  });
  it("uses a non-destructive Core preview while dragging and discards it on Escape", async () => {
    const canvasState = {
      ...state,
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [],
        dimensionConstraints: [],
        constraintMarkers: [],
      },
    };
    const movedPreview = {
      ...canvasState,
      entities: [{ id: "point-1", kind: { point: { xMm: 10, yMm: 0 } } }],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return canvasState;
      if (command === "preview_command") return movedPreview;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return canvasState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    fireEvent.pointerUp(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 2 });
    fireEvent.pointerMove(canvas, { ...canvasClientPoint({ xMm: 10, yMm: 0 }), pointerId: 2 });
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "preview_command",
        expect.objectContaining({
          command: {
            kind: "moveEntities",
            payload: expect.objectContaining({
              entityIds: ["point-1"],
              delta: expect.objectContaining({ xMm: expect.closeTo(10) }),
            }),
          },
        }),
      ),
    );
    expect(screen.getByText("移動プレビュー中")).toBeInTheDocument();
    fireEvent.keyDown(window, { key: "Escape" });
    fireEvent.pointerUp(canvas, { ...canvasClientPoint({ xMm: 10, yMm: 0 }), button: 0, pointerId: 2 });
    expect(screen.getAllByText(/1 選択/).length).toBeGreaterThan(0);
    expect(screen.getByText("移動プレビューを取り消しました。")).toBeInTheDocument();
    expect(mocks.invoke).not.toHaveBeenCalledWith(
      "apply_command",
      expect.objectContaining({ command: expect.objectContaining({ kind: "moveEntities" }) }),
    );
  });
  it("keeps a selected point ahead of an overlapping later line while dragging", async () => {
    const overlappingState = {
      ...state,
      entities: [
        { id: "point:front", kind: { point: { xMm: 0, yMm: 0 } } },
        { id: "line:later", kind: { lineSegment: { start: { xMm: -20, yMm: 0 }, end: { xMm: 20, yMm: 0 } } } },
      ],
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [],
        dimensionConstraints: [],
        constraintMarkers: [],
      },
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return overlappingState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return overlappingState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });

    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, ctrlKey: true, pointerId: 1 });
    fireEvent.pointerUp(canvas, { clientX: 50, clientY: 50, button: 0, ctrlKey: true, pointerId: 1 });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, ctrlKey: true, pointerId: 2 });
    fireEvent.pointerUp(canvas, { clientX: 50, clientY: 40, button: 0, ctrlKey: true, pointerId: 2 });

    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({
          command: expect.objectContaining({
            kind: "moveEntities",
            payload: expect.objectContaining({ entityIds: ["point:front"] }),
          }),
        }),
      ),
    );
  });
  it("offers SwiftUI-equivalent paste placement choices and reuses the pasted namespace", async () => {
    const pastedState = {
      ...state,
      entities: [...state.entities, { id: "point:pasted", kind: { point: { xMm: 10, yMm: 0 } } }],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return state;
      if (command === "export_selection")
        return { clipboardJson: "opaque-core-selection", anchorPoint: { xMm: 0, yMm: 0 } };
      if (command === "apply_command") return pastedState;
      if (command === "undo") return state;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return state;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    fireEvent.keyDown(window, { key: "c", metaKey: true });
    await waitFor(() => expect(mocks.invoke).toHaveBeenCalledWith("export_selection", expect.anything()));
    fireEvent.pointerMove(canvas, { ...canvasClientPoint({ xMm: 10, yMm: 0 }), pointerId: 1 });
    fireEvent.keyDown(window, { key: "v", metaKey: true });
    await screen.findByRole("group", { name: "貼り付け位置" });
    const firstPaste = mocks.invoke.mock.calls.find(
      ([command, request]) => command === "apply_command" && request.command.kind === "pasteSelection",
    )?.[1].command.payload;
    expect(firstPaste.delta.xMm).toBe(10);
    expect(firstPaste.delta.yMm).toBeCloseTo(0);
    const namespace = firstPaste.idNamespace;

    fireEvent.click(screen.getByRole("button", { name: "元図形の近く" }));
    await waitFor(() => expect(mocks.invoke).toHaveBeenCalledWith("undo"));
    await waitFor(() => {
      const pastes = mocks.invoke.mock.calls.filter(
        ([command, request]) => command === "apply_command" && request.command.kind === "pasteSelection",
      );
      expect(pastes).toHaveLength(2);
      expect(pastes[1][1].command.payload.idNamespace).toBe(namespace);
      expect(pastes[1][1].command.payload.delta).toEqual({ xMm: 5, yMm: 5 });
    });
  });
  it("dismisses paste placement with Escape before clearing canvas selection", async () => {
    const pastedState = { ...state, entities: [...state.entities, { id: "point:pasted", kind: { point: {} } }] };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return state;
      if (command === "export_selection")
        return { clipboardJson: "opaque-core-selection", anchorPoint: { xMm: 0, yMm: 0 } };
      if (command === "apply_command") return pastedState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return state;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    fireEvent.keyDown(window, { key: "c", metaKey: true });
    await waitFor(() => expect(mocks.invoke).toHaveBeenCalledWith("export_selection", expect.anything()));
    fireEvent.keyDown(window, { key: "v", metaKey: true });
    await screen.findByRole("group", { name: "貼り付け位置" });
    fireEvent.keyDown(window, { key: "Escape" });
    expect(screen.queryByRole("group", { name: "貼り付け位置" })).not.toBeInTheDocument();
    expect(screen.getAllByText(/1 選択/).length).toBeGreaterThan(0);
    expect(screen.getByText("貼り付け位置の選択を閉じました。")).toBeInTheDocument();
  });
  it("selects and moves a displayed dimension constraint from the canvas", async () => {
    const dimensionState = {
      ...state,
      constraints: [{ id: "constraint:1", kind: "segmentLength", status: "unknown", value: { fixedMm: 20 } }],
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [],
        dimensionConstraints: [
          { id: "constraint:1", startMm: { xMm: -10, yMm: 0 }, endMm: { xMm: 10, yMm: 0 }, visible: true },
        ],
        constraintMarkers: [],
      },
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return dimensionState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return dimensionState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { clientX: 50, clientY: 50, button: 0, pointerId: 1 });
    expect(screen.getByText("拘束を選択中")).toBeInTheDocument();
    fireEvent.pointerUp(canvas, { ...canvasClientPoint({ xMm: 10, yMm: 0 }), button: 0, pointerId: 1 });
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({
          command: {
            kind: "moveDimensionConstraintAnnotation",
            payload: expect.objectContaining({
              constraintId: "constraint:1",
              delta: expect.objectContaining({ xMm: expect.closeTo(10) }),
              labelOnly: true,
            }),
          },
        }),
      ),
    );
  });
  it("uses the SwiftUI-style editable document header", async () => {
    render(<App />);
    const name = await screen.findByRole("textbox", { name: "プロジェクト名" });
    expect(name).toHaveValue("Test project");
    expect(screen.getByText(".kawa 0.1.0 / mm / A4 Portrait")).toBeInTheDocument();
    fireEvent.change(name, { target: { value: "Renamed project" } });
    fireEvent.blur(name);
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({ command: { kind: "renameDocument", payload: { name: "Renamed project" } } }),
      ),
    );
  });
  it("commits an in-progress document name before saving the current project", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state")
        return { ...state, persistence: { isDirty: true, hasPath: true, path: "/projects/current.kawa" } };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return state;
    });
    render(<App />);
    const name = await screen.findByRole("textbox", { name: "プロジェクト名" });
    fireEvent.change(name, { target: { value: "保存する名称" } });
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "save" }));
    await waitFor(() => expect(mocks.invoke).toHaveBeenCalledWith("save_current_document"));
    const renameIndex = mocks.invoke.mock.calls.findIndex(
      ([command, payload]) =>
        command === "apply_command" &&
        (payload as { command?: { kind?: string; payload?: { name?: string } } }).command?.kind === "renameDocument",
    );
    const saveIndex = mocks.invoke.mock.calls.findIndex(([command]) => command === "save_current_document");
    expect(renameIndex).toBeGreaterThanOrEqual(0);
    expect(renameIndex).toBeLessThan(saveIndex);
  });
  it("blocks saving when the in-progress document name is invalid", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return { ...state, persistence: { isDirty: true, hasPath: true } };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return state;
    });
    render(<App />);
    const name = await screen.findByRole("textbox", { name: "プロジェクト名" });
    fireEvent.change(name, { target: { value: "   " } });
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "save" }));
    await waitFor(() => expect(screen.getByText("プロジェクト名を入力してください。")).toBeInTheDocument());
    expect(mocks.invoke).not.toHaveBeenCalledWith("save_current_document");
    expect(mocks.invoke).not.toHaveBeenCalledWith(
      "apply_command",
      expect.objectContaining({ command: expect.objectContaining({ kind: "renameDocument" }) }),
    );
  });
  it("blocks a replacement action when the in-progress document name is invalid", async () => {
    render(<App />);
    const name = await screen.findByRole("textbox", { name: "プロジェクト名" });
    fireEvent.change(name, { target: { value: "   " } });
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "new" }));
    await waitFor(() => expect(screen.getByText("プロジェクト名を入力してください。")).toBeInTheDocument());
    expect(screen.queryByRole("dialog", { name: "新規プロジェクト" })).not.toBeInTheDocument();
    expect(mocks.invoke).not.toHaveBeenCalledWith("new_document", expect.anything());
  });
  it("uses a committed project name for Save As even when the dialog is cancelled", async () => {
    render(<App />);
    const name = await screen.findByRole("textbox", { name: "プロジェクト名" });
    fireEvent.change(name, { target: { value: "別名保存する名称" } });
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "saveAs" }));
    await waitFor(() => expect(mocks.save).toHaveBeenCalledOnce());
    expect(mocks.save).toHaveBeenCalledWith(expect.objectContaining({ defaultPath: "別名保存する名称.kawa" }));
    expect(mocks.invoke).toHaveBeenCalledWith(
      "apply_command",
      expect.objectContaining({
        command: { kind: "renameDocument", payload: { name: "別名保存する名称" } },
      }),
    );
    expect(mocks.invoke).not.toHaveBeenCalledWith("save_document", expect.anything());
  });
  it("normalizes an extensionless Save As path and only offers .kawa files", async () => {
    mocks.save.mockResolvedValue("/projects/wallet-pattern");
    render(<App />);
    await screen.findByDisplayValue("Test project");

    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "saveAs" }));

    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith("save_document", { path: "/projects/wallet-pattern.kawa" }),
    );
    expect(mocks.save).toHaveBeenCalledWith({
      defaultPath: "Test project.kawa",
      filters: [{ name: "KawaCAD project", extensions: ["kawa"] }],
    });
  });
  it("keeps the current selection when creating a replacement document fails", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "new_document") throw new Error("create failed");
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return state;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    await waitFor(() => expect(screen.getAllByText(/1 選択/).length).toBeGreaterThan(0));
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "new" }));
    const dialog = await screen.findByRole("dialog", { name: "新規プロジェクト" });
    fireEvent.click(within(dialog).getByRole("button", { name: "適用" }));
    await waitFor(() => expect(screen.getByText("Error: create failed")).toBeInTheDocument());
    expect(screen.getAllByText(/1 選択/).length).toBeGreaterThan(0);
  });
  it("keeps an uncommitted project-name draft when creating a replacement document fails", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "new_document") throw new Error("create failed");
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return state;
    });
    render(<App />);
    const name = await screen.findByRole("textbox", { name: "プロジェクト名" });
    fireEvent.change(name, { target: { value: "入力中の名称" } });
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "new" }));
    const dialog = await screen.findByRole("dialog", { name: "新規プロジェクト" });
    fireEvent.click(within(dialog).getByRole("button", { name: "適用" }));
    await waitFor(() => expect(screen.getByText("Error: create failed")).toBeInTheDocument());
    expect(name).toHaveValue("入力中の名称");
    expect(mocks.invoke).not.toHaveBeenCalledWith(
      "apply_command",
      expect.objectContaining({ command: expect.objectContaining({ kind: "renameDocument" }) }),
    );
  });
  it("keeps the current selection when opening a replacement document fails", async () => {
    mocks.open.mockResolvedValue("/projects/broken.kawa");
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "open_document") throw new Error("open failed");
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return state;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    await waitFor(() => expect(screen.getAllByText(/1 選択/).length).toBeGreaterThan(0));
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "open" }));
    await waitFor(() => expect(screen.getByText("Error: open failed")).toBeInTheDocument());
    expect(screen.getAllByText(/1 選択/).length).toBeGreaterThan(0);
  });
  it("uses the SwiftUI-style inspector tabs and compact tool filter", async () => {
    render(<App />);
    await screen.findByDisplayValue("Test project");
    expect(screen.getByRole("tab", { name: "選択" })).toHaveAttribute("aria-selected", "true");
    fireEvent.click(screen.getByRole("tab", { name: "レイヤー" }));
    expect(screen.getByRole("button", { name: "レイヤーを追加" })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("tab", { name: "共有スタイル" }));
    expect(screen.getByRole("button", { name: "共有線種を追加" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "詳細ツールを表示" })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "詳細ツールを表示" }));
    fireEvent.click(screen.getByRole("button", { name: "基本ツールだけを表示" }));
    expect(screen.queryByTitle("一致")).not.toBeInTheDocument();
  });
  it("applies a bulk style through owner commands for resolved derived entities", async () => {
    const styleState = {
      ...state,
      entities: [
        { id: "entity:base", kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 10, yMm: 0 } } } },
        { id: "entity:derived", kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 10, yMm: 0 } } } },
      ],
      sharedStyles: [
        ...state.sharedStyles,
        { id: "style:stitch", name: "縫い線", style: { ...state.sharedStyles[0].style, pattern: "dashed" } },
      ],
      drawingEntityMetadata: [
        { entityId: "entity:base" },
        { entityId: "entity:derived", derivedElementId: "derived:offset" },
      ],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return styleState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return styleState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    const stylePicker = await screen.findByRole("combobox", { name: "選択図形の共有線種" });
    fireEvent.change(stylePicker, { target: { value: "style:stitch" } });
    const bulkStyleButtons = screen.getAllByRole("button", { name: "選択へ適用" });
    fireEvent.click(bulkStyleButtons[bulkStyleButtons.length - 1]);

    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({
          command: {
            kind: "compound",
            payload: [
              { kind: "setEntitySharedStyle", payload: { entityId: "entity:base", styleId: "style:stitch" } },
              {
                kind: "setDerivedSharedStyle",
                payload: { derivedElementId: "derived:offset", styleId: "style:stitch" },
              },
            ],
          },
        }),
      ),
    );
  });
  it("resets inspector tabs and search state when a new document replaces the current one", async () => {
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.click(screen.getByRole("tab", { name: "レイヤー" }));
    fireEvent.change(screen.getByRole("searchbox", { name: "レイヤーを検索" }), { target: { value: "cut" } });
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "new" }));
    const dialog = await screen.findByRole("dialog", { name: "新規プロジェクト" });
    fireEvent.change(within(dialog).getByRole("textbox", { name: "プロジェクト名" }), {
      target: { value: "Replacement" },
    });
    fireEvent.click(within(dialog).getByRole("button", { name: "適用" }));
    await waitFor(() => expect(screen.getByRole("tab", { name: "選択" })).toHaveAttribute("aria-selected", "true"));
    fireEvent.click(screen.getByRole("tab", { name: "レイヤー" }));
    expect(screen.getByRole("searchbox", { name: "レイヤーを検索" })).toHaveValue("");
  });
  it("uses the native warning confirmation before replacing a dirty document", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return { ...state, persistence: { isDirty: true } };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return state;
    });
    mocks.confirm.mockResolvedValue(false);
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "new" }));
    await waitFor(() =>
      expect(mocks.confirm).toHaveBeenCalledWith(expect.stringContaining("未保存の変更"), expect.any(Object)),
    );
    expect(screen.queryByRole("dialog", { name: "新規プロジェクト" })).not.toBeInTheDocument();
    expect(mocks.invoke).not.toHaveBeenCalledWith("new_document", expect.anything());
  });
  it("saves a dirty document before opening the SwiftUI new-project entry", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state")
        return { ...state, persistence: { isDirty: true, hasPath: true, path: "/projects/dirty.kawa" } };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return state;
    });
    mocks.confirm.mockResolvedValue(true);
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "new" }));
    await waitFor(() => expect(mocks.invoke).toHaveBeenCalledWith("save_document", { path: "/projects/dirty.kawa" }));
    expect(await screen.findByRole("dialog", { name: "新規プロジェクト" })).toBeInTheDocument();
  });
  it("saves a dirty document before opening another project", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state")
        return { ...state, persistence: { isDirty: true, hasPath: true, path: "/projects/dirty.kawa" } };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return state;
    });
    mocks.confirm.mockResolvedValue(true);
    mocks.open.mockResolvedValue("/projects/opened.kawa");
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "open" }));
    await waitFor(() => expect(mocks.invoke).toHaveBeenCalledWith("save_document", { path: "/projects/dirty.kawa" }));
    expect(mocks.open).toHaveBeenCalledWith({
      multiple: false,
      filters: [{ name: "KawaCAD project", extensions: ["kawa"] }],
    });
    expect(mocks.invoke).toHaveBeenCalledWith("open_document", { path: "/projects/opened.kawa" });
  });
  it("keeps an unsaved dirty document when the save dialog is cancelled", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return { ...state, persistence: { isDirty: true } };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return state;
    });
    mocks.confirm.mockResolvedValue(true);
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "new" }));
    await waitFor(() => expect(mocks.save).toHaveBeenCalledOnce());
    expect(screen.queryByRole("dialog", { name: "新規プロジェクト" })).not.toBeInTheDocument();
    expect(mocks.invoke).not.toHaveBeenCalledWith("new_document", expect.anything());
  });
  it("resizes the tool palette within the SwiftUI range and restores its default", async () => {
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const handle = screen.getByRole("separator", { name: "ツールパレットの幅" });
    expect(handle).toHaveAttribute("aria-valuenow", "176");
    fireEvent.keyDown(handle, { key: "ArrowRight" });
    expect(handle).toHaveAttribute("aria-valuenow", "184");
    expect(window.localStorage.getItem("leather.layout.toolPanelWidth")).toBe("184");
    fireEvent.keyDown(handle, { key: "End" });
    expect(handle).toHaveAttribute("aria-valuenow", "260");
    fireEvent.keyDown(handle, { key: "Home" });
    expect(handle).toHaveAttribute("aria-valuenow", "176");
    expect(window.localStorage.getItem("leather.layout.toolPanelWidth")).toBeNull();
  });
  it("persists the SwiftUI tool-palette and inspector preferences", async () => {
    render(<App />);
    await screen.findByDisplayValue("Test project");
    expect(screen.getByRole("button", { name: "詳細ツールを表示" })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "詳細ツールを表示" }));
    expect(window.localStorage.getItem("leather.toolPalette.showsDetailedTools")).toBe("true");
    fireEvent.click(screen.getByRole("button", { name: "基本ツールだけを表示" }));
    expect(window.localStorage.getItem("leather.toolPalette.showsDetailedTools")).toBeNull();
    fireEvent.click(screen.getByRole("button", { name: "詳細ツールを表示" }));
    expect(window.localStorage.getItem("leather.toolPalette.showsDetailedTools")).toBe("true");
    expect(screen.getByRole("button", { name: "派生" })).toHaveAttribute("aria-expanded", "false");
    fireEvent.click(screen.getByRole("button", { name: "派生" }));
    expect(window.localStorage.getItem("leather.toolPalette.groupCollapsed.v1.derived")).toBeNull();
    fireEvent.click(screen.getByRole("button", { name: "派生" }));
    expect(window.localStorage.getItem("leather.toolPalette.groupCollapsed.v1.derived")).toBe("true");
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "toggleInspector" }));
    await waitFor(() => expect(window.localStorage.getItem("leather.layout.inspectorPanelVisible")).toBe("false"));
  });
  it("accepts native menu intents through the same command path", async () => {
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "circle" }));
    await waitFor(() => expect(screen.getByText("円", { selector: ".toolbar-tool" })).toBeInTheDocument());
  });
  it("opens, closes, and reopens bundled OSS notices from the native menu action", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          components: [
            { name: "first", version: "1", license: "MIT", text: "first notice" },
            { name: "last", version: "2", license: "Apache-2.0", text: "last notice" },
          ],
        }),
      }),
    );
    render(<App />);
    await screen.findByDisplayValue("Test project");

    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "openLicenses" }));
    expect(await screen.findByText("last notice", { exact: true })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "閉じる" }));
    expect(screen.queryByRole("dialog", { name: "OSSライセンス" })).not.toBeInTheDocument();
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "openLicenses" }));
    expect(await screen.findByText("last notice", { exact: true })).toBeInTheDocument();
  });
  it("reloads the saved document through the adapter command", async () => {
    const reloadedState = {
      ...state,
      snapshot: { ...state.snapshot, name: "Reloaded project" },
      persistence: { isDirty: false, hasPath: true, path: "/projects/reloaded.kawa" },
      layers: [{ ...state.layers[0], id: "layer:reloaded", name: "Reloaded layer" }],
      sharedStyles: [{ ...state.sharedStyles[0], id: "style:reloaded", name: "Reloaded style" }],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return state;
      if (command === "reload_document") return reloadedState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return state;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    await waitFor(() => expect(screen.getAllByText(/1 選択/).length).toBeGreaterThan(0));
    fireEvent.keyDown(window, { key: "3", metaKey: true });
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "reload" }));
    await waitFor(() => expect(mocks.invoke).toHaveBeenCalledWith("reload_document"));
    expect(await screen.findByDisplayValue("Reloaded project")).toBeInTheDocument();
    expect(screen.getByRole("combobox", { name: "作図レイヤー" })).toHaveValue("layer:reloaded");
    expect(screen.getByRole("combobox", { name: "型紙線種" })).toHaveValue("style:reloaded");
    expect(screen.queryByText(/1 選択/)).not.toBeInTheDocument();
    expect(screen.getByText("選択", { selector: ".toolbar-tool" })).toBeInTheDocument();
    expect(screen.getByText("ドキュメントを再読み込みしました。")).toBeInTheDocument();
  });
  it("preserves the current UI state when reloading fails", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "reload_document") throw new Error("reload failed");
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return state;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    await waitFor(() => expect(screen.getAllByText(/1 選択/).length).toBeGreaterThan(0));
    fireEvent(window, new CustomEvent("kawa-cad-menu", { detail: "reload" }));
    await waitFor(() => expect(screen.getByText("Error: reload failed")).toBeInTheDocument());
    expect(screen.getByDisplayValue("Test project")).toBeInTheDocument();
    expect(screen.getAllByText(/1 選択/).length).toBeGreaterThan(0);
  });
  it("exposes the canvas context menu with accessible actions", async () => {
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.contextMenu(screen.getByRole("application", { name: "型紙作図キャンバス" }), {
      clientX: 12,
      clientY: 14,
      offsetX: 12,
      offsetY: 14,
    });
    expect(screen.getByRole("menu")).toBeInTheDocument();
    expect(screen.getByRole("menuitem", { name: "すべてを選択" })).toBeInTheDocument();
  });
  it("uses the measurement-specific SwiftUI context actions", async () => {
    const measurementState = {
      ...state,
      measurementAnnotations: [
        {
          id: "measurement:1",
          kind: "distance",
          targets: [],
          labelOffsetMm: { xMm: 0, yMm: 0 },
          overallOffsetMm: { xMm: 0, yMm: 0 },
          visible: true,
        },
      ],
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [
          { id: "measurement:1", startMm: { xMm: -10, yMm: 0 }, endMm: { xMm: 10, yMm: 0 }, visible: true },
        ],
        dimensionConstraints: [],
        constraintMarkers: [],
      },
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return measurementState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return measurementState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.contextMenu(canvas, { clientX: 50, clientY: 50, offsetX: 50, offsetY: 50 });
    expect(screen.getByRole("menuitem", { name: "寸法拘束へ変換" })).toBeInTheDocument();
    expect(screen.queryByRole("menuitem", { name: "コピー" })).not.toBeInTheDocument();
  });
  it("runs the SwiftUI smooth-tangencies command from an arc context menu", async () => {
    const arcState = {
      ...state,
      entities: [
        {
          id: "arc:1",
          kind: { arc: { center: { xMm: 0, yMm: 0 }, radiusMm: 10, startAngleRad: 0, sweepAngleRad: Math.PI / 2 } },
        },
      ],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return arcState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return arcState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    const arcPoint = canvasClientPoint({ xMm: 10, yMm: 0 });
    fireEvent.contextMenu(canvas, {
      ...arcPoint,
      offsetX: arcPoint.clientX,
      offsetY: arcPoint.clientY,
    });
    expect(screen.queryByRole("menuitem", { name: "貼り付け" })).not.toBeInTheDocument();
    expect(screen.queryByRole("menuitem", { name: "すべてを選択" })).not.toBeInTheDocument();
    fireEvent.click(await screen.findByRole("menuitem", { name: "両端を接線化（試作）" }));
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({ command: { kind: "smoothArcTangencies", payload: { arcEntityId: "arc:1" } } }),
      ),
    );
  });
  it("opens the inline editor from the free-text context action", async () => {
    const freeTextState = {
      ...state,
      freeTexts: [{ id: "text:1", content: "Note", positionMm: { xMm: 0, yMm: 0 }, fontSizeMm: 3 }],
      canvasProjection: {
        stitchStartPoints: [],
        measurementAnnotations: [],
        dimensionConstraints: [],
        constraintMarkers: [],
      },
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return freeTextState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return freeTextState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.contextMenu(canvas, { clientX: 50, clientY: 50, offsetX: 50, offsetY: 50 });
    fireEvent.click(screen.getByRole("menuitem", { name: "テキストを編集" }));
    expect(screen.getByRole("textbox", { name: "テキストを編集" })).toHaveValue("Note");
  });
  it("keeps Cut and the A4 orientation control available in the React workspace", async () => {
    const landscapeState = { ...state, settings: { orientation: "landscape" as const } };
    mocks.invoke.mockImplementation(async (command: string, payload?: unknown) => {
      if (
        command === "apply_command" &&
        (payload as { command?: { kind?: string } } | undefined)?.command?.kind === "setPrintOrientation"
      )
        return landscapeState;
      return defaultInvoke(command);
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const orientation = screen.getByRole("button", { name: "A4横向き" });
    fireEvent.click(orientation);
    await waitFor(() => expect(orientation).toHaveAttribute("aria-pressed", "true"));
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith("apply_command", {
        command: { kind: "setPrintOrientation", payload: { orientation: "landscape" } },
      }),
    );
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    await waitFor(() => expect(screen.getAllByText(/1 選択/).length).toBeGreaterThan(0));
    fireEvent.keyDown(window, { key: "x", metaKey: true });
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({ command: expect.objectContaining({ kind: "compound" }) }),
      ),
    );
  });
  it("restores the A4 orientation from the loaded Core document state", async () => {
    const landscapeState = { ...state, settings: { orientation: "landscape" as const } };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return landscapeState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return landscapeState;
    });

    render(<App />);

    await screen.findByDisplayValue("Test project");
    expect(screen.getByRole("button", { name: "A4横向き" })).toHaveAttribute("aria-pressed", "true");
  });
  it("orders the wide toolbar controls and Japanese labels like the SwiftUI toolbar", async () => {
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const toolbar = screen.getByRole("navigation", { name: "CAD ツールバー" });
    const text = toolbar.textContent ?? "";
    expect(text).toContain(
      "選択選択図形をコピーコピーした図形をペースト選択図形を複製作図レイヤーCut Line未評価倍率 100%",
    );
    expect(screen.getByRole("button", { name: "グリッド" })).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByRole("button", { name: "編集表示" })).toHaveAttribute("aria-pressed", "true");
  });
  it("reflects the aggregated Core constraint status in the toolbar badge", async () => {
    const constrainedState = {
      ...state,
      constraints: [
        { id: "constraint:1", kind: "horizontal", status: "underConstrained" },
        { id: "constraint:2", kind: "vertical", status: "conflicting" },
      ],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return constrainedState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return constrainedState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    expect(screen.getByTitle("拘束状態")).toHaveTextContent("競合");
    expect(screen.getByTitle("拘束状態")).toHaveClass("conflicting");
  });
  it("keeps part library export and placement in the React workspace", async () => {
    const part = {
      id: "part-1",
      name: "Card case",
      quantity: 1,
      visible: true,
      printable: true,
      originMm: { xMm: 0, yMm: 0 },
      entityIds: ["point-1"],
      outlineEntityIds: ["point-1"],
      holeEntityIdGroups: [],
      derivedElementIds: [],
      freeTextIds: [],
      measurementAnnotationIds: [],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return { ...state, parts: [part] };
      if (command === "export_part_library_item") return { libraryJson: "opaque-core-library-item", sourcePart: part };
      return { ...state, parts: [part] };
    });
    render(<App />);
    await screen.findByRole("tab", { name: "パーツ" });
    fireEvent.click(screen.getByRole("tab", { name: "パーツ" }));
    await screen.findByRole("button", { name: "ライブラリへ追加" });
    fireEvent.click(screen.getByRole("button", { name: "ライブラリへ追加" }));
    await screen.findByRole("button", { name: "配置" });
    fireEvent.click(screen.getByRole("button", { name: "配置" }));
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({ command: expect.objectContaining({ kind: "insertPartLibraryItem" }) }),
      ),
    );
  });
  it("expands a selected part to its resolved derived drawing entities", async () => {
    const part = {
      id: "part:resolved",
      name: "Resolved part",
      quantity: 1,
      visible: true,
      printable: true,
      originMm: { xMm: 2, yMm: 3 },
      entityIds: ["entity:base"],
      outlineEntityIds: ["entity:base"],
      holeEntityIdGroups: [],
      derivedElementIds: ["derived:offset"],
      freeTextIds: ["text:note"],
      measurementAnnotationIds: [],
    };
    const partState = {
      ...state,
      entities: [
        { id: "entity:base", kind: { point: { xMm: 0, yMm: 0 } } },
        { id: "derived:offset:resolved:0", kind: { point: { xMm: 5, yMm: 0 } } },
      ],
      drawingEntityMetadata: [
        { entityId: "entity:base" },
        { entityId: "derived:offset:resolved:0", derivedElementId: "derived:offset" },
      ],
      parts: [part],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return partState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return partState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.click(screen.getByRole("tab", { name: "パーツ" }));
    fireEvent.click(screen.getByRole("button", { name: "内容を選択" }));
    expect(screen.getAllByText(/2 選択/).length).toBeGreaterThan(0);
  });
  it("clears part content selection before clearing the selected part on Escape", async () => {
    const part = {
      id: "part:escape",
      name: "Escape part",
      quantity: 1,
      visible: true,
      printable: true,
      originMm: { xMm: 0, yMm: 0 },
      entityIds: ["point-1"],
      outlineEntityIds: ["point-1"],
      holeEntityIdGroups: [],
      derivedElementIds: [],
      freeTextIds: [],
      measurementAnnotationIds: [],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return { ...state, parts: [part] };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return { ...state, parts: [part] };
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.click(screen.getByRole("tab", { name: "パーツ" }));
    fireEvent.click(screen.getByRole("button", { name: "内容を選択" }));
    fireEvent.keyDown(window, { key: "Escape" });
    expect(screen.queryByText(/1 選択/)).not.toBeInTheDocument();
    fireEvent.keyDown(window, { key: "Escape" });
    expect(screen.getByText("パーツ選択を解除しました。")).toBeInTheDocument();
  });
  it("offers the same recovery decision as the SwiftUI session on launch", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return state;
      if (command === "load_part_library") return [];
      if (command === "recovery_candidate")
        return { displayName: "復旧する型紙", originalDocumentPath: "/projects/recover.kawa" };
      if (command === "restore_recovery_snapshot") return { ...state, persistence: { isDirty: true } };
      return state;
    });
    render(<App />);
    expect(await screen.findByRole("complementary", { name: "復旧候補" })).toHaveTextContent("復旧する型紙");
    fireEvent.click(screen.getByRole("button", { name: "復元" }));
    await waitFor(() => expect(mocks.invoke).toHaveBeenCalledWith("restore_recovery_snapshot"));
    expect(screen.queryByRole("complementary", { name: "復旧候補" })).not.toBeInTheDocument();
  });
  it("keeps a SwiftUI recovery candidate when the user chooses to review it later", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return state;
      if (command === "load_part_library") return [];
      if (command === "recovery_candidate") return { displayName: "後で復旧する型紙" };
      return state;
    });
    render(<App />);
    await screen.findByRole("complementary", { name: "復旧候補" });
    fireEvent.click(screen.getByRole("button", { name: "後で" }));
    expect(screen.queryByRole("complementary", { name: "復旧候補" })).not.toBeInTheDocument();
    expect(screen.getByText("復旧候補は後で確認できます。")).toBeInTheDocument();
    expect(mocks.invoke).not.toHaveBeenCalledWith("discard_recovery_snapshot");
  });
  it("persists a recovery snapshot after the Core document becomes dirty", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return { ...state, persistence: { isDirty: true } };
      if (command === "load_part_library") return [];
      if (command === "recovery_candidate") return null;
      return state;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    await waitFor(() => expect(mocks.invoke).toHaveBeenCalledWith("save_recovery_snapshot"), { timeout: 3_000 });
  });
  it("presents a Core document warning and lets the user dismiss it", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return { ...state, warnings: [{ message: "拘束を確認してください。" }] };
      if (command === "load_part_library") return [];
      if (command === "recovery_candidate") return null;
      return state;
    });
    render(<App />);
    const warning = await screen.findByRole("alert");
    expect(warning).toHaveTextContent("拘束を確認してください。");
    fireEvent.click(within(warning).getByRole("button", { name: "閉じる" }));
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
  });
  it("sets the native document title and confirms a dirty window close", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return { ...state, persistence: { isDirty: true } };
      if (command === "load_part_library") return [];
      if (command === "recovery_candidate") return null;
      return state;
    });
    mocks.confirm.mockResolvedValueOnce(false).mockResolvedValueOnce(true);
    render(<App />);
    await screen.findByDisplayValue("Test project");
    await waitFor(() => expect(mocks.setTitle).toHaveBeenCalledWith("Test project — 未保存"));
    const calls = mocks.onCloseRequested.mock.calls as unknown as Array<
      [(event: { preventDefault: () => void }) => Promise<void>]
    >;
    const handler = calls[calls.length - 1]?.[0] as
      ((event: { preventDefault: () => void }) => Promise<void>) | undefined;
    expect(handler).toBeDefined();
    const preventDefault = vi.fn();
    await handler?.({ preventDefault });
    expect(preventDefault).toHaveBeenCalledOnce();
    expect(mocks.confirm).toHaveBeenCalledTimes(2);
    expect(mocks.invoke).toHaveBeenCalledWith("exit_application");
  });
  it("saves a dirty document before completing a window close", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state")
        return { ...state, persistence: { isDirty: true, hasPath: true, path: "/projects/dirty.kawa" } };
      if (command === "load_part_library") return [];
      if (command === "recovery_candidate") return null;
      return state;
    });
    mocks.confirm.mockResolvedValue(true);
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const calls = mocks.onCloseRequested.mock.calls as unknown as Array<
      [(event: { preventDefault: () => void }) => Promise<void>]
    >;
    const handler = calls[calls.length - 1]?.[0] as
      ((event: { preventDefault: () => void }) => Promise<void>) | undefined;
    await handler?.({ preventDefault: vi.fn() });
    expect(mocks.invoke).toHaveBeenCalledWith("save_document", { path: "/projects/dirty.kawa" });
    expect(mocks.invoke).toHaveBeenCalledWith("exit_application");
  });
  it("destroys a clean window when the native close button is requested", async () => {
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const calls = mocks.onCloseRequested.mock.calls as unknown as Array<
      [(event: { preventDefault: () => void }) => Promise<void>]
    >;
    const handler = calls[calls.length - 1]?.[0] as
      ((event: { preventDefault: () => void }) => Promise<void>) | undefined;
    const preventDefault = vi.fn();
    await handler?.({ preventDefault });
    expect(preventDefault).toHaveBeenCalledOnce();
    expect(mocks.invoke).toHaveBeenCalledWith("exit_application");
    expect(mocks.confirm).not.toHaveBeenCalled();
  });
  it("falls back to destroying the window when the adapter exit command is unavailable", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return state;
      if (command === "load_part_library") return [];
      if (command === "recovery_candidate") return null;
      if (command === "exit_application") throw new Error("legacy adapter");
      return state;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const calls = mocks.onCloseRequested.mock.calls as unknown as Array<
      [(event: { preventDefault: () => void }) => Promise<void>]
    >;
    const handler = calls[calls.length - 1]?.[0] as
      ((event: { preventDefault: () => void }) => Promise<void>) | undefined;
    await handler?.({ preventDefault: vi.fn() });
    expect(mocks.destroy).toHaveBeenCalledOnce();
  });
  it("uses mutually exclusive compact drawers and closes them when returning to a docked layout", async () => {
    Object.defineProperty(window, "innerWidth", { configurable: true, writable: true, value: 800 });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent(window, new Event("resize"));
    await waitFor(() => expect(document.querySelector(".layout-compact")).toBeInTheDocument());
    fireEvent.click(screen.getByRole("button", { name: "ツールを表示" }));
    expect(screen.getByRole("complementary", { name: "ツール" })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "ドロワーを閉じる" }));
    expect(screen.queryByRole("complementary", { name: "ツール" })).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "ツールを表示" }));
    fireEvent.click(screen.getByRole("button", { name: "インスペクタを表示" }));
    expect(screen.queryByRole("complementary", { name: "ツール" })).not.toBeInTheDocument();
    expect(screen.getByRole("complementary", { name: "インスペクタ" })).toBeInTheDocument();
    Object.defineProperty(window, "innerWidth", { configurable: true, writable: true, value: 1600 });
    fireEvent(window, new Event("resize"));
    await waitFor(() => expect(document.querySelector(".layout-wide")).toBeInTheDocument());
    expect(screen.queryByRole("complementary", { name: "インスペクタ" })).toBeInTheDocument();
  });
  it("does not leave an empty compact backdrop when the inspector preference is hidden", async () => {
    Object.defineProperty(window, "innerWidth", { configurable: true, writable: true, value: 800 });
    window.localStorage.setItem("leather.layout.inspectorPanelVisible", "false");
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent(window, new Event("resize"));
    await waitFor(() => expect(document.querySelector(".layout-compact")).toBeInTheDocument());
    fireEvent.keyDown(window, { key: "a", metaKey: true });
    await waitFor(() => expect(screen.getAllByText(/1 選択/).length).toBeGreaterThan(0));
    expect(screen.queryByRole("button", { name: "ドロワーを閉じる" })).not.toBeInTheDocument();
    expect(screen.queryByRole("complementary", { name: "インスペクタ" })).not.toBeInTheDocument();
  });
  it("toggles the SwiftUI bottom workbench from the status bar", async () => {
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.click(screen.getByRole("button", { name: "サマリーを表示" }));
    expect(screen.getByRole("region", { name: "サマリー" })).toHaveTextContent("選択なし");
    fireEvent.click(screen.getByRole("button", { name: "サマリーを隠す" }));
    expect(screen.queryByRole("region", { name: "サマリー" })).not.toBeInTheDocument();
  });
  it("shows the output-preview page or warning summary in the status bar", async () => {
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state")
        return {
          ...state,
          viewMode: "outputPreview",
          outputPreview: { pages: [{ widthMm: 210, heightMm: 297, gridColumn: 0, gridRow: 0 }], warnings: [] },
        };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return state;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    expect(screen.getByText("出力プレビュー: 1 ページ")).toBeInTheDocument();
  });
  it("returns from output preview before activating a SwiftUI editing tool", async () => {
    const previewState = {
      ...state,
      viewMode: "outputPreview",
      outputPreview: { pages: [], warnings: [] },
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return previewState;
      if (command === "set_view_mode") return { ...previewState, viewMode: "editDisplay", outputPreview: null };
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return previewState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    fireEvent.keyDown(window, { key: "3", metaKey: true });
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith("set_view_mode", {
        viewMode: "editDisplay",
      }),
    );
    expect(screen.getByText("線分", { selector: ".toolbar-tool" })).toBeInTheDocument();
  });
  it("matches the SwiftUI window title rules for saved and unsaved projects", () => {
    expect(documentWindowPresentation("丸型キーホルダー", "/tmp/keyholder-round.kawa", false)).toMatchObject({
      title: "keyholder-round.kawa — 丸型キーホルダー",
    });
    expect(documentWindowPresentation("KeyHolder", "C:\\projects\\keyholder.kawa", true)).toMatchObject({
      title: "keyholder.kawa",
      accessibilityLabel: expect.stringContaining("未保存の変更あり"),
    });
    expect(documentWindowPresentation("新しい型紙", undefined, true)).toMatchObject({
      title: "新しい型紙 — 未保存",
      accessibilityLabel: expect.stringContaining("新しい型紙"),
    });
  });
});

describe("Derived edit handles", () => {
  it("uses Core's entity_id wire key when dragging a normal control point", async () => {
    const lineState = {
      ...state,
      entities: [
        { id: "line:control", kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 20, yMm: 0 } } } },
      ],
    };
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "document_state") return lineState;
      if (command === "recovery_candidate") return null;
      if (command === "load_part_library") return [];
      return lineState;
    });
    render(<App />);
    await screen.findByDisplayValue("Test project");
    const canvas = screen.getByRole("application", { name: "型紙作図キャンバス" });
    Object.defineProperty(canvas, "getBoundingClientRect", {
      value: () => ({ left: 0, top: 0, width: 100, height: 100 }),
    });
    fireEvent.pointerDown(canvas, { ...canvasClientPoint({ xMm: 20, yMm: 0 }), button: 0, pointerId: 1 });
    fireEvent.pointerUp(canvas, { ...canvasClientPoint({ xMm: 30, yMm: 0 }), button: 0, pointerId: 1 });
    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith(
        "apply_command",
        expect.objectContaining({
          command: expect.objectContaining({
            kind: "moveControlPoint",
            payload: expect.objectContaining({
              target: { controlPoint: { entity_id: "line:control", point: "end" } },
            }),
          }),
        }),
      ),
    );
  });

  it("resolves a fillet radius handle to the owning derived element", () => {
    const viewport: Viewport = { zoom: 1, panX: 0, panY: 0 };
    expect(
      hitDerivedRadiusControl(
        { xMm: 12, yMm: 0 },
        [{ id: "derived:fillet:resolved:0", kind: { circle: { center: { xMm: 0, yMm: 0 }, radiusMm: 12 } } }],
        [{ entityId: "derived:fillet:resolved:0", derivedElementId: "derived:fillet", resolvedIndex: 0 }],
        viewport,
      ),
    ).toEqual({ controlPoint: { entityId: "derived:fillet:resolved:0", point: "radius" } });
    expect(
      hitDerivedRadiusControl(
        { xMm: 12, yMm: 0 },
        [{ id: "derived:offset:resolved:0", kind: { circle: { center: { xMm: 0, yMm: 0 }, radiusMm: 12 } } }],
        [{ entityId: "derived:offset:resolved:0", derivedElementId: "derived:offset", resolvedIndex: 0 }],
        viewport,
        [
          {
            id: "derived:offset",
            kind: { offsetCurve: { sourceEntityIds: ["line:1"], distance: { fixedMm: 3 }, direction: "left" } },
          },
        ],
      ),
    ).toBeUndefined();
  });
});
