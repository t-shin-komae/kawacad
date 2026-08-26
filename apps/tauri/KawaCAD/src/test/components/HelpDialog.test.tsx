import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { HelpDialog } from "@/features/help/components/HelpDialog";

describe("HelpDialog", () => {
  afterEach(cleanup);

  it("shows searchable tool guidance and canvas operation headings", () => {
    render(<HelpDialog initialSection="tools" onClose={() => undefined} />);

    expect(screen.getByRole("heading", { name: "ツールとショートカット" })).toBeInTheDocument();
    expect(screen.getByText("接線")).toBeInTheDocument();
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "フィレット" } });
    expect(screen.getByText("フィレット")).toBeInTheDocument();
    expect(screen.queryByText("接線")).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "スナップとキャンバス操作" }));
    expect(screen.getByRole("heading", { name: "スナップとキャンバス操作" })).toBeInTheDocument();
    expect(screen.getByText(/Controlを押すと/)).toBeInTheDocument();
  });
});
