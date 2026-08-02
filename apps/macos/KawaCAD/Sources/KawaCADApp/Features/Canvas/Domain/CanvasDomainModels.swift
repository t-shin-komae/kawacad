import Foundation

enum CanvasTool: String, CaseIterable, Identifiable {
  case select
  case point
  case line
  case circle
  case roundHole
  case stitchStartPoint
  case arc
  case freeText
  case centerLine
  case horizontalCenterLine
  case verticalCenterLine
  case offset
  case fillet
  case coincident
  case horizontal
  case vertical
  case parallel
  case perpendicular
  case tangent
  case equalLength
  case angle
  case symmetric
  case pointOnLine
  case distance
  case horizontalDistance
  case verticalDistance
  case lineLineDistance
  case segmentLength
  case diameter
  case radius
  case fixed
  case measureDistance
  case measureSegmentLength
  case measureAngle
  case measureRadius
  case measureDiameter
  case measureArcSweepAngle

  var id: String { rawValue }

  var iconKind: CanvasToolIconKind {
    switch self {
    case .select: return .system("cursorarrow")
    case .point: return .point
    case .line: return .line
    case .circle: return .system("circle")
    case .roundHole: return .system("smallcircle.filled.circle")
    case .stitchStartPoint: return .system("mappin.and.ellipse")
    case .arc: return .arc
    case .freeText: return .system("textformat")
    case .centerLine: return .system("line.diagonal.arrow")
    case .horizontalCenterLine: return .system("arrow.left.and.right")
    case .verticalCenterLine: return .system("arrow.up.and.down")
    case .offset: return .system("arrow.up.and.line.horizontal.and.arrow.down")
    case .fillet: return .fillet
    case .coincident: return .system("scope")
    case .horizontal: return .system("arrow.left.and.right")
    case .vertical: return .system("arrow.up.and.down")
    case .parallel: return .system("equal")
    case .perpendicular: return .perpendicular
    case .tangent: return .system("point.topleft.down.curvedto.point.bottomright.up")
    case .equalLength: return .system("ruler")
    case .angle: return .angle
    case .symmetric: return .symmetric
    case .pointOnLine: return .system("point.topleft.down.to.point.bottomright.curvepath")
    case .distance: return .distance
    case .horizontalDistance: return .system("arrow.left.and.right")
    case .verticalDistance: return .system("arrow.up.and.down")
    case .lineLineDistance: return .system("arrow.up.and.down.and.arrow.left.and.right")
    case .segmentLength: return .segmentLength
    case .diameter: return .diameter
    case .radius: return .radius
    case .fixed: return .system("pin")
    case .measureDistance: return .distance
    case .measureSegmentLength: return .segmentLength
    case .measureAngle: return .angle
    case .measureRadius: return .radius
    case .measureDiameter: return .diameter
    case .measureArcSweepAngle: return .angle
    }
  }

  var symbolName: String { iconKind.fallbackSymbolName }
  var iconIdentity: String { iconKind.identity }

