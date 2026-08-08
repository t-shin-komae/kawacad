import { cleanup, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { PDFExportDialog } from "@/features/output/components/PDFExportDialog";

const mocks = vi.hoisted(() => ({ invoke: vi.fn(), save: vi.fn(), open: vi.fn(), confirm: vi.fn() }));

vi.mock("@tauri-apps/api/core", () => ({ invoke: mocks.invoke }));
vi.mock("@tauri-apps/plugin-dialog", () => ({ save: mocks.save, open: mocks.open, confirm: mocks.confirm }));

const prepared = {
  outputDocumentModel: {
    paperSize: "a4",
    orientation: "portrait",
    scale: "actualSize",
    pageCount: 1,
    pages: [
      {
        gridColumn: 0,
        gridRow: 0,
        widthMm: 210,
        heightMm: 297,
        rotationDeg: 0,
        printableAreaMm: { leftMm: -100, rightMm: 100, topMm: 143.5, bottomMm: -143.5 },
        graphics: [
          {
            geometry: {
              kind: "lineSegment",
              payload: { startMm: { xMm: -20, yMm: -40 }, endMm: { xMm: 20, yMm: -40 } },
            },
            style: { stroke: { red: 0, green: 0, blue: 0, alpha: 1 }, strokeWidthMm: 0.2, pattern: "solid" },
          },
          {
            geometry: { kind: "circle", payload: { centerMm: { xMm: 10, yMm: 20 }, radiusMm: 12 } },
            style: { stroke: { red: 1, green: 0, blue: 0, alpha: 1 }, strokeWidthMm: 0.4, pattern: "dashed" },
          },
          {
            geometry: {
              kind: "arc",
              payload: { centerMm: { xMm: -10, yMm: 20 }, radiusMm: 8, startAngleRad: 0, sweepAngleRad: Math.PI / 2 },
            },
            style: { stroke: { red: 0, green: 0, blue: 1, alpha: 1 }, strokeWidthMm: 0.2, pattern: "dotted" },
          },
        ],
        texts: [
          { content: "自由テキスト", positionMm: { xMm: 0, yMm: 0 }, fontSizeMm: 3.5 },
          { content: "50mm", positionMm: { xMm: -65, yMm: -125 }, fontSizeMm: 3.5 },
        ],
        guide: {
          startMm: { xMm: -90, yMm: -130 },
          endMm: { xMm: -40, yMm: -130 },
          label: "50mm",
          labelPositionMm: { xMm: -65, yMm: -125 },
        },
      },
    ],
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

  it("clears a previously prepared model when regeneration fails", async () => {
    let rejectRegeneration: (reason?: unknown) => void = () => undefined;
    let preparationCount = 0;
    mocks.invoke.mockImplementation((command: string) => {
      if (command !== "prepare_pdf_output") return undefined;
      preparationCount += 1;
      if (preparationCount === 1) return Promise.resolve(prepared);
      return new Promise((_, reject) => {
        rejectRegeneration = reject;
      });
    });
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
    expect(save).toBeEnabled();
    fireEvent.change(screen.getByLabelText("用紙向き"), { target: { value: "landscape" } });
    await waitFor(() => expect(preparationCount).toBe(2));
    rejectRegeneration(new Error("範囲外です"));

    expect(await screen.findByText(/出力内容を生成できません/)).toBeInTheDocument();
    expect(save).toBeDisabled();
    expect(screen.getByText("0 ページ")).toBeInTheDocument();
  });

  it("renders graphics, text, the printable area, and the scale guide in the final preview", async () => {
    render(
      <PDFExportDialog
        documentName="Pattern"
        initialOrientation="portrait"
        onClose={vi.fn()}
        onOrientationChange={vi.fn()}
        onSaved={vi.fn()}
      />,
    );

    const page = await screen.findByTestId("pdf-preview-page-1");
    expect(within(page).getByTestId("pdf-printable-area")).toBeInTheDocument();
    expect(within(page).getByTestId("pdf-output-line")).toHaveAttribute("x1", "85");
    expect(within(page).getByTestId("pdf-output-circle")).toHaveAttribute("stroke-dasharray", "6 3");
    expect(within(page).getByTestId("pdf-output-arc")).toBeInTheDocument();
    expect(within(page).getByTestId("pdf-output-guide")).toBeInTheDocument();
    expect(within(page).getAllByTestId("pdf-output-text")).toHaveLength(2);
    expect(within(page).getByText("自由テキスト")).toBeInTheDocument();
    expect(within(page).getByText("50mm")).toBeInTheDocument();
  });

  it("updates the final preview with the regenerated rotation", async () => {
    mocks.invoke.mockImplementation(async (command: string, payload?: { options?: { rotationDeg?: number } }) => {
      if (command !== "prepare_pdf_output") return undefined;
      const rotationDeg = payload?.options?.rotationDeg ?? 0;
      return {
        ...prepared,
        outputDocumentModel: {
          ...prepared.outputDocumentModel,
          pages: prepared.outputDocumentModel.pages.map((page) => ({ ...page, rotationDeg })),
        },
      };
    });
    render(
      <PDFExportDialog
        documentName="Pattern"
        initialOrientation="portrait"
        onClose={vi.fn()}
        onOrientationChange={vi.fn()}
        onSaved={vi.fn()}
      />,
    );

    const page = await screen.findByTestId("pdf-preview-page-1");
    const line = within(page).getByTestId("pdf-output-line");
    expect(line).toHaveAttribute("x1", "85");
    fireEvent.change(screen.getByLabelText("回転"), { target: { value: "90" } });

    await waitFor(() => expect(screen.getByTestId("pdf-preview-page-1")).toHaveAttribute("data-rotation-deg", "90"));
    expect(within(screen.getByTestId("pdf-preview-page-1")).getByTestId("pdf-output-line")).toHaveAttribute(
      "x1",
      "145",
    );
    expect(mocks.invoke).toHaveBeenLastCalledWith("prepare_pdf_output", {
      options: expect.objectContaining({ rotationDeg: 90 }),
    });
  });
});
