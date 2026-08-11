import { cloneElement } from "react";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { RawEntity } from "@/features/canvas/domain/cad";
import { InspectorPanel, type DerivedElement, type Part } from "@/features/inspector/components/InspectorPanel";

const style = {
  stroke: { red: 0.07, green: 0.09, blue: 0.15, alpha: 1 },
  strokeWidthMm: 0.2,
  pattern: "solid",
};

function panel(
  onCommand = vi.fn(),
  parameters: Array<{ id: string; name: string; valueMm: number; unit: string; memo: string }> = [],
  sharedStyles: Array<{ id: string; name: string; style: typeof style }> = [],
  parts: Part[] = [],
  selectedEntity?: RawEntity,
  selectedDerivedElement?: DerivedElement,
  selectedFreeText?: { id: string; content: string; positionMm: { xMm: number; yMm: number }; fontSizeMm: number },
  selectedConstraint?: { id: string; kind: string; status: string; value?: Record<string, number | string> },
  selectedMeasurement?: { id: string; kind: string; visible: boolean },
  selectedStitchStartPoint?: { id: string; targetEntityId: string },
  onConvertMeasurement = vi.fn(),
  selectedEntityIds: string[] = [],
  roundHoles: Array<{ id: string; entityId: string; kind: string }> = [],
  selectedEntities: RawEntity[] = [],
  selectedCount = 0,
  onCreatePart = vi.fn(),
  onApplyStyle = vi.fn(),
) {
  return (
    <InspectorPanel
      selectedCount={selectedCount}
      selectedEntityIds={selectedEntityIds}
      selectedEntities={selectedEntities}
      documentSummary={{
        viewMode: "編集表示",
        activeLayerName: "Outline",
        visibleEntityCount: 2,
        constraintCount: 1,
        parameterCount: parameters.length,
      }}
      constraints={[]}
      selectedEntity={selectedEntity}
      selectedDerivedElement={selectedDerivedElement}
      selectedFreeText={selectedFreeText}
      selectedConstraint={selectedConstraint}
      selectedMeasurement={selectedMeasurement}
      selectedStitchStartPoint={selectedStitchStartPoint}
      measurements={[]}
      freeTexts={[]}
      parameters={parameters}
      layers={[
        { id: "layer:outline", name: "Outline", visible: true, printable: true, kind: "cutLine", style },
        { id: "layer:stitch", name: "Stitch", visible: true, printable: true, kind: "cutLine", style },
      ]}
      activeLayerId="layer:outline"
      sharedStyles={sharedStyles}
      parts={parts}
      arrangementPartIds={new Set()}
      partLibrary={[]}
      roundHoles={roundHoles}
      onCommand={onCommand}
      onApplyStyle={onApplyStyle}
      onDeleteSelection={vi.fn()}
      onCreatePart={onCreatePart}
      onAddParameter={vi.fn()}
      onAddLayer={vi.fn()}
      onActiveLayerChange={vi.fn()}
      onRenameLayer={vi.fn()}
      onDeleteLayer={vi.fn()}
      onSelectPart={vi.fn()}
      onToggleArrangementPart={vi.fn()}
      onAlignParts={vi.fn()}
      onDistributeParts={vi.fn()}
      onAddPartToLibrary={vi.fn()}
      onInsertPartFromLibrary={vi.fn()}
      onRemovePartFromLibrary={vi.fn()}
      onConvertMeasurement={onConvertMeasurement}
    />
  );
}