  var displayName: String {
    switch self {
    case .select: return AppStrings.tr("tool.select")
    case .point: return AppStrings.tr("tool.point")
    case .line: return AppStrings.tr("tool.line")
    case .circle: return AppStrings.tr("tool.circle")
    case .roundHole: return AppStrings.tr("tool.round_hole")
    case .stitchStartPoint: return AppStrings.tr("tool.stitch_start_point")
    case .arc: return AppStrings.tr("tool.arc")
    case .freeText: return AppStrings.tr("tool.free_text")
    case .centerLine: return AppStrings.tr("tool.center_line")
    case .horizontalCenterLine: return AppStrings.tr("tool.horizontal_center_line")
    case .verticalCenterLine: return AppStrings.tr("tool.vertical_center_line")
    case .offset: return AppStrings.tr("tool.offset")
    case .fillet: return AppStrings.tr("tool.fillet")
    case .coincident: return AppStrings.tr("tool.coincident")
    case .horizontal: return AppStrings.tr("tool.horizontal")
    case .vertical: return AppStrings.tr("tool.vertical")
    case .parallel: return AppStrings.tr("tool.parallel")
    case .perpendicular: return AppStrings.tr("tool.perpendicular")
    case .tangent: return AppStrings.tr("tool.tangent")
    case .equalLength: return AppStrings.tr("tool.equal_length")
    case .angle: return AppStrings.tr("tool.angle")
    case .symmetric: return AppStrings.tr("tool.symmetric")
    case .pointOnLine: return AppStrings.tr("tool.point_on_line")
    case .distance: return AppStrings.tr("tool.distance")
    case .horizontalDistance: return AppStrings.tr("tool.horizontal_distance")
    case .verticalDistance: return AppStrings.tr("tool.vertical_distance")
    case .lineLineDistance: return AppStrings.tr("tool.line_line_distance")
    case .segmentLength: return AppStrings.tr("tool.segment_length")
    case .diameter: return AppStrings.tr("tool.diameter")
    case .radius: return AppStrings.tr("tool.radius")
    case .fixed: return AppStrings.tr("tool.fixed")
    case .measureDistance: return AppStrings.tr("tool.measure_distance")
    case .measureSegmentLength: return AppStrings.tr("tool.measure_segment_length")
    case .measureAngle: return AppStrings.tr("tool.measure_angle")
    case .measureRadius: return AppStrings.tr("tool.measure_radius")
    case .measureDiameter: return AppStrings.tr("tool.measure_diameter")
    case .measureArcSweepAngle: return AppStrings.tr("tool.measure_arc_sweep_angle")
    }
  }

  var groupName: String {
    switch self {
    case .select, .point, .line, .circle, .roundHole, .stitchStartPoint, .arc, .freeText,
      .centerLine, .horizontalCenterLine, .verticalCenterLine, .offset, .fillet:
      return AppStrings.tr("tool.group.drawing")
    case .coincident, .horizontal, .vertical, .parallel, .perpendicular, .tangent, .equalLength,
      .angle, .symmetric,
      .pointOnLine, .distance, .horizontalDistance, .verticalDistance, .lineLineDistance,
      .segmentLength, .diameter, .radius, .fixed:
      return AppStrings.tr("tool.group.constraint")
    case .measureDistance, .measureSegmentLength, .measureAngle, .measureRadius, .measureDiameter,
      .measureArcSweepAngle:
      return AppStrings.tr("tool.group.measurement")
    }
  }

  var isBasicTool: Bool {
    switch self {
    case .select, .line, .circle, .arc, .roundHole, .freeText, .stitchStartPoint, .offset, .fillet,
      .distance, .horizontalDistance, .verticalDistance, .segmentLength, .diameter, .radius:
      return true
    case .point, .centerLine, .horizontalCenterLine, .verticalCenterLine, .coincident, .horizontal,
      .vertical,
      .parallel, .perpendicular, .tangent, .equalLength, .angle, .symmetric, .pointOnLine,
      .lineLineDistance,
      .fixed, .measureDistance, .measureSegmentLength, .measureAngle, .measureRadius,
      .measureDiameter,
      .measureArcSweepAngle:
      return false
    }
  }

  var isDetailedTool: Bool {
    !isBasicTool
  }

