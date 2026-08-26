import { appStrings } from "@/localization";
import type { CanvasProjection } from "@/shared/domain/coreWireTypes";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
import {
  annotationArcLayout,
  annotationLabelLayout,
  canvasLayoutMetrics,
  constraintMarkerLayout,
} from "@/features/canvas/domain/canvasLayout";
import {
  controlPointsOf,
  displayScale,
  geometryOf,
  a4GridBounds,
  selectionInRect,
  normalizedScreenRect,
  screenPoint,
  type PointMm,
  type RawEntity,
  type Viewport,
} from "@/features/canvas/domain/cad";

export type ResolvedCanvasGeometry = {
  id: string;
  visible: boolean;
  arc?: boolean;
  centerMm?: PointMm;
  startMm?: PointMm;
  endMm?: PointMm;
};
export type DisplayStyle = {
  stroke: { red: number; green: number; blue: number; alpha: number };
  strokeWidthMm: number;
  pattern: string;
};
export type OutputPreviewPage = {
  widthMm: number;
  heightMm: number;
  gridColumn: number;
  gridRow: number;
};

export type CanvasRenderOptions = {
  context: CanvasRenderingContext2D;
  width: number;
  height: number;
  viewport: Viewport;
  outputPreview: boolean;
  gridVisible: boolean;
  a4Visible: boolean;
  a4Landscape: boolean;
  outputPages: OutputPreviewPage[];
  entities: RawEntity[];
  suppressedByFilletEntityIds?: Set<string>;
  layers: CanvasLayer[];
  sharedStyles: CanvasSharedStyle[];
  selectedIds: Set<string>;
  freeTexts: CanvasFreeText[];
  editingFreeTextId?: string;
  highlightedFreeTextIds: Set<string>;
  highlightedEntityIds?: Set<string>;
  highlightedMeasurementAnnotationIds: Set<string>;
  highlightedStitchStartPointIds: Set<string>;
  projection: CanvasProjection;
  selectedMeasurementAnnotationId?: string;
  selectedConstraintId?: string;
  selectedStitchStartPointId?: string;
  measurementLabels: Record<string, string>;
  measurementLabelOffsets: Record<string, PointMm>;
  measurementArcCounterclockwise: Record<string, boolean>;
  dimensionLabels: Record<string, string>;
  dimensionLabelOffsets: Record<string, PointMm>;
  dimensionArcCounterclockwise: Record<string, boolean>;
  selectedPartOrigin?: PointMm;
  coincidentPointGroups: Array<{ id: string; representative: PointMm; targets: unknown[] }>;
  tool: Tool;
  draftPoints: PointMm[];
  cursorPoint?: PointMm;
  arcSweepAngleRad?: number;
  hoveredConstraintId?: string;
  hoveredTargetEntityId?: string;
  pendingTargetEntityIds?: Set<string>;
  marqueeStart?: PointMm;
  marqueeCurrent?: PointMm;
  dragDuplicating: boolean;
  dragging: boolean;
  snapActive: boolean;
  snapSuppressed: boolean;
};

export type CanvasRenderModel = Omit<CanvasRenderOptions, "context" | "width" | "height">;

type CanvasLayer = { id: string; style: DisplayStyle; visible?: boolean };
type CanvasSharedStyle = { id: string; style: DisplayStyle };
type CanvasFreeText = { id: string; content: string; positionMm: PointMm; fontSizeMm: number };

/** Visual priority for canvas aids; primary geometry remains platform styled. */
export const canvasVisualHierarchy = {
  gridStroke: "rgba(95, 108, 119, .13)",
  gridLineWidth: 0.5,
  a4SecondaryStroke: "rgba(95, 108, 119, .35)",
  a4PrimaryStroke: "rgba(95, 108, 119, .68)",
  a4SecondaryLineWidth: 0.8,
  a4PrimaryLineWidth: 1.2,
  a4ReferenceStroke: "rgba(10,132,255,.35)",
  a4ReferenceLineWidth: 0.8,
  coordinateStroke: "rgba(10,132,255,.72)",
  coordinateLineWidth: 1.4,
  selectionStroke: "rgba(59,130,246,.28)",
  selectionLineWidth: 3,
  selectionDash: [5, 3],
} as const;

