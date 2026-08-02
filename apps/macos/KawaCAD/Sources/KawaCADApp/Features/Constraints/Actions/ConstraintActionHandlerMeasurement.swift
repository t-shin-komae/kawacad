import Foundation

/// Measurement target and annotation actions.
extension ConstraintActionHandler {
  func handleMeasurementTargetSelection(
    _ target: CanvasSelectionTarget,
    entity: CanvasEntity
  ) {
    switch canvasPresentation.selectedTool {
    case .measureDistance:
      guard
        let distanceTarget = ConstraintTargetPreflight.pointTarget(
          from: target, fallbackEntity: entity)
      else {
        statusMessage = AppStrings.tr("status.dimension_point_target_not_supported", entity.label)
        return
      }
      collectConstraintTarget(distanceTarget, requiredCount: 2) { targets in
        let targetPayloads = targets.map(\.constraintJSON)
        guard
          let result = coreConstraintPreflightResult(
            kind: canvasPresentation.selectedTool.constraintKind,
            targets: targetPayloads
          )
        else {
          statusMessage = AppStrings.tr("status.dimension_point_target_not_supported", entity.label)
          return
        }
        applyMeasurementAnnotation(
          kind: result.kind,
          targets: CanvasInteractionFeature.constraintTargetPayloads(
            from: result, fallback: targetPayloads)
        )
      }

    case .measureSegmentLength:
      guard target.isLineTarget else {
        statusMessage = AppStrings.tr(
          "status.segment_length_constraint_not_supported", entity.label)
        return
      }
      applyMeasurementAnnotation(
        kind: canvasPresentation.selectedTool.constraintKind, targets: [target.constraintJSON])

    case .measureAngle:
      guard target.isLineTarget else {
        statusMessage = AppStrings.tr("status.line_constraint_target_not_supported", entity.label)
        return
      }
      collectConstraintTarget(target, requiredCount: 2) { targets in
        let targetPayloads = targets.map(\.constraintJSON)
        guard
          let result = coreConstraintPreflightResult(
            kind: "angle",
            targets: targetPayloads
          ), result.value != nil
        else {
          statusMessage = AppStrings.tr("status.angle_requires_two_distinct_lines")
          return
        }
        applyMeasurementAnnotation(
          kind: result.kind,
          targets: CanvasInteractionFeature.constraintTargetPayloads(
            from: result, fallback: targetPayloads)
        )
      }

    case .measureRadius:
      guard entity.supportsRadiusConstraint else {
        statusMessage = AppStrings.tr("status.radius_constraint_not_supported", entity.label)
        return
      }
      applyMeasurementAnnotation(
        kind: canvasPresentation.selectedTool.constraintKind,
        targets: [entity.entitySelectionTarget.constraintJSON])

    case .measureDiameter:
      guard entity.supportsDiameterMeasurement else {
        statusMessage = AppStrings.tr("status.diameter_constraint_not_supported", entity.label)
        return
      }
      applyMeasurementAnnotation(
        kind: canvasPresentation.selectedTool.constraintKind,
        targets: [entity.entitySelectionTarget.constraintJSON])

    case .measureArcSweepAngle:
      guard case .arc = entity.geometry else {
        statusMessage = AppStrings.tr("status.angle_constraint_not_supported", entity.label)
        return
      }
      applyMeasurementAnnotation(
        kind: canvasPresentation.selectedTool.constraintKind,
        targets: [entity.entitySelectionTarget.constraintJSON])

    default:
      break
    }
  }

  func applyMeasurementAnnotation(kind: String, targets: [[String: Any]]) {
    let request = commandFactory.makeAddMeasurementAnnotationCommand(
      kind: kind,
      displayName: canvasPresentation.selectedTool.displayName,
      targets: targets
    )
    executeDocumentCommand(request)
  }

}
