import type * as React from "react";
import type { DocumentHeaderHandle } from "@/features/document/components/DocumentHeader";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
import type { ConstraintTarget, PointMm, RawEntity, Viewport } from "@/features/canvas/domain/cad";
import type { CanvasProjection, EditControlTarget, State } from "@/shared/domain/workspaceState";
import type {
  PasteOptions,
  PendingConstraintValue,
  PendingDerivedValue,
  PendingTextEntry,
  ContextMenu,
  SelectionExport,
} from "@/features/canvas/state/useCanvasPresentation";
import type { PartLibraryEntry } from "@/features/inspector/components/InspectorPanel";

type Setter<T> = React.Dispatch<React.SetStateAction<T>>;

export type AppActionContext = {
  state: State | undefined;
  a4Landscape: boolean;
  run: (
    work: () => Promise<State>,
    success: string,
    operation?: string,
    commandKind?: string,
  ) => Promise<State | undefined>;
  command: (kind: string, payload: unknown, success: string) => Promise<State | undefined>;
  applyState: (next: State) => State;
  clearCanvasPreview: () => void;
  previewCommand: (command: unknown, success: string) => void;
  previewActive: React.MutableRefObject<boolean>;
  tool: Tool;
  setViewport: Setter<Viewport>;
  cursorPoint: PointMm | undefined;
  editingFreeTextId: string | undefined;
  layerDeletionConfirmation: { id: string; name: string; affectedCount: number } | undefined;
  setLayerDeletionConfirmation: Setter<{ id: string; name: string; affectedCount: number } | undefined>;
  presentOperationFailure: (error: unknown, operation: string, commandKind?: string) => void;
  setSelected: Setter<Set<string>>;
  clearAnnotationSelection: () => void;
  setEditingFreeTextId: Setter<string | undefined>;
  setHoveredConstraintId: Setter<string | undefined>;
  setPendingTargets: Setter<ConstraintTarget[]>;
  setPendingConstraintValue: Setter<PendingConstraintValue | undefined>;
  setPendingDerivedValue: Setter<PendingDerivedValue | undefined>;
  setPendingTextEntry: Setter<PendingTextEntry | undefined>;
  setDraft: Setter<PointMm[]>;
  setCursorPoint: Setter<PointMm | undefined>;
  setPasteOptions: Setter<PasteOptions | undefined>;
  setContextMenu: Setter<ContextMenu | undefined>;
  setInspectorSelectedPartId: Setter<string | undefined>;
  setSettingPartOriginId: Setter<string | undefined>;
  setCompactDrawer: Setter<"tools" | "inspector" | undefined>;
  setActiveLayer: Setter<string>;
  setActiveStyle: Setter<string>;
  setTool: Setter<Tool>;
  setMessage: (message: string) => void;
  setInspectorRevision: Setter<number>;
  documentHeader: React.MutableRefObject<DocumentHeaderHandle | null>;
  documentNameForFileDialog: React.MutableRefObject<string | undefined>;
  resetWorkspacePreferences: () => void;
  resetWorkspaceLayout: () => void;
  activeLayer: string;
  activeStyle: string;
  selected: Set<string>;
  viewport: Viewport;
  snapEnabled: boolean;
  pointSnapEnabled: boolean;
  visibleEntities: RawEntity[];
  clipboard: SelectionExport | undefined;
  setClipboard: Setter<SelectionExport | undefined>;
  pasteOptions: PasteOptions | undefined;
  pasteSequence: number;
  setPasteSequence: Setter<number>;
  pendingTargets: ConstraintTarget[];
  pendingDerivedValue: PendingDerivedValue | undefined;
  roundDiameter: number;
  roundKind: string;
  selectedFreeTextId: string | undefined;
  selectedConstraintId: string | undefined;
  selectedMeasurementId: string | undefined;
  selectedStitchStartPointId: string | undefined;
  setSelectedFreeTextId: (id: string | undefined) => void;
  setSelectedConstraintId: (id: string | undefined) => void;
  setSelectedMeasurementId: (id: string | undefined) => void;
  setSelectedStitchStartPointId: (id: string | undefined) => void;
  canvasProjection: CanvasProjection;
  measurementLabels: Record<string, string>;
  measurementLabelOffsets: Record<string, PointMm>;
  dimensionLabels: Record<string, string>;
  dimensionLabelOffsets: Record<string, PointMm>;
  settingPartOriginId: string | undefined;
  pan: React.MutableRefObject<{ screen: { x: number; y: number }; viewport: Viewport } | undefined>;
  marquee: React.MutableRefObject<PointMm | undefined>;
  move: React.MutableRefObject<{ start: PointMm; ids: string[]; partId?: string } | undefined>;
  controlMove: React.MutableRefObject<{ target: EditControlTarget } | undefined>;
  measurementMove: React.MutableRefObject<{ id: string; start: PointMm; labelOnly: boolean } | undefined>;
  dimensionMove: React.MutableRefObject<{ constraintId: string; start: PointMm; labelOnly: boolean } | undefined>;
  freeTextMove: React.MutableRefObject<{ id: string; start: PointMm } | undefined>;
  arcSweepAngle: React.MutableRefObject<number | undefined>;
  lineStartSnap: React.MutableRefObject<ConstraintTarget | undefined>;
  draft: PointMm[];
  partLibrary: PartLibraryEntry[];
  updatePartLibrary: (entries: PartLibraryEntry[]) => void;
  arrangementPartIds: Set<string>;
  setArrangementPartIds: Setter<Set<string>>;
  inspectorSelectedPartId: string | undefined;
};

