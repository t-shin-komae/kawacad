import type { Part, State } from "@/shared/domain/coreWireTypes";

export function partCanvasHighlights(
  part: Part | undefined,
  drawingEntityMetadata: State["drawingEntityMetadata"],
  stitchStartPoints: State["stitchStartPoints"],
) {
  if (!part)
    return {
      entityIds: new Set<string>(),
      freeTextIds: new Set<string>(),
      measurementAnnotationIds: new Set<string>(),
      stitchStartPointIds: new Set<string>(),
    };
  const derivedIds = new Set(part.derivedElementIds);
  const resolvedEntityIds = drawingEntityMetadata
    .filter((item) => derivedIds.has(item.derivedElementId ?? ""))
    .map((item) => item.entityId);
  const stitchTargetIds = new Set([...part.entityIds, ...part.derivedElementIds]);
  return {
    entityIds: new Set([...part.entityIds, ...resolvedEntityIds]),
    freeTextIds: new Set(part.freeTextIds),
    measurementAnnotationIds: new Set(part.measurementAnnotationIds),
    stitchStartPointIds: new Set(
      stitchStartPoints.filter((item) => stitchTargetIds.has(item.targetEntityId)).map((item) => item.id),
    ),
  };
}
