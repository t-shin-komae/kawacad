import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { DerivedValueDialog } from "@/features/constraints/components/DerivedValueDialog";

describe("DerivedValueDialog", () => {
  afterEach(cleanup);

  it("uses the Core-selected offset scope and allows a parameter reference", () => {
    const onConfirm = vi.fn();
    render(
      <DerivedValueDialog
        kind="offset"
        parameters={[{ id: "parameter:offset", name: "縫い代", valueMm: 3 }]}
        offsetOptions={[
          { scope: "closedContour", sourceEntityIds: ["line:1", "line:2"], direction: "inward" },
          { scope: "singleElement", sourceEntityIds: ["line:1"], direction: "right" },
        ]}
        onConfirm={onConfirm}
        onCancel={vi.fn()}
      />,
    );

    fireEvent.change(screen.getByRole("combobox", { name: "オフセット元" }), { target: { value: "singleElement" } });
    fireEvent.click(screen.getByLabelText("パラメータ参照"));
    fireEvent.click(screen.getByRole("button", { name: "適用" }));

    expect(onConfirm).toHaveBeenCalledWith(
      { parameter: "parameter:offset" },
      expect.objectContaining({ scope: "singleElement", sourceEntityIds: ["line:1"], direction: "right" }),
    );
  });

  it("uses the shared offset initial value", () => {
    render(<DerivedValueDialog kind="offset" parameters={[]} onConfirm={vi.fn()} onCancel={vi.fn()} />);
    expect(screen.getByRole("textbox", { name: "値 (mm)" })).toHaveValue("3.00");
  });

  it("keeps fillet value entry explicit and cancellable", () => {
    const onConfirm = vi.fn();
    const onCancel = vi.fn();
    render(
      <DerivedValueDialog kind="fillet" sourceCount={3} parameters={[]} onConfirm={onConfirm} onCancel={onCancel} />,
    );

    expect(screen.getByText("選択した 3 件の連続する要素にフィレットを作成します。")).toBeInTheDocument();
    expect(screen.getByRole("textbox", { name: "値 (mm)" })).toHaveValue("5.00");
    fireEvent.change(screen.getByRole("textbox", { name: "値 (mm)" }), { target: { value: "2.5" } });
    fireEvent.click(screen.getByRole("button", { name: "適用" }));
    expect(onConfirm).toHaveBeenCalledWith({ fixedMm: 2.5 }, undefined);
    fireEvent.click(screen.getByRole("button", { name: "キャンセル" }));
    expect(onCancel).toHaveBeenCalledOnce();
  });

  it("keeps a floating fillet draft's entered value under its owner state", () => {
    const onValueTextChange = vi.fn();
    render(
      <DerivedValueDialog
        kind="fillet"
        floating
        sourceCount={3}
        valueText="2.5"
        parameters={[]}
        onValueTextChange={onValueTextChange}
        onConfirm={vi.fn()}
        onCancel={vi.fn()}
      />,
    );

    expect(screen.getByRole("textbox", { name: "値 (mm)" })).toHaveValue("2.5");
    fireEvent.change(screen.getByRole("textbox", { name: "値 (mm)" }), { target: { value: "3" } });
    expect(onValueTextChange).toHaveBeenCalledWith("3");
  });

  it("places a floating derived editor near the recorded work position", () => {
    render(
      <DerivedValueDialog
        kind="fillet"
        floating
        floatingPosition={{ x: 120, y: 80 }}
        sourceCount={2}
        parameters={[]}
        onConfirm={vi.fn()}
        onCancel={vi.fn()}
      />,
    );

    expect(screen.getByRole("presentation")).toHaveStyle({ left: "136px", top: "96px", right: "auto", bottom: "auto" });
  });
});
