import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { OpenSourceLicensesDialog } from "@/features/licenses/components/OpenSourceLicensesDialog";

describe("OpenSourceLicensesDialog", () => {
  afterEach(() => {
    cleanup();
    vi.unstubAllGlobals();
  });

  it("loads the bundled notices without showing the fallback first", async () => {
    const onClose = vi.fn();
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          components: [
            {
              name: "serde",
              version: "1.0.228",
              license: "MIT OR Apache-2.0",
              text: "serde license",
            },
          ],
        }),
      }),
    );
    render(<OpenSourceLicensesDialog onClose={onClose} />);

    expect(screen.getByRole("dialog", { name: "OSSライセンス" })).toBeInTheDocument();
    expect(screen.getByText("読み込み中…")).toBeInTheDocument();
    expect(screen.queryByText("lucide-react", { exact: true })).not.toBeInTheDocument();
    expect(await screen.findByText("serde", { exact: true })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "閉じる" }));
    expect(onClose).toHaveBeenCalledOnce();
  });
});
