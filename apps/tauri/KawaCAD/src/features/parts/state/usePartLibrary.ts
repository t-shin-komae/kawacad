import { useCallback, useEffect, useState } from "react";
import type { PartLibraryEntry } from "@/shared/domain/coreWireTypes";
import { partLibraryAdapter } from "@/adapters/partLibraryAdapter";
import { appStrings } from "@/localization";

type Props = {
  report: (message: string) => void;
};

export function usePartLibrary({ report }: Props) {
  const [partLibrary, setPartLibrary] = useState<PartLibraryEntry[]>([]);

  useEffect(() => {
    void partLibraryAdapter
      .load()
      .then((entries) => setPartLibrary(Array.isArray(entries) ? entries : []))
      .catch((error) => report(appStrings.error.partLibrary.loadFailed(error)));
  }, [report]);

  const updatePartLibrary = useCallback(
    (entries: PartLibraryEntry[]) => {
      setPartLibrary(entries);
      void partLibraryAdapter.save(entries).catch((error) => report(appStrings.error.partLibrary.saveFailed(error)));
    },
    [report],
  );

  return { partLibrary, updatePartLibrary };
}
