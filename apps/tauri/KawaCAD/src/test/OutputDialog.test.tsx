import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { OutputDialog } from "@/features/output/components/OutputDialog";

const mocks = vi.hoisted(() => ({ invoke: vi.fn() }));

vi.mock("@tauri-apps/api/core", () => ({ invoke: mocks.invoke }));

describe("OutputDialog", () => {
  beforeEach(() => {
    mocks.invoke.mockReset();
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "direct_print_availability") return { status: "available" };
      if (command === "prepare_pdf_output") return { outputDocumentModel: { pageCount: 1, pages: [] }, warnings: [] };
      if (command === "list_printers") return [{ id: "printer:1", displayName: "Test Printer", selectable: true }];
      if (command === "prepare_direct_print")
        return { preparedPrintId: "prepared:1", outputDocumentModel: { pageCount: 1, pages: [] }, warnings: [] };
      return undefined;
    });
  });

  afterEach(cleanup);

  it("switches PDF and direct print in one settings sheet while preserving options", async () => {
    render(
      <OutputDialog
        documentName="Pattern"
        initialOrientation="portrait"
        initialDestination="pdf"
        onClose={vi.fn()}
        onSaved={vi.fn()}
        onPrinted={vi.fn()}
      />,
    );

    const includeDimensions = await screen.findByLabelText("寸法数値を出力に含める");
    fireEvent.click(includeDimensions);
    const destination = await screen.findByRole("combobox", { name: "出力先" });
    fireEvent.change(destination, { target: { value: "directPrint" } });

    expect(await screen.findByRole("dialog", { name: "直接印刷" })).toBeInTheDocument();
    expect(screen.getByLabelText("寸法数値を出力に含める")).not.toBeChecked();
    fireEvent.change(screen.getByRole("combobox", { name: "出力先" }), { target: { value: "pdf" } });

    expect(await screen.findByRole("dialog", { name: "PDF出力" })).toBeInTheDocument();
    expect(screen.getByLabelText("寸法数値を出力に含める")).not.toBeChecked();
    await waitFor(() => expect(mocks.invoke).toHaveBeenCalledWith("prepare_pdf_output", expect.any(Object)));
  });
});