export function drawCanvasFrame(options: CanvasRenderOptions) {
  const {
    context,
    width,
    height,
    viewport,
    outputPreview,
    gridVisible,
    a4Visible,
    a4Landscape,
    outputPages,
    entities,
    suppressedByFilletEntityIds = new Set(),
    layers,
    sharedStyles,
    selectedIds,
    freeTexts,
    editingFreeTextId,
    highlightedFreeTextIds,
    highlightedEntityIds = new Set(),
    highlightedMeasurementAnnotationIds,
    highlightedStitchStartPointIds,
    projection,
    selectedMeasurementAnnotationId,
    selectedConstraintId,
    selectedStitchStartPointId,
    measurementLabels,
    measurementLabelOffsets,
    measurementArcCounterclockwise,
    dimensionLabels,
    dimensionLabelOffsets,
    dimensionArcCounterclockwise,
    selectedPartOrigin,
    coincidentPointGroups,
    tool,
    draftPoints,
    cursorPoint,
    arcSweepAngleRad,
    hoveredConstraintId,
    hoveredTargetEntityId,
    pendingTargetEntityIds = new Set(),
    marqueeStart,
    marqueeCurrent,
    dragDuplicating,
    dragging,
    snapActive,
    snapSuppressed,
  } = options;
  if (!outputPreview && gridVisible) drawGrid(context, width, height, viewport, a4Landscape);
  if (!outputPreview && a4Visible) drawA4(context, width, height, viewport, a4Landscape);
  if (!outputPreview) drawCoordinateReference(context, width, height, viewport);
  const visibleEntities = entities.filter((entity) => entityIsVisible(entity, layers));
  if (!outputPreview && entities.length === 0 && freeTexts.length === 0) drawEmptyState(context, width, height);
  visibleEntities.forEach((entity) =>
    drawEntity(
      context,
      entity,
      displayStyleFor(entity, layers, sharedStyles),
      width,
      height,
      viewport,
      !outputPreview && selectedIds.has(entity.id),
      !outputPreview && pendingTargetEntityIds.has(entity.id),
      !outputPreview && entity.id === hoveredTargetEntityId,
      suppressedByFilletEntityIds.has(entity.id),
      !outputPreview && highlightedEntityIds.has(entity.id),
    ),
  );
  freeTexts
    .filter((item) => item.id !== editingFreeTextId)
    .forEach((item) => drawFreeText(context, item, width, height, viewport, highlightedFreeTextIds.has(item.id)));
  if (!outputPreview) {
    projection.measurementAnnotations.forEach((item) =>
      drawAnnotation(
        context,
        item,
        measurementLabels[item.id],
        measurementLabelOffsets[item.id],
        item.id === selectedMeasurementAnnotationId || highlightedMeasurementAnnotationIds.has(item.id)
          ? "#dd5615"
          : "#0c6058",
        width,
        height,
        viewport,
        measurementArcCounterclockwise[item.id],
        item.id === selectedMeasurementAnnotationId || highlightedMeasurementAnnotationIds.has(item.id),
      ),
    );
    projection.dimensionConstraints.forEach((item) =>
      drawAnnotation(
        context,
        item,
        dimensionLabels[item.id],
        dimensionLabelOffsets[item.id],
        item.id === selectedConstraintId || item.id === hoveredConstraintId ? "#dd5615" : "#2e426b",
        width,
        height,
        viewport,
        dimensionArcCounterclockwise[item.id],
        item.id === selectedConstraintId || item.id === hoveredConstraintId,
      ),
    );
  }
  projection.stitchStartPoints
    .filter((item) => item.visible)
    .forEach((item) =>
      drawStitchStart(
        context,
        item.positionMm,
        width,
        height,
        viewport,
        item.id === selectedStitchStartPointId || highlightedStitchStartPointIds.has(item.id),
      ),
    );
  if (outputPreview) drawOutputPreviewPages(context, outputPages, width, height, viewport);
  if (!outputPreview && selectedPartOrigin) drawPartOrigin(context, selectedPartOrigin, width, height, viewport);
  if (!outputPreview) {
    if (showsCoincidentGroups(tool)) {
      const visibleEntityIds = new Set(visibleEntities.map((entity) => entity.id));
      coincidentPointGroups
        .filter((group) => coincidentGroupIsVisible(group, visibleEntityIds))
        .forEach((group) => drawCoincidentPointGroup(context, group.representative, width, height, viewport));
    }
    projection.constraintMarkers
      .filter((item) => item.visible)
      .forEach((item) => drawConstraintMarker(context, item, item.id === hoveredConstraintId, width, height, viewport));
    if (draftPoints.length > 0)
      drawDraft(
        context,
        cursorPoint ? [...draftPoints, cursorPoint] : draftPoints,
        tool,
        arcSweepAngleRad,
        width,
        height,
        viewport,
      );
    if (marqueeStart && marqueeCurrent)
      drawSelectionMarquee(context, visibleEntities, marqueeStart, marqueeCurrent, width, height, viewport);
    drawPendingTargetFeedback(
      context,
      pendingTargetEntityIds,
      hoveredTargetEntityId,
      cursorPoint,
      tool,
      width,
      height,
      viewport,
    );
    if (dragging && moveFeedbackVisible(selectedIds, cursorPoint))
      drawDragFeedback(context, selectedIds.size, dragDuplicating, cursorPoint, width, height, viewport);
    drawSnapFeedback(context, cursorPoint, snapActive, snapSuppressed, width, height, viewport);
  }
}

function moveFeedbackVisible(selectedIds: Set<string>, cursorPoint: PointMm | undefined) {
  return selectedIds.size > 0 && Boolean(cursorPoint);
}

export function entityIsVisible(entity: RawEntity, layers: CanvasLayer[]) {
  return layers.find((layer) => layer.id === entity.layerId)?.visible ?? true;
}

function showsCoincidentGroups(tool: Tool) {
  return ![
    "point",
    "line",
    "circle",
    "arc",
    "freeText",
    "centerLine",
    "horizontalCenterLine",
    "verticalCenterLine",
    "roundHole",
    "stitchStartPoint",
  ].includes(tool);
}

function entityIdOfConstraintTarget(target: unknown): string | undefined {
  if (!target || typeof target !== "object") return undefined;
  const value = target as Record<string, unknown>;
  if (typeof value.entity === "string") return value.entity;
  if (!value.controlPoint || typeof value.controlPoint !== "object") return undefined;
  const controlPoint = value.controlPoint as Record<string, unknown>;
  return typeof controlPoint.entityId === "string"
    ? controlPoint.entityId
    : typeof controlPoint.entity_id === "string"
      ? controlPoint.entity_id
      : undefined;
}

export function coincidentGroupIsVisible(group: { targets: unknown[] }, visibleEntityIds: Set<string>) {
  const entityIds = group.targets.map(entityIdOfConstraintTarget);
  return entityIds.length > 0 && entityIds.every((entityId) => entityId && visibleEntityIds.has(entityId));
}

function drawCoincidentPointGroup(
  context: CanvasRenderingContext2D,
  pointMm: PointMm,
  width: number,
  height: number,
  viewport: Viewport,
) {
  const point = screenPoint(pointMm, width, height, viewport);
  context.save();
  context.fillStyle = "rgba(255, 242, 225, .9)";
  context.strokeStyle = "rgba(242, 82, 35, .92)";
  context.lineWidth = 2;
  context.beginPath();
  context.arc(point.x, point.y, 6, 0, Math.PI * 2);
  context.fill();
  context.stroke();
  context.restore();
}

export function outputPreviewPageRects(pages: OutputPreviewPage[], width: number, height: number, viewport: Viewport) {
  const scale = displayScale(viewport);
  return pages.map((page) => {
    const center = screenPoint(
      { xMm: page.gridColumn * page.widthMm, yMm: page.gridRow * page.heightMm },
      width,
      height,
      viewport,
    );
    return {
      x: center.x - (page.widthMm * scale) / 2,
      y: center.y - (page.heightMm * scale) / 2,
      width: page.widthMm * scale,
      height: page.heightMm * scale,
    };
  });
}

