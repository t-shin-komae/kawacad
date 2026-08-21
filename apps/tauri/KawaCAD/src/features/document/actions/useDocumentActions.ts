import { useCallback } from "react";
import { appStrings } from "@/localization";
import { parseDecimal } from "@/shared/state/syncedField";
import type { PointMm } from "@/features/canvas/domain/cad";
import type { State } from "@/shared/domain/coreWireTypes";
import { id } from "@/features/canvas/domain/workspaceTools";
import { documentAdapter } from "@/adapters/documentAdapter";
import {
  type PasteOptions,
  type PendingTextEntry,
  type SelectionExport,
} from "@/features/canvas/state/useCanvasPresentation";
import type { PastePlacementMode } from "@/features/document/components/PasteOptionsOverlay";
import type { TextEntryField } from "@/shared/components/TextEntryDialog";
import { useDocumentActionCallbacks } from "@/features/document/actions/useDocumentActionCallbacks";
import type { DocumentActionInput } from "@/features/document/actions/documentActionTypes";
import {
  defaultLayerName,
  defaultParameter,
  defaultParameterName,
  defaultUserLayer,
} from "@/features/document/domain/documentDefaults";

export function useDocumentActions(context: DocumentActionInput, resetInspectorPresentation: () => void) {
  const {
    state,
    run,
    command,
    onDocumentLoaded,
    onHistoryRestored,
    canvas: { cursorPoint, activeStyle, startPastePlacement, clearPastePlacement, clearFreeTextEdit },
    showLayerDeletionConfirmation,
    clearLayerDeletionConfirmation,
    presentOperationFailure,
    selection: {
      entityIDs: selected,
      replaceEntitySelection: selectEntities,
      annotation: selectedAnnotation,
      clearAnnotationSelection,
    },
    presentTextEntry,
    clearPendingTextEntry,
    setMessage,
    clipboard,
    storeSelectionExport,
    pasteOptions,
    pasteSequence,
    advancePasteSequence,
    layerDeletionConfirmation,
  } = context;
  const openTextEntry = useCallback(
    (title: string, fields: TextEntryField[], onConfirm: PendingTextEntry["onConfirm"]) => {
      presentTextEntry({ title, fields, onConfirm });
    },
    [presentTextEntry],
  );
  const resetLoadedDocumentPresentation = useCallback(
    (next: State) => {
      onDocumentLoaded(next);
      clearPendingTextEntry();
      clearPastePlacement();
      resetInspectorPresentation();
    },
    [clearPendingTextEntry, onDocumentLoaded, clearPastePlacement, resetInspectorPresentation],
  );
  const documentActions = useDocumentActionCallbacks({
    ...context,
    onHistoryRestored,
    openTextEntry,
    resetLoadedDocumentPresentation,
  });
  const addLayer = useCallback(() => {
    const number = (state?.layers.length ?? 0) + 1;
    const layer = defaultUserLayer(id("layer"), number);
    openTextEntry(
      appStrings.app.addLayerTitle,
      [{ id: "name", label: appStrings.app.layerName, initialValue: defaultLayerName(number) }],
      (values) => {
        const name = values.name.trim();
        if (!name) return;
        void command(
          "addLayer",
          {
            ...layer,
            name,
          },
          appStrings.app.layerAdded,
        );
      },
    );
  }, [command, openTextEntry, state?.layers.length]);
  const deleteLayer = useCallback(
    async (layer: { id: string; name: string }) => {
      if ((state?.layers.length ?? 0) <= 1) {
        setMessage(appStrings.status.cannotDeleteLastLayer);
        return;
      }
      try {
        const impact = await documentAdapter.command<{ entityCount: number; derivedElementCount: number }>(
          "layer_deletion_impact",
          {
            layerId: layer.id,
          },
        );
        const affectedCount = impact.entityCount + impact.derivedElementCount;
        if (affectedCount) {
          showLayerDeletionConfirmation({ id: layer.id, name: layer.name, affectedCount });
          setMessage(appStrings.status.layerDeletionAffectsGeometry(layer.name));
        } else {
          void command("deleteLayer", layer.id, appStrings.app.layerDeleted);
        }
      } catch (error) {
        presentOperationFailure(new Error(appStrings.status.layerDeletionCheckFailed(error)), "inspectLayerDeletion");
      }
    },
    [command, showLayerDeletionConfirmation, state?.layers.length],
  );
  const addParameter = useCallback(() => {
    const number = (state?.parameters.length ?? 0) + 1;
    const parameter = defaultParameter(id("parameter"), number);
    openTextEntry(
      appStrings.app.addParameterTitle,
      [
        { id: "name", label: appStrings.app.parameterName, initialValue: defaultParameterName(number) },
        {
          id: "value",
          label: appStrings.dialog.value.millimeters,
          initialValue: String(parameter.valueMm),
          inputMode: "decimal",
        },
      ],
      (values) => {
        const name = values.name.trim();
        const parsed = parseDecimal(values.value);
        const valueMm = parsed.ok ? parsed.value : undefined;
        if (name && typeof valueMm === "number" && Number.isFinite(valueMm) && valueMm > 0)
          void command("addParameter", { ...parameter, name, valueMm }, appStrings.app.parameterAdded);
      },
    );
  }, [command, openTextEntry, state?.parameters.length]);
  const renameLayer = useCallback(
    (layerId: string, requestedName: string) => {
      const name = requestedName.trim();
      if (name) void command("renameLayer", { layerId, name }, appStrings.app.layerNameUpdated);
    },
    [command],
  );
  const setPartQuantity = useCallback(
    (partId: string, current: number) => {
      openTextEntry(
        appStrings.app.partQuantityTitle,
        [{ id: "quantity", label: appStrings.app.partQuantity, initialValue: String(current), inputMode: "numeric" }],
        (values) => {
          const quantity = Number(values.quantity);
          if (Number.isFinite(quantity) && quantity > 0)
            void command(
              "setPartQuantity",
              { partId, quantity: Math.round(quantity) },
              appStrings.app.partQuantityUpdated,
            );
        },
      );
    },
    [command, openTextEntry],
  );
  const activeStyleId = activeStyle || null;
  const applyActiveStyle = useCallback(
    (requestedStyleId?: string) => {
      const styleId = requestedStyleId || activeStyleId;
      if (!selected.size || !styleId) return;
      const derivedOwners = new Set<string>();
      const commands: Array<{ kind: string; payload: unknown }> = [];
      [...selected].forEach((entityId) => {
        const derivedElementId = state?.drawingEntityMetadata.find(
          (item) => item.entityId === entityId,
        )?.derivedElementId;
        if (derivedElementId) {
          if (derivedOwners.has(derivedElementId)) return;
          derivedOwners.add(derivedElementId);
          commands.push({
            kind: "setDerivedSharedStyle",
            payload: { derivedElementId, styleId },
          });
          return;
        }
        commands.push({ kind: "setEntitySharedStyle", payload: { entityId, styleId } });
      });
      if (commands.length) void command("compound", commands, appStrings.app.styleUpdated);
    },
    [activeStyleId, command, selected, state?.drawingEntityMetadata],
  );
  const deleteSelection = useCallback(() => {
    if (selectedAnnotation) {
      const commandByKind = {
        measurement: ["deleteMeasurementAnnotation", appStrings.app.measurementDeleted],
        stitchStartPoint: ["deleteStitchStartPoint", appStrings.app.stitchStartPointDeleted],
        constraint: ["deleteConstraint", appStrings.app.constraintDeleted],
        freeText: ["deleteFreeText", appStrings.app.textDeleted],
      } as const;
      const [kind, success] = commandByKind[selectedAnnotation.kind];
      void command(kind, selectedAnnotation.id, success);
      clearAnnotationSelection();
      return;
    }
    if (!selected.size) return;
    const deletedDerived = new Set<string>();
    const commands = [...selected].flatMap((entityId) => {
      const derivedElementId = state?.drawingEntityMetadata.find(
        (item) => item.entityId === entityId,
      )?.derivedElementId;
      if (derivedElementId) {
        if (deletedDerived.has(derivedElementId)) return [];
        deletedDerived.add(derivedElementId);
        return [{ kind: "deleteDerivedElement", payload: derivedElementId }];
      }
      return [{ kind: "deleteEntity", payload: entityId }];
    });
    void command("compound", commands, appStrings.app.geometryDeleted);
    selectEntities(new Set());
  }, [command, selectEntities, selected, selectedAnnotation, clearAnnotationSelection, state?.drawingEntityMetadata]);
  const copySelection = useCallback(async () => {
    if (!selected.size) return setMessage(appStrings.status.selectGeometryToCopy);
    try {
      const result = await documentAdapter.command<SelectionExport>("export_selection", {
        selection: { entityIds: [...selected] },
      });
      storeSelectionExport(result);
      clearPastePlacement();
      setMessage(appStrings.status.copiedGeometry(selected.size));
    } catch (error) {
      presentOperationFailure(new Error(appStrings.status.copyFailed(error)), "copySelection");
    }
  }, [clearPastePlacement, selected, setMessage, storeSelectionExport]);
  const cutSelection = useCallback(async () => {
    if (!selected.size) return setMessage(appStrings.status.selectGeometryToCut);
    try {
      const result = await documentAdapter.command<SelectionExport>("export_selection", {
        selection: { entityIds: [...selected] },
      });
      storeSelectionExport(result);
      clearPastePlacement();
      await run(
        () =>
          documentAdapter.command<State>("apply_command", {
            command: {
              kind: "compound",
              payload: [...selected].map((entity) => ({ kind: "deleteEntity", payload: entity })),
            },
          }),
        appStrings.app.geometryCut,
      );
      selectEntities(new Set());
    } catch (error) {
      presentOperationFailure(new Error(appStrings.status.cutFailed(error)), "cutSelection");
    }
  }, [clearPastePlacement, run, selectEntities, selected, storeSelectionExport]);
  const pasteSelection = useCallback(
    async (
      requestedPoint: PointMm | undefined = cursorPoint,
      replacement?: Pick<PasteOptions, "namespace" | "activeMode" | "nearSourcePoint" | "anchorPoint">,
    ) => {
      if (!clipboard) return setMessage(appStrings.status.clipboardEmpty);
      const anchor = replacement?.anchorPoint ?? clipboard.anchorPoint ?? { xMm: 0, yMm: 0 };
      const canPlaceAtCursor =
        requestedPoint !== undefined &&
        Math.hypot(requestedPoint.xMm - anchor.xMm, requestedPoint.yMm - anchor.yMm) > 0.001;
      const nearSourcePoint = replacement?.nearSourcePoint ?? {
        xMm: anchor.xMm + (pasteSequence + 1) * 5,
        yMm: anchor.yMm + (pasteSequence + 1) * 5,
      };
      const activeMode = replacement?.activeMode ?? (canPlaceAtCursor ? "cursor" : "nearSource");
      const target = activeMode === "cursor" && requestedPoint ? requestedPoint : nearSourcePoint;
      const namespace = replacement?.namespace ?? crypto.randomUUID();
      const before = new Set(state?.entities.map((entity) => entity.id) ?? []);
      const next = await command(
        "pasteSelection",
        {
          clipboardJson: clipboard.clipboardJson,
          idNamespace: namespace,
          delta: { xMm: target.xMm - anchor.xMm, yMm: target.yMm - anchor.yMm },
        },
        appStrings.app.geometryPasted,
      );
      if (!next) return;
      const created = next.entities.filter((entity) => !before.has(entity.id)).map((entity) => entity.id);
      if (created.length) selectEntities(new Set(created));
      if (!replacement && activeMode === "nearSource") advancePasteSequence();
      if (clipboard.anchorPoint)
        startPastePlacement({
          activeMode,
          anchorPoint: anchor,
          cursorPoint: requestedPoint,
          nearSourcePoint,
          namespace,
        });
    },
    [
      advancePasteSequence,
      clipboard,
      command,
      cursorPoint,
      pasteSequence,
      selectEntities,
      startPastePlacement,
      state?.entities,
    ],
  );
  const selectPastePlacement = useCallback(
    async (mode: PastePlacementMode) => {
      if (!pasteOptions) return;
      if (mode === pasteOptions.activeMode) {
        clearPastePlacement();
        return;
      }
      const undone = await run(() => documentAdapter.command<State>("undo"), appStrings.app.pastePositionChanged);
      if (!undone) return;
      await pasteSelection(pasteOptions.cursorPoint, {
        activeMode: mode,
        anchorPoint: pasteOptions.anchorPoint,
        nearSourcePoint: pasteOptions.nearSourcePoint,
        namespace: pasteOptions.namespace,
      });
    },
    [clearPastePlacement, pasteOptions, pasteSelection, run],
  );
  const duplicateSelection = useCallback(async () => {
    if (!selected.size) return setMessage(appStrings.status.selectGeometryToDuplicate);
    clearPastePlacement();
    const before = new Set(state?.entities.map((entity) => entity.id) ?? []);
    const next = await command(
      "duplicateSelection",
      { selection: { entityIds: [...selected] }, idNamespace: crypto.randomUUID(), delta: { xMm: 5, yMm: 5 } },
      appStrings.app.geometryDuplicated,
    );
    if (next) {
      const created = next.entities.filter((entity) => !before.has(entity.id)).map((entity) => entity.id);
      if (created.length) selectEntities(new Set(created));
    }
  }, [clearPastePlacement, command, selectEntities, selected, state?.entities]);
  const confirmDeleteLayer = useCallback(() => {
    if (!layerDeletionConfirmation) return;
    void command("deleteLayer", layerDeletionConfirmation.id, appStrings.app.layerDeleted);
    clearLayerDeletionConfirmation();
  }, [clearLayerDeletionConfirmation, command, layerDeletionConfirmation]);
  const cancelDeleteLayer = useCallback(() => {
    if (!layerDeletionConfirmation) return;
    clearLayerDeletionConfirmation();
    setMessage(appStrings.status.layerDeletionCancelled(layerDeletionConfirmation.name));
  }, [clearLayerDeletionConfirmation, layerDeletionConfirmation, setMessage]);
  const commitFreeTextEdit = useCallback(
    (freeTextId: string, content: string) => {
      const freeText = state?.freeTexts.find((item) => item.id === freeTextId);
      clearFreeTextEdit();
      if (freeText && content !== freeText.content)
        void command("updateFreeText", { ...freeText, content }, appStrings.inspector.operationMessage.textUpdated);
    },
    [clearFreeTextEdit, command, state?.freeTexts],
  );
  const cancelFreeTextEdit = useCallback(() => clearFreeTextEdit(), [clearFreeTextEdit]);
  const executeCommand = useCallback(
    (kind: string, payload: unknown, success: string) => {
      void command(kind, payload, success);
    },
    [command],
  );
  return {
    clearTransientCanvasState: onHistoryRestored,
    ...documentActions,
    openTextEntry,
    resetLoadedDocumentPresentation,
    addLayer,
    deleteLayer,
    addParameter,
    renameLayer,
    setPartQuantity,
    applyActiveStyle,
    copySelection,
    cutSelection,
    pasteSelection,
    selectPastePlacement,
    duplicateSelection,
    deleteSelection,
    confirmDeleteLayer,
    cancelDeleteLayer,
    commitFreeTextEdit,
    cancelFreeTextEdit,
    executeCommand,
  };
}

export type DocumentActions = ReturnType<typeof useDocumentActions>;
