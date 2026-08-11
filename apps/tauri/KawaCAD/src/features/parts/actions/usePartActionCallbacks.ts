import { useCallback } from "react";
import { appStrings } from "@/localization";
import { documentAdapter } from "@/adapters/documentAdapter";
import { id } from "@/features/canvas/domain/workspaceTools";
import { partCanvasHighlights } from "@/features/parts/selectors/partCanvasHighlights";
import type { Part, PartLibraryEntry } from "@/shared/domain/coreWireTypes";
import type { PendingTextEntry } from "@/features/canvas/state/useCanvasPresentation";
import type { TextEntryField } from "@/shared/components/TextEntryDialog";
import type { PartActionContext } from "@/app/actions/useActionRuntime";

type PartActionDependencies = Pick<
  PartActionContext,
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
> & {
  openTextEntry: (title: string, fields: TextEntryField[], onConfirm: PendingTextEntry["onConfirm"]) => void;
};

export function usePartActionCallbacks(dependencies: PartActionDependencies) {
  const {
    state,
    command,
    selected,
    setSelected,
    setSelectedFreeTextId,
    setSelectedConstraintId,
    setInspectorSelectedPartId,
    setMessage,
    partLibrary,
    updatePartLibrary,
    presentOperationFailure,
    openTextEntry,
  } = dependencies;

  const createPart = useCallback(() => {
    if (!selected.size) {
      setMessage(appStrings.status.selectGeometryForPart);
      return;
    }
    openTextEntry(
      appStrings.app.createPartTitle,
      [{ id: "name", label: appStrings.app.partName, initialValue: appStrings.app.newPart }],
      (values) => {
        const name = values.name.trim();
        if (name) {
          const partId = id("part");
          void command("createPart", { id: partId, name, entityIds: [...selected] }, appStrings.app.partCreated).then(
            (next) => {
              if (next?.parts.some((part) => part.id === partId)) setInspectorSelectedPartId(partId);
            },
          );
        }
      },
    );
  }, [command, openTextEntry, selected]);

  const selectPartContents = useCallback(
    (part: Part) => {
      const highlights = partCanvasHighlights(part, state?.drawingEntityMetadata ?? [], state?.stitchStartPoints ?? []);
      setSelected(highlights.entityIds);
      setSelectedFreeTextId(undefined);
      setSelectedConstraintId(undefined);
      setInspectorSelectedPartId(part.id);
      setMessage(appStrings.status.partContentsSelected(part.name));
    },
    [state?.drawingEntityMetadata, state?.stitchStartPoints],
  );
  const addPartToLibrary = useCallback(
    async (part: Part) => {
      try {
        const exported = await documentAdapter.command<{ libraryJson: string; sourcePart: Part }>(
          "export_part_library_item",
          {
            partId: part.id,
          },
        );
        const entry = {
          id: crypto.randomUUID(),
          name: part.name,
          libraryJson: exported.libraryJson,
          sourcePart: exported.sourcePart,
        };
        updatePartLibrary(
          [...partLibrary.filter((item) => item.name !== part.name), entry].sort((left, right) =>
            left.name.localeCompare(right.name, "ja"),
          ),
        );
        setMessage(appStrings.status.partAddedToLibrary(part.name));
      } catch (error) {
        presentOperationFailure(new Error(appStrings.status.partLibraryAddFailed(error)), "addPartToLibrary");
      }
    },
    [partLibrary, updatePartLibrary],
  );
  const insertPartFromLibrary = useCallback(
    (entry: PartLibraryEntry) => {
      const source = entry.sourcePart.originMm ?? { xMm: 0, yMm: 0 };
      const target = {
        xMm:
          (state?.parts.map((part) => part.originMm.xMm).reduce((max, value) => Math.max(max, value), -30) ?? -30) + 30,
        yMm: 0,
      };
      const duplicateCount = state?.parts.filter((part) => part.name === entry.name).length ?? 0;
      const newName = duplicateCount ? `${entry.name} ${duplicateCount + 1}` : entry.name;
      void command(
        "insertPartLibraryItem",
        {
          libraryJson: entry.libraryJson,
          newPartId: id("part"),
          newName,
          idNamespace: crypto.randomUUID(),
          delta: { xMm: target.xMm - source.xMm, yMm: target.yMm - source.yMm },
        },
        appStrings.app.libraryPartPlaced(newName),
      );
    },
    [command, state?.parts],
  );

  return { createPart, selectPartContents, addPartToLibrary, insertPartFromLibrary };
}