function drawOutputPreviewPages(
  context: CanvasRenderingContext2D,
  pages: OutputPreviewPage[],
  width: number,
  height: number,
  viewport: Viewport,
) {
  context.save();
  for (const [index, page] of outputPreviewPageRects(pages, width, height, viewport).entries()) {
    context.fillStyle = "rgba(10, 132, 255, .045)";
    context.fillRect(page.x, page.y, page.width, page.height);
    context.strokeStyle = "rgba(10, 132, 255, .75)";
    context.lineWidth = 1.4;
    context.setLineDash([7, 4]);
    context.strokeRect(page.x, page.y, page.width, page.height);
    context.setLineDash([]);
    const label = `${index + 1}`;
    context.font = "600 11px -apple-system, BlinkMacSystemFont, sans-serif";
    const badgeWidth = Math.max(24, context.measureText(label).width + 14);
    context.fillStyle = "#0a84ff";
    context.beginPath();
    context.roundRect(page.x + 8, page.y + 8, badgeWidth, 22, 5);
    context.fill();
    context.fillStyle = "#fff";
    context.textAlign = "center";
    context.textBaseline = "middle";
    context.fillText(label, page.x + 8 + badgeWidth / 2, page.y + 19);
  }
  context.restore();
}

function a4GridScreenRect(width: number, height: number, viewport: Viewport, landscape: boolean) {
  const bounds = a4GridBounds(landscape ? "landscape" : "portrait");
  const topLeft = screenPoint({ xMm: bounds.minXmm, yMm: bounds.maxYmm }, width, height, viewport);
  const bottomRight = screenPoint({ xMm: bounds.maxXmm, yMm: bounds.minYmm }, width, height, viewport);
  return {
    x: topLeft.x,
    y: topLeft.y,
    width: bottomRight.x - topLeft.x,
    height: bottomRight.y - topLeft.y,
  };
}

export function a4GridScreenBounds(width: number, height: number, viewport: Viewport, landscape: boolean) {
  return a4GridScreenRect(width, height, viewport, landscape);
}

function drawGrid(
  context: CanvasRenderingContext2D,
  width: number,
  height: number,
  viewport: Viewport,
  landscape: boolean,
) {
  const step = 5 * displayScale(viewport),
    origin = screenPoint({ xMm: 0, yMm: 0 }, width, height, viewport),
    bounds = a4GridScreenRect(width, height, viewport, landscape);
  context.save();
  context.strokeStyle = canvasVisualHierarchy.gridStroke;
  context.lineWidth = canvasVisualHierarchy.gridLineWidth;
  const firstX = origin.x + Math.ceil((bounds.x - origin.x) / step) * step;
  const firstY = origin.y + Math.ceil((bounds.y - origin.y) / step) * step;
  for (let x = firstX; x <= bounds.x + bounds.width; x += step) {
    context.beginPath();
    context.moveTo(x, bounds.y);
    context.lineTo(x, bounds.y + bounds.height);
    context.stroke();
  }
  for (let y = firstY; y <= bounds.y + bounds.height; y += step) {
    context.beginPath();
    context.moveTo(bounds.x, y);
    context.lineTo(bounds.x + bounds.width, y);
    context.stroke();
  }
  context.strokeStyle = "#b6b6ba";
  context.beginPath();
  context.moveTo(origin.x, bounds.y);
  context.lineTo(origin.x, bounds.y + bounds.height);
  context.moveTo(bounds.x, origin.y);
  context.lineTo(bounds.x + bounds.width, origin.y);
  context.stroke();
  context.restore();
}
function drawA4(
  context: CanvasRenderingContext2D,
  width: number,
  height: number,
  viewport: Viewport,
  landscape: boolean,
) {
  const pageWidth = landscape ? 297 : 210,
    pageHeight = landscape ? 210 : 297,
    center = 2,
    scale = displayScale(viewport),
    gridBounds = a4GridScreenRect(width, height, viewport, landscape);
  context.save();
  context.fillStyle = "rgba(255,255,255,.38)";
  context.fillRect(gridBounds.x, gridBounds.y, gridBounds.width, gridBounds.height);
  context.setLineDash([]);
  for (let row = 0; row < 5; row += 1)
    for (let column = 0; column < 5; column += 1) {
      const centerPoint = { xMm: (column - center) * pageWidth, yMm: (center - row) * pageHeight };
      const topLeft = screenPoint(
        { xMm: centerPoint.xMm - pageWidth / 2, yMm: centerPoint.yMm + pageHeight / 2 },
        width,
        height,
        viewport,
      );
      context.strokeStyle =
        row === center && column === center
          ? canvasVisualHierarchy.a4PrimaryStroke
          : canvasVisualHierarchy.a4SecondaryStroke;
      context.lineWidth =
        row === center && column === center
          ? canvasVisualHierarchy.a4PrimaryLineWidth
          : canvasVisualHierarchy.a4SecondaryLineWidth;
      context.strokeRect(topLeft.x, topLeft.y, pageWidth * scale, pageHeight * scale);
    }
  const centralTopLeft = screenPoint({ xMm: -pageWidth / 2, yMm: pageHeight / 2 }, width, height, viewport);
  context.setLineDash([5, 4]);
  context.strokeStyle = canvasVisualHierarchy.a4ReferenceStroke;
  context.lineWidth = canvasVisualHierarchy.a4ReferenceLineWidth;
  context.strokeRect(centralTopLeft.x, centralTopLeft.y, pageWidth * scale, pageHeight * scale);
  context.setLineDash([]);
  context.fillStyle = "#6e6e73";
  context.font = "11px -apple-system, BlinkMacSystemFont, sans-serif";
  context.fillText(
    "DrawingSnapshot / A4 5x5 / 100%",
    centralTopLeft.x + 14,
    centralTopLeft.y + pageHeight * scale - 14,
  );
  context.restore();
}

