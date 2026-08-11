/**
 * UI-side CAD domain vocabulary.
 *
 * String unions are the TypeScript equivalent of Swift's raw-value enums:
 * they remain exhaustive without introducing a runtime enum object.
 */
export type Tool =
  | "select"
  | "point"
  | "line"
  | "circle"
  | "arc"
  | "freeText"
  | "centerLine"
  | "horizontalCenterLine"
  | "verticalCenterLine"
  | "roundHole"
  | "stitchStartPoint"
  | "offset"
  | "fillet"
  | "coincident"
  | "horizontal"
  | "vertical"
  | "parallel"
  | "perpendicular"
  | "tangent"
  | "equalLength"
  | "angle"
  | "symmetric"
  | "pointOnLine"
  | "fixed"
  | "distance"
  | "horizontalDistance"
  | "verticalDistance"
  | "lineLineDistance"
  | "segmentLength"
  | "diameter"
  | "radius"
  | "measureDistance"
  | "measureSegmentLength"
  | "measureAngle"
  | "measureRadius"
  | "measureDiameter"
  | "measureArcSweepAngle";

export type { CanvasViewMode } from "@/shared/domain/coreWireTypes";

export type ConstraintStatus = "unknown" | "underConstrained" | "fullyConstrained" | "overConstrained" | "conflicting";

export type CenterLineIconAxis = "diagonal" | "horizontal" | "vertical";
