import { useEffect, type Dispatch, type SetStateAction } from "react";
import { appStrings } from "@/localization";
import { defaultViewport } from "@/features/canvas/domain/cad";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
import type { State } from "@/shared/domain/coreWireTypes";
import type { MenuAction } from "@/app/domain/nativeMenuTypes";
import type { AppActionContext } from "@/app/actions/useActionRuntime";
import type { AppActionSurface } from "@/app/actions/useAppActions";
import type { OutputDestination } from "@/features/output/state/useOutputPresentation";
import type {
  PendingConstraintValue,
  PendingDerivedValue,
  PendingTextEntry,
} from "@/features/canvas/state/useCanvasPresentation";

function isTextEditingElement(element: EventTarget | null) {
  return (
    element instanceof HTMLElement &&
    (element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement || element.isContentEditable)
  );
}

function performTextEditingCommand(action: "cut" | "copy" | "paste") {
  return (
    isTextEditingElement(document.activeElement) &&
    typeof document.execCommand === "function" &&
    document.execCommand(action)
  );
}

type ActionContext = Pick<
  AppActionContext,
  | "state"
  | "selected"
  | "setSelected"
  | "pasteOptions"
  | "setPasteOptions"
  | "pan"
  | "marquee"
  | "move"
  | "controlMove"
  | "measurementMove"
  | "dimensionMove"
  | "freeTextMove"
  | "setSnapSuppressed"
  | "setSnapActive"
  | "setDragDuplicating"
  | "setMarqueeCurrent"
  | "setHoveredTargetEntityId"
  | "setEditingFreeTextId"
  | "setPendingConstraintValue"
  | "setPendingDerivedValue"
  | "setPendingTextEntry"
  | "setPendingTargets"
  | "setDraft"
  | "setSettingPartOriginId"
  | "setSelectedMeasurementId"
  | "setSelectedConstraintId"
  | "setSelectedFreeTextId"
  | "setSelectedStitchStartPointId"
  | "setInspectorSelectedPartId"
  | "setLayerDeletionConfirmation"
  | "setCompactDrawer"
  | "pendingTargets"
  | "draft"
  | "settingPartOriginId"
  | "selectedMeasurementId"
  | "selectedConstraintId"
  | "selectedFreeTextId"
  | "selectedStitchStartPointId"
  | "inspectorSelectedPartId"
  | "editingFreeTextId"
  | "layerDeletionConfirmation"
  | "previewActive"
> & {
  layoutMode: string;
  a4Landscape: boolean;
  setOutputDestination: Dispatch<SetStateAction<OutputDestination | undefined>>;
  setOutputOrientation: (landscape: boolean) => void;
  compactDrawer: "tools" | "inspector" | undefined;
  pendingConstraintValue: PendingConstraintValue | undefined;
  pendingDerivedValue: PendingDerivedValue | undefined;
  pendingTextEntry: PendingTextEntry | undefined;
  clearCanvasPreview: AppActionContext["clearCanvasPreview"];
  setLicensesOpen: Dispatch<SetStateAction<boolean>>;
  setInspectorOpen: Dispatch<SetStateAction<boolean>>;
  setBottomWorkbenchVisible: Dispatch<SetStateAction<boolean>>;
  setViewport: AppActionContext["setViewport"];
  setMessage: AppActionContext["setMessage"];
  resetWorkspace: AppActionSurface["resetWorkspace"];
  actions: Pick<
    AppActionSurface,
    | "saveDocument"
    | "saveCurrentDocument"
    | "openDocument"
    | "newDocument"
    | "restoreHistory"
    | "cutSelection"
    | "copySelection"
    | "pasteSelection"
    | "duplicateSelection"
    | "reloadDocument"
    | "addLayer"
    | "deleteSelection"
    | "selectTool"
    | "setDocumentViewMode"
    | "rewindFilletDraft"
    | "smoothSelectedArcTangencies"
  >;
};