function drawCoordinateReference(context: CanvasRenderingContext2D, width: number, height: number, viewport: Viewport) {
  const origin = screenPoint({ xMm: 0, yMm: 0 }, width, height, viewport);
  context.save();
  const axisColor = canvasVisualHierarchy.coordinateStroke;
  const axisEndX = Math.min(origin.x + 70, width);
  const axisEndY = Math.max(origin.y - 70, 0);
  context.strokeStyle = axisColor;
  context.fillStyle = axisColor;
  context.lineWidth = canvasVisualHierarchy.coordinateLineWidth;
  context.beginPath();
  context.moveTo(origin.x, origin.y);
  context.lineTo(axisEndX, origin.y);
  context.moveTo(origin.x, origin.y);
  context.lineTo(origin.x, axisEndY);
  context.stroke();
  context.beginPath();
  context.moveTo(axisEndX, origin.y);
  context.lineTo(Math.max(origin.x, axisEndX - 8), origin.y - 4);
  context.lineTo(Math.max(origin.x, axisEndX - 8), origin.y + 4);
  context.fill();
  context.beginPath();
  context.moveTo(origin.x, axisEndY);
  context.lineTo(origin.x - 4, Math.min(origin.y, axisEndY + 8));
  context.lineTo(origin.x + 4, Math.min(origin.y, axisEndY + 8));
  context.fill();
  context.fillStyle = "rgba(255,255,255,.95)";
  context.strokeStyle = axisColor;
  context.beginPath();
  context.arc(origin.x, origin.y, 4, 0, Math.PI * 2);
  context.fill();
  context.stroke();
  context.font = "10px -apple-system, BlinkMacSystemFont, sans-serif";
  context.fillStyle = axisColor;
  context.fillText("X", Math.min(axisEndX + 6, width - 10), origin.y + 4);
  context.fillText("Y", origin.x - 4, Math.max(axisEndY - 8, 10));
  context.fillText(appStrings.canvas.origin, origin.x + 7, Math.max(origin.y - 8, 12));
  const scale = 112;
  context.strokeStyle = "rgba(29,29,31,.72)";
  context.lineWidth = 3;
  context.beginPath();
  context.moveTo(20, height - 34);
  context.lineTo(20 + scale, height - 34);
  context.stroke();
  context.fillStyle = "#1d1d1f";
  context.font = "600 11px -apple-system, BlinkMacSystemFont, sans-serif";
  context.fillText(appStrings.canvas.scaleGuide, 20, height - 42);
  context.restore();
}

function drawEmptyState(context: CanvasRenderingContext2D, width: number, height: number) {
  const centerX = width / 2;
  // Keep the first-use guide above the origin and coordinate axes while leaving
  // the canvas center available for the A4 reference and the first drawing.
  const centerY = height * 0.24;
  context.save();
  context.fillStyle = "#323238";
  context.font = "600 15px -apple-system, BlinkMacSystemFont, sans-serif";
  context.textAlign = "center";
  context.fillText(appStrings.canvas.emptyTitle, centerX, centerY + 18);
  context.fillStyle = "#6e6e73";
  context.font = "12px -apple-system, BlinkMacSystemFont, sans-serif";
  context.fillText(appStrings.canvas.emptyBody, centerX, centerY + 39);
  context.restore();
}

function drawSelectionMarquee(
  context: CanvasRenderingContext2D,
  entities: RawEntity[],
  start: PointMm,
  current: PointMm,
  width: number,
  height: number,
  viewport: Viewport,
) {
  const crossing = current.xMm < start.xMm;
  const screenStart = screenPoint(start, width, height, viewport);
  const screenCurrent = screenPoint(current, width, height, viewport);
  const rect = normalizedScreenRect(screenStart, screenCurrent);
  const ids = new Set(selectionInRect(entities, start, current, crossing));
  context.save();
  context.fillStyle = crossing ? "rgba(52,199,89,.12)" : "rgba(10,132,255,.12)";
  context.strokeStyle = crossing ? "#34c759" : "#0a84ff";
  context.lineWidth = 1.5;
  context.setLineDash(crossing ? [6, 4] : []);
  context.fillRect(rect.x, rect.y, rect.width, rect.height);
  context.strokeRect(rect.x, rect.y, rect.width, rect.height);
  context.setLineDash([4, 3]);
  for (const entity of entities) {
    if (!ids.has(entity.id)) continue;
    const bounds = geometryScreenBounds(entity, width, height, viewport);
    if (!bounds) continue;
    context.strokeRect(bounds.x - 4, bounds.y - 4, bounds.width + 8, bounds.height + 8);
  }
  context.setLineDash([]);
  drawCanvasBadge(
    context,
    crossing
      ? appStrings.status.marqueeFeedback("crossing", ids.size)
      : appStrings.status.marqueeFeedback("contained", ids.size),
    rect.x,
    Math.max(6, rect.y - 25),
    crossing ? "#34c759" : "#0a84ff",
  );
  context.restore();
}

function geometryScreenBounds(
  entity: RawEntity | NonNullable<ReturnType<typeof geometryOf>>,
  width: number,
  height: number,
  viewport: Viewport,
) {
  const geometry = "tag" in entity ? entity : geometryOf(entity);
  if (!geometry) return undefined;
  if (geometry.tag === "point") {
    const point = screenPoint(geometry.point, width, height, viewport);
    return { x: point.x, y: point.y, width: 0, height: 0 };
  }
  if (geometry.tag === "lineSegment" || geometry.tag === "centerLine") {
    const start = screenPoint(geometry.start, width, height, viewport);
    const end = screenPoint(geometry.end, width, height, viewport);
    return normalizedScreenRect(start, end);
  }
  if (geometry.tag !== "circle" && geometry.tag !== "arc") return undefined;
  const center = screenPoint(geometry.center, width, height, viewport);
  const radius = geometry.radiusMm * displayScale(viewport);
  return { x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2 };
}

function drawPendingTargetFeedback(
  context: CanvasRenderingContext2D,
  pendingTargetEntityIds: Set<string>,
  hoveredTargetEntityId: string | undefined,
  point: PointMm | undefined,
  tool: Tool,
  width: number,
  height: number,
  viewport: Viewport,
) {
  if (
    !point ||
    !hoveredTargetEntityId ||
    tool === "select" ||
    [
      "point",
      "line",
      "circle",
      "arc",
      "freeText",
      "centerLine",
      "horizontalCenterLine",
      "verticalCenterLine",
      "roundHole",
      "stitchStartPoint",
    ].includes(tool)
  )
    return;
  const screen = screenPoint(point, width, height, viewport);
  context.save();
  context.strokeStyle = "#048174";
  context.lineWidth = 2;
  context.setLineDash([]);
  context.beginPath();
  context.arc(screen.x, screen.y, 8, 0, Math.PI * 2);
  context.stroke();
  context.setLineDash([]);
  drawOutlinedCanvasBadge(
    context,
    constraintGuidanceText(tool, pendingTargetEntityIds.size),
    screen.x + 12,
    screen.y + 12,
    "#048174",
  );
  context.restore();
}

function drawDragFeedback(
  context: CanvasRenderingContext2D,
  count: number,
  duplicating: boolean,
  point: PointMm | undefined,
  width: number,
  height: number,
  viewport: Viewport,
) {
  if (!point) return;
  const screen = screenPoint(point, width, height, viewport);
  drawDragCanvasBadge(
    context,
    duplicating ? appStrings.canvas.dragCopy(count) : appStrings.canvas.dragMove(count),
    screen.x + 12,
    screen.y - 27,
    duplicating ? "#048174" : "#204ab3",
  );
}

