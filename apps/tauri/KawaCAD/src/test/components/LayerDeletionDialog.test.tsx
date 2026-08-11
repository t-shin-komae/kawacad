import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { LayerDeletionDialog } from "@/features/document/components/LayerDeletionDialog";

describe("LayerDeletionDialog", () => {
  afterEach(cleanup);

  it("describes the Core-reported impact before deletion", () => {
    render(<LayerDeletionDialog layerName="補助線" affectedCount={3} onConfirm={vi.fn()} onCancel={vi.fn()} />);

    expect(screen.getByRole("alertdialog", { name: "レイヤー削除の確認" })).toHaveTextContent(
      "「補助線」には3件の図形または派生要素が紐づいています。削除すると、対象は残りのレイヤーへ移動します。",
    );
  });

  it("keeps confirmation and cancellation as distinct user actions", () => {
    const onConfirm = vi.fn();
    const onCancel = vi.fn();
    render(<LayerDeletionDialog layerName="補助線" affectedCount={1} onConfirm={onConfirm} onCancel={onCancel} />);

    fireEvent.click(screen.getByRole("button", { name: "キャンセル" }));
    expect(onCancel).toHaveBeenCalledOnce();
    expect(onConfirm).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "削除" }));
    expect(onConfirm).toHaveBeenCalledOnce();
  });
});