  var idleMessage: String {
    switch self {
    case .select: return AppStrings.tr("tool.idle.select")
    case .point: return AppStrings.tr("tool.idle.point")
    case .line: return AppStrings.tr("tool.idle.line")
    case .circle: return AppStrings.tr("tool.idle.circle")
    case .roundHole: return AppStrings.tr("tool.idle.round_hole")
    case .stitchStartPoint: return AppStrings.tr("tool.idle.stitch_start_point")
    case .arc: return AppStrings.tr("tool.idle.arc")
    case .freeText: return AppStrings.tr("tool.idle.free_text")
    case .centerLine: return AppStrings.tr("tool.idle.center_line")
    case .horizontalCenterLine: return AppStrings.tr("tool.idle.horizontal_center_line")
    case .verticalCenterLine: return AppStrings.tr("tool.idle.vertical_center_line")
    case .offset: return AppStrings.tr("tool.idle.offset")
    case .fillet: return AppStrings.tr("tool.idle.fillet")
    case .coincident: return AppStrings.tr("tool.idle.coincident")
    case .horizontal: return AppStrings.tr("tool.idle.horizontal")
    case .vertical: return AppStrings.tr("tool.idle.vertical")
    case .parallel: return AppStrings.tr("tool.idle.parallel")
    case .perpendicular: return AppStrings.tr("tool.idle.perpendicular")
    case .tangent: return AppStrings.tr("tool.idle.tangent")
    case .equalLength: return AppStrings.tr("tool.idle.equal_length")
    case .angle: return AppStrings.tr("tool.idle.angle")
    case .symmetric: return AppStrings.tr("tool.idle.symmetric")
    case .pointOnLine: return AppStrings.tr("tool.idle.point_on_line")
    case .distance: return AppStrings.tr("tool.idle.distance")
    case .horizontalDistance: return AppStrings.tr("tool.idle.horizontal_distance")
    case .verticalDistance: return AppStrings.tr("tool.idle.vertical_distance")
    case .lineLineDistance: return AppStrings.tr("tool.idle.line_line_distance")
    case .segmentLength: return AppStrings.tr("tool.idle.segment_length")
    case .diameter: return AppStrings.tr("tool.idle.diameter")
    case .radius: return AppStrings.tr("tool.idle.radius")
    case .fixed: return AppStrings.tr("tool.idle.fixed")
    case .measureDistance: return AppStrings.tr("tool.idle.measure_distance")
    case .measureSegmentLength: return AppStrings.tr("tool.idle.measure_segment_length")
    case .measureAngle: return AppStrings.tr("tool.idle.measure_angle")
    case .measureRadius: return AppStrings.tr("tool.idle.measure_radius")
    case .measureDiameter: return AppStrings.tr("tool.idle.measure_diameter")
    case .measureArcSweepAngle: return AppStrings.tr("tool.idle.measure_arc_sweep_angle")
    }
  }

  var placementContinuationMessage: String {
    switch self {
    case .line: return AppStrings.tr("tool.continuation.line")
    case .circle: return AppStrings.tr("tool.continuation.circle")
    case .arc: return AppStrings.tr("tool.continuation.arc")
    case .centerLine: return AppStrings.tr("tool.continuation.center_line")
    case .horizontalCenterLine: return AppStrings.tr("tool.continuation.horizontal_center_line")
    case .verticalCenterLine: return AppStrings.tr("tool.continuation.vertical_center_line")
    default: return idleMessage
    }
  }

  var isConstraintTool: Bool {
    switch self {
    case .offset, .fillet, .coincident, .horizontal, .vertical, .parallel, .perpendicular, .tangent,
      .equalLength, .angle, .symmetric,
      .pointOnLine, .distance, .horizontalDistance, .verticalDistance, .lineLineDistance,
      .segmentLength, .diameter, .radius, .fixed:
      return true
    case .select, .point, .line, .circle, .roundHole, .stitchStartPoint, .arc, .freeText,
      .centerLine, .horizontalCenterLine, .verticalCenterLine,
      .measureDistance, .measureSegmentLength, .measureAngle, .measureRadius, .measureDiameter,
      .measureArcSweepAngle:
      return false
    }
  }

  var isMeasurementTool: Bool {
    switch self {
    case .measureDistance, .measureSegmentLength, .measureAngle, .measureRadius, .measureDiameter,
      .measureArcSweepAngle:
      return true
    default:
      return false
    }
  }