function drawSnapFeedback(
  context: CanvasRenderingContext2D,
  point: PointMm | undefined,
  enabled: boolean,
  suppressed: boolean,
  width: number,
  height: number,
  viewport: Viewport,
) {
  if (!point) return;
  const screen = screenPoint(point, width, height, viewport);
  if (suppressed) {
    drawOutlinedCanvasBadge(context, appStrings.canvas.snapOff, screen.x + 12, screen.y + 10, "#4a525d", true);
    return;
  }
  if (!enabled) return;
  context.save();
  context.strokeStyle = "#048174";
  context.lineWidth = 1.5;
  context.beginPath();
  context.moveTo(screen.x - 8, screen.y);
  context.lineTo(screen.x + 8, screen.y);
  context.moveTo(screen.x, screen.y - 8);
  context.lineTo(screen.x, screen.y + 8);
  context.stroke();
  context.restore();
}

function drawCanvasBadge(context: CanvasRenderingContext2D, text: string, x: number, y: number, color: string) {
  context.save();
  context.font = "600 11px -apple-system, BlinkMacSystemFont, sans-serif";
  const width = context.measureText(text).width + 14;
  context.fillStyle = color;
  context.beginPath();
  context.roundRect(x, y, width, 20, 5);
  context.fill();
  context.fillStyle = "#fff";
  context.textAlign = "center";
  context.textBaseline = "middle";
  context.fillText(text, x + width / 2, y + 10);
  context.restore();
}

function drawOutlinedCanvasBadge(
  context: CanvasRenderingContext2D,
  text: string,
  x: number,
  y: number,
  color: string,
  monospaced = false,
) {
  context.save();
  context.font = monospaced
    ? "700 9px ui-monospace, SFMono-Regular, Menlo, monospace"
    : "600 10px -apple-system, BlinkMacSystemFont, sans-serif";
  const metrics = context.measureText(text);
  const badgeWidth = metrics.width + 14;
  const badgeHeight = metrics.actualBoundingBoxAscent + metrics.actualBoundingBoxDescent + 7;
  context.fillStyle = monospaced ? "rgba(74,82,93,.88)" : "rgba(255,255,255,.92)";
  context.strokeStyle = monospaced ? "rgba(251,245,228,.92)" : "rgba(4,129,116,.58)";
  context.lineWidth = 1;
  context.beginPath();
  context.roundRect(x, y, badgeWidth, badgeHeight, 6);
  context.fill();
  context.stroke();
  context.fillStyle = monospaced ? "#fbf5e4" : color;
  context.textAlign = "left";
  context.textBaseline = "middle";
  context.fillText(text, x + 7, y + badgeHeight / 2);
  context.restore();
}

function drawDragCanvasBadge(context: CanvasRenderingContext2D, text: string, x: number, y: number, color: string) {
  context.save();
  context.font = "600 11px -apple-system, BlinkMacSystemFont, sans-serif";
  const metrics = context.measureText(text);
  const badgeWidth = metrics.width + 18;
  const badgeHeight = metrics.actualBoundingBoxAscent + metrics.actualBoundingBoxDescent + 8;
  context.fillStyle = color === "#048174" ? "rgba(4,129,116,.92)" : "rgba(32,74,179,.90)";
  context.strokeStyle = "rgba(255,255,255,.84)";
  context.lineWidth = 1;
  context.beginPath();
  context.roundRect(x, y, badgeWidth, badgeHeight, 8);
  context.fill();
  context.stroke();
  context.fillStyle = "#fff";
  context.textAlign = "left";
  context.textBaseline = "middle";
  context.fillText(text, x + 9, y + badgeHeight / 2);
  context.restore();
}

function constraintGuidanceText(tool: Tool, pendingTargetCount: number) {
  const hints = appStrings.canvas.constraintHint;
  switch (tool) {
    case "distance":
    case "measureDistance":
    case "horizontal":
    case "vertical":
      return pendingTargetCount === 0 ? hints.pointOrLine : hints.nextPointOrLine;
    case "horizontalDistance":
    case "verticalDistance":
    case "coincident":
      return pendingTargetCount === 0 ? hints.point : hints.nextPoint;
    case "parallel":
    case "perpendicular":
    case "equalLength":
    case "angle":
    case "segmentLength":
    case "fillet":
    case "measureSegmentLength":
    case "measureAngle":
      return pendingTargetCount === 0 ? hints.line : hints.nextLine;
    case "diameter":
    case "measureDiameter":
      return hints.circle;
    case "radius":
    case "measureRadius":
    case "measureArcSweepAngle":
      return hints.circleOrArc;
    case "fixed":
      return hints.pointOrCenter;
    case "symmetric":
      return pendingTargetCount < 2 ? hints.point : hints.nextAxis;
    default:
      return hints.target;
  }
}

