import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { DocumentHeader } from "@/features/document/components/DocumentHeader";

describe("DocumentHeader synced editing", () => {
  afterEach(cleanup);
  it("commits a canonical project-name draft", () => {
    const onRename = vi.fn();
    render(<DocumentHeader documentName="旧名称" paperLabel="A4 Portrait" onRename={onRename} />);
    const input = screen.getByRole("textbox", { name: "プロジェクト名" });
    fireEvent.change(input, { target: { value: "  新名称  " } });
    fireEvent.blur(input);
    expect(onRename).toHaveBeenCalledWith("新名称");
  });
  it("keeps an invalid draft and explains the validation problem", () => {
    render(<DocumentHeader documentName="名称" paperLabel="A4 Portrait" onRename={vi.fn()} />);
    const input = screen.getByRole("textbox", { name: "プロジェクト名" });
    fireEvent.change(input, { target: { value: "   " } });
    fireEvent.blur(input);
    expect(input).toHaveAttribute("aria-invalid", "true");
    expect(screen.getByText("プロジェクト名を入力してください。")).toBeInTheDocument();
  });
  it("shows a choice when an external name update arrives during editing", () => {
    const view = render(<DocumentHeader documentName="初期" paperLabel="A4 Portrait" onRename={vi.fn()} />);
    const input = screen.getByRole("textbox", { name: "プロジェクト名" });
    fireEvent.focus(input);
    fireEvent.change(input, { target: { value: "手元の入力" } });
    view.rerender(<DocumentHeader documentName="外部更新" paperLabel="A4 Portrait" onRename={vi.fn()} />);
    expect(screen.getByText(/外部で更新されています/)).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "最新値を使う" }));
    expect(input).toHaveValue("外部更新");
  });
});
