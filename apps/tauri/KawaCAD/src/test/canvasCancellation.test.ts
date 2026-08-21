import { describe, expect, it, vi } from "vitest";
import { cancelCanvasInteraction, type CanvasCancellationInput } from "@/features/canvas/actions/canvasCancellation";

function cancellationInput(overrides: Partial<CanvasCancellationInput> = {}): CanvasCancellationInput {
  return {
    pasteOptions: undefined,
    clearPastePlacement: vi.fn(),
    setMessage: vi.fn(),
    pan: { current: undefined },
    marquee: { current: undefined },
    move: { current: undefined },
    controlMove: { current: undefined },
    measurementMove: { current: undefined },
    dimensionMove: { current: undefined },
    freeTextMove: { current: undefined },
    setSnapSuppressed: vi.fn(),
    setSnapActive: vi.fn(),
    setDragDuplicating: vi.fn(),
    setMarqueeCurrent: vi.fn(),
    setHoveredTargetEntityId: vi.fn(),
    setPendingConstraintValue: vi.fn(),
    setPendingDerivedValue: vi.fn(),
    clearPendingTextEntry: vi.fn(),
    clearCanvasPreview: vi.fn(),
    previewActive: { current: false },
    pendingTargets: [],
    setPendingTargets: vi.fn(),
    draft: [],
    setDraft: vi.fn(),
    selectedMeasurementId: undefined,
    clearSelectedMeasurement: vi.fn(),
    selectedConstraintId: undefined,
    clearSelectedConstraint: vi.fn(),
    selectedFreeTextId: undefined,
    clearSelectedFreeText: vi.fn(),
    selectedStitchStartPointId: undefined,
    clearSelectedStitchStartPoint: vi.fn(),
    selected: new Set(),
    clearEntitySelection: vi.fn(),
    pendingConstraintValue: undefined,
    pendingDerivedValue: undefined,
    pendingTextEntry: undefined,
    editingFreeTextId: undefined,
    clearFreeTextEdit: vi.fn(),
    rewindFilletDraft: vi.fn(),
    selectedTool: "select",
    selectTool: vi.fn(),
    ...overrides,
  };
}

describe("Canvas cancellation boundary", () => {
  it("cancels paste placement before any selection state", () => {
    const input = cancellationInput({
      pasteOptions: {
        activeMode: "cursor",
        anchorPoint: { xMm: 0, yMm: 0 },
        nearSourcePoint: { xMm: 0, yMm: 0 },
        namespace: "copy:1",
      },
    });

    expect(cancelCanvasInteraction(input)).toBe(true);
    expect(input.clearPastePlacement).toHaveBeenCalledOnce();
    expect(input.clearEntitySelection).not.toHaveBeenCalled();
  });

  it("cancels preview, then switches a drawing tool before external Escape targets", () => {
    const preview = cancellationInput({ previewActive: { current: true } });
    expect(cancelCanvasInteraction(preview)).toBe(true);
    expect(preview.clearCanvasPreview).toHaveBeenCalledOnce();

    const drawing = cancellationInput({ selectedTool: "line" });
    expect(cancelCanvasInteraction(drawing)).toBe(true);
    expect(drawing.selectTool).toHaveBeenCalledWith("select");

    const idle = cancellationInput();
    expect(cancelCanvasInteraction(idle)).toBe(false);
    expect(idle.selectTool).not.toHaveBeenCalled();
  });
});
