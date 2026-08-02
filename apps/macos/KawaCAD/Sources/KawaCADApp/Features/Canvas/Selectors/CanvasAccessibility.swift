import Foundation

/// Pure accessibility value formatting for the canvas.
enum CanvasAccessibility {
  static func value(
    selectedTool: CanvasTool,
    viewMode: CanvasViewMode,
    entityCount: Int,
    selectedEntityCount: Int,
    pendingConstraintTargetCount: Int,
    interactionDescription: String
  ) -> String {
    AppStrings.tr(
      "accessibility.canvas.value",
      selectedTool.displayName,
      viewMode.displayName,
      entityCount,
      selectedEntityCount,
      pendingConstraintTargetCount,
      interactionDescription
    )
  }
}
