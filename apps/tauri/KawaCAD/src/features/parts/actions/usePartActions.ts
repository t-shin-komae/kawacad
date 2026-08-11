import { usePartActionCallbacks } from "@/features/parts/actions/usePartActionCallbacks";
import { useCallback } from "react";
import { appStrings } from "@/localization";
import type { Part, PartLibraryEntry } from "@/shared/domain/coreWireTypes";
import type { PendingTextEntry } from "@/features/canvas/state/useCanvasPresentation";
import type { TextEntryField } from "@/shared/components/TextEntryDialog";
import type { PartActionContext } from "@/app/actions/useActionRuntime";

type OpenTextEntry = (title: string, fields: TextEntryField[], onConfirm: PendingTextEntry["onConfirm"]) => void;

/** Part and part-library operations are owned by the part action feature. */
export function usePartActions(context: PartActionContext, openTextEntry: OpenTextEntry) {
  const callbacks = usePartActionCallbacks({ ...context, openTextEntry });
  const toggleArrangementPart = useCallback(
    (partId: string) =>
      context.setArrangementPartIds((current) =>
        current.has(partId) ? new Set([...current].filter((id) => id !== partId)) : new Set([...current, partId]),
      ),
    [context.setArrangementPartIds],
  );
  const alignParts = useCallback(
    (alignment: string) =>
      void context.command(
        "alignParts",
        { partIds: [...context.arrangementPartIds].sort(), alignment },
        appStrings.app.alignmentUpdated,
      ),
    [context.arrangementPartIds, context.command],
  );
  const distributeParts = useCallback(
    (axis: string) =>
      void context.command(
        "distributeParts",
        { partIds: [...context.arrangementPartIds].sort(), axis },
        appStrings.app.distributionUpdated,
      ),
    [context.arrangementPartIds, context.command],
  );
  const removePartFromLibrary = useCallback(
    (entry: PartLibraryEntry) => context.updatePartLibrary(context.partLibrary.filter((item) => item.id !== entry.id)),
    [context.partLibrary, context.updatePartLibrary],
  );
  const beginSetPartOrigin = useCallback(
    (part: Part) => {
      context.setSettingPartOriginId(part.id);
      context.setMessage(appStrings.status.selectPartOrigin(part.name));
    },
    [context.setMessage, context.setSettingPartOriginId],
  );
  return {
    ...callbacks,
    toggleArrangementPart,
    alignParts,
    distributeParts,
    removePartFromLibrary,
    beginSetPartOrigin,
  };
}
