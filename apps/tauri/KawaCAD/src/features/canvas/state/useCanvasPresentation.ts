import { useRef, useState } from "react";
import type { PastePlacementMode } from "@/features/document/components/PasteOptionsOverlay";
import type { TextEntryField } from "@/shared/components/TextEntryDialog";
import type { OffsetSourceOption } from "@/features/constraints/components/DerivedValueDialog";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
import { defaultViewport, type ConstraintTarget, type PointMm, type Viewport } from "@/features/canvas/domain/cad";
import type { EditControlTarget } from "@/shared/domain/workspaceState";

export type SelectionExport = { clipboardJson: string; anchorPoint?: PointMm };
export type PasteOptions = {
  activeMode: PastePlacementMode;
  anchorPoint: PointMm;
  cursorPoint?: PointMm;
  nearSourcePoint: PointMm;
  namespace: string;
};
export type ConstraintPreflight = {
  kind: string;
  normalizedTargets: unknown[];
  value?: Record<string, number | string | undefined>;
};
export type HudPosition = { x: number; y: number };
export type PendingConstraintValue = {
  candidate: Tool;
  preflight: ConstraintPreflight;
  hudPosition?: HudPosition;
};
export type DerivedPreflight = {
  offsetOptions: OffsetSourceOption[];
  sourceEntityIds: string[];
  updateDerivedElementId?: string;
  closed: boolean;
};
export type PendingDerivedValue = {
  candidate: "offset" | "fillet";
  preflight: DerivedPreflight;
  clickPoint?: PointMm;
  valueText: string;
  entryMode: "fixed" | "parameter";
  parameterId: string;
};
export type PendingTextEntry = {
  title: string;
  fields: TextEntryField[];
  onConfirm: (values: Record<string, string>) => void;
};
export type ContextSelectionKind = "none" | "entity" | "constraint" | "measurement" | "freeText";
export type ContextMenu = { x: number; y: number; point: PointMm; selectionKind: ContextSelectionKind };

/** Owns transient Canvas interaction state; it does not execute commands. */
export function useCanvasPresentation() {
  const [tool, setTool] = useState<Tool>("select");
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [editingFreeTextId, setEditingFreeTextId] = useState<string>();
  const [pendingTargets, setPendingTargets] = useState<ConstraintTarget[]>([]);
  const [draft, setDraft] = useState<PointMm[]>([]);
  const [cursorPoint, setCursorPoint] = useState<PointMm>();
  const [viewport, setViewport] = useState<Viewport>(defaultViewport);
  const [activeLayer, setActiveLayer] = useState("layer:cut-line");
  const [activeStyle, setActiveStyle] = useState("style:outer-cut-line");
  const [roundDiameter, setRoundDiameter] = useState(5);
  const [roundKind, setRoundKind] = useState("keyRing");
  const [clipboard, setClipboard] = useState<SelectionExport>();
  const [pasteOptions, setPasteOptions] = useState<PasteOptions>();
  const [pasteSequence, setPasteSequence] = useState(0);
  const [pendingConstraintValue, setPendingConstraintValue] = useState<PendingConstraintValue>();
  const [pendingDerivedValue, setPendingDerivedValue] = useState<PendingDerivedValue>();
  const [pendingTextEntry, setPendingTextEntry] = useState<PendingTextEntry>();
  const [contextMenu, setContextMenu] = useState<ContextMenu>();
  const [hoveredConstraintId, setHoveredConstraintId] = useState<string>();
  const pan = useRef<{ screen: { x: number; y: number }; viewport: Viewport }>();
  const marquee = useRef<PointMm>();
  const move = useRef<{ start: PointMm; ids: string[] }>();
  const controlMove = useRef<{ target: EditControlTarget }>();
  const measurementMove = useRef<{ id: string; start: PointMm; labelOnly: boolean }>();
  const dimensionMove = useRef<{ constraintId: string; start: PointMm; labelOnly: boolean }>();
  const freeTextMove = useRef<{ id: string; start: PointMm }>();
  const arcSweepAngle = useRef<number>();
  const lineStartSnap = useRef<ConstraintTarget>();

  return {
    tool,
    setTool,
    selected,
    setSelected,
    editingFreeTextId,
    setEditingFreeTextId,
    pendingTargets,
    setPendingTargets,
    draft,
    setDraft,
    cursorPoint,
    setCursorPoint,
    viewport,
    setViewport,
    activeLayer,
    setActiveLayer,
    activeStyle,
    setActiveStyle,
    roundDiameter,
    setRoundDiameter,
    roundKind,
    setRoundKind,
    clipboard,
    setClipboard,
    pasteOptions,
    setPasteOptions,
    pasteSequence,
    setPasteSequence,
    pendingConstraintValue,
    setPendingConstraintValue,
    pendingDerivedValue,
    setPendingDerivedValue,
    pendingTextEntry,
    setPendingTextEntry,
    contextMenu,
    setContextMenu,
    hoveredConstraintId,
    setHoveredConstraintId,
    pan,
    marquee,
    move,
    controlMove,
    measurementMove,
    dimensionMove,
    freeTextMove,
    arcSweepAngle,
    lineStartSnap,
  };
}
