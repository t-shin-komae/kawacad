import Foundation

enum CanvasTargetSelectionPriority {
  case pointFirst
  case lineFirst
  case entityOnly
  case lineThenPoint
  case pointThenLine
}

enum CanvasTargetKind: Hashable {
  case point
  case line
  case centerLine
  case circle
  case arc
  case entity
}

extension CanvasTargetKind {
  func matches(_ target: CanvasSelectionTarget) -> Bool {
    switch self {
    case .point:
      return target.isPointTarget
    case .line:
      return target.controlPoint == nil && target.entityKind == .lineSegment
    case .centerLine:
      return target.controlPoint == nil && target.entityKind == .centerLine
    case .circle:
      return target.controlPoint == nil && target.entityKind == .circle
    case .arc:
      return target.controlPoint == nil && target.entityKind == .arc
    case .entity:
      return target.controlPoint == nil
    }
  }
}

enum CanvasDerivedTargetPolicy {
  case reject
  case allow
  case normalizeFilletLineToSource
}

struct CanvasTargetSelectionSpec {
  let selectionPriority: CanvasTargetSelectionPriority
  let allowedTargetKinds: Set<CanvasTargetKind>
  let derivedTargetPolicy: CanvasDerivedTargetPolicy

  var usesPointCandidate: Bool {
    allowedTargetKinds.contains(.point)
  }

  var usesLineCandidate: Bool {
    allowedTargetKinds.contains(.line) || allowedTargetKinds.contains(.centerLine)
  }

  var usesEntityCandidate: Bool {
    selectionPriority == .entityOnly
      || allowedTargetKinds.contains(.circle)
      || allowedTargetKinds.contains(.arc)
      || allowedTargetKinds.contains(.entity)
  }

  func preferredTarget(
    lineTarget: CanvasSelectionTarget?,
    pointTarget: CanvasSelectionTarget?,
    entityTarget: CanvasSelectionTarget?
  ) -> CanvasSelectionTarget? {
    switch selectionPriority {
    case .pointFirst:
      return pointTarget ?? entityTarget
    case .lineFirst:
      return lineTarget ?? entityTarget
    case .entityOnly:
      return entityTarget
    case .lineThenPoint:
      return lineTarget ?? pointTarget ?? entityTarget
    case .pointThenLine:
      return pointTarget ?? lineTarget ?? entityTarget
    }
  }

  func accepts(_ target: CanvasSelectionTarget) -> Bool {
    allowedTargetKinds.contains { kind in
      kind.matches(target)
    }
  }
}

extension CanvasTool {
  var targetSelectionSpec: CanvasTargetSelectionSpec {
    switch self {
    case .offset:
      return .lineThenPoint([.line, .centerLine, .circle, .arc], derived: .allow)
    case .fillet:
      return .lineFirst([.line, .centerLine], derived: .allow)
    case .horizontal, .vertical:
      return .lineThenPoint([.line, .centerLine, .point])
    case .distance:
      return .pointThenLine([.line, .centerLine, .point])
    case .horizontalDistance, .verticalDistance:
      return .pointFirst([.point])
    case .pointOnLine:
      return .pointFirst([.point, .line, .centerLine])
    case .segmentLength, .lineLineDistance, .parallel, .perpendicular, .equalLength:
      return .lineFirst([.line, .centerLine])
    case .tangent:
      return .pointFirst([.point])
    case .angle:
      return .lineFirst([.line, .centerLine, .arc])
    case .coincident, .fixed:
      return .pointFirst([.point])
    case .symmetric:
      return .pointFirst([.point, .line, .centerLine])
    case .diameter:
      return .entityOnly([.circle])
    case .radius:
      return .pointFirst([.point, .circle, .arc])
    case .measureDistance:
      return .pointFirst([.point], derived: .normalizeFilletLineToSource)
    case .measureSegmentLength:
      return .lineFirst([.line, .centerLine], derived: .normalizeFilletLineToSource)
    case .measureAngle:
      return .lineFirst([.line, .centerLine], derived: .normalizeFilletLineToSource)
    case .measureRadius, .measureDiameter:
      return .entityOnly([.circle, .arc], derived: .normalizeFilletLineToSource)
    case .measureArcSweepAngle:
      return .entityOnly([.arc], derived: .normalizeFilletLineToSource)
    default:
      return .pointFirst([.point, .entity])
    }
  }

  func acceptsSelectionTarget(
    _ target: CanvasSelectionTarget,
    entity: CanvasEntity,
    pendingTargetCount: Int
  ) -> Bool {
    let spec = targetSelectionSpec
    switch self {
    case .symmetric:
      return pendingTargetCount < 2
        ? CanvasTargetKind.point.matches(target)
        : CanvasTargetKind.line.matches(target) || CanvasTargetKind.centerLine.matches(target)
    case .diameter:
      return spec.accepts(target) && entity.supportsDiameterConstraint
    case .radius:
      return spec.accepts(target) && entity.supportsRadiusConstraint
    case .measureRadius:
      return spec.accepts(target) && entity.supportsRadiusConstraint
    case .measureDiameter:
      return spec.accepts(target) && entity.supportsDiameterMeasurement
    case .measureArcSweepAngle:
      return spec.accepts(target) && entity.kind == .arc
    default:
      return spec.accepts(target)
    }
  }
}

extension CanvasTargetSelectionSpec {
  fileprivate static func pointFirst(
    _ kinds: Set<CanvasTargetKind>,
    derived: CanvasDerivedTargetPolicy = .reject
  ) -> CanvasTargetSelectionSpec {
    CanvasTargetSelectionSpec(
      selectionPriority: .pointFirst,
      allowedTargetKinds: kinds,
      derivedTargetPolicy: derived
    )
  }

  fileprivate static func lineFirst(
    _ kinds: Set<CanvasTargetKind>,
    derived: CanvasDerivedTargetPolicy = .reject
  ) -> CanvasTargetSelectionSpec {
    CanvasTargetSelectionSpec(
      selectionPriority: .lineFirst,
      allowedTargetKinds: kinds,
      derivedTargetPolicy: derived
    )
  }

  fileprivate static func entityOnly(
    _ kinds: Set<CanvasTargetKind>,
    derived: CanvasDerivedTargetPolicy = .reject
  ) -> CanvasTargetSelectionSpec {
    CanvasTargetSelectionSpec(
      selectionPriority: .entityOnly,
      allowedTargetKinds: kinds,
      derivedTargetPolicy: derived
    )
  }

  fileprivate static func lineThenPoint(
    _ kinds: Set<CanvasTargetKind>,
    derived: CanvasDerivedTargetPolicy = .reject
  ) -> CanvasTargetSelectionSpec {
    CanvasTargetSelectionSpec(
      selectionPriority: .lineThenPoint,
      allowedTargetKinds: kinds,
      derivedTargetPolicy: derived
    )
  }

  fileprivate static func pointThenLine(
    _ kinds: Set<CanvasTargetKind>,
    derived: CanvasDerivedTargetPolicy = .reject
  ) -> CanvasTargetSelectionSpec {
    CanvasTargetSelectionSpec(
      selectionPriority: .pointThenLine,
      allowedTargetKinds: kinds,
      derivedTargetPolicy: derived
    )
  }
}
