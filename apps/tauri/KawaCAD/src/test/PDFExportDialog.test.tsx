import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { PDFExportDialog } from "@/features/output/components/PDFExportDialog";

const mocks = vi.hoisted(() => ({ invoke: vi.fn(), save: vi.fn(), open: vi.fn(), confirm: vi.fn() }));

vi.mock("@tauri-apps/api/core", () => ({ invoke: mocks.invoke }));
vi.mock("@tauri-apps/plugin-dialog", () => ({ save: mocks.save, open: mocks.open, confirm: mocks.confirm }));

const prepared = {
  outputDocumentModel: {
    paperSize: "a4",
    pageCount: 1,
    pages: [{ gridColumn: 0, gridRow: 0, widthMm: 210, heightMm: 297 }],
  },
  warnings: [],
};

describe("PDFExportDialog", () => {
  beforeEach(() => {
    mocks.invoke.mockReset();
    mocks.save.mockReset();
    mocks.invoke.mockImplementation(async (command: string) => {
      if (command === "prepare_pdf_output") return prepared;
      return undefined;
    });
    mocks.save.mockResolvedValue("/tmp/pattern.pdf");
  });

  afterEach(cleanup);

  it("prepares the configured model and saves that same model", async () => {
    const onSaved = vi.fn();
    render(
      <PDFExportDialog
        documentName="Pattern"
        initialOrientation="portrait"
        onClose={vi.fn()}
        onOrientationChange={vi.fn()}
        onSaved={onSaved}
      />,
    );

    await screen.findByText("1 ページ");
    fireEvent.click(screen.getByRole("button", { name: "保存へ進む" }));

    await waitFor(() =>
      expect(mocks.invoke).toHaveBeenCalledWith("save_prepared_pdf", {
        outputDocumentModel: prepared.outputDocumentModel,
        path: "/tmp/pattern.pdf",
      }),
    );
    expect(mocks.save).toHaveBeenCalledWith(expect.objectContaining({ defaultPath: "Pattern.pdf" }));
    expect(onSaved).toHaveBeenCalledWith("/tmp/pattern.pdf");
  });

  it("requires warning acknowledgement before saving", async () => {
    mocks.invoke.mockImplementation(async (command: string) =>
      command === "prepare_pdf_output" ? { ...prepared, warnings: [{ message: "境界をまたいでいます" }] } : undefined,
    );
    render(
      <PDFExportDialog
        documentName="Pattern"
        initialOrientation="portrait"
        onClose={vi.fn()}
        onOrientationChange={vi.fn()}
        onSaved={vi.fn()}
      />,
    );

    const save = await screen.findByRole("button", { name: "保存へ進む" });
    expect(save).toBeDisabled();
    fireEvent.click(screen.getByLabelText("警告内容を確認しました"));
    expect(save).toBeEnabled();
  });
});
