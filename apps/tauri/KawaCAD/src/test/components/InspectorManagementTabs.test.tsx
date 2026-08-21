import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { InspectorLayerTab } from "@/features/inspector/components/InspectorLayerTab";
import { InspectorStylesTab } from "@/features/inspector/components/InspectorStylesTab";
import { InspectorParametersTab } from "@/features/inspector/components/InspectorParametersTab";
import { InspectorPartsTab } from "@/features/parts/components/InspectorPartsTab";
import {
  initialLayerTabState,
  initialParametersTabState,
  initialStylesTabState,
} from "@/features/inspector/selectors/inspectorFeature";
import type {
  LayerInspectorModel,
  ParameterInspectorModel,
  PartInspectorModel,
  StyleInspectorModel,
} from "@/features/inspector/domain/inspectorViewModel";
import { defaultSharedStyle } from "@/features/inspector/domain/sharedStyleDefaults";

const layer = {
  id: "layer:outline",
  name: "外形",
  visible: true,
  printable: true,
  kind: "cutLine",
  style: defaultSharedStyle,
};

const part = {
  id: "part:case",
  name: "ケース",
  quantity: 1,
  visible: true,
  printable: true,
  originMm: { xMm: 0, yMm: 0 },
  entityIds: ["line:1"],
  outlineEntityIds: ["line:1"],
  holeEntityIdGroups: [],
  derivedElementIds: [],
  freeTextIds: [],
  measurementAnnotationIds: [],
};

afterEach(cleanup);

describe("Inspector management tabs", () => {
  it("renders the layer tab from only a layer model", () => {
    const actions = {
      setVisibility: vi.fn(),
      setPrintable: vi.fn(),
      setStyle: vi.fn(),
      addLayer: vi.fn(),
      changeActiveLayer: vi.fn(),
      renameLayer: vi.fn(),
      deleteLayer: vi.fn(),
    } as LayerInspectorModel["actions"];
    render(
      <InspectorLayerTab
        model={{ layers: [layer], activeLayerId: layer.id, actions }}
        state={initialLayerTabState}
        updateState={vi.fn()}
        renderStyleFields={() => null}
      />,
    );
    fireEvent.click(screen.getByRole("button", { name: "レイヤーを追加" }));
    expect(actions.addLayer).toHaveBeenCalledOnce();
  });

  it("renders the shared-style tab from only a style model", () => {
    const actions = { update: vi.fn(), delete: vi.fn(), add: vi.fn() } as StyleInspectorModel["actions"];
    render(
      <InspectorStylesTab
        model={{ sharedStyles: [{ id: "style:outer", name: "外形", style: defaultSharedStyle }], actions }}
        state={initialStylesTabState}
        updateState={vi.fn()}
        defaultStyle={defaultSharedStyle}
        renderStyleFields={() => null}
      />,
    );
    fireEvent.click(screen.getByRole("button", { name: "共有スタイル追加" }));
    expect(actions.add).toHaveBeenCalledOnce();
  });

  it("renders the parameter tab from only a parameter model", () => {
    const actions = { update: vi.fn(), delete: vi.fn(), add: vi.fn() } as ParameterInspectorModel["actions"];
    render(
      <InspectorParametersTab
        model={{
          parameters: [{ id: "parameter:width", name: "幅", valueMm: 20, unit: "millimeter", memo: "" }],
          constraints: [],
          actions,
        }}
        state={initialParametersTabState}
        updateState={vi.fn()}
        renderParameterEditor={() => null}
      />,
    );
    fireEvent.click(screen.getByRole("button", { name: "追加" }));
    expect(actions.add).toHaveBeenCalledOnce();
  });

  it("renders the parts tab from only a parts model", () => {
    const actions = {
      create: vi.fn(),
      select: vi.fn(),
      align: vi.fn(),
      distribute: vi.fn(),
      insertFromLibrary: vi.fn(),
      removeFromLibrary: vi.fn(),
      addToLibrary: vi.fn(),
      toggleArrangement: vi.fn(),
      beginSetOrigin: vi.fn(),
      rename: vi.fn(),
      setPosition: vi.fn(),
      setVisibility: vi.fn(),
      setPrintable: vi.fn(),
      setQuantity: vi.fn(),
      move: vi.fn(),
      duplicate: vi.fn(),
      delete: vi.fn(),
    } as PartInspectorModel["actions"];
    render(
      <InspectorPartsTab
        model={{
          selectedCount: 1,
          parts: [part],
          arrangementPartIds: new Set(),
          partLibrary: [],
          actions,
        }}
        renderPartEditor={() => null}
      />,
    );
    fireEvent.click(screen.getByRole("button", { name: "選択図形からパーツを作成" }));
    expect(actions.create).toHaveBeenCalledOnce();
  });
});
