import {
  ArrowLeftRight,
  ArrowUpDown,
  BetweenHorizontalStart,
  Circle,
  CircleDot,
  Crosshair,
  Diameter,
  Equal,
  FlipHorizontal,
  MapPin,
  MousePointer2,
  MoveDiagonal,
  MoveUpRight,
  Pin,
  Radius,
  Route,
  Ruler,
  RulerDimensionLine,
  Spline,
  SquareRoundCorner,
  Triangle,
  Type,
  type LucideIcon,
} from "lucide-react";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";

type Props = { tool: Tool; size?: number; className?: string };

/**
 * Cross-platform, OSS alternatives to the SwiftUI tool symbols.
 * Lucide is ISC-licensed (with the bundled notice covering Feather-derived icons).
 */
export const toolIcons: Record<Tool, LucideIcon> = {
  select: MousePointer2,
  point: CircleDot,
  line: MoveUpRight,
  circle: Circle,
  arc: Spline,
  freeText: Type,
  centerLine: MoveDiagonal,
  horizontalCenterLine: ArrowLeftRight,
  verticalCenterLine: ArrowUpDown,
  roundHole: CircleDot,
  stitchStartPoint: MapPin,
  offset: BetweenHorizontalStart,
  fillet: SquareRoundCorner,
  coincident: Crosshair,
  horizontal: ArrowLeftRight,
  vertical: ArrowUpDown,
  parallel: Equal,
  perpendicular: SquareRoundCorner,
  tangent: Spline,
  equalLength: Ruler,
  angle: Triangle,
  symmetric: FlipHorizontal,
  pointOnLine: Route,
  fixed: Pin,
  distance: RulerDimensionLine,
  horizontalDistance: ArrowLeftRight,
  verticalDistance: ArrowUpDown,
  lineLineDistance: BetweenHorizontalStart,
  segmentLength: RulerDimensionLine,
  diameter: Diameter,
  radius: Radius,
  measureDistance: RulerDimensionLine,
  measureSegmentLength: Ruler,
  measureAngle: Triangle,
  measureRadius: Radius,
  measureDiameter: Diameter,
  measureArcSweepAngle: Triangle,
};

export function ToolIcon({ tool, size = 16, className }: Props) {
  const Icon = toolIcons[tool];
  // CanvasToolIcon places an SF Symbol in a size-sized frame at 82% of that
  // frame. Lucide needs the same optical reduction to avoid looking larger.
  return <Icon className={className} size={size * 0.82} strokeWidth={1.8} aria-hidden="true" focusable="false" />;
}
