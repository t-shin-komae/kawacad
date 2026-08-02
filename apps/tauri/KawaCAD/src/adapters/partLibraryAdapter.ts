import { invokeCommand } from "@/adapters/tauriCommandAdapter";
import type { PartLibraryEntry } from "@/features/inspector/components/InspectorPanel";

export const partLibraryAdapter = {
  load: () => invokeCommand<PartLibraryEntry[]>("load_part_library"),
  save: (entries: PartLibraryEntry[]) => invokeCommand<void>("save_part_library", { entries }),
};
