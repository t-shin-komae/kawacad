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
});
