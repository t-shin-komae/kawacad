import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { useState } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { OpenSourceLicensesDialog } from "@/features/licenses/components/OpenSourceLicensesDialog";

describe("OpenSourceLicensesDialog", () => {
  afterEach(() => {
    cleanup();
    vi.unstubAllGlobals();
  });

  it("loads through the last bundled notice and can close and reopen without showing the fallback", async () => {
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
            {
              name: "tauri",
              version: "2.10.3",
              license: "MIT OR Apache-2.0",
              text: "last bundled license",
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
    expect(screen.getByText("tauri", { exact: true })).toBeInTheDocument();
    expect(screen.getByText("last bundled license", { exact: true })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "閉じる" }));
    expect(onClose).toHaveBeenCalledOnce();
  });

  it("reloads the bundled notices after the dialog is reopened", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          components: [
            {
              name: "serde_json",
              version: "1.0.149",
              license: "MIT OR Apache-2.0",
              text: "serde_json license",
            },
          ],
        }),
      }),
    );

    function Harness() {
      const [open, setOpen] = useState(true);
      return open ? (
        <OpenSourceLicensesDialog onClose={() => setOpen(false)} />
      ) : (
        <button type="button" onClick={() => setOpen(true)}>
          OSSライセンスを再表示
        </button>
      );
    }

    render(<Harness />);
    expect(await screen.findByText("serde_json", { exact: true })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "閉じる" }));
    fireEvent.click(screen.getByRole("button", { name: "OSSライセンスを再表示" }));
    expect(await screen.findByText("serde_json", { exact: true })).toBeInTheDocument();
    expect(fetch).toHaveBeenCalledTimes(2);
  });

  it("renders duplicate package notices without collapsing entries", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          components: [
            {
              name: "shared-package",
              version: "1.0.0",
              license: "MIT",
              text: "first notice",
            },
            {
              name: "shared-package",
              version: "1.0.0",
              license: "MIT",
              text: "second notice",
            },
          ],
        }),
      }),
    );

    render(<OpenSourceLicensesDialog onClose={vi.fn()} />);

    expect(await screen.findByText("first notice", { exact: true })).toBeInTheDocument();
    expect(screen.getByText("second notice", { exact: true })).toBeInTheDocument();
    expect(screen.getAllByRole("article")).toHaveLength(2);
  });
});
