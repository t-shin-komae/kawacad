import { act, renderHook } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { useDocumentLifecycleComposition } from "@/app/actions/useDocumentLifecycleComposition";
import type { State } from "@/shared/domain/coreWireTypes";

describe("document lifecycle composition", () => {
  it("clears both inspector and part-origin selections after loading a document", () => {
    const resetCanvasPresentation = vi.fn();
    const clearInspectorSelection = vi.fn();
    const clearPartOriginSelection = vi.fn();
    const closeWorkspacePanels = vi.fn();
    const next = { layers: [], sharedStyles: [] } as unknown as State;
    const { result } = renderHook(() =>
      useDocumentLifecycleComposition({
        resetCanvasPresentation,
        clearTransientCanvasState: vi.fn(),
        clearInspectorSelection,
        clearPartOriginSelection,
        closeWorkspacePanels,
      }),
    );

    act(() => result.current.onDocumentLoaded(next));

    expect(resetCanvasPresentation).toHaveBeenCalledWith({ layers: [], sharedStyles: [] });
    expect(clearInspectorSelection).toHaveBeenCalledOnce();
    expect(clearPartOriginSelection).toHaveBeenCalledOnce();
    expect(closeWorkspacePanels).toHaveBeenCalledOnce();
  });
});
