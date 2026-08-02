import Foundation

enum CanvasSelectionPriority {
  static func preferredEntitySelectionTarget(
    controlPointTarget: CanvasSelectionTarget?,
    entityTarget: CanvasSelectionTarget?
  ) -> CanvasSelectionTarget? {
    controlPointTarget ?? entityTarget
  }

  static func preferredConstraintTarget(
    for tool: CanvasTool,
    lineTarget: CanvasSelectionTarget?,
    pointTarget: CanvasSelectionTarget?,
    entityTarget: CanvasSelectionTarget?,
    pendingTargets: [CanvasSelectionTarget] = []
  ) -> CanvasSelectionTarget? {
    if tool == .pointOnLine {
      let hasPendingPoint = pendingTargets.contains(where: \.isPointTarget)
      let hasPendingLine = pendingTargets.contains(where: \.isLineTarget)
      if hasPendingPoint && !hasPendingLine {
        return lineTarget ?? pointTarget ?? entityTarget
      }
      if hasPendingLine && !hasPendingPoint {
        return pointTarget ?? lineTarget ?? entityTarget
      }
    }
    if tool == .symmetric, pendingTargets.count >= 2 {
      return lineTarget ?? pointTarget ?? entityTarget
    }
    return tool.targetSelectionSpec.preferredTarget(
      lineTarget: lineTarget,
      pointTarget: pointTarget,
      entityTarget: entityTarget
    )
  }
}
