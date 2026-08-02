import type { Tool } from "@/features/canvas/domain/canvasDomainModels";

export type MenuAction =
  | "new"
  | "open"
  | "save"
  | "saveAs"
  | "undo"
  | "redo"
  | "cut"
  | "copy"
  | "paste"
  | "duplicate"
  | "delete"
  | "selectAll"
  | Tool
  | "toggleInspector"
  | "toggleBottomWorkbench"
  | "findInspector"
  | "zoomToFit"
  | "editDisplay"
  | "outputPreview"
  | "addLayer"
  | "resetLayout"
  | "reload"
  | "smoothArcTangencies"
  | "toggleA4Orientation";
