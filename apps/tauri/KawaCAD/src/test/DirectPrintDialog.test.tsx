import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { DirectPrintDialog } from "@/features/output/components/DirectPrintDialog";

const mocks = vi.hoisted(() => ({ invoke: vi.fn() }));

vi.mock("@tauri-apps/api/core", () => ({ invoke: mocks.invoke }));

const prepared = {
  outputDocumentModel: { pageCount: 1, pages: [] },
  warnings: [],
};

describe("DirectPrintDialog", () => {
  beforeEach(() => {
    mocks.invoke.mockReset();
  });

  afterEach(cleanup);

  it("reprepares the print after a consumed submission fails", async () => {
    let preparationCount = 0;
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "direct_print_availability") return { status: "available" };
      if (command === "list_printers") return [{ id: "printer:1", displayName: "Test Printer", selectable: true }];
      if (command === "prepare_direct_print") {
        preparationCount += 1;
        return { ...prepared, preparedPrintId: `prepared:${preparationCount}` };
      }
      if (command === "run_prepared_direct_print") throw new Error("stale print job");
      return undefined;
    });

    render(<DirectPrintDialog initialOrientation="portrait" onClose={vi.fn()} onPrinted={vi.fn()} />);

    const print = await screen.findByRole("button", { name: "印刷を開始" });
    await waitFor(() => expect(print).toBeEnabled());
    fireEvent.click(print);

    await waitFor(() => expect(preparationCount).toBe(2));
    await waitFor(() => expect(print).toBeEnabled());
    expect(mocks.invoke).toHaveBeenCalledWith("run_prepared_direct_print", { preparedPrintId: "prepared:1" });
  });
});