describe("InspectorPanel", () => {
  afterEach(cleanup);

  it("keeps the SwiftUI tab order in a fixed header outside the scrolling content", () => {
    render(panel());
    const inspector = screen.getByRole("complementary", { name: "インスペクタ" });
    const header = inspector.querySelector(":scope > .inspector-header");
    const content = inspector.querySelector(":scope > .inspector-content");

    expect(header).not.toBeNull();
    expect(content).not.toBeNull();
    expect(header?.nextElementSibling).toBe(content);
    expect(content?.querySelector('[role="tablist"]')).toBeNull();
    expect(screen.getAllByRole("tab").map((tab) => tab.textContent)).toEqual([
      "選択",
      "レイヤー",
      "共有スタイル",
      "パラメータ",
      "パーツ",
    ]);
  });

  it("shows the SwiftUI document overview on the selection tab", () => {
    render(panel());
    expect(screen.getByText("ドキュメント")).toBeInTheDocument();
    expect(screen.getByText("表示モード")).toBeInTheDocument();
    expect(screen.getByText("Outline")).toBeInTheDocument();
    expect(screen.getByText("2")).toBeInTheDocument();
  });

  it("selects constraints, measurements, and notes from the same rows as SwiftUI", () => {
    const onSelectConstraint = vi.fn();
    const onSelectMeasurement = vi.fn();
    const onSelectFreeText = vi.fn();
    render(
      cloneElement(panel(), {
        constraints: [{ id: "constraint:1", kind: "segmentLength", status: "fullyConstrained" }],
        measurements: [{ id: "measurement:1", kind: "distance", visible: true }],
        freeTexts: [{ id: "text:1", content: "注記", positionMm: { xMm: 0, yMm: 0 }, fontSizeMm: 3 }],
        onSelectConstraint,
        onSelectMeasurement,
        onSelectFreeText,
      }),
    );

    fireEvent.click(screen.getByRole("button", { name: /^線分長完全拘束/ }));
    fireEvent.click(screen.getByRole("button", { name: "距離表示" }));
    fireEvent.click(screen.getByRole("button", { name: "注記" }));

    expect(onSelectConstraint).toHaveBeenCalledWith("constraint:1");
    expect(onSelectMeasurement).toHaveBeenCalledWith("measurement:1");
    expect(onSelectFreeText).toHaveBeenCalledWith("text:1");
  });

  it("summarizes multiple selections and applies a shared style to all selected entities", () => {
    const onCommand = vi.fn();
    const onApplyStyle = vi.fn();
    const line: RawEntity = {
      id: "entity:line",
      kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 10, yMm: 0 } } },
      layerId: "layer:outline",
    };
    const circle: RawEntity = {
      id: "entity:circle",
      kind: { circle: { center: { xMm: 20, yMm: 20 }, radiusMm: 4 } },
      layerId: "layer:stitch",
    };
    render(
      panel(
        onCommand,
        [],
        [{ id: "style:stitch", name: "縫い線", style }],
        [],
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        [],
        [],
        [line, circle],
        2,
        vi.fn(),
        onApplyStyle,
      ),
    );

    expect(screen.getByText("2 件を選択中")).toBeInTheDocument();
    expect(screen.getByText("線分、円")).toBeInTheDocument();
    expect(screen.getByText("Outline、Stitch")).toBeInTheDocument();
    fireEvent.change(screen.getByRole("combobox", { name: "選択図形の共有スタイル" }), {
      target: { value: "style:stitch" },
    });
    fireEvent.click(screen.getByRole("button", { name: "選択へ適用" }));
    expect(onCommand).not.toHaveBeenCalled();
    expect(onApplyStyle).toHaveBeenCalledOnce();
  });

  it("exposes the parts creation path from a selected drawing", () => {
    const onCreatePart = vi.fn();
    const line: RawEntity = {
      id: "entity:line",
      kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 10, yMm: 0 } } },
      layerId: "layer:outline",
    };
    render(
      panel(
        vi.fn(),
        [],
        [],
        [],
        line,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        [],
        [],
        [line],
        1,
        onCreatePart,
      ),
    );

    fireEvent.click(screen.getByRole("tab", { name: "パーツ" }));
    fireEvent.click(screen.getByRole("button", { name: "選択図形からパーツを作成" }));

    expect(onCreatePart).toHaveBeenCalledOnce();
  });

  it("edits a selected round-hole kind and diameter through Core commands", () => {
    const onCommand = vi.fn();
    const circle: RawEntity = {
      id: "entity:hole",
      kind: { circle: { center: { xMm: 0, yMm: 0 }, radiusMm: 2.5 } },
    };
    render(
      panel(
        onCommand,
        [],
        [],
        [],
        circle,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        [],
        [{ id: "round-hole:1", entityId: "entity:hole", kind: "rivet" }],
      ),
    );
    fireEvent.change(screen.getByRole("combobox", { name: "穴種別" }), { target: { value: "decorative" } });
    const diameter = screen.getByRole("spinbutton", { name: "丸穴の直径 (mm)" });
    fireEvent.change(diameter, { target: { value: "8" } });
    fireEvent.blur(diameter);
    expect(onCommand).toHaveBeenCalledWith(
      "setRoundHoleKind",
      { roundHoleId: "round-hole:1", kind: "decorative" },
      "穴種別を更新しました。",
    );
    expect(onCommand).toHaveBeenCalledWith(
      "setRoundHoleDiameter",
      { roundHoleId: "round-hole:1", diameterMm: 8 },
      "丸穴の直径を更新しました。",
    );
  });

  it("uses the layer tab and filters it with the inspector feature query", () => {
    render(panel());
    expect(screen.getByRole("tab", { name: "選択" })).toHaveAttribute("aria-selected", "true");
    fireEvent.click(screen.getByRole("tab", { name: "レイヤー" }));

    expect(screen.getByRole("button", { name: /^Outline/ })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /^Stitch/ })).toBeInTheDocument();
    fireEvent(window, new Event("kawa-cad-find-inspector"));
    const search = screen.getByRole("searchbox", { name: "レイヤーを検索" });
    fireEvent.change(search, { target: { value: "outline" } });
    expect(screen.getByRole("button", { name: /^Outline/ })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /^Stitch/ })).not.toBeInTheDocument();
  });

  it("shows the selection-change notice only after selection changes on another tab", () => {
    const view = render(panel());
    fireEvent.click(screen.getByRole("tab", { name: "レイヤー" }));
    expect(screen.queryByText("選択が変更されました。")).not.toBeInTheDocument();

    view.rerender(
      panel(vi.fn(), [], [], [], undefined, undefined, undefined, undefined, undefined, undefined, vi.fn(), [
        "entity:changed",
      ]),
    );
    expect(screen.getByText("選択が変更されました。")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "選択を表示" }));
    expect(screen.getByRole("tab", { name: "選択" })).toHaveAttribute("aria-selected", "true");
  });

  it("offers the SwiftUI color and drafting-width presets with custom fallback", () => {
    render(panel());
    fireEvent.click(screen.getByRole("tab", { name: "レイヤー" }));
    fireEvent.click(screen.getByRole("button", { name: /^Outline/ }));
    expect(screen.getAllByRole("combobox", { name: "色プリセット" })[0]).toHaveValue("custom");
    expect(screen.getAllByRole("combobox", { name: "線幅プリセット" })[0]).toHaveValue("custom");
  });

  it("edits a shared-style name inline like SwiftUI", () => {
    const onCommand = vi.fn();
    render(panel(onCommand, [], [{ id: "style:stitch", name: "縫い線", style }]));
    fireEvent.click(screen.getByRole("tab", { name: "共有スタイル" }));
    fireEvent.click(screen.getByRole("button", { name: /^縫い線/ }));
    const name = screen.getByRole("textbox", { name: "縫い線 の名前" });
    fireEvent.change(name, { target: { value: "飾り縫い" } });
    fireEvent.blur(name);
    expect(onCommand).toHaveBeenCalledWith(
      "updateSharedStyle",
      { id: "style:stitch", name: "飾り縫い", style },
      "共有スタイルを更新しました。",
    );
  });

  it("commits an inline layer name without opening another editor", () => {
    const onRenameLayer = vi.fn();
    render(cloneElement(panel(), { onRenameLayer }));
    fireEvent.click(screen.getByRole("tab", { name: "レイヤー" }));
    fireEvent.click(screen.getByRole("button", { name: /^Outline/ }));
    const name = screen.getByRole("textbox", { name: "Outline の名前" });
    fireEvent.change(name, { target: { value: "外形線" } });
    fireEvent.blur(name);

    expect(onRenameLayer).toHaveBeenCalledWith("layer:outline", "外形線");
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });

  it("keeps an incomplete custom color draft and commits it once valid", () => {
    const onCommand = vi.fn();
    render(panel(onCommand));
    fireEvent.click(screen.getByRole("tab", { name: "レイヤー" }));
    fireEvent.click(screen.getByRole("button", { name: /^Outline/ }));
    fireEvent.change(screen.getAllByRole("combobox", { name: "色プリセット" })[0], {
      target: { value: "custom" },
    });
    const color = screen.getByRole("textbox", { name: "カスタム色 (#RRGGBB)" });
    fireEvent.change(color, { target: { value: "#AB" } });
    expect(color).toHaveValue("#AB");
    expect(onCommand).not.toHaveBeenCalled();

    fireEvent.change(color, { target: { value: "#ABCDEF" } });
    expect(onCommand).toHaveBeenCalledWith(
      "setLayerStyle",
      {
        layerId: "layer:outline",
        style: {
          ...style,
          stroke: {
            red: 171 / 255,
            green: 205 / 255,
            blue: 239 / 255,
            alpha: 1,
          },
        },
      },
      "レイヤー線種を更新しました。",
    );
  });

  it("updates the layer output flag through the existing Core command", () => {
    const onCommand = vi.fn();
    render(panel(onCommand));
    fireEvent.click(screen.getByRole("tab", { name: "レイヤー" }));
    fireEvent.click(screen.getByRole("button", { name: /^Outline/ }));
    fireEvent.click(screen.getByRole("checkbox", { name: "Outline を出力対象に含める" }));
    expect(onCommand).toHaveBeenCalledWith(
      "setLayerPrintable",
      { layerId: "layer:outline", printable: false },
      "レイヤーの出力対象を更新しました。",
    );
  });

  it("edits the SwiftUI part settings through existing Core commands", () => {
    const onCommand = vi.fn();
    const part: Part = {
      id: "part:card-case",
      name: "カードケース",
      quantity: 1,
      visible: true,
      printable: true,
      originMm: { xMm: 10, yMm: 20 },
      entityIds: ["line:1"],
      outlineEntityIds: ["line:1"],
      holeEntityIdGroups: [["circle:1"]],
      derivedElementIds: ["derived:1"],
      freeTextIds: ["text:1"],
      measurementAnnotationIds: ["measurement:1"],
    };
    render(panel(onCommand, [], [], [part]));
    fireEvent.click(screen.getByRole("tab", { name: "パーツ" }));
    fireEvent.click(screen.getByRole("button", { name: /^カードケース/ }));
    fireEvent.click(screen.getByRole("checkbox", { name: "カードケース を出力対象に含める" }));
    fireEvent.change(screen.getByRole("spinbutton", { name: "カードケース の数量" }), {
      target: { value: "3" },
    });
    fireEvent.change(screen.getByRole("spinbutton", { name: "カードケース の原点 X (mm)" }), {
      target: { value: "12.5" },
    });
    fireEvent.blur(screen.getByRole("spinbutton", { name: "カードケース の原点 X (mm)" }));
    expect(onCommand).toHaveBeenCalledWith(
      "setPartPrintable",
      { partId: "part:card-case", printable: false },
      "パーツの出力対象を更新しました。",
    );
    expect(onCommand).toHaveBeenCalledWith(
      "setPartQuantity",
      { partId: "part:card-case", quantity: 3 },
      "パーツ数量を更新しました。",
    );
    expect(onCommand).toHaveBeenCalledWith(
      "setPartPosition",
      { partId: "part:card-case", position: { xMm: 12.5, yMm: 20 } },
      "パーツ原点を更新しました。",
    );
    expect(screen.getByLabelText("カードケース の構成")).toHaveTextContent("外形 1穴 1派生 1テキスト 1計測 1");
  });
  it("keeps fixed part membership controls out of the SwiftUI-equivalent editor", () => {
    const onCommand = vi.fn();
    const part: Part = {
      id: "part:card-case",
      name: "カードケース",
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
    render(
      panel(onCommand, [], [], [part], undefined, undefined, undefined, undefined, undefined, undefined, undefined, [
        "line:1",
        "line:2",
      ]),
    );
    fireEvent.click(screen.getByRole("tab", { name: "パーツ" }));
    fireEvent.click(screen.getByRole("button", { name: /^カードケース/ }));
    expect(screen.queryByRole("button", { name: "選択を追加" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "選択を除外" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "選択を外形に設定" })).not.toBeInTheDocument();
    expect(
      screen.getByText("パーツの形状は固定されています。形状を編集するには、先にパーツを解除してください。"),
    ).toBeInTheDocument();
    expect(onCommand).not.toHaveBeenCalled();
  });

  it("ports the SwiftUI part rename, visibility, movement, duplication, and removal commands", () => {
    const onCommand = vi.fn();
    const part: Part = {
      id: "part:card-case",
      name: "カードケース",
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
    render(panel(onCommand, [], [], [part]));
    fireEvent.click(screen.getByRole("tab", { name: "パーツ" }));
    fireEvent.click(screen.getByRole("button", { name: /^カードケース/ }));

    const name = screen.getByRole("textbox", { name: "カードケース の名前" });
    fireEvent.change(name, { target: { value: "カード入れ" } });
    fireEvent.blur(name);
    fireEvent.click(screen.getByLabelText("表示"));
    fireEvent.click(screen.getByRole("button", { name: "→" }));
    fireEvent.click(screen.getByRole("button", { name: "複製" }));
    fireEvent.click(screen.getByRole("button", { name: "解除" }));

    expect(onCommand).toHaveBeenCalledWith(
      "renamePart",
      { partId: "part:card-case", name: "カード入れ" },
      "パーツ名を更新しました。",
    );
    expect(onCommand).toHaveBeenCalledWith(
      "setPartVisibility",
      { partId: "part:card-case", visible: false },
      "パーツ表示を更新しました。",
    );
    expect(onCommand).toHaveBeenCalledWith(
      "movePart",
      { partId: "part:card-case", delta: { xMm: 10, yMm: 0 } },
      "パーツを移動しました。",
    );
    expect(onCommand).toHaveBeenCalledWith(
      "duplicatePart",
      expect.objectContaining({
        partId: "part:card-case",
        newPartId: expect.stringMatching(/^part:/),
        newName: "カードケース のコピー",
        idNamespace: expect.any(String),
        delta: { xMm: 10, yMm: -10 },
      }),
      "パーツを複製しました。",
    );
    expect(onCommand).toHaveBeenCalledWith("deletePart", "part:card-case", "パーツを解除しました。");
  });

  it("edits a resolved derived element through its owning Core element", () => {
    const onCommand = vi.fn();
    const entity: RawEntity = {
      id: "derived:offset-1:resolved:0",
      kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 10, yMm: 0 } } },
    };
    const derivedElement: DerivedElement = {
      id: "derived:offset-1",
      layerId: "layer:outline",
      styleId: "style:outer",
      kind: { offsetCurve: { sourceEntityIds: ["line:base"], distance: { fixedMm: 3 }, direction: "left" } },
    };
    render(panel(onCommand, [], [{ id: "style:outer", name: "外形", style }], [], entity, derivedElement));
    fireEvent.click(screen.getByRole("button", { name: "方向を反転" }));
    expect(onCommand).toHaveBeenCalledWith(
      "setDerivedDirection",
      { derivedElementId: "derived:offset-1", direction: "right" },
      "オフセット方向を更新しました。",
    );
    fireEvent.change(screen.getByRole("spinbutton", { name: "オフセット線の距離 (mm)" }), {
      target: { value: "4.5" },
    });
    fireEvent.blur(screen.getByRole("spinbutton", { name: "オフセット線の距離 (mm)" }));
    fireEvent.change(screen.getByRole("combobox", { name: "方向" }), { target: { value: "right" } });
    expect(onCommand).toHaveBeenCalledWith(
      "setDerivedDistance",
      { derivedElementId: "derived:offset-1", value: { fixedMm: 4.5 } },
      "オフセット線を更新しました。",
    );
    expect(onCommand).toHaveBeenCalledWith(
      "setDerivedDirection",
      { derivedElementId: "derived:offset-1", direction: "right" },
      "オフセット方向を更新しました。",
    );
  });

  it("edits the selected free text with its complete Core payload", () => {
    const onCommand = vi.fn();
    render(
      panel(onCommand, [], [], [], undefined, undefined, {
        id: "text:1",
        content: "注記",
        positionMm: { xMm: 3, yMm: 4 },
        fontSizeMm: 3.2,
      }),
    );
    fireEvent.change(screen.getByRole("textbox", { name: "テキスト内容" }), { target: { value: "更新後" } });
    fireEvent.blur(screen.getByRole("textbox", { name: "テキスト内容" }));
    expect(onCommand).toHaveBeenCalledWith(
      "updateFreeText",
      { id: "text:1", content: "更新後", positionMm: { xMm: 3, yMm: 4 }, fontSizeMm: 3.2 },
      "テキストを更新しました。",
    );
  });

  it("uses explicit SwiftUI-equivalent geometry fields instead of prompt editing", () => {
    const onCommand = vi.fn();
    const arc: RawEntity = {
      id: "arc:1",
      kind: { arc: { center: { xMm: 0, yMm: 0 }, radiusMm: 10, startAngleRad: 0, sweepAngleRad: Math.PI / 2 } },
    };
    render(panel(onCommand, [], [], [], arc));
    fireEvent.change(screen.getByRole("spinbutton", { name: "半径 (mm)" }), { target: { value: "12" } });
    fireEvent.blur(screen.getByRole("spinbutton", { name: "半径 (mm)" }));
    fireEvent.change(screen.getByRole("spinbutton", { name: "掃引角 (度)" }), { target: { value: "200" } });
    fireEvent.blur(screen.getByRole("spinbutton", { name: "掃引角 (度)" }));
    expect(onCommand).toHaveBeenCalledWith(
      "setEntityMetric",
      { entityId: "arc:1", metric: { kind: "arcUpdate", radiusMm: 12 } },
      "円弧を更新しました。",
    );
    expect(onCommand).toHaveBeenCalledWith(
      "setEntityMetric",
      {
        entityId: "arc:1",
        metric: { kind: "arcUpdate", radiusMm: 12, sweepAngleRad: (200 * Math.PI) / 180 },
      },
      "円弧を更新しました。",
    );
  });

  it("edits the selected constraint marker through the Core value command", () => {
    const onCommand = vi.fn();
    render(
      panel(onCommand, [], [], [], undefined, undefined, undefined, {
        id: "constraint:length",
        kind: "segmentLength",
        status: "fullyConstrained",
        value: { fixedMm: 20 },
      }),
    );
    expect(screen.getByText("線分長", { exact: true })).toBeInTheDocument();
    expect(screen.getByText("完全拘束", { exact: true })).toBeInTheDocument();
    fireEvent.change(screen.getByRole("spinbutton", { name: "拘束値 (mm)" }), { target: { value: "25" } });
    fireEvent.blur(screen.getByRole("spinbutton", { name: "拘束値 (mm)" }));
    expect(onCommand).toHaveBeenCalledWith(
      "setConstraintValue",
      { constraintId: "constraint:length", value: { fixedMm: 25 } },
      "拘束値を更新しました。",
    );
  });

  it("shows resolved parameter values with two decimals without replacing the reference", () => {
    const onCommand = vi.fn();
    render(
      panel(
        onCommand,
        [{ id: "parameter:length", name: "長さ", valueMm: 12.345, unit: "millimeter", memo: "" }],
        [],
        [],
        undefined,
        undefined,
        undefined,
        {
          id: "constraint:length",
          kind: "segmentLength",
          status: "fullyConstrained",
          value: { parameter: "parameter:length" },
        },
      ),
    );
    const value = screen.getByRole("spinbutton", { name: "拘束値 (mm)" });
    expect(value).toHaveValue(12.35);
    fireEvent.blur(value);
    expect(onCommand).not.toHaveBeenCalled();
  });

  it("shows resolved derived values with two decimals without replacing the reference", () => {
    const onCommand = vi.fn();
    const derivedElement: DerivedElement = {
      id: "derived:offset-1",
      kind: {
        offsetCurve: {
          sourceEntityIds: ["line:base"],
          distance: { parameter: "parameter:offset" },
          direction: "left",
        },
      },
    };
    const entity: RawEntity = {
      id: "derived:offset-1:resolved:0",
      kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 10, yMm: 0 } } },
    };
    render(
      panel(
        onCommand,
        [{ id: "parameter:offset", name: "縫い代", valueMm: 3.456, unit: "millimeter", memo: "" }],
        [],
        [],
        entity,
        derivedElement,
      ),
    );
    const value = screen.getByRole("spinbutton", { name: "オフセット線の距離 (mm)" });
    expect(value).toHaveValue(3.46);
    fireEvent.blur(value);
    expect(onCommand).not.toHaveBeenCalled();
  });

  it("exposes the SwiftUI conversion and deletion actions for a selected measurement", () => {
    const onCommand = vi.fn();
    const onConvertMeasurement = vi.fn();
    const selectedMeasurement = { id: "measurement:1", kind: "distance", visible: true };
    render(
      panel(
        onCommand,
        [],
        [],
        [],
        undefined,
        undefined,
        undefined,
        undefined,
        selectedMeasurement,
        undefined,
        onConvertMeasurement,
      ),
    );
    expect(screen.getByText("距離表示", { exact: true })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "寸法拘束へ変換" }));
    expect(screen.getByRole("button", { name: "削除" })).toBeInTheDocument();
    expect(onConvertMeasurement).toHaveBeenCalledWith("measurement:1");
  });

  it("shows the owning geometry without exposing its internal id", () => {
    const target: RawEntity = {
      id: "line:1",
      kind: { lineSegment: { start: { xMm: 0, yMm: 0 }, end: { xMm: 10, yMm: 0 } } },
    };
    render(
      cloneElement(
        panel(vi.fn(), [], [], [], undefined, undefined, undefined, undefined, undefined, {
          id: "stitch:1",
          targetEntityId: "line:1",
        }),
        { selectedStitchTargetEntity: target },
      ),
    );
    expect(screen.getByText("縫い始め点")).toBeInTheDocument();
    expect(screen.getByText("線分")).toBeInTheDocument();
    expect(screen.queryByText("line:1")).not.toBeInTheDocument();
  });

  it("updates and deletes a parameter with the full Core payload", () => {
    const onCommand = vi.fn();
    render(panel(onCommand, [{ id: "parameter:width", name: "幅", valueMm: 25, unit: "millimeter", memo: "胴回り" }]));
    fireEvent.click(screen.getByRole("tab", { name: "パラメータ" }));
    fireEvent.click(screen.getByRole("button", { name: /^幅/ }));
    const value = screen.getByRole("spinbutton", { name: "幅 の値 (mm)" });
    fireEvent.change(value, { target: { value: "30" } });
    fireEvent.blur(value);
    expect(onCommand).toHaveBeenCalledWith(
      "updateParameter",
      { id: "parameter:width", name: "幅", valueMm: 30, unit: "millimeter", memo: "胴回り" },
      "幅 を更新しました。",
    );
    expect(screen.getByText("このパラメータは使用されていません。")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "幅 を削除" }));
    expect(onCommand).toHaveBeenCalledWith(
      "deleteParameter",
      { parameterId: "parameter:width", replacementValueMm: 25 },
      "幅 を削除しました。",
    );
  });

  it("reveals and filters the current management tab with the native Find command", () => {
    const sharedStyles = [{ id: "style:stitch", name: "縫い線", style }];
    render(panel(vi.fn(), [], sharedStyles));
    fireEvent.click(screen.getByRole("tab", { name: "共有スタイル" }));
    expect(screen.queryByRole("searchbox", { name: "共有スタイルを検索" })).not.toBeInTheDocument();
    fireEvent(window, new Event("kawa-cad-find-inspector"));
    const search = screen.getByRole("searchbox", { name: "共有スタイルを検索" });
    fireEvent.change(search, { target: { value: "折り線" } });
    expect(screen.queryByText("縫い線")).not.toBeInTheDocument();
  });

  it("keeps management rows collapsed until selected and exposes their SwiftUI summaries", () => {
    const parameter = {
      id: "parameter:width",
      name: "幅",
      valueMm: 25,
      unit: "millimeter",
      memo: "胴回り",
      usageCount: 3,
    };
    const part: Part = {
      id: "part:card-case",
      name: "カードケース",
      quantity: 2,
      visible: true,
      printable: true,
      originMm: { xMm: 10, yMm: 20 },
      entityIds: ["line:1", "circle:1"],
      outlineEntityIds: ["line:1"],
      holeEntityIdGroups: [["circle:1"]],
      derivedElementIds: [],
      freeTextIds: [],
      measurementAnnotationIds: [],
    };
    render(panel(vi.fn(), [parameter], [{ id: "style:stitch", name: "縫い線", style }], [part]));

    fireEvent.click(screen.getByRole("tab", { name: "レイヤー" }));
    const layer = screen.getByRole("button", { name: /^Outline/ });
    expect(layer).toHaveAttribute("aria-expanded", "false");
    expect(layer).toHaveTextContent("カット線");
    expect(layer).toHaveTextContent("表示");
    fireEvent.click(layer);
    expect(layer).toHaveAttribute("aria-expanded", "true");

    fireEvent.click(screen.getByRole("tab", { name: "共有スタイル" }));
    const sharedStyle = screen.getByRole("button", { name: /^縫い線/ });
    expect(sharedStyle).toHaveAttribute("aria-expanded", "false");
    expect(sharedStyle).toHaveTextContent("実線");
    expect(sharedStyle).toHaveTextContent("#121726");
    fireEvent.click(sharedStyle);
    expect(sharedStyle).toHaveAttribute("aria-expanded", "true");

    fireEvent.click(screen.getByRole("tab", { name: "パラメータ" }));
    const parameterRow = screen.getByRole("button", { name: /^幅/ });
    expect(parameterRow).toHaveAttribute("aria-expanded", "false");
    expect(parameterRow).toHaveTextContent("25.00 mm");
    expect(parameterRow).toHaveTextContent("使用 3 件");
    fireEvent.click(parameterRow);
    expect(parameterRow).toHaveAttribute("aria-expanded", "true");
    expect(screen.getByText("3 件の拘束で使用されています。")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("tab", { name: "パーツ" }));
    const partRow = screen.getByRole("button", { name: /^カードケース/ });
    expect(partRow).toHaveAttribute("aria-expanded", "false");
    expect(partRow).toHaveTextContent("外形 1 / 穴 1");
    expect(partRow).toHaveTextContent("数量 2 / 所属 2");
    fireEvent.click(partRow);
    expect(partRow).toHaveAttribute("aria-expanded", "true");
  });

  it("shows management empty states and keeps add actions reachable", () => {
    const onAddParameter = vi.fn();
    const onCreatePart = vi.fn();
    render(cloneElement(panel(), { onAddParameter, onCreatePart }));

    fireEvent.click(screen.getByRole("tab", { name: "共有スタイル" }));
    expect(screen.getByText("共有スタイルはありません。")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "共有スタイルを追加" })).toBeEnabled();

    fireEvent.click(screen.getByRole("tab", { name: "パラメータ" }));
    expect(screen.getByText("名前付きパラメータはありません。")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "追加" }));
    expect(onAddParameter).toHaveBeenCalledOnce();

    fireEvent.click(screen.getByRole("tab", { name: "パーツ" }));
    expect(
      screen.getByText("パーツはまだありません。閉じた外形と内側の要素を選択して作成します。"),
    ).toBeInTheDocument();
    expect(screen.getByText("登録済みのパーツはありません。")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "選択図形からパーツを作成" })).toBeDisabled();
    expect(onCreatePart).not.toHaveBeenCalled();
  });
});
