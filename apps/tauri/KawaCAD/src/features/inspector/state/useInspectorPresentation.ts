import { useState } from "react";

/** Owns Inspector-only selection and invalidation state. */
export function useInspectorPresentation() {
  const [arrangementPartIds, setArrangementPartIds] = useState<Set<string>>(new Set());
  const [inspectorSelectedPartId, setInspectorSelectedPartId] = useState<string>();
  const [settingPartOriginId, setSettingPartOriginId] = useState<string>();
  const [inspectorRevision, setInspectorRevision] = useState(0);

  return {
    arrangementPartIds,
    setArrangementPartIds,
    inspectorSelectedPartId,
    setInspectorSelectedPartId,
    settingPartOriginId,
    setSettingPartOriginId,
    inspectorRevision,
    setInspectorRevision,
  };
}
