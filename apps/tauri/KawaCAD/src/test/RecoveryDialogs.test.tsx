import { cleanup, fireEvent, render, screen, within } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { RecoveryChooserDialog } from "@/features/recovery/components/RecoveryChooserDialog";
import { RecoverySaveFailureBanner } from "@/features/recovery/components/RecoverySaveFailureBanner";

describe("recovery presentation", () => {
  afterEach(cleanup);

  it("lists multiple candidates and prevents a broken candidate from being restored", () => {
    const onRestore = vi.fn();
    const onDiscard = vi.fn();
    const onReveal = vi.fn();
    render(
      <RecoveryChooserDialog
        candidates={[
          {
            id: "recoverable-1",
            displayName: "カードケース",
            originalDocumentPath: "/projects/card-case.kawa",
            updatedAtMs: 1_700_000_000_000,
            status: "recoverable",
          },
          {
            id: "broken-1",
            displayName: "破損した復旧候補",
            updatedAtMs: 1_700_000_100_000,
            status: "broken",
            details: "snapshot.kawa を読み込めません。",
          },
        ]}
        onRestore={onRestore}
        onDiscard={onDiscard}
        onReveal={onReveal}
        onPostpone={vi.fn()}
      />,
    );

    const dialog = screen.getByRole("dialog", { name: "復旧するドキュメントを選択" });
    const candidates = dialog.querySelectorAll(".recovery-candidate-card");
    expect(candidates).toHaveLength(2);
    fireEvent.click(within(candidates[0] as HTMLElement).getByRole("button", { name: "復元" }));
    expect(onRestore).toHaveBeenCalledWith("recoverable-1");
    expect(within(candidates[1] as HTMLElement).getByRole("button", { name: "復元" })).toBeDisabled();
    expect(within(candidates[1] as HTMLElement).getByRole("alert")).toHaveTextContent("snapshot.kawa");
    fireEvent.click(within(candidates[1] as HTMLElement).getByRole("button", { name: "破棄" }));
    fireEvent.click(within(candidates[1] as HTMLElement).getByRole("button", { name: "フォルダーに表示" }));
    expect(onDiscard).toHaveBeenCalledWith("broken-1");
    expect(onReveal).toHaveBeenCalledWith("broken-1");
  });

  it("keeps recovery-save failure actions available", () => {
    const onRetry = vi.fn();
    const onDismiss = vi.fn();
    render(<RecoverySaveFailureBanner details="disk full" onRetry={onRetry} onDismiss={onDismiss} />);
    const alert = screen.getByRole("alert");
    fireEvent.click(within(alert).getByRole("button", { name: "詳細" }));
    expect(alert).toHaveTextContent("disk full");
    fireEvent.click(within(alert).getByRole("button", { name: "再試行" }));
    fireEvent.click(within(alert).getByRole("button", { name: "閉じる" }));
    expect(onRetry).toHaveBeenCalledOnce();
    expect(onDismiss).toHaveBeenCalledOnce();
  });
});