  var constraintKind: String {
    switch self {
    case .coincident: return "coincident"
    case .horizontal: return "horizontal"
    case .vertical: return "vertical"
    case .parallel: return "parallel"
    case .perpendicular: return "perpendicular"
    case .tangent: return "tangent"
    case .equalLength: return "equalSegmentLength"
    case .angle: return "angle"
    case .symmetric: return "symmetric"
    case .pointOnLine: return "pointOnLine"
    case .distance: return "distance"
    case .horizontalDistance: return "horizontalDistance"
    case .verticalDistance: return "verticalDistance"
    case .lineLineDistance: return "lineLineDistance"
    case .segmentLength: return "segmentLength"
    case .diameter: return "diameter"
    case .radius: return "radius"
    case .fixed: return "fixed"
    case .measureDistance: return "distance"
    case .measureSegmentLength: return "segmentLength"
    case .measureAngle: return "angle"
    case .measureRadius: return "radius"
    case .measureDiameter: return "diameter"
    case .measureArcSweepAngle: return "arcSweepAngle"
    case .offset: return "offsetCurve"
    case .fillet: return "fillet"
    case .select, .point, .line, .circle, .roundHole, .stitchStartPoint, .arc, .freeText,
      .centerLine, .horizontalCenterLine, .verticalCenterLine:
      return rawValue
    }
  }
}

enum CenterLineIconAxis: String {
  case diagonal
  case horizontal
  case vertical
}

enum CanvasToolIconKind: Equatable {
  case system(String)
  case point
  case line
  case arc
  case centerLine(CenterLineIconAxis)
  case fillet
  case coincident
  case horizontalConstraint
  case verticalConstraint
  case parallel
  case perpendicular
  case equalLength
  case angle
  case symmetric
  case distance
  case segmentLength
  case diameter
  case radius

  var fallbackSymbolName: String {
    switch self {
    case .system(let symbolName): return symbolName
    case .point: return "smallcircle.filled.circle"
    case .line: return "line.diagonal"
    case .arc: return "circle.bottomhalf.filled"
    case .centerLine(.diagonal): return "line.diagonal.arrow"
    case .centerLine(.horizontal): return "arrow.left.and.right"
    case .centerLine(.vertical): return "arrow.up.and.down"
    case .fillet: return "arc"
    case .coincident: return "scope"
    case .horizontalConstraint: return "arrow.left.and.right"
    case .verticalConstraint: return "arrow.up.and.down"
    case .parallel: return "equal"
    case .perpendicular: return "angle"
    case .equalLength: return "ruler"
    case .angle: return "angle"
    case .symmetric: return "arrow.left.and.right"
    case .distance: return "point.3.connected.trianglepath.dotted"
    case .segmentLength: return "ruler"
    case .diameter: return "diameter"
    case .radius: return "ruler"
    }
  }

  var identity: String {
    switch self {
    case .system(let symbolName): return "system:\(symbolName)"
    case .point: return "cad:point"
    case .line: return "cad:line"
    case .arc: return "cad:arc"
    case .centerLine(let axis): return "cad:centerLine:\(axis.rawValue)"
    case .fillet: return "cad:fillet"
    case .coincident: return "cad:coincident"
    case .horizontalConstraint: return "cad:constraint:horizontal"
    case .verticalConstraint: return "cad:constraint:vertical"
    case .parallel: return "cad:constraint:parallel"
    case .perpendicular: return "cad:constraint:perpendicular"
    case .equalLength: return "cad:constraint:equalLength"
    case .angle: return "cad:constraint:angle"
    case .symmetric: return "cad:constraint:symmetric"
    case .distance: return "cad:dimension:distance"
    case .segmentLength: return "cad:dimension:segmentLength"
    case .diameter: return "cad:dimension:diameter"
    case .radius: return "cad:dimension:radius"
    }
  }
}

enum CanvasViewMode: String, CaseIterable, Identifiable {
  case editDisplay
  case outputPreview

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .editDisplay: return AppStrings.tr("view_mode.edit_display")
    case .outputPreview: return AppStrings.tr("view_mode.output_preview")
    }
  }
}

enum ConstraintStatus: String, CaseIterable, Identifiable {
  case unknown
  case underConstrained
  case fullyConstrained
  case overConstrained
  case conflicting

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .unknown: return AppStrings.tr("constraint_status.unknown")
    case .underConstrained: return AppStrings.tr("constraint_status.under_constrained")
    case .fullyConstrained: return AppStrings.tr("constraint_status.fully_constrained")
    case .overConstrained: return AppStrings.tr("constraint_status.over_constrained")
    case .conflicting: return AppStrings.tr("constraint_status.conflicting")
    }
  }
}
