import type { CanvasViewMode } from "@/features/canvas/domain/canvasDomainModels";

export type NativeMenuState = {
  hasDocument: boolean;
  viewMode: CanvasViewMode;
  canUndo: boolean;
  canRedo: boolean;
  hasSelection: boolean;
  canPaste: boolean;
  canEditLayers: boolean;
  canExportPDF: boolean;
  canDirectPrint: boolean;
  canSmoothArcTangencies: boolean;
  inspectorOpen: boolean;
  bottomWorkbenchVisible: boolean;
};

export type NativeMenuAvailability = {
  save: boolean;
  saveAs: boolean;
  exportPDF: boolean;
  directPrint: boolean;
  undo: boolean;
  redo: boolean;
  duplicate: boolean;
  delete: boolean;
  paste: boolean;
  addLayer: boolean;
  smoothArcTangencies: boolean;
  findInspector: boolean;
  inspectorLabel: string;
  bottomWorkbenchLabel: string;
};

export function nativeMenuAvailability(state: NativeMenuState | undefined): NativeMenuAvailability {
  const hasDocument = Boolean(state?.hasDocument);
  const editable = hasDocument && state?.viewMode === "editDisplay";
  return {
    save: hasDocument,
    saveAs: hasDocument,
    exportPDF: Boolean(state?.canExportPDF && hasDocument),
    directPrint: Boolean(state?.canDirectPrint && hasDocument),
    undo: Boolean(state?.canUndo && hasDocument),
    redo: Boolean(state?.canRedo && hasDocument),
    duplicate: Boolean(state?.hasSelection && editable),
    delete: Boolean(state?.hasSelection && editable),
    paste: Boolean(state?.canPaste && editable),
    addLayer: Boolean(state?.canEditLayers && editable),
    smoothArcTangencies: Boolean(state?.canSmoothArcTangencies && editable),
    findInspector: Boolean(state?.inspectorOpen),
    inspectorLabel: state?.inspectorOpen ? "インスペクタを隠す" : "インスペクタを表示",
    bottomWorkbenchLabel: state?.bottomWorkbenchVisible ? "サマリーを隠す" : "サマリーを表示",
  };
}
