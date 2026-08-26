import { useEffect, type Dispatch, type SetStateAction } from "react";
import { appStrings } from "@/localization";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
import type { MenuAction } from "@/app/domain/nativeMenuTypes";
import type { AppActionSurface } from "@/app/actions/useAppActions";
import type { OutputDestination } from "@/features/output/state/useOutputPresentation";
import type { HelpSection } from "@/features/help/state/useHelpPresentation";

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

type GlobalCommandActions = {
  document: Pick<
    AppActionSurface["document"],
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
  >;
  canvas: Pick<AppActionSurface["canvas"], "selectTool" | "rewindFilletDraft" | "smoothSelectedArcTangencies">;
  output: Pick<AppActionSurface["output"], "setDocumentViewMode">;
};

type GlobalCanvasCommandsInput = {
  canvasActions: GlobalCommandActions["canvas"];
  cancelCurrentInteraction: () => void;
  zoomToFit: () => void;
};

type GlobalDocumentCommandsInput = {
  selectAllEntities: () => void;
  documentActions: GlobalCommandActions["document"];
};

type GlobalPresentationCommandsInput = {
  layoutMode: string;
  a4Landscape: boolean;
  setOutputDestination: Dispatch<SetStateAction<OutputDestination | undefined>>;
  setOutputOrientation: (landscape: boolean) => void;
  compactDrawer: "tools" | "inspector" | undefined;
  setLicensesOpen: Dispatch<SetStateAction<boolean>>;
  setHelpSection: Dispatch<SetStateAction<HelpSection | undefined>>;
  setInspectorOpen: Dispatch<SetStateAction<boolean>>;
  setBottomWorkbenchVisible: Dispatch<SetStateAction<boolean>>;
  setCompactDrawer: Dispatch<SetStateAction<"tools" | "inspector" | undefined>>;
  setMessage: (message: string) => void;
  resetWorkspace: AppActionSurface["workspace"]["resetWorkspace"];
  outputActions: GlobalCommandActions["output"];
};

type GlobalCommandsInput = {
  document: GlobalDocumentCommandsInput;
  canvas: GlobalCanvasCommandsInput;
  presentation: GlobalPresentationCommandsInput;
};

type GlobalKeyboardCommandsInput = {
  document: GlobalDocumentCommandsInput;
  canvas: GlobalCanvasCommandsInput;
  outputActions: GlobalCommandActions["output"];
};

function useGlobalKeyboardCommands(input: GlobalKeyboardCommandsInput) {
  const { document: documentInput, canvas: canvasInput, outputActions } = input;
  const { selectAllEntities, documentActions } = documentInput;
  const { canvasActions, cancelCurrentInteraction } = canvasInput;
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.defaultPrevented) return;
      const primary = event.metaKey || event.ctrlKey;
      const key = event.key.toLowerCase();
      if (primary && ["x", "c", "v"].includes(key) && isTextEditingElement(event.target)) return;
      if (primary && key === "s") {
        event.preventDefault();
        if (event.shiftKey) void documentActions.saveDocument();
        else documentActions.saveCurrentDocument();
      } else if (primary && key === "o") {
        event.preventDefault();
        void documentActions.openDocument();
      } else if (primary && key === "n") {
        event.preventDefault();
        documentActions.newDocument();
      } else if (primary && key === "z") {
        event.preventDefault();
        documentActions.restoreHistory(event.shiftKey ? "redo" : "undo");
      } else if (primary && key === "x") {
        event.preventDefault();
        void documentActions.cutSelection();
      } else if (primary && key === "c") {
        event.preventDefault();
        void documentActions.copySelection();
      } else if (primary && key === "v") {
        event.preventDefault();
        documentActions.pasteSelection();
      } else if (primary && key === "d") {
        event.preventDefault();
        documentActions.duplicateSelection();
      } else if (primary && key === "a") {
        event.preventDefault();
        selectAllEntities();
      } else if (primary && key === "f") {
        event.preventDefault();
        window.dispatchEvent(new Event("kawa-cad-find-inspector"));
      } else if (primary && key === "r") {
        event.preventDefault();
        documentActions.reloadDocument();
      } else if (primary && event.altKey && (key === "1" || key === "2")) {
        event.preventDefault();
        outputActions.setDocumentViewMode(key === "1" ? "editDisplay" : "outputPreview");
      } else if (primary && key >= "1" && key <= "5") {
        event.preventDefault();
        canvasActions.selectTool((["select", "point", "line", "circle", "centerLine"] as Tool[])[Number(key) - 1]);
      } else if (!primary && !event.altKey && key === "v") {
        event.preventDefault();
        canvasActions.selectTool("select");
      } else if (primary && event.shiftKey && key === "h") {
        event.preventDefault();
        canvasActions.selectTool("horizontal");
      } else if (primary && event.shiftKey && key === "v") {
        event.preventDefault();
        canvasActions.selectTool("vertical");
      } else if (primary && event.shiftKey && key === "l") {
        event.preventDefault();
        documentActions.addLayer();
      } else if ((event.key === "Delete" || event.key === "Backspace") && isTextEditingElement(event.target)) {
        return;
      } else if (event.key === "Delete" || event.key === "Backspace") {
        event.preventDefault();
        documentActions.deleteSelection();
      } else if (event.key === "Escape") {
        event.preventDefault();
        cancelCurrentInteraction();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [input]);
}

