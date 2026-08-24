import CoreGraphics

struct CanvasHitTesting {
  let displayEntities: [CanvasEntity]
  let derivedElements: [ProjectDerivedElement]
  let selectedTool: CanvasTool
  let coordinateSpace: CanvasCoordinateSpace

  func entity(at point: CGPoint) -> CanvasEntity? {
    entity(at: point, preferring: [])
  }

  func entity(at point: CGPoint, preferring preferredEntityIDs: Set<String>) -> CanvasEntity? {
    let hits =
      displayEntities
      .reversed()
      .filter {
        hitRect(for: $0)
          .insetBy(
            dx: -CanvasMetrics.entityCandidatePaddingPx,
            dy: -CanvasMetrics.entityCandidatePaddingPx
          )
          .contains(point)
      }
    if selectedTool == .select,
      let preferred =
        hits
        .filter({ preferredEntityIDs.contains($0.id) })
        .min(by: { selectionHitRank(for: $0) < selectionHitRank(for: $1) })
    {
      return preferred
    }
    if selectedTool == .select {
      return hits.min { lhs, rhs in
        selectionHitRank(for: lhs) < selectionHitRank(for: rhs)
      }
    }
    return hits.first
  }

  func controlPointTarget(
    at point: CGPoint,
    includeEditHandles: Bool = false
  ) -> CanvasSelectionTarget? {
    let hits = controlPointTargets(at: point, includeEditHandles: includeEditHandles)
    if selectedTool == .select {
      return hits.min { lhs, rhs in
        selectionHitRank(for: lhs) < selectionHitRank(for: rhs)
      }
    }
    return hits.first
  }

  private func controlPointTargets(
    at point: CGPoint,
    includeEditHandles: Bool = false
  ) -> [CanvasSelectionTarget] {
    let hits =
      displayEntities
      .reversed()
      .flatMap { includeEditHandles ? $0.editPointTargets : $0.pointSelectionTargets }
      .filter { includeEditHandles || ($0.target.controlPoint?.isConstraintCompatible ?? true) }
      .filter { !includeEditHandles || $0.target.controlPoint != nil }
      .filter { item in
        let canvasPoint = coordinateSpace.canvasPoint(for: item.point)
        let halfSize = CanvasMetrics.controlPointHitSizePx / 2
        return CGRect(
          x: canvasPoint.x - halfSize, y: canvasPoint.y - halfSize,
          width: CanvasMetrics.controlPointHitSizePx,
          height: CanvasMetrics.controlPointHitSizePx
        )
        .contains(point)
      }
      .map(\.target)
    return hits
  }

  func lineTarget(at point: CGPoint) -> CanvasSelectionTarget? {
    let tolerance = CanvasMetrics.entityLineHitTolerancePx
    let hits =
      displayEntities
      .reversed()
      .flatMap(\.lineSelectionTargets)
      .filter { item in
        let start = coordinateSpace.canvasPoint(for: item.start)
        let end = coordinateSpace.canvasPoint(for: item.end)
        return Self.distanceFromCanvasPoint(point, toSegmentStart: start, end: end) <= tolerance
      }
    if selectedTool.prefersBaseLineTarget {
      return hits.min { lhs, rhs in
        selectionHitRank(for: lhs.target) < selectionHitRank(for: rhs.target)
      }?.target
    }
    return hits.first?.target
  }

  func preferredConstraintTarget(
    at point: CGPoint,
    pendingTargets: [CanvasSelectionTarget] = []
  ) -> CanvasSelectionTarget? {
    let spec = selectedTool.targetSelectionSpec
    let candidateLineTarget =
      spec.usesLineCandidate
      ? targetWithClickPoint(lineTarget(at: point), canvasPoint: point)
      : nil
    let pointTargets =
      spec.usesPointCandidate
      ? controlPointTargets(at: point)
      : []
    let candidatePointTarget = targetWithClickPoint(
      preferredPointTarget(for: selectedTool, from: pointTargets, pendingTargets: pendingTargets),
      canvasPoint: point
    )
    let entityTarget =
      spec.usesEntityCandidate
      ? targetWithClickPoint(entity(at: point)?.entitySelectionTarget, canvasPoint: point)
      : nil

    if selectedTool == .offset,
      let entityTarget,
      isFilletResolvedTarget(entityTarget)
    {
      return entityTarget
    }

    return CanvasSelectionPriority.preferredConstraintTarget(
      for: selectedTool,
      lineTarget: candidateLineTarget,
      pointTarget: candidatePointTarget,
      entityTarget: entityTarget,
      pendingTargets: pendingTargets
    )
  }

