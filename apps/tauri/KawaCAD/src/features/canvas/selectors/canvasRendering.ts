import { appStrings } from "@/localization";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
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
  layers: CanvasLayer[];
  sharedStyles: CanvasSharedStyle[];
  selectedIds: Set<string>;
  freeTexts: CanvasFreeText[];
  editingFreeTextId?: string;
  highlightedFreeTextIds: Set<string>;
  highlightedMeasurementAnnotationIds: Set<string>;
  highlightedStitchStartPointIds: Set<string>;
  projection: CanvasProjection;
  selectedMeasurementAnnotationId?: string;
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
  pendingTargetEntityIds?: Set<string>;
  marqueeStart?: PointMm;
  marqueeCurrent?: PointMm;
  dragDuplicating: boolean;
  dragging: boolean;
  snapEnabled: boolean;
  pointSnapEnabled: boolean;
  snapSuppressed: boolean;
};

type CanvasLayer = { id: string; style: DisplayStyle; visible?: boolean };
type CanvasSharedStyle = { id: string; style: DisplayStyle };
type CanvasFreeText = { id: string; content: string; positionMm: PointMm; fontSizeMm: number };
type CanvasProjection = {
  stitchStartPoints: Array<{ id: string; positionMm: PointMm; visible: boolean }>;
  measurementAnnotations: ResolvedCanvasGeometry[];
  dimensionConstraints: ResolvedCanvasGeometry[];
  constraintMarkers: Array<{
    id: string;
    positionMm: PointMm;
    visible: boolean;
    label?: string;
    icon?: string;
    stackIndex?: number;
  }>;
};

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
    layers,
    sharedStyles,
    selectedIds,
    freeTexts,
    editingFreeTextId,
    highlightedFreeTextIds,
    highlightedMeasurementAnnotationIds,
    highlightedStitchStartPointIds,
    projection,
    selectedMeasurementAnnotationId,
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
    pendingTargetEntityIds = new Set(),
    marqueeStart,
    marqueeCurrent,
    dragDuplicating,
    dragging,
    snapEnabled,
    pointSnapEnabled,
    snapSuppressed,
  } = options;
  if (!outputPreview && gridVisible) drawGrid(context, width, height, viewport, a4Landscape);
  if (!outputPreview && a4Visible) drawA4(context, width, height, viewport, a4Landscape);
  if (outputPreview) drawOutputPreviewPages(context, outputPages, width, height, viewport);
  const visibleEntities = entities.filter((entity) => entityIsVisible(entity, layers));
  if (!outputPreview && visibleEntities.length === 0 && freeTexts.length === 0) drawEmptyState(context, width, height);
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
      ),
    );
    projection.dimensionConstraints.forEach((item) =>
      drawAnnotation(
        context,
        item,
        dimensionLabels[item.id],
        dimensionLabelOffsets[item.id],
        "#2e426b",
        width,
        height,
        viewport,
        dimensionArcCounterclockwise[item.id],
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
    drawPendingTargetFeedback(context, pendingTargetEntityIds, cursorPoint, tool, width, height, viewport);
    if (dragging && moveFeedbackVisible(selectedIds, cursorPoint))
      drawDragFeedback(context, selectedIds.size, dragDuplicating, cursorPoint, width, height, viewport);
    drawSnapFeedback(context, cursorPoint, snapEnabled || pointSnapEnabled, snapSuppressed, width, height, viewport);
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
    context.lineWidth = 1;
    context.setLineDash([5, 4]);
    context.strokeRect(page.x, page.y, page.width, page.height);
    context.setLineDash([]);
    const label = `${index + 1}`;
    context.font = "600 11px -apple-system, BlinkMacSystemFont, sans-serif";
    const badgeWidth = context.measureText(label).width + 12;
    context.fillStyle = "#0a84ff";
    context.beginPath();
    context.roundRect(page.x + 8, page.y + 8, badgeWidth, 18, 5);
    context.fill();
    context.fillStyle = "#fff";
    context.textAlign = "center";
    context.textBaseline = "middle";
    context.fillText(label, page.x + 8 + badgeWidth / 2, page.y + 17);
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
  context.strokeStyle = "#ececef";
  context.lineWidth = 1;
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
  context.setLineDash([4, 4]);
  for (let row = 0; row < 5; row += 1)
    for (let column = 0; column < 5; column += 1) {
      const centerPoint = { xMm: (column - center) * pageWidth, yMm: (center - row) * pageHeight };
      const topLeft = screenPoint(
        { xMm: centerPoint.xMm - pageWidth / 2, yMm: centerPoint.yMm + pageHeight / 2 },
        width,
        height,
        viewport,
      );
      context.strokeStyle = row === center && column === center ? "#777780" : "#b9b9bf";
      context.lineWidth = row === center && column === center ? 1.2 : 0.8;
      context.strokeRect(topLeft.x, topLeft.y, pageWidth * scale, pageHeight * scale);
    }
  const centralTopLeft = screenPoint({ xMm: -pageWidth / 2, yMm: pageHeight / 2 }, width, height, viewport);
  context.setLineDash([5, 4]);
  context.strokeStyle = "rgba(10,132,255,.35)";
  context.lineWidth = 0.8;
  context.strokeRect(centralTopLeft.x, centralTopLeft.y, pageWidth * scale, pageHeight * scale);
  context.setLineDash([]);
  drawCoordinateReference(context, width, height, viewport);
  context.fillStyle = "#6e6e73";
  context.font = "11px -apple-system, BlinkMacSystemFont, sans-serif";
  context.fillText(`A4 5×5 · ${landscape ? "横" : "縦"}`, 14, height - 14);
  context.restore();
}

function drawCoordinateReference(context: CanvasRenderingContext2D, width: number, height: number, viewport: Viewport) {
  const origin = screenPoint({ xMm: 0, yMm: 0 }, width, height, viewport);
  context.save();
  context.strokeStyle = "rgba(90,90,96,.75)";
  context.fillStyle = "rgba(90,90,96,.85)";
  context.lineWidth = 1;
  context.beginPath();
  context.moveTo(origin.x, origin.y);
  context.lineTo(origin.x + 34, origin.y);
  context.moveTo(origin.x, origin.y);
  context.lineTo(origin.x, origin.y - 34);
  context.stroke();
  context.font = "10px -apple-system, BlinkMacSystemFont, sans-serif";
  context.fillText("X", origin.x + 38, origin.y + 4);
  context.fillText("Y", origin.x + 4, origin.y - 38);
  context.fillText(appStrings.canvas.origin, origin.x + 6, origin.y + 14);
  const scale = Math.max(10, 50 * displayScale(viewport));
  context.strokeStyle = "rgba(90,90,96,.6)";
  context.beginPath();
  context.moveTo(14, height - 28);
  context.lineTo(14 + scale, height - 28);
  context.stroke();
  context.fillText(appStrings.canvas.scaleGuide, 14, height - 32);
  context.restore();
}

function drawEmptyState(context: CanvasRenderingContext2D, width: number, height: number) {
  const centerX = width / 2;
  const centerY = height / 2;
  context.save();
  context.fillStyle = "rgba(10,132,255,.1)";
  context.strokeStyle = "rgba(10,132,255,.65)";
  context.lineWidth = 1.5;
  context.beginPath();
  context.arc(centerX, centerY - 22, 18, 0, Math.PI * 2);
  context.fill();
  context.stroke();
  context.strokeStyle = "#0a84ff";
  context.beginPath();
  context.moveTo(centerX - 8, centerY - 22);
  context.lineTo(centerX + 8, centerY - 22);
  context.moveTo(centerX, centerY - 30);
  context.lineTo(centerX, centerY - 14);
  context.stroke();
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

function geometryScreenBounds(entity: RawEntity, width: number, height: number, viewport: Viewport) {
  const geometry = geometryOf(entity);
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
  point: PointMm | undefined,
  tool: Tool,
  width: number,
  height: number,
  viewport: Viewport,
) {
  if (
    !point ||
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
  context.strokeStyle = pendingTargetEntityIds.size ? "#0a84ff" : "#f59f00";
  context.lineWidth = 2;
  context.setLineDash(pendingTargetEntityIds.size ? [] : [5, 3]);
  context.beginPath();
  context.arc(screen.x, screen.y, 8, 0, Math.PI * 2);
  context.stroke();
  context.setLineDash([]);
  drawCanvasBadge(
    context,
    appStrings.canvas.constraintTargetSelection(pendingTargetEntityIds.size + 1),
    screen.x + 12,
    screen.y - 10,
    pendingTargetEntityIds.size ? "#0a84ff" : "#f59f00",
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
  drawCanvasBadge(
    context,
    duplicating ? appStrings.canvas.dragCopy(count) : appStrings.canvas.dragMove(count),
    screen.x + 12,
    screen.y - 27,
    duplicating ? "#34c759" : "#0a84ff",
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
    drawCanvasBadge(context, appStrings.canvas.snapOff, screen.x + 12, screen.y + 10, "#6e6e73");
    return;
  }
  if (!enabled) return;
  context.save();
  context.strokeStyle = "#34c759";
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

function drawEntity(
  context: CanvasRenderingContext2D,
  entity: RawEntity,
  style: DisplayStyle,
  width: number,
  height: number,
  viewport: Viewport,
  selected: boolean,
  pendingTarget = false,
) {
  const geometry = geometryOf(entity);
  if (!geometry) return;
  const scale = displayScale(viewport);
  context.save();
  context.strokeStyle = selected ? "#0a84ff" : pendingTarget ? "#34c759" : rgba(style.stroke);
  context.fillStyle = context.strokeStyle;
  context.lineWidth = selected || pendingTarget ? 2.2 : Math.max(0.8, style.strokeWidthMm * scale);
  if (!selected && pendingTarget) context.setLineDash([5, 3]);
  else if (!selected) setLinePattern(context, style.pattern, context.lineWidth);
  if (geometry.tag === "point") {
    const point = screenPoint(geometry.point, width, height, viewport);
    context.beginPath();
    context.arc(point.x, point.y, selected ? 5 : 3, 0, Math.PI * 2);
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
export function displayStyleFor(
  entity: RawEntity,
  layers: CanvasLayer[],
  sharedStyles: CanvasSharedStyle[],
): DisplayStyle {
  const base = sharedStyles.find((style) => style.id === entity.styleId)?.style ??
    layers.find((layer) => layer.id === entity.layerId)?.style ?? {
      stroke: { red: 0.11, green: 0.11, blue: 0.12, alpha: 1 },
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
  context.fillStyle = highlighted ? "#007aff" : "#1d1d1f";
  context.font = `${Math.max(11, item.fontSizeMm * scale)}px -apple-system, BlinkMacSystemFont, sans-serif`;
  context.textBaseline = "alphabetic";
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
  context.strokeStyle = highlighted ? "#007aff" : "#dc2626";
  context.fillStyle = "#fff";
  context.lineWidth = 1.5;
  context.beginPath();
  context.arc(point.x, point.y, highlighted ? 6.5 : 5, 0, Math.PI * 2);
  context.fill();
  context.stroke();
  context.beginPath();
  context.moveTo(point.x, point.y - 9);
  context.lineTo(point.x, point.y - 3);
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
  const label = marker.label ?? appStrings.canvas.constraint;
  const stackIndex = marker.stackIndex ?? 0;
  const x = point.x + 10 + stackIndex * 5;
  const y = point.y - 20 - stackIndex * 5;
  context.save();
  context.font = "600 10px -apple-system, BlinkMacSystemFont, sans-serif";
  const markerText = marker.icon ? `${marker.icon} ${label}` : label;
  const markerWidth = Math.max(22, context.measureText(markerText).width + 10);
  context.fillStyle = hovered ? "rgba(32, 74, 179, .95)" : "rgba(4, 129, 116, .92)";
  context.strokeStyle = hovered ? "#204ab3" : "rgba(4, 129, 116, .72)";
  context.lineWidth = hovered ? 1.5 : 1;
  context.beginPath();
  context.roundRect(x, y, markerWidth, 16, 4);
  context.fill();
  context.stroke();
  context.fillStyle = "#fff";
  context.textAlign = "center";
  context.textBaseline = "middle";
  context.fillText(markerText, x + markerWidth / 2, y + 8);
  context.beginPath();
  context.arc(point.x, point.y, hovered ? 4.5 : 3.5, 0, Math.PI * 2);
  context.fill();
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
) {
  if (!item.visible || !item.startMm || !item.endMm) return;
  const start = screenPoint(item.startMm, width, height, viewport),
    end = screenPoint(item.endMm, width, height, viewport);
  context.save();
  context.strokeStyle = color;
  context.fillStyle = color;
  context.lineWidth = 1;
  context.setLineDash([3, 3]);
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
    drawArcArrowhead(context, center, start, end, Boolean(arcCounterclockwise), color);
  } else {
    drawLinearArrowhead(context, start, end, color);
    drawLinearArrowhead(context, end, start, color);
  }
  if (label) {
    const midpoint =
      item.arc && item.centerMm
        ? arcMidpoint(item.centerMm, item.startMm, item.endMm, arcCounterclockwise)
        : {
            xMm: (item.startMm.xMm + item.endMm.xMm) / 2,
            yMm: (item.startMm.yMm + item.endMm.yMm) / 2,
          };
    const labelPoint = screenPoint(
      {
        xMm: midpoint.xMm + (labelOffsetMm?.xMm ?? 0),
        yMm: midpoint.yMm + (labelOffsetMm?.yMm ?? 0),
      },
      width,
      height,
      viewport,
    );
    drawAnnotationLabel(context, label, labelPoint.x + 5, labelPoint.y - 5, color);
  }
  context.restore();
}

function drawLinearArrowhead(
  context: CanvasRenderingContext2D,
  point: { x: number; y: number },
  toward: { x: number; y: number },
  color: string,
) {
  const angle = Math.atan2(toward.y - point.y, toward.x - point.x);
  const size = 5;
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
) {
  const tangent = counterclockwise
    ? { x: -(end.y - center.y), y: end.x - center.x }
    : { x: end.y - center.y, y: -(end.x - center.x) };
  drawLinearArrowhead(context, end, { x: end.x + tangent.x, y: end.y + tangent.y }, color);
  const startTangent = counterclockwise
    ? { x: start.y - center.y, y: -(start.x - center.x) }
    : { x: -(start.y - center.y), y: start.x - center.x };
  drawLinearArrowhead(context, start, { x: start.x + startTangent.x, y: start.y + startTangent.y }, color);
}

function drawAnnotationLabel(context: CanvasRenderingContext2D, label: string, x: number, y: number, color: string) {
  context.save();
  context.font = "600 10px -apple-system, BlinkMacSystemFont, sans-serif";
  context.textBaseline = "middle";
  const metrics = context.measureText(label);
  const paddingX = 4;
  const paddingY = 3;
  context.fillStyle = "rgba(255,255,255,.82)";
  context.strokeStyle = color;
  context.lineWidth = 1;
  context.beginPath();
  context.roundRect(
    x - paddingX,
    y - metrics.actualBoundingBoxAscent / 2 - paddingY,
    metrics.width + paddingX * 2,
    metrics.actualBoundingBoxAscent + metrics.actualBoundingBoxDescent + paddingY * 2,
    3,
  );
  context.fill();
  context.stroke();
  context.fillStyle = color;
  context.fillText(label, x, y);
  context.restore();
}

function arcMidpoint(center: PointMm, start: PointMm, end: PointMm, counterclockwise?: boolean) {
  const radius = Math.hypot(start.xMm - center.xMm, start.yMm - center.yMm);
  if (radius <= 0.0001) return start;
  const startAngle = Math.atan2(start.yMm - center.yMm, start.xMm - center.xMm);
  const endAngle = Math.atan2(end.yMm - center.yMm, end.xMm - center.xMm);
  let sweep = endAngle - startAngle;
  while (sweep <= -Math.PI) sweep += Math.PI * 2;
  while (sweep > Math.PI) sweep -= Math.PI * 2;
  if (counterclockwise === false && sweep > 0) sweep -= Math.PI * 2;
  if (counterclockwise === true && sweep < 0) sweep += Math.PI * 2;
  const angle = startAngle + sweep / 2;
  return { xMm: center.xMm + radius * Math.cos(angle), yMm: center.yMm + radius * Math.sin(angle) };
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