/** Explicit dependency surfaces keep feature hooks from depending on the composition context by accident. */
export type DocumentActionContext = Pick<
  AppActionContext,
  | "state"
  | "run"
  | "command"
  | "clearCanvasPreview"
  | "layerDeletionConfirmation"
  | "cursorPoint"
  | "setLayerDeletionConfirmation"
  | "presentOperationFailure"
  | "setSelected"
  | "clearAnnotationSelection"
  | "setEditingFreeTextId"
  | "setHoveredConstraintId"
  | "setPendingTargets"
  | "setPendingConstraintValue"
  | "setPendingDerivedValue"
  | "setPendingTextEntry"
  | "setDraft"
  | "setCursorPoint"
  | "setPasteOptions"
  | "setInspectorSelectedPartId"
  | "setSettingPartOriginId"
  | "setCompactDrawer"
  | "setActiveLayer"
  | "setActiveStyle"
  | "setTool"
  | "setMessage"
  | "documentHeader"
  | "documentNameForFileDialog"
  | "activeStyle"
  | "selected"
  | "clipboard"
  | "setClipboard"
  | "pasteOptions"
  | "pasteSequence"
  | "setPasteSequence"
  | "selectedFreeTextId"
  | "selectedConstraintId"
  | "selectedMeasurementId"
  | "selectedStitchStartPointId"
  | "setSelectedFreeTextId"
  | "setSelectedConstraintId"
  | "setSelectedMeasurementId"
  | "setSelectedStitchStartPointId"
  | "arcSweepAngle"
  | "lineStartSnap"
>;

export type CanvasActionContext = Pick<
  AppActionContext,
  | "state"
  | "command"
  | "applyState"
  | "clearCanvasPreview"
  | "previewCommand"
  | "tool"
  | "setViewport"
  | "viewport"
  | "cursorPoint"
  | "setSelected"
  | "setHoveredConstraintId"
  | "setPendingTargets"
  | "setPendingConstraintValue"
  | "setPendingDerivedValue"
  | "setDraft"
  | "setCursorPoint"
  | "setContextMenu"
  | "setSelectedFreeTextId"
  | "setSelectedConstraintId"
  | "setSelectedMeasurementId"
  | "setSelectedStitchStartPointId"
  | "setEditingFreeTextId"
  | "setInspectorSelectedPartId"
  | "setSettingPartOriginId"
  | "setTool"
  | "setMessage"
  | "presentOperationFailure"
  | "activeLayer"
  | "activeStyle"
  | "snapEnabled"
  | "pointSnapEnabled"
  | "visibleEntities"
  | "selected"
  | "pendingTargets"
  | "pendingDerivedValue"
  | "roundDiameter"
  | "roundKind"
  | "canvasProjection"
  | "measurementLabels"
  | "measurementLabelOffsets"
  | "dimensionLabels"
  | "dimensionLabelOffsets"
  | "settingPartOriginId"
  | "pan"
  | "marquee"
  | "move"
  | "controlMove"
  | "measurementMove"
  | "dimensionMove"
  | "freeTextMove"
  | "arcSweepAngle"
  | "lineStartSnap"
  | "draft"
>;

export type ConstraintActionContext = Pick<
  AppActionContext,
  | "state"
  | "command"
  | "applyState"
  | "presentOperationFailure"
  | "setPendingConstraintValue"
  | "setPendingDerivedValue"
  | "setMessage"
  | "setSelected"
  | "activeLayer"
  | "activeStyle"
  | "selected"
  | "tool"
  | "pendingDerivedValue"
>;

export type InspectorActionContext = Pick<
  AppActionContext,
  | "setInspectorRevision"
  | "setSelected"
  | "setSelectedConstraintId"
  | "setSelectedFreeTextId"
  | "setSelectedStitchStartPointId"
  | "setSelectedMeasurementId"
  | "setInspectorSelectedPartId"
>;

export type PartActionContext = Pick<
  AppActionContext,
  | "state"
  | "command"
  | "selected"
  | "setSelected"
  | "setSelectedFreeTextId"
  | "setSelectedConstraintId"
  | "setInspectorSelectedPartId"
  | "setMessage"
  | "partLibrary"
  | "updatePartLibrary"
  | "presentOperationFailure"
  | "arrangementPartIds"
  | "setArrangementPartIds"
  | "setSettingPartOriginId"
>;

export type OutputActionContext = Pick<AppActionContext, "state" | "a4Landscape" | "run" | "setTool">;

export type WorkspaceActionContext = Pick<
  AppActionContext,
  "setViewport" | "resetWorkspacePreferences" | "resetWorkspaceLayout" | "setMessage"
>;
