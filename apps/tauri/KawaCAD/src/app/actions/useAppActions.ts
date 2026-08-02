import { useCanvasActions } from "@/features/canvas/actions/useCanvasActions";
import { useDocumentActions } from "@/features/document/actions/useDocumentActions";
import { useInspectorActions } from "@/features/inspector/actions/useInspectorActions";
import { useOutputActions } from "@/features/output/actions/useOutputActions";
import { usePartActions } from "@/features/parts/actions/usePartActions";
import { useWorkspaceActions } from "@/features/workspace/actions/useWorkspaceActions";
import type {
  AppActionContext,
  CanvasActionContext,
  DocumentActionContext,
  InspectorActionContext,
  OutputActionContext,
  PartActionContext,
  WorkspaceActionContext,
} from "@/app/actions/useActionRuntime";

export type { AppActionContext } from "@/app/actions/useActionRuntime";

/** Composition root for typed feature action surfaces. */
export function useAppActions(context: AppActionContext) {
  const inspectorContext: InspectorActionContext = pickContext(context, [
    "setInspectorRevision",
    "setSelected",
    "setSelectedConstraintId",
    "setSelectedFreeTextId",
    "setSelectedStitchStartPointId",
    "setSelectedMeasurementId",
    "setInspectorSelectedPartId",
  ]);
  const documentContext: DocumentActionContext = pickContext(context, [
    "state",
    "run",
    "command",
    "clearCanvasPreview",
    "layerDeletionConfirmation",
    "cursorPoint",
    "setLayerDeletionConfirmation",
    "presentOperationFailure",
    "setSelected",
    "clearAnnotationSelection",
    "setEditingFreeTextId",
    "setHoveredConstraintId",
    "setPendingTargets",
    "setPendingConstraintValue",
    "setPendingDerivedValue",
    "setPendingTextEntry",
    "setDraft",
    "setCursorPoint",
    "setPasteOptions",
    "setInspectorSelectedPartId",
    "setSettingPartOriginId",
    "setCompactDrawer",
    "setActiveLayer",
    "setActiveStyle",
    "setTool",
    "setMessage",
    "documentHeader",
    "documentNameForFileDialog",
    "activeStyle",
    "selected",
    "clipboard",
    "setClipboard",
    "pasteOptions",
    "pasteSequence",
    "setPasteSequence",
    "selectedFreeTextId",
    "selectedConstraintId",
    "selectedMeasurementId",
    "selectedStitchStartPointId",
    "setSelectedFreeTextId",
    "setSelectedConstraintId",
    "setSelectedMeasurementId",
    "setSelectedStitchStartPointId",
    "arcSweepAngle",
    "lineStartSnap",
  ]);
  const canvasContext: CanvasActionContext = pickContext(context, [
    "state",
    "command",
    "applyState",
    "clearCanvasPreview",
    "previewCommand",
    "tool",
    "setViewport",
    "cursorPoint",
    "setSelected",
    "setHoveredConstraintId",
    "setPendingTargets",
    "setPendingConstraintValue",
    "setPendingDerivedValue",
    "setDraft",
    "setCursorPoint",
    "setContextMenu",
    "setSelectedFreeTextId",
    "setSelectedConstraintId",
    "setSelectedMeasurementId",
    "setSelectedStitchStartPointId",
    "setEditingFreeTextId",
    "setInspectorSelectedPartId",
    "setSettingPartOriginId",
    "setTool",
    "setMessage",
    "presentOperationFailure",
    "activeLayer",
    "activeStyle",
    "snapEnabled",
    "pointSnapEnabled",
    "visibleEntities",
    "selected",
    "viewport",
    "pendingTargets",
    "pendingDerivedValue",
    "roundDiameter",
    "roundKind",
    "canvasProjection",
    "measurementLabels",
    "measurementLabelOffsets",
    "dimensionLabels",
    "dimensionLabelOffsets",
    "settingPartOriginId",
    "pan",
    "marquee",
    "move",
    "controlMove",
    "measurementMove",
    "dimensionMove",
    "freeTextMove",
    "arcSweepAngle",
    "lineStartSnap",
    "draft",
  ]);
  const partContext: PartActionContext = pickContext(context, [
    "state",
    "command",
    "selected",
    "setSelected",
    "setSelectedFreeTextId",
    "setSelectedConstraintId",
    "setInspectorSelectedPartId",
    "setMessage",
    "partLibrary",
    "updatePartLibrary",
    "presentOperationFailure",
    "arrangementPartIds",
    "setArrangementPartIds",
    "setSettingPartOriginId",
  ]);
  const outputContext: OutputActionContext = pickContext(context, ["state", "a4Landscape", "run", "setTool"]);
  const workspaceContext: WorkspaceActionContext = pickContext(context, [
    "setViewport",
    "resetWorkspacePreferences",
    "resetWorkspaceLayout",
    "setMessage",
  ]);
  const inspectorActions = useInspectorActions(inspectorContext);
  const documentActions = useDocumentActions(documentContext, inspectorActions.resetInspectorPresentation);
  const outputActions = useOutputActions(outputContext, documentActions.clearTransientCanvasState);
  const canvasActions = useCanvasActions(canvasContext, {
    clearTransientCanvasState: documentActions.clearTransientCanvasState,
    openTextEntry: documentActions.openTextEntry,
    setDocumentViewMode: outputActions.setDocumentViewMode,
  });
  const partActions = usePartActions(partContext, documentActions.openTextEntry);
  const workspaceActions = useWorkspaceActions(workspaceContext);

  return {
    ...documentActions,
    ...canvasActions,
    ...partActions,
    ...outputActions,
    ...inspectorActions,
    ...workspaceActions,
  };
}

function pickContext<Key extends keyof AppActionContext>(
  context: AppActionContext,
  keys: readonly Key[],
): Pick<AppActionContext, Key> {
  return Object.fromEntries(keys.map((key) => [key, context[key]])) as Pick<AppActionContext, Key>;
}