type GlobalMenuCommandsInput = {
  document: GlobalDocumentCommandsInput;
  canvas: GlobalCanvasCommandsInput;
  presentation: GlobalPresentationCommandsInput;
};

function useGlobalMenuCommands(input: GlobalMenuCommandsInput) {
  const { document: documentInput, canvas: canvasInput, presentation: presentationInput } = input;
  const { selectAllEntities, documentActions } = documentInput;
  const { canvasActions, cancelCurrentInteraction, zoomToFit } = canvasInput;
  const {
    compactDrawer,
    layoutMode,
    a4Landscape,
    setOutputDestination,
    setOutputOrientation,
    setLicensesOpen,
    setHelpSection,
    setInspectorOpen,
    setBottomWorkbenchVisible,
    setCompactDrawer,
    setMessage,
    resetWorkspace,
    outputActions,
  } = presentationInput;
  useEffect(() => {
    const onMenu = (event: Event) => {
      const action = (event as CustomEvent<MenuAction>).detail;
      if (action === "new") documentActions.newDocument();
      else if (action === "open") void documentActions.openDocument();
      else if (action === "save") documentActions.saveCurrentDocument();
      else if (action === "saveAs") void documentActions.saveDocument();
      else if (action === "exportPDF") setOutputDestination("pdf");
      else if (action === "directPrint") setOutputDestination("directPrint");
      else if (action === "undo" || action === "redo") documentActions.restoreHistory(action);
      else if (action === "cut") {
        if (!performTextEditingCommand("cut")) void documentActions.cutSelection();
      } else if (action === "copy") {
        if (!performTextEditingCommand("copy")) void documentActions.copySelection();
      } else if (action === "paste") {
        if (!performTextEditingCommand("paste")) documentActions.pasteSelection();
      } else if (action === "duplicate") documentActions.duplicateSelection();
      else if (action === "delete") documentActions.deleteSelection();
      else if (action === "selectAll") selectAllEntities();
      else if (action === "cancelCurrentInteraction") cancelCurrentInteraction();
      else if (action === "findInspector") window.dispatchEvent(new Event("kawa-cad-find-inspector"));
      else if (action === "toggleInspector") {
        if (layoutMode === "compact") setCompactDrawer((value) => (value === "inspector" ? undefined : "inspector"));
        else setInspectorOpen((value) => !value);
      } else if (action === "toggleBottomWorkbench")
        setBottomWorkbenchVisible((visible) => {
          setMessage(visible ? appStrings.status.summaryHidden : appStrings.status.summaryShown);
          return !visible;
        });
      else if (action === "zoomToFit") zoomToFit();
      else if (action === "resetLayout") resetWorkspace();
      else if (action === "reload") documentActions.reloadDocument();
      else if (action === "smoothArcTangencies") canvasActions.smoothSelectedArcTangencies();
      else if (action === "editDisplay" || action === "outputPreview") outputActions.setDocumentViewMode(action);
      else if (action === "toggleA4Orientation") setOutputOrientation(!a4Landscape);
      else if (action === "addLayer") documentActions.addLayer();
      else if (action === "openLicenses") setLicensesOpen(true);
      else if (action === "openHelp") setHelpSection("overview");
      else if (action === "openToolGuide") setHelpSection("tools");
      else if (action === "openCanvasGuide") setHelpSection("canvas");
      else canvasActions.selectTool(action);
    };
    window.addEventListener("kawa-cad-menu", onMenu);
    return () => window.removeEventListener("kawa-cad-menu", onMenu);
  }, [input, a4Landscape]);
}

/** Coordinates focused keyboard and native-menu command inputs. */
export function useGlobalCommands(input: GlobalCommandsInput) {
  useGlobalKeyboardCommands({
    document: input.document,
    canvas: input.canvas,
    outputActions: input.presentation.outputActions,
  });
  useGlobalMenuCommands(input);
}
