import type { PointMm } from "@/features/canvas/domain/cad";
import type { PartLibraryEntry, State } from "@/shared/domain/coreWireTypes";

export type PartActionInput = {
  state: State | undefined;
  canvas: { cursorPoint: PointMm | undefined };
  command: (kind: string, payload: unknown, success: string) => Promise<State | undefined>;
  selection: {
    selected: Set<string>;
    replace: (ids: Set<string>) => void;
    clearFreeText: () => void;
    clearConstraint: () => void;
  };
  inspector: {
    selectPart: (id: string | undefined) => void;
    beginPartOrigin: (id: string) => void;
  };
  setMessage: (message: string) => void;
  partLibrary: PartLibraryEntry[];
  updatePartLibrary: (entries: PartLibraryEntry[]) => void;
  presentOperationFailure: (error: unknown, operation: string, commandKind?: string) => void;
  arrangementPartIds: Set<string>;
  toggleArrangementPart: (id: string) => void;
};
