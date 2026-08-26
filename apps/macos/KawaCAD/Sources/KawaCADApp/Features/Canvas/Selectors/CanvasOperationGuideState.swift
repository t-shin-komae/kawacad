import Foundation

/// Chooses the short, fixed-position instruction shown above the canvas.
enum CanvasOperationGuideState {
  static func instruction(
    selectedTool: CanvasTool,
    viewMode: CanvasViewMode,
    isSettingPartOrigin: Bool,
    filletDraftEntityCount: Int,
    filletDraftClosed: Bool,
    draftPointCount: Int,
    hasArcStartPoint: Bool,
    pendingConstraintTargetCount: Int
  ) -> String? {
    guard viewMode == .editDisplay else { return nil }

    let interactionInProgress =
      isSettingPartOrigin
      || filletDraftEntityCount > 0
      || draftPointCount > 0
      || hasArcStartPoint
      || pendingConstraintTargetCount > 0
    guard selectedTool != .select || interactionInProgress else { return nil }

    if isSettingPartOrigin {
      return AppStrings.tr("inspector.set_part_origin_on_canvas")
    }
    if filletDraftEntityCount > 0 {
      return AppStrings.tr(
        "accessibility.canvas.interaction.fillet_draft",
        filletDraftEntityCount,
        max(0, filletDraftEntityCount - (filletDraftClosed ? 0 : 1)),
        filletDraftClosed
          ? AppStrings.tr("fillet.draft.closed") : AppStrings.tr("fillet.draft.open")
      )
    }
    if hasArcStartPoint {
      return AppStrings.tr("accessibility.canvas.interaction.arc_end")
    }
    if draftPointCount > 0 {
      return AppStrings.tr("accessibility.canvas.interaction.next_point")
    }
    if pendingConstraintTargetCount > 0 {
      return AppStrings.tr("accessibility.canvas.interaction.constraint_target")
    }
    return selectedTool.idleMessage
  }
}