function drawEntity(
  context: CanvasRenderingContext2D,
  entity: RawEntity,
  style: DisplayStyle,
  width: number,
  height: number,
  viewport: Viewport,
  selected: boolean,
  pendingTarget = false,
  hoveredTarget = false,
  suppressedByFillet = false,
  highlightedPart = false,
) {
  const geometry = geometryOf(entity);
  if (!geometry) return;
  const scale = displayScale(viewport);
  const distinguishedStyle = suppressedByFillet
    ? {
        ...style,
        stroke: { ...style.stroke, alpha: style.stroke.alpha * 0.26 },
        strokeWidthMm: style.strokeWidthMm * 0.75,
        pattern: "dashed",
      }
    : style;
  context.save();
  context.strokeStyle = rgba(distinguishedStyle.stroke);
  context.fillStyle = rgba(distinguishedStyle.stroke);
  context.lineWidth = Math.max(0.8, distinguishedStyle.strokeWidthMm * scale);
  setLinePattern(context, distinguishedStyle.pattern, context.lineWidth);
  if (geometry.tag === "point") {
    const point = screenPoint(geometry.point, width, height, viewport);
    context.beginPath();
    context.arc(point.x, point.y, 3, 0, Math.PI * 2);
    context.fill();
  }
  if (geometry.tag === "lineSegment" || geometry.tag === "centerLine") {
    const start = screenPoint(geometry.start, width, height, viewport),
      end = screenPoint(geometry.end, width, height, viewport);
    if (geometry.tag === "centerLine") context.setLineDash([7, 4]);
    context.beginPath();
    context.moveTo(start.x, start.y);
    context.lineTo(end.x, end.y);
    context.stroke();
  }
  if (geometry.tag === "circle") {
    const center = screenPoint(geometry.center, width, height, viewport);
    context.beginPath();
    context.arc(center.x, center.y, geometry.radiusMm * scale, 0, Math.PI * 2);
    context.stroke();
  }
  if (geometry.tag === "arc") {
    const center = screenPoint(geometry.center, width, height, viewport);
    context.beginPath();
    context.arc(
      center.x,
      center.y,
      geometry.radiusMm * scale,
      -geometry.startAngleRad,
      -(geometry.startAngleRad + geometry.sweepAngleRad),
      geometry.sweepAngleRad > 0,
    );
    context.stroke();
  }
  if (selected) drawEntitySelectionHighlight(context, geometry, width, height, viewport);
  if (highlightedPart && !selected) drawEntityPartHighlight(context, geometry, width, height, viewport);
  if (pendingTarget || hoveredTarget)
    drawEntityTargetHighlight(context, geometry, width, height, viewport, hoveredTarget);
  if (selected) {
    context.fillStyle = "#fff";
    context.strokeStyle = "#0a84ff";
    context.lineWidth = 1.4;
    for (const control of controlPointsOf(geometry)) {
      const point = screenPoint(control.point, width, height, viewport);
      context.beginPath();
      context.rect(point.x - 3.5, point.y - 3.5, 7, 7);
      context.fill();
      context.stroke();
    }
  }
  context.restore();
}

function drawEntitySelectionHighlight(
  context: CanvasRenderingContext2D,
  geometry: NonNullable<ReturnType<typeof geometryOf>>,
  width: number,
  height: number,
  viewport: Viewport,
) {
  const bounds = geometryScreenBounds(geometry, width, height, viewport);
  if (!bounds) return;
  context.save();
  context.strokeStyle = canvasVisualHierarchy.selectionStroke;
  context.lineWidth = canvasVisualHierarchy.selectionLineWidth;
  context.setLineDash(canvasVisualHierarchy.selectionDash);
  context.beginPath();
  if (geometry.tag === "point" || geometry.tag === "circle" || geometry.tag === "arc") {
    const inset = geometry.tag === "point" ? 4 : 3;
    context.arc(
      bounds.x + bounds.width / 2,
      bounds.y + bounds.height / 2,
      Math.max(bounds.width, bounds.height) / 2 + inset,
      0,
      Math.PI * 2,
    );
  } else {
    context.roundRect(bounds.x - 4, bounds.y - 4, bounds.width + 8, bounds.height + 8, 8);
  }
  context.stroke();
  context.setLineDash([]);
  context.restore();
}

function drawEntityTargetHighlight(
  context: CanvasRenderingContext2D,
  geometry: NonNullable<ReturnType<typeof geometryOf>>,
  width: number,
  height: number,
  viewport: Viewport,
  hovered: boolean,
) {
  const bounds = geometryScreenBounds(geometry, width, height, viewport);
  if (!bounds) return;
  const stroke = hovered ? "rgba(4,129,116,.92)" : "rgba(32,74,179,.95)";
  const fill = hovered ? "rgba(4,129,116,.10)" : "rgba(59,130,246,.14)";
  context.save();
  context.strokeStyle = stroke;
  context.fillStyle = fill;
  context.lineWidth = hovered ? 2 : 3;
  context.setLineDash([]);
  context.beginPath();
  if (geometry.tag === "lineSegment" || geometry.tag === "centerLine") {
    const start = screenPoint(geometry.start, width, height, viewport);
    const end = screenPoint(geometry.end, width, height, viewport);
    context.moveTo(start.x, start.y);
    context.lineTo(end.x, end.y);
  } else if (geometry.tag === "point" || geometry.tag === "circle" || geometry.tag === "arc") {
    const inset = geometry.tag === "point" ? 8 : 5;
    context.arc(
      bounds.x + bounds.width / 2,
      bounds.y + bounds.height / 2,
      Math.max(bounds.width, bounds.height) / 2 + inset,
      0,
      Math.PI * 2,
    );
  } else {
    context.roundRect(bounds.x - 5, bounds.y - 5, bounds.width + 10, bounds.height + 10, 8);
  }
  if (geometry.tag !== "lineSegment" && geometry.tag !== "centerLine") context.fill();
  context.stroke();
  context.restore();
}

function drawEntityPartHighlight(
  context: CanvasRenderingContext2D,
  geometry: NonNullable<ReturnType<typeof geometryOf>>,
  width: number,
  height: number,
  viewport: Viewport,
) {
  const bounds = geometryScreenBounds(geometry, width, height, viewport);
  if (!bounds) return;
  context.save();
  context.strokeStyle = "rgba(234,128,36,.55)";
  context.lineWidth = 2;
  context.setLineDash([]);
  context.beginPath();
  if (geometry.tag === "point" || geometry.tag === "circle" || geometry.tag === "arc") {
    context.arc(
      bounds.x + bounds.width / 2,
      bounds.y + bounds.height / 2,
      Math.max(bounds.width, bounds.height) / 2 + 3,
      0,
      Math.PI * 2,
    );
  } else {
    context.roundRect(bounds.x - 3, bounds.y - 3, bounds.width + 6, bounds.height + 6, 7);
  }
  context.stroke();
  context.restore();
}

export function displayStyleFor(
  entity: RawEntity,
  layers: CanvasLayer[],
  sharedStyles: CanvasSharedStyle[],
): DisplayStyle {
  const base = sharedStyles.find((style) => style.id === entity.styleId)?.style ??
    layers.find((layer) => layer.id === entity.layerId)?.style ?? {
      stroke: { red: 0.067, green: 0.094, blue: 0.153, alpha: 1 },
      strokeWidthMm: 0.2,
      pattern: "solid",
    };
  return geometryOf(entity)?.tag === "centerLine"
    ? {
        stroke: { red: 0.075, green: 0.365, blue: 0.612, alpha: 0.88 },
        strokeWidthMm: base.strokeWidthMm * 0.9,
        pattern: "construction",
      }
    : base;
}
function rgba(color: DisplayStyle["stroke"]) {
  return `rgba(${Math.round(color.red * 255)}, ${Math.round(color.green * 255)}, ${Math.round(color.blue * 255)}, ${color.alpha})`;
}
export function lineDashPattern(pattern: string, lineWidth: number): number[] | undefined {
  if (pattern === "construction") return [lineWidth * 6, lineWidth * 2, lineWidth * 1.2, lineWidth * 2];
  if (pattern === "dashed") return [lineWidth * 4, lineWidth * 2.5];
  if (pattern === "dotted") return [lineWidth, lineWidth * 2];
  return undefined;
}

