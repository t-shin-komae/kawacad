import Foundation

enum CanvasMarqueeSelectionMode: Equatable {
  case contained
  case crossing

  init(startPoint: CGPoint, currentPoint: CGPoint) {
    self = currentPoint.x >= startPoint.x ? .contained : .crossing
  }
}

struct CanvasMarqueeSelection {
  let coordinateSpace: CanvasCoordinateSpace

  func candidateIDs(
    from entities: [CanvasEntity],
    in canvasRect: CGRect,
    mode: CanvasMarqueeSelectionMode
  ) -> Set<String> {
    let rect = ModelRect(canvasRect: canvasRect, coordinateSpace: coordinateSpace)
    return Set(
      entities.filter { entity in
        switch mode {
        case .contained:
          contains(entity.geometry, in: rect)
        case .crossing:
          intersects(entity.geometry, with: rect)
        }
      }.map(\.id))
  }

  private func contains(_ geometry: CanvasGeometry, in rect: ModelRect) -> Bool {
    switch geometry {
    case .point(let point):
      rect.contains(point)
    case .line(let start, let end, _):
      rect.contains(start) && rect.contains(end)
    case .circle(let center, let radiusMM):
      rect.contains(ModelPoint(xMM: center.xMM - radiusMM, yMM: center.yMM - radiusMM))
        && rect.contains(ModelPoint(xMM: center.xMM + radiusMM, yMM: center.yMM + radiusMM))
    case .arc(let center, let radiusMM, let startAngleRad, let sweepAngleRad):
      arcExtrema(
        center: center,
        radiusMM: radiusMM,
        startAngleRad: startAngleRad,
        sweepAngleRad: sweepAngleRad
      ).allSatisfy(rect.contains)
    case .unsupported:
      false
    }
  }

  private func intersects(_ geometry: CanvasGeometry, with rect: ModelRect) -> Bool {
    switch geometry {
    case .point(let point):
      rect.contains(point)
    case .line(let start, let end, _):
      rect.intersectsSegment(from: start, to: end)
    case .circle(let center, let radiusMM):
      circleIntersectsRect(center: center, radiusMM: radiusMM, rect: rect)
    case .arc(let center, let radiusMM, let startAngleRad, let sweepAngleRad):
      arcIntersectsRect(
        center: center,
        radiusMM: radiusMM,
        startAngleRad: startAngleRad,
        sweepAngleRad: sweepAngleRad,
        rect: rect
      )
    case .unsupported:
      false
    }
  }

  private func circleIntersectsRect(center: ModelPoint, radiusMM: Double, rect: ModelRect) -> Bool {
    let nearestX = min(max(center.xMM, rect.minX), rect.maxX)
    let nearestY = min(max(center.yMM, rect.minY), rect.maxY)
    let minimumDistance = hypot(center.xMM - nearestX, center.yMM - nearestY)
    let maximumDistance =
      rect.corners
      .map { hypot(center.xMM - $0.xMM, center.yMM - $0.yMM) }
      .max() ?? 0
    return minimumDistance <= radiusMM && radiusMM <= maximumDistance
  }

  private func arcIntersectsRect(
    center: ModelPoint,
    radiusMM: Double,
    startAngleRad: Double,
    sweepAngleRad: Double,
    rect: ModelRect
  ) -> Bool {
    let endpoints = arcExtrema(
      center: center,
      radiusMM: radiusMM,
      startAngleRad: startAngleRad,
      sweepAngleRad: sweepAngleRad
    ).prefix(2)
    if endpoints.contains(where: rect.contains) {
      return true
    }

    return rectangleIntersectionAngles(center: center, radiusMM: radiusMM, rect: rect)
      .contains { angle in
        angleIsOnArc(angle, startAngleRad: startAngleRad, sweepAngleRad: sweepAngleRad)
      }
  }

  private func arcExtrema(
    center: ModelPoint,
    radiusMM: Double,
    startAngleRad: Double,
    sweepAngleRad: Double
  ) -> [ModelPoint] {
    let endpointAngles = [startAngleRad, startAngleRad + sweepAngleRad]
    let extremaAngles = [0.0, .pi / 2, .pi, 3 * .pi / 2]
      .filter { angleIsOnArc($0, startAngleRad: startAngleRad, sweepAngleRad: sweepAngleRad) }
    return (endpointAngles + extremaAngles).map { angle in
      ModelPoint(
        xMM: center.xMM + radiusMM * cos(angle),
        yMM: center.yMM + radiusMM * sin(angle)
      )
    }
  }

