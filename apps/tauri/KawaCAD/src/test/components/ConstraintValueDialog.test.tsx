import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { ConstraintValueDialog } from "@/features/constraints/components/ConstraintValueDialog";

describe("ConstraintValueDialog", () => {
  afterEach(cleanup);

  it("accepts locale decimals and signed angle values through the shared parser", () => {
    const onConfirm = vi.fn();
    render(
      <ConstraintValueDialog
        label="角度"
        initialValue={{ fixedDegrees: 90 }}
        parameters={[]}
        degrees
        onConfirm={onConfirm}
        onCancel={vi.fn()}
      />,
    );
    const value = screen.getByRole("textbox", { name: "角度 (度)" });
    fireEvent.change(value, { target: { value: "-12,5" } });
    fireEvent.click(screen.getByRole("button", { name: "確定" }));
    expect(onConfirm).toHaveBeenCalledWith({ fixedDegrees: -12.5 });
  });

  it("rejects exponent notation and non-positive dimensional values", () => {
    const onConfirm = vi.fn();
    render(
      <ConstraintValueDialog label="距離" parameters={[]} degrees={false} onConfirm={onConfirm} onCancel={vi.fn()} />,
    );
    const value = screen.getByRole("textbox", { name: "値 (mm)" });
    fireEvent.change(value, { target: { value: "1e3" } });
    expect(screen.getByRole("button", { name: "確定" })).toBeDisabled();
    fireEvent.change(value, { target: { value: "0" } });
    expect(screen.getByRole("button", { name: "確定" })).toBeDisabled();
    expect(onConfirm).not.toHaveBeenCalled();
  });

  it("marks a floating value editor for the canvas HUD presentation", () => {
    render(
      <ConstraintValueDialog
        label="距離"
        initialValue={{ fixedMm: 12 }}
        parameters={[]}
        degrees={false}
        floating
        onConfirm={vi.fn()}
        onCancel={vi.fn()}
      />,
    );

    expect(screen.getByRole("presentation")).toHaveClass("floating-value-backdrop");
  });

  it("formats fixed initial values and leaves unresolved values blank", () => {
    render(
      <ConstraintValueDialog
        label="距離"
        initialValue={{ fixedMm: 12 }}
        parameters={[]}
        degrees={false}
        onConfirm={vi.fn()}
        onCancel={vi.fn()}
      />,
    );
    expect(screen.getByRole("textbox", { name: "値 (mm)" })).toHaveValue("12.00");
    cleanup();
    render(
      <ConstraintValueDialog
        label="距離"
        initialValue={{}}
        parameters={[]}
        degrees={false}
        onConfirm={vi.fn()}
        onCancel={vi.fn()}
      />,
    );
    expect(screen.getByRole("textbox", { name: "値 (mm)" })).toHaveValue("");
  });

  it("places a floating value editor near the recorded work position", () => {
    render(
      <ConstraintValueDialog
        label="距離"
        initialValue={{ fixedMm: 12 }}
        parameters={[]}
        degrees={false}
        floating
        floatingPosition={{ x: 120, y: 80 }}
        onConfirm={vi.fn()}
        onCancel={vi.fn()}
      />,
    );

    expect(screen.getByRole("presentation")).toHaveStyle({ left: "136px", top: "96px", right: "auto", bottom: "auto" });
  });
});
