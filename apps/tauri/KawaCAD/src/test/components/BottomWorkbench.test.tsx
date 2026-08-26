import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { BottomWorkbench } from "@/features/workspace/components/BottomWorkbench";

describe("BottomWorkbench", () => {
  afterEach(cleanup);

  it("summarizes the SwiftUI selection, constraint, and parameter sections", () => {
    render(
      <BottomWorkbench
        selectedEntity={{ id: "line:edge", layerId: "layer:cut", kind: { lineSegment: { start: {}, end: {} } } }}
        layers={[{ id: "layer:cut", name: "外形カット線" }]}
        constraints={[
          {
            id: "constraint:length",
            kind: "segmentLength",
            status: "satisfied",
            targets: ["line:edge"],
            value: { parameter: "parameter:width" },
          },
        ]}
        parameters={[
          { id: "parameter:width", name: "幅", valueMm: 20, unit: "millimeter" },
          { id: "parameter:height", name: "高さ", valueMm: 30, unit: "millimeter" },
        ]}
      />,
    );

    expect(screen.getByRole("region", { name: "サマリー" })).toHaveTextContent("線分");
    expect(screen.getByRole("region", { name: "サマリー" })).not.toHaveTextContent("line:edge");
    expect(screen.getByRole("region", { name: "サマリー" })).toHaveTextContent("外形カット線");
    expect(screen.getByRole("region", { name: "サマリー" })).toHaveTextContent("完全拘束");
    expect(
      screen.getByRole("region", { name: "サマリー" }).querySelector(".constraint-status-summary svg"),
    ).toBeInTheDocument();
    expect(screen.getByRole("region", { name: "サマリー" })).toHaveTextContent("幅 20.00 mm");
    expect(screen.getByRole("region", { name: "サマリー" })).toHaveTextContent("使用 1 件 / 未使用 1 件");
  });

  it("uses the Swift empty-state labels when no constraint or parameter exists", () => {
    render(<BottomWorkbench selectedEntity={undefined} layers={[]} constraints={[]} parameters={[]} />);

    const summary = screen.getByRole("region", { name: "サマリー" });
    expect(summary).toHaveTextContent("選択なし");
    expect(summary).toHaveTextContent("拘束なし");
    expect(summary).not.toHaveTextContent("拘束はありません。");
    expect(summary).toHaveTextContent("パラメータなし");
    expect(summary).toHaveTextContent("未使用 0 件");
    expect(summary.querySelector(".constraint-status-summary svg")).toBeInTheDocument();
  });
});
