import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { TextEntryDialog } from "@/shared/components/TextEntryDialog";

describe("TextEntryDialog", () => {
  afterEach(cleanup);

  it("returns explicit, labelled values without using a browser prompt", () => {
    const onConfirm = vi.fn();
    render(
      <TextEntryDialog
        title="パラメータを追加"
        fields={[
          { id: "name", label: "パラメータ名", initialValue: "幅" },
          { id: "value", label: "値 (mm)", initialValue: "10", inputMode: "decimal" },
        ]}
        onConfirm={onConfirm}
        onCancel={vi.fn()}
      />,
    );

    fireEvent.change(screen.getByRole("textbox", { name: "パラメータ名" }), { target: { value: "縫い代" } });
    fireEvent.change(screen.getByRole("textbox", { name: "値 (mm)" }), { target: { value: "3.5" } });
    fireEvent.click(screen.getByRole("button", { name: "適用" }));
    expect(onConfirm).toHaveBeenCalledWith({ name: "縫い代", value: "3.5" });
  });
});
