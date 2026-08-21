import { useCallback, useState } from "react";
import type { InspectorTab } from "@/features/inspector/selectors/inspectorFeature";

/** Owns Inspector-only selection and invalidation state. */
export function useInspectorPresentation() {
  const [arrangementPartIds, setArrangementPartIds] = useState<Set<string>>(new Set());
  const [inspectorSelectedPartId, setInspectorSelectedPartId] = useState<string>();
  const [settingPartOriginId, setSettingPartOriginId] = useState<string>();
  const [inspectorRevision, setInspectorRevision] = useState(0);
  const [inspectorTab, setInspectorTab] = useState<InspectorTab>("selection");
  const clearInspectorSelectedPart = useCallback(() => setInspectorSelectedPartId(undefined), []);
  const clearPartOriginSelection = useCallback(() => setSettingPartOriginId(undefined), []);

  return {
    arrangementPartIds,
    setArrangementPartIds,
    inspectorSelectedPartId,
    setInspectorSelectedPartId,
    clearInspectorSelectedPart,
    settingPartOriginId,
    setSettingPartOriginId,
    clearPartOriginSelection,
    inspectorRevision,
    setInspectorRevision,
    inspectorTab,
    setInspectorTab,
  };
}