  private func preferredPointTarget(
    for tool: CanvasTool,
    from targets: [CanvasSelectionTarget],
    pendingTargets: [CanvasSelectionTarget]
  ) -> CanvasSelectionTarget? {
    guard let pendingTarget = pendingTargets.first else {
      return targets.first
    }
    if tool == .tangent {
      return targets.first(where: { candidate in
        tangentEndpointKindsCanPair(pendingTarget, candidate)
      }) ?? targets.first(where: { $0.wireTarget != pendingTarget.wireTarget }) ?? targets.first
    }
    return targets.first(where: { $0.wireTarget != pendingTarget.wireTarget }) ?? targets.first
  }

  private func tangentEndpointKindsCanPair(
    _ first: CanvasSelectionTarget,
    _ second: CanvasSelectionTarget
  ) -> Bool {
    guard first.entityID != second.entityID else {
      return false
    }
    return (first.isLineEndpointTarget && second.isArcEndpointTarget)
      || (first.isArcEndpointTarget && second.isLineEndpointTarget)
  }

  func isValidConstraintTarget(
    _ target: CanvasSelectionTarget,
    pendingTargetCount: Int
  ) -> Bool {
    guard let entity = displayEntities.first(where: { $0.id == target.entityID }) else {
      return false
    }
    return selectedTool.acceptsSelectionTarget(
      target, entity: entity, pendingTargetCount: pendingTargetCount)
  }

  func hitRect(for entity: CanvasEntity) -> CGRect {
    switch entity.geometry {
    case .point(let point):
      let canvasPoint = coordinateSpace.canvasPoint(for: point)
      return CGRect(x: canvasPoint.x - 6, y: canvasPoint.y - 6, width: 12, height: 12)

    case .line(let start, let end, _):
      let startPoint = coordinateSpace.canvasPoint(for: start)
      let endPoint = coordinateSpace.canvasPoint(for: end)
      return CGRect(
        x: min(startPoint.x, endPoint.x),
        y: min(startPoint.y, endPoint.y),
        width: abs(endPoint.x - startPoint.x),
        height: abs(endPoint.y - startPoint.y)
      )

    case .circle(let center, let radiusMM), .arc(let center, let radiusMM, _, _):
      return rect(forCircleAt: center, radiusMM: radiusMM)

    case .unsupported:
      return .zero
    }
  }

  func isFilletResolvedEntity(_ entity: CanvasEntity) -> Bool {
    guard let derivedElementID = entity.derivedElementID else {
      return false
    }
    return derivedElements.contains { $0.id == derivedElementID && $0.kind == .fillet }
  }

  private func targetWithClickPoint(
    _ target: CanvasSelectionTarget?,
    canvasPoint: CGPoint
  ) -> CanvasSelectionTarget? {
    guard let target else {
      return nil
    }
    if target.isPointTarget {
      return target
    }
    return CanvasSelectionTarget(
      entityID: target.entityID,
      entityLabel: target.entityLabel,
      entityKind: target.entityKind,
      controlPoint: target.controlPoint,
      point: coordinateSpace.modelPoint(for: canvasPoint)
    )
  }

  private func selectionHitRank(for target: CanvasSelectionTarget) -> Int {
    guard let entity = displayEntities.first(where: { $0.id == target.entityID }) else {
      return 1
    }
    return selectionHitRank(for: entity)
  }

  private func selectionHitRank(for entity: CanvasEntity) -> Int {
    entity.derivedElementID == nil ? 0 : 1
  }

  private func isFilletResolvedTarget(_ target: CanvasSelectionTarget) -> Bool {
    guard let entity = displayEntities.first(where: { $0.id == target.entityID }) else {
      return false
    }
    return isFilletResolvedEntity(entity)
  }

  private func rect(forCircleAt center: ModelPoint, radiusMM: Double) -> CGRect {
    let centerPoint = coordinateSpace.canvasPoint(for: center)
    let radius = radiusMM * coordinateSpace.scale
    return CGRect(
      x: centerPoint.x - radius,
      y: centerPoint.y - radius,
      width: radius * 2,
      height: radius * 2
    )
  }

  static func distanceFromCanvasPoint(
    _ point: CGPoint,
    toSegmentStart start: CGPoint,
    end: CGPoint
  ) -> CGFloat {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let lengthSquared = dx * dx + dy * dy
    guard lengthSquared > 0 else {
      return hypot(point.x - start.x, point.y - start.y)
    }
    let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
    let projection = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
    return hypot(point.x - projection.x, point.y - projection.y)
  }
}

extension CanvasTool {
  fileprivate var prefersBaseLineTarget: Bool {
    targetSelectionSpec.selectionPriority == .lineFirst
      || targetSelectionSpec.selectionPriority == .lineThenPoint
  }
}
