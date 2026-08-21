import { usePartActionCallbacks } from "@/features/parts/actions/usePartActionCallbacks";
import { useCallback } from "react";
import { appStrings } from "@/localization";
import type { Part, PartLibraryEntry } from "@/shared/domain/coreWireTypes";
import type { PendingTextEntry } from "@/features/canvas/state/useCanvasPresentation";
import type { TextEntryField } from "@/shared/components/TextEntryDialog";
import type { PartActionInput } from "@/features/parts/actions/partActionTypes";

type OpenTextEntry = (title: string, fields: TextEntryField[], onConfirm: PendingTextEntry["onConfirm"]) => void;

/** Part and part-library operations are owned by the part action feature. */
export function usePartActions(context: PartActionInput, openTextEntry: OpenTextEntry) {
  const callbacks = usePartActionCallbacks({ ...context, openTextEntry });
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
      context.inspector.beginPartOrigin(part.id);
      context.setMessage(appStrings.status.selectPartOrigin(part.name));
    },
    [context.inspector, context.setMessage],
  );
  return {
    ...callbacks,
    toggleArrangementPart: context.toggleArrangementPart,
    alignParts,
    distributeParts,
    removePartFromLibrary,
    beginSetPartOrigin,
  };
}