  private func rectangleIntersectionAngles(
    center: ModelPoint,
    radiusMM: Double,
    rect: ModelRect
  ) -> [Double] {
    guard radiusMM > 0 else { return [] }
    var angles: [Double] = []
    for x in [rect.minX, rect.maxX] {
      let ratio = (x - center.xMM) / radiusMM
      guard abs(ratio) <= 1 else { continue }
      let first = acos(ratio)
      for angle in [first, 2 * .pi - first] {
        let y = center.yMM + radiusMM * sin(angle)
        if y >= rect.minY && y <= rect.maxY {
          angles.append(angle)
        }
      }
    }
    for y in [rect.minY, rect.maxY] {
      let ratio = (y - center.yMM) / radiusMM
      guard abs(ratio) <= 1 else { continue }
      let first = asin(ratio)
      for angle in [first, .pi - first] {
        let normalized = normalizedAngle(angle)
        let x = center.xMM + radiusMM * cos(normalized)
        if x >= rect.minX && x <= rect.maxX {
          angles.append(normalized)
        }
      }
    }
    return angles
  }

  private func angleIsOnArc(
    _ angle: Double,
    startAngleRad: Double,
    sweepAngleRad: Double
  ) -> Bool {
    let fullTurn = 2 * Double.pi
    if abs(sweepAngleRad) >= fullTurn { return true }
    if sweepAngleRad >= 0 {
      return normalizedAngle(angle - startAngleRad) <= sweepAngleRad + 0.000_000_1
    }
    return normalizedAngle(startAngleRad - angle) <= -sweepAngleRad + 0.000_000_1
  }

  private func normalizedAngle(_ angle: Double) -> Double {
    let fullTurn = 2 * Double.pi
    let value = angle.truncatingRemainder(dividingBy: fullTurn)
    return value < 0 ? value + fullTurn : value
  }
}

private struct ModelRect {
  let minX: Double
  let maxX: Double
  let minY: Double
  let maxY: Double

  init(canvasRect: CGRect, coordinateSpace: CanvasCoordinateSpace) {
    let first = coordinateSpace.modelPoint(for: canvasRect.origin)
    let second = coordinateSpace.modelPoint(for: CGPoint(x: canvasRect.maxX, y: canvasRect.maxY))
    minX = min(first.xMM, second.xMM)
    maxX = max(first.xMM, second.xMM)
    minY = min(first.yMM, second.yMM)
    maxY = max(first.yMM, second.yMM)
  }

  var corners: [ModelPoint] {
    [
      ModelPoint(xMM: minX, yMM: minY),
      ModelPoint(xMM: minX, yMM: maxY),
      ModelPoint(xMM: maxX, yMM: minY),
      ModelPoint(xMM: maxX, yMM: maxY),
    ]
  }

  func contains(_ point: ModelPoint) -> Bool {
    point.xMM >= minX && point.xMM <= maxX && point.yMM >= minY && point.yMM <= maxY
  }

  func intersectsSegment(from start: ModelPoint, to end: ModelPoint) -> Bool {
    if contains(start) || contains(end) { return true }
    let edges = [
      (corners[0], corners[1]), (corners[1], corners[3]), (corners[3], corners[2]),
      (corners[2], corners[0]),
    ]
    return edges.contains { segmentsIntersect(start, end, $0.0, $0.1) }
  }

  private func segmentsIntersect(
    _ start: ModelPoint,
    _ end: ModelPoint,
    _ edgeStart: ModelPoint,
    _ edgeEnd: ModelPoint
  ) -> Bool {
    func orientation(_ first: ModelPoint, _ second: ModelPoint, _ third: ModelPoint) -> Double {
      (second.xMM - first.xMM) * (third.yMM - first.yMM)
        - (second.yMM - first.yMM) * (third.xMM - first.xMM)
    }
    let first = orientation(start, end, edgeStart)
    let second = orientation(start, end, edgeEnd)
    let third = orientation(edgeStart, edgeEnd, start)
    let fourth = orientation(edgeStart, edgeEnd, end)
    let epsilon = 0.000_000_1
    func liesOnSegment(_ point: ModelPoint, from start: ModelPoint, to end: ModelPoint) -> Bool {
      point.xMM >= min(start.xMM, end.xMM) - epsilon
        && point.xMM <= max(start.xMM, end.xMM) + epsilon
        && point.yMM >= min(start.yMM, end.yMM) - epsilon
        && point.yMM <= max(start.yMM, end.yMM) + epsilon
    }
    if abs(first) <= epsilon, liesOnSegment(edgeStart, from: start, to: end) { return true }
    if abs(second) <= epsilon, liesOnSegment(edgeEnd, from: start, to: end) { return true }
    if abs(third) <= epsilon, liesOnSegment(start, from: edgeStart, to: edgeEnd) { return true }
    if abs(fourth) <= epsilon, liesOnSegment(end, from: edgeStart, to: edgeEnd) { return true }
    return (first > 0) != (second > 0) && (third > 0) != (fourth > 0)
  }
}
