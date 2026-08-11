import { useState } from "react";
import type { InspectorTab } from "@/features/inspector/selectors/inspectorFeature";

/** Owns Inspector-only selection and invalidation state. */
export function useInspectorPresentation() {
  const [arrangementPartIds, setArrangementPartIds] = useState<Set<string>>(new Set());
  const [inspectorSelectedPartId, setInspectorSelectedPartId] = useState<string>();
  const [settingPartOriginId, setSettingPartOriginId] = useState<string>();
  const [inspectorRevision, setInspectorRevision] = useState(0);
  const [inspectorTab, setInspectorTab] = useState<InspectorTab>("selection");

  return {
    arrangementPartIds,
    setArrangementPartIds,
    inspectorSelectedPartId,
    setInspectorSelectedPartId,
    settingPartOriginId,
    setSettingPartOriginId,
    inspectorRevision,
    setInspectorRevision,
    inspectorTab,
    setInspectorTab,
  };
}