function setLinePattern(context: CanvasRenderingContext2D, pattern: string, lineWidth: number) {
  context.setLineDash(lineDashPattern(pattern, lineWidth) ?? []);
}
function drawFreeText(
  context: CanvasRenderingContext2D,
  item: CanvasFreeText,
  width: number,
  height: number,
  viewport: Viewport,
  highlighted: boolean,
) {
  const point = screenPoint(item.positionMm, width, height, viewport);
  const scale = displayScale(viewport);
  context.save();
  context.font = `${Math.max(11, item.fontSizeMm * scale)}px -apple-system, BlinkMacSystemFont, sans-serif`;
  context.textBaseline = "alphabetic";
  const metrics = context.measureText(item.content);
  if (highlighted) {
    const ascent = metrics.actualBoundingBoxAscent || Math.max(9, item.fontSizeMm * scale);
    const descent = metrics.actualBoundingBoxDescent || 3;
    context.fillStyle = "rgba(59,130,246,.12)";
    context.strokeStyle = "rgba(59,130,246,.75)";
    context.lineWidth = 1;
    context.beginPath();
    context.roundRect(point.x - 4, point.y - ascent - 3, metrics.width + 8, ascent + descent + 6, 4);
    context.fill();
    context.stroke();
  }
  context.fillStyle = "#1d1d1f";
  context.fillText(item.content, point.x, point.y);
  context.restore();
}
function drawStitchStart(
  context: CanvasRenderingContext2D,
  pointMm: PointMm,
  width: number,
  height: number,
  viewport: Viewport,
  highlighted: boolean,
) {
  const point = screenPoint(pointMm, width, height, viewport);
  context.save();
  const size = highlighted ? 13 : 10;
  context.fillStyle = "rgba(23,31,42,.96)";
  context.strokeStyle = "#fff";
  context.lineWidth = highlighted ? 2 : 1.4;
  context.beginPath();
  context.arc(point.x, point.y, size / 2, 0, Math.PI * 2);
  context.fill();
  context.stroke();
  context.beginPath();
  context.arc(point.x, point.y, Math.max(1, size / 2 - 2), 0, Math.PI * 2);
  context.stroke();
  context.restore();
}
function drawPartOrigin(
  context: CanvasRenderingContext2D,
  pointMm: PointMm,
  width: number,
  height: number,
  viewport: Viewport,
) {
  const point = screenPoint(pointMm, width, height, viewport);
  context.save();
  context.strokeStyle = "#0a84ff";
  context.fillStyle = "rgba(10,132,255,.16)";
  context.lineWidth = 1.5;
  context.beginPath();
  context.arc(point.x, point.y, 8, 0, Math.PI * 2);
  context.fill();
  context.stroke();
  context.beginPath();
  context.moveTo(point.x - 12, point.y);
  context.lineTo(point.x + 12, point.y);
  context.moveTo(point.x, point.y - 12);
  context.lineTo(point.x, point.y + 12);
  context.stroke();
  context.restore();
}
function drawConstraintMarker(
  context: CanvasRenderingContext2D,
  marker: { positionMm: PointMm; label?: string; icon?: string; stackIndex?: number },
  hovered: boolean,
  width: number,
  height: number,
  viewport: Viewport,
) {
  const point = screenPoint(marker.positionMm, width, height, viewport);
  const layout = constraintMarkerLayout({ ...marker, label: marker.label ?? appStrings.canvas.constraint });
  const x = point.x + layout.offsetX;
  const y = point.y + layout.offsetY;
  context.save();
  const visualRect = {
    x,
    y,
    width: canvasLayoutMetrics.constraintMarkerMinimumWidthPx,
    height: canvasLayoutMetrics.constraintMarkerHeightPx,
  };
  const icon = marker.icon ?? "?";
  context.font = "600 13px -apple-system, BlinkMacSystemFont, sans-serif";
  context.textAlign = "center";
  context.textBaseline = "middle";
  context.fillStyle = hovered ? "rgba(255,249,230,1)" : "rgba(12,96,88,.94)";
  context.strokeStyle = hovered ? "rgba(221,86,21,.90)" : "rgba(12,96,88,.94)";
  context.lineWidth = 1.6;
  context.beginPath();
  if (hovered) {
    context.roundRect(visualRect.x, visualRect.y, visualRect.width, visualRect.height, 5);
    context.fill();
  }
  context.fillText(icon, visualRect.x + visualRect.width / 2, visualRect.y + visualRect.height / 2);
  if (hovered) {
    context.font = "600 10px -apple-system, BlinkMacSystemFont, sans-serif";
    const name = marker.label ?? appStrings.canvas.constraint;
    const labelWidth = context.measureText(name).width + 12;
    const labelX = visualRect.x + visualRect.width + 5;
    const labelY = visualRect.y + 2;
    context.fillStyle = "rgba(221,86,21,.88)";
    context.beginPath();
    context.roundRect(labelX, labelY, labelWidth, 18, 6);
    context.fill();
    context.fillStyle = "rgba(251,245,228,1)";
    context.textAlign = "left";
    context.textBaseline = "middle";
    context.fillText(name, labelX + 6, labelY + 9);
  }
  context.restore();
}
function drawAnnotation(
  context: CanvasRenderingContext2D,
  item: ResolvedCanvasGeometry,
  label: string | undefined,
  labelOffsetMm: PointMm | undefined,
  color: string,
  width: number,
  height: number,
  viewport: Viewport,
  arcCounterclockwise?: boolean,
  highlighted = false,
) {
  if (!item.visible || !item.startMm || !item.endMm) return;
  const start = screenPoint(item.startMm, width, height, viewport),
    end = screenPoint(item.endMm, width, height, viewport);
  context.save();
  context.strokeStyle = color;
  context.fillStyle = color;
  context.lineWidth = highlighted ? 1.5 : 1;
  context.setLineDash([]);
  context.beginPath();
  if (item.arc && item.centerMm) {
    const center = screenPoint(item.centerMm, width, height, viewport);
    context.arc(
      center.x,
      center.y,
      Math.hypot(start.x - center.x, start.y - center.y),
      Math.atan2(start.y - center.y, start.x - center.x),
      Math.atan2(end.y - center.y, end.x - center.x),
      arcCounterclockwise,
    );
  } else {
    context.moveTo(start.x, start.y);
    context.lineTo(end.x, end.y);
  }
  context.stroke();
  context.setLineDash([]);
  if (item.arc && item.centerMm) {
    const center = screenPoint(item.centerMm, width, height, viewport);
    drawArcArrowhead(context, center, start, end, Boolean(arcCounterclockwise), color, highlighted);
  } else {
    drawLinearArrowhead(context, start, end, color, highlighted);
    drawLinearArrowhead(context, end, start, color, highlighted);
  }
  if (label) {
    const midpoint =
      item.arc && item.centerMm
        ? annotationArcLayout({
            centerMm: item.centerMm,
            startMm: item.startMm,
            endMm: item.endMm,
            counterclockwise: arcCounterclockwise,
          }).midpointMm
        : {
            xMm: (item.startMm.xMm + item.endMm.xMm) / 2,
            yMm: (item.startMm.yMm + item.endMm.yMm) / 2,
          };
    context.font = "600 10px -apple-system, BlinkMacSystemFont, sans-serif";
    const labelLayout = annotationLabelLayout(
      midpoint,
      label,
      labelOffsetMm,
      Math.max(displayScale(viewport), 0.01),
      context.measureText(label).width,
    );
    const labelPoint = screenPoint(labelLayout.centerMm, width, height, viewport);
    drawAnnotationLabel(
      context,
      label,
      labelPoint.x,
      labelPoint.y,
      color,
      {
        halfWidthPx: labelLayout.halfWidthMm * displayScale(viewport),
        halfHeightPx: labelLayout.halfHeightMm * displayScale(viewport),
      },
      highlighted,
    );
  }
  context.restore();
}

