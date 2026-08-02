import Foundation

func radiansToDegrees(_ radians: Double) -> Double {
  radians * 180.0 / .pi
}

func degreesToRadians(_ degrees: Double) -> Double {
  degrees * .pi / 180.0
}

func angleRadians(from center: ModelPoint, to point: ModelPoint) -> Double {
  atan2(point.yMM - center.yMM, point.xMM - center.xMM)
}

func normalizedSignedSweepAngle(startAngleRad: Double, endAngleRad: Double) -> Double {
  var sweep = endAngleRad - startAngleRad
  while sweep <= -.pi {
    sweep += .pi * 2.0
  }
  while sweep > .pi {
    sweep -= .pi * 2.0
  }
  return sweep
}

func canvasArcPathParameters(startAngleRad: Double, sweepAngleRad: Double) -> (
  startAngleDeg: Double,
  endAngleDeg: Double,
  clockwise: Bool
) {
  (
    startAngleDeg: -radiansToDegrees(startAngleRad),
    endAngleDeg: -radiansToDegrees(startAngleRad + sweepAngleRad),
    clockwise: sweepAngleRad > 0
  )
}