/** Owns application-wide keyboard and native-menu command translation. */
export function useGlobalCommands(context: ActionContext) {
  const {
    actions,
    state,
    selected,
    setSelected,
    pasteOptions,
    setPasteOptions,
    pan,
    marquee,
    move,
    controlMove,
    measurementMove,
    dimensionMove,
    freeTextMove,
    setSnapSuppressed,
    setSnapActive,
    setDragDuplicating,
    setMarqueeCurrent,
    setHoveredTargetEntityId,
    setEditingFreeTextId,
    setPendingConstraintValue,
    setPendingDerivedValue,
    setPendingTextEntry,
    setLayerDeletionConfirmation,
    setCompactDrawer,
    compactDrawer,
    pendingTargets,
    draft,
    settingPartOriginId,
    selectedMeasurementId,
    selectedConstraintId,
    selectedFreeTextId,
    selectedStitchStartPointId,
    inspectorSelectedPartId,
    editingFreeTextId,
    pendingConstraintValue,
    pendingDerivedValue,
    pendingTextEntry,
    layerDeletionConfirmation,
    previewActive,
    layoutMode,
    a4Landscape,
    setOutputDestination,
    setOutputOrientation,
    setLicensesOpen,
    setInspectorOpen,
    setBottomWorkbenchVisible,
    setViewport,
    setMessage,
    resetWorkspace,
  } = context;

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.defaultPrevented) return;
      const primary = event.metaKey || event.ctrlKey;
      const key = event.key.toLowerCase();
      if (primary && ["x", "c", "v"].includes(key) && isTextEditingElement(event.target)) return;
      if (primary && key === "s") {
        event.preventDefault();
        if (event.shiftKey) void actions.saveDocument();
        else actions.saveCurrentDocument();
      } else if (primary && key === "o") {
        event.preventDefault();
        void actions.openDocument();
      } else if (primary && key === "n") {
        event.preventDefault();
        actions.newDocument();
      } else if (primary && key === "z") {
        event.preventDefault();
        actions.restoreHistory(event.shiftKey ? "redo" : "undo");
      } else if (primary && key === "x") {
        event.preventDefault();
        void actions.cutSelection();
      } else if (primary && key === "c") {
        event.preventDefault();
        void actions.copySelection();
      } else if (primary && key === "v") {
        event.preventDefault();
        actions.pasteSelection();
      } else if (primary && key === "d") {
        event.preventDefault();
        actions.duplicateSelection();
      } else if (primary && key === "a") {
        event.preventDefault();
        setSelected(new Set(state?.entities.map((entity) => entity.id) ?? []));
      } else if (primary && key === "f") {
        event.preventDefault();
        window.dispatchEvent(new Event("kawa-cad-find-inspector"));
      } else if (primary && key === "r") {
        event.preventDefault();
        actions.reloadDocument();
      } else if (primary && event.altKey && (key === "1" || key === "2")) {
        event.preventDefault();
        actions.setDocumentViewMode(key === "1" ? "editDisplay" : "outputPreview");
      } else if (primary && key >= "1" && key <= "5") {
        event.preventDefault();
        actions.selectTool((["select", "point", "line", "circle", "centerLine"] as Tool[])[Number(key) - 1]);
      } else if (!primary && !event.altKey && key === "v") {
        event.preventDefault();
        actions.selectTool("select");
      } else if (primary && event.shiftKey && key === "h") {
        event.preventDefault();
        actions.selectTool("horizontal");
      } else if (primary && event.shiftKey && key === "v") {
        event.preventDefault();
        actions.selectTool("vertical");
      } else if (primary && event.shiftKey && key === "l") {
        event.preventDefault();
        actions.addLayer();
      } else if ((event.key === "Delete" || event.key === "Backspace") && isTextEditingElement(event.target)) {
        return;
      } else if (event.key === "Delete" || event.key === "Backspace") {
        event.preventDefault();
        actions.deleteSelection();
      } else if (event.key === "Escape") {
        event.preventDefault();
        if (pasteOptions) {
          setPasteOptions(undefined);
          setMessage(appStrings.status.pastePositionDismissed);
          return;
        }
        pan.current = undefined;
        marquee.current = undefined;
        move.current = undefined;
        setSnapSuppressed(false);
        setSnapActive(false);
        setDragDuplicating(false);
        setMarqueeCurrent(undefined);
        setHoveredTargetEntityId(undefined);
        controlMove.current = undefined;
        measurementMove.current = undefined;
        dimensionMove.current = undefined;
        freeTextMove.current = undefined;
        if (editingFreeTextId) setEditingFreeTextId(undefined);
        else if (pendingConstraintValue) setPendingConstraintValue(undefined);
        else if (pendingDerivedValue?.candidate === "fillet") actions.rewindFilletDraft();
        else if (pendingDerivedValue) setPendingDerivedValue(undefined);
        else if (pendingTextEntry) setPendingTextEntry(undefined);
        else if (layerDeletionConfirmation) setLayerDeletionConfirmation(undefined);
        else if (compactDrawer) setCompactDrawer(undefined);
        else if (previewActive.current) {
          context.clearCanvasPreview();
          setMessage(appStrings.status.movePreviewCancelled);
        } else if (pendingTargets.length) context.setPendingTargets([]);
        else if (draft.length) context.setDraft([]);
        else if (settingPartOriginId) context.setSettingPartOriginId(undefined);
        else if (selectedMeasurementId) context.setSelectedMeasurementId(undefined);
        else if (selectedConstraintId) context.setSelectedConstraintId(undefined);
        else if (selectedFreeTextId) context.setSelectedFreeTextId(undefined);
        else if (selectedStitchStartPointId) context.setSelectedStitchStartPointId(undefined);
        else if (selected.size) setSelected(new Set());
        else if (inspectorSelectedPartId) {
          context.setInspectorSelectedPartId(undefined);
          setMessage(appStrings.status.partSelectionCleared);
        } else actions.selectTool("select");
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [context, actions]);

  useEffect(() => {
    const onMenu = (event: Event) => {
      const action = (event as CustomEvent<MenuAction>).detail;
      if (action === "new") actions.newDocument();
      else if (action === "open") void actions.openDocument();
      else if (action === "save") actions.saveCurrentDocument();
      else if (action === "saveAs") void actions.saveDocument();
      else if (action === "exportPDF") setOutputDestination("pdf");
      else if (action === "directPrint") setOutputDestination("directPrint");
      else if (action === "undo" || action === "redo") actions.restoreHistory(action);
      else if (action === "cut") {
        if (!performTextEditingCommand("cut")) void actions.cutSelection();
      } else if (action === "copy") {
        if (!performTextEditingCommand("copy")) void actions.copySelection();
      } else if (action === "paste") {
        if (!performTextEditingCommand("paste")) actions.pasteSelection();
      } else if (action === "duplicate") actions.duplicateSelection();
      else if (action === "delete") actions.deleteSelection();
      else if (action === "selectAll") setSelected(new Set(state?.entities.map((entity) => entity.id) ?? []));
      else if (action === "cancelCurrentInteraction")
        window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
      else if (action === "findInspector") window.dispatchEvent(new Event("kawa-cad-find-inspector"));
      else if (action === "toggleInspector") {
        if (layoutMode === "compact") setCompactDrawer((value) => (value === "inspector" ? undefined : "inspector"));
        else setInspectorOpen((value) => !value);
      } else if (action === "toggleBottomWorkbench")
        setBottomWorkbenchVisible((visible) => {
          setMessage(visible ? appStrings.status.summaryHidden : appStrings.status.summaryShown);
          return !visible;
        });
      else if (action === "zoomToFit") setViewport(defaultViewport);
      else if (action === "resetLayout") resetWorkspace();
      else if (action === "reload") actions.reloadDocument();
      else if (action === "smoothArcTangencies") actions.smoothSelectedArcTangencies();
      else if (action === "editDisplay" || action === "outputPreview") actions.setDocumentViewMode(action);
      else if (action === "toggleA4Orientation") setOutputOrientation(!a4Landscape);
      else if (action === "addLayer") actions.addLayer();
      else if (action === "openLicenses") setLicensesOpen(true);
      else actions.selectTool(action);
    };
    window.addEventListener("kawa-cad-menu", onMenu);
    return () => window.removeEventListener("kawa-cad-menu", onMenu);
  }, [context, actions, a4Landscape]);
}