function drawLinearArrowhead(
  context: CanvasRenderingContext2D,
  point: { x: number; y: number },
  toward: { x: number; y: number },
  color: string,
  highlighted = false,
) {
  const angle = Math.atan2(toward.y - point.y, toward.x - point.x);
  const size = highlighted ? 10 : 8;
  context.save();
  context.fillStyle = color;
  context.beginPath();
  context.moveTo(point.x, point.y);
  context.lineTo(point.x + Math.cos(angle + Math.PI * 0.8) * size, point.y + Math.sin(angle + Math.PI * 0.8) * size);
  context.lineTo(point.x + Math.cos(angle - Math.PI * 0.8) * size, point.y + Math.sin(angle - Math.PI * 0.8) * size);
  context.lineTo(point.x, point.y);
  context.fill();
  context.restore();
}

function drawArcArrowhead(
  context: CanvasRenderingContext2D,
  center: { x: number; y: number },
  start: { x: number; y: number },
  end: { x: number; y: number },
  counterclockwise: boolean,
  color: string,
  highlighted = false,
) {
  const tangent = counterclockwise
    ? { x: -(end.y - center.y), y: end.x - center.x }
    : { x: end.y - center.y, y: -(end.x - center.x) };
  drawLinearArrowhead(context, end, { x: end.x + tangent.x, y: end.y + tangent.y }, color, highlighted);
  const startTangent = counterclockwise
    ? { x: start.y - center.y, y: -(start.x - center.x) }
    : { x: -(start.y - center.y), y: start.x - center.x };
  drawLinearArrowhead(context, start, { x: start.x + startTangent.x, y: start.y + startTangent.y }, color, highlighted);
}

function drawAnnotationLabel(
  context: CanvasRenderingContext2D,
  label: string,
  x: number,
  y: number,
  color: string,
  layout?: { halfWidthPx: number; halfHeightPx: number },
  highlighted = false,
) {
  context.save();
  context.font = "600 10px -apple-system, BlinkMacSystemFont, sans-serif";
  context.textBaseline = "middle";
  const metrics = context.measureText(label);
  const measuredHalfWidth = metrics.width / 2 + 4;
  const halfWidth = Math.max(layout?.halfWidthPx ?? 0, measuredHalfWidth);
  const halfHeight = layout?.halfHeightPx ?? 8;
  context.fillStyle = highlighted ? "rgba(221,86,21,.90)" : "rgba(255,255,255,.82)";
  context.strokeStyle = color;
  context.lineWidth = highlighted ? 0 : 1;
  context.beginPath();
  context.roundRect(x - halfWidth, y - halfHeight, halfWidth * 2, halfHeight * 2, 3);
  context.fill();
  if (!highlighted) context.stroke();
  context.fillStyle = highlighted ? "#fbf5e4" : color;
  context.fillText(label, x, y);
  context.restore();
}

/** Canvas coordinates invert model-space Y, so a positive model angle uses
 * Canvas's counterclockwise direction. */
export function angleArcCounterclockwise(fixedDegrees: number | undefined) {
  return typeof fixedDegrees === "number" ? fixedDegrees > 0 : undefined;
}
function drawDraft(
  context: CanvasRenderingContext2D,
  points: PointMm[],
  tool: Tool,
  arcSweepAngleRad: number | undefined,
  width: number,
  height: number,
  viewport: Viewport,
) {
  if (points.length < 2) return;
  const first = screenPoint(points[0], width, height, viewport),
    last = screenPoint(points[points.length - 1], width, height, viewport);
  context.save();
  context.strokeStyle = "#0a70d8";
  context.setLineDash([5, 4]);
  context.beginPath();
  if (tool === "circle") context.arc(first.x, first.y, Math.hypot(last.x - first.x, last.y - first.y), 0, Math.PI * 2);
  else if (tool === "arc" && points.length === 2) {
    context.moveTo(first.x, first.y);
    context.lineTo(last.x, last.y);
  } else if (tool === "arc" && points.length >= 3 && arcSweepAngleRad !== undefined) {
    const center = first;
    const start = screenPoint(points[1], width, height, viewport);
    const radius = Math.hypot(start.x - center.x, start.y - center.y);
    const startAngle = Math.atan2(start.y - center.y, start.x - center.x);
    context.arc(center.x, center.y, radius, startAngle, startAngle - arcSweepAngleRad, arcSweepAngleRad > 0);
  } else {
    context.moveTo(first.x, first.y);
    context.lineTo(last.x, last.y);
  }
  context.stroke();
  context.restore();
}
