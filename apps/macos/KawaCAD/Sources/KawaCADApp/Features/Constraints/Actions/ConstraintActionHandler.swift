import Foundation

/// Constraint target collection, preflight, and application actions.
extension ConstraintActionHandler {
  func handleConstraintTargetSelection(_ target: CanvasSelectionTarget?) {
    guard let target,
      let entity = entities.first(where: { $0.id == target.entityID })
    else {
      canvasPresentation.setPendingConstraintTargets([])
      canvasPresentation.setPrimaryEntityID(nil)
      canvasPresentation.setEntityIDs([])
      statusMessage = CanvasInteractionFeature.initialConstraintSelectionMessage(
        for: canvasPresentation.selectedTool)
      return
    }

    if canvasPresentation.selectedTool.isMeasurementTool {
      let selection = CanvasInteractionFeature.persistentMeasurementSelection(
        target: target,
        entity: entity,
        entities: entities
      )
      let measurementTarget = selection.target
      let measurementEntity = selection.entity
      canvasPresentation.setPrimaryEntityID(measurementTarget.entityID)
      canvasPresentation.setEntityIDs([measurementTarget.entityID])
      canvasPresentation.setConstraintID(nil)
      guard measurementEntity.derivedElementID == nil else {
        statusMessage = AppStrings.tr("status.derived_measurement_target_not_supported")
        return
      }
      handleMeasurementTargetSelection(measurementTarget, entity: measurementEntity)
      return
    }

    let previousSelectedEntityIDs = selectedEntityIDs
    canvasPresentation.setPrimaryEntityID(target.entityID)
    canvasPresentation.setEntityIDs([target.entityID])
    canvasPresentation.setConstraintID(nil)
    let selectedDerivedElement = WorkspaceViewStateFactory.selectedDerivedElement(
      selectedEntities: selectedEntities,
      derivedElements: derivedElements
    )
    let allowsDerivedTarget = ConstraintTargetPreflight.allowsDerivedTarget(
      tool: canvasPresentation.selectedTool,
      entity: entity,
      selectedDerivedElement: selectedDerivedElement
    )
    if !allowsDerivedTarget, entity.derivedElementID != nil {
      presentConstraintSelectionWarning(
        AppStrings.tr("status.derived_constraint_target_not_supported"))
      return
    }

    switch canvasPresentation.selectedTool {
    case .measureDistance:
      handleMeasurementTargetSelection(target, entity: entity)

    case .measureSegmentLength:
      handleMeasurementTargetSelection(target, entity: entity)

    case .measureAngle:
      handleMeasurementTargetSelection(target, entity: entity)

    case .measureRadius:
      handleMeasurementTargetSelection(target, entity: entity)

    case .measureDiameter:
      handleMeasurementTargetSelection(target, entity: entity)

    case .measureArcSweepAngle:
      handleMeasurementTargetSelection(target, entity: entity)

    case .offset:
      guard ConstraintTargetPreflight.supportsOffsetTarget(target) else {
        statusMessage = AppStrings.tr("status.offset_target_not_supported", entity.label)
        return
      }
      let selectedSourceIDs =
        CanvasInteractionFeature.shouldPreserveOffsetSelection(
          selectedEntityIDs: previousSelectedEntityIDs,
          hitEntity: entity,
          derivedElements: derivedElements
        )
        ? previousSelectedEntityIDs
        : [target.entityID]
      let options = offsetSourceOptions(
        for: entity,
        selectedSourceIDs: selectedSourceIDs,
        clickPoint: target.point
      )
      if let defaultOption = options.first {
        beginOffsetValueEntry(
          sourceEntityIDs: defaultOption.sourceEntityIDs,
          sourceResolvedEntityIDs: defaultOption.sourceResolvedEntityIDs,
          direction: defaultOption.direction,
          scopeOptions: options
        )
      }

    case .fillet:
      guard ConstraintTargetPreflight.supportsFilletTarget(target) else {
        statusMessage = AppStrings.tr("status.fillet_target_not_supported", entity.label)
        return
      }
      if canvasPresentation.pendingConstraintValueDraft?.kind != "fillet",
        previousSelectedEntityIDs.count >= 2
      {
        beginFilletValueEntry(
          sourceEntityIDs: filletSourceEntityIDs(from: previousSelectedEntityIDs))
        if let draft = canvasPresentation.pendingConstraintValueDraft,
          draft.kind == "fillet"
        {
          canvasPresentation.setEntityIDs(Set(draft.filletSourceEntityIDs))
          canvasPresentation.setPrimaryEntityID(draft.filletSourceEntityIDs.first)
        }
        return
      }
      let startingSources =
        canvasPresentation.pendingConstraintValueDraft?.kind == "fillet"
        ? canvasPresentation.pendingConstraintValueDraft!.filletSourceEntityIDs
        : []
      updateFilletDraft(with: target, startingSources: startingSources)

    case .horizontal, .vertical:
      if target.isLineTarget {
        applyConstraint(
          kind: canvasPresentation.selectedTool.constraintKind, targets: [target.constraintJSON])
      } else if let pointTarget = ConstraintTargetPreflight.pointTarget(
        from: target, fallbackEntity: entity)
      {
        collectConstraintTarget(pointTarget, requiredCount: 2) { targets in
          applyConstraintUsingCoreNormalization(
            kind: canvasPresentation.selectedTool.constraintKind,
            targets: targets.map(\.constraintJSON)
          )
        }
      } else {
        statusMessage = AppStrings.tr(
          "status.constraint_entity_not_supported", entity.label,
          canvasPresentation.selectedTool.displayName)
      }

    case .fixed:
      guard
        let pointTarget = ConstraintTargetPreflight.pointTarget(
          from: target, fallbackEntity: entity)
      else {
        statusMessage = AppStrings.tr("status.fixed_constraint_entity_not_supported", entity.label)
        return
      }
      applyConstraintUsingCoreNormalization(
        kind: canvasPresentation.selectedTool.constraintKind,
        targets: [pointTarget.constraintJSON]
      )

    case .distance:
      guard
        let distanceTarget = ConstraintTargetPreflight.pointOrLineTarget(
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
          ),
          let value = CanvasInteractionFeature.fixedMillimeterValue(result)
        else {
          statusMessage = AppStrings.tr("status.distance_constraint_target_required")
          return
        }
        beginConstraintValueEntry(
          kind: result.kind,
          title: canvasPresentation.selectedTool.displayName,
          prompt: AppStrings.tr(
            "status.specify_constraint", canvasPresentation.selectedTool.displayName),
          targets: CanvasInteractionFeature.constraintTargetPayloads(
            from: result, fallback: targetPayloads),
          initialValueMM: value
        )
      }

    case .horizontalDistance, .verticalDistance:
      guard
        let pointTarget = ConstraintTargetPreflight.pointTarget(
          from: target, fallbackEntity: entity)
      else {
        statusMessage = AppStrings.tr("status.dimension_point_target_not_supported", entity.label)
        return
      }
      collectConstraintTarget(pointTarget, requiredCount: 2) { targets in
        let targetPayloads = targets.map(\.constraintJSON)
        guard
          let result = coreConstraintPreflightResult(
            kind: canvasPresentation.selectedTool.constraintKind,
            targets: targetPayloads
          ),
          let value = CanvasInteractionFeature.fixedMillimeterValue(result)
        else {
          statusMessage = AppStrings.tr("status.axis_distance_constraint_target_required")
          return
        }
        beginConstraintValueEntry(
          kind: result.kind,
          title: canvasPresentation.selectedTool.displayName,
          prompt: AppStrings.tr(
            "status.specify_constraint", canvasPresentation.selectedTool.displayName),
          targets: CanvasInteractionFeature.constraintTargetPayloads(
            from: result, fallback: targetPayloads),
          initialValueMM: value
        )
      }

    case .lineLineDistance:
      guard target.isLineTarget else {
        statusMessage = AppStrings.tr("status.line_constraint_target_not_supported", entity.label)
        return
      }
      collectConstraintTarget(target, requiredCount: 2) { targets in
        let targetPayloads = targets.map(\.constraintJSON)
        guard
          let result = coreConstraintPreflightResult(
            kind: canvasPresentation.selectedTool.constraintKind,
            targets: targetPayloads
          ),
          let value = CanvasInteractionFeature.fixedMillimeterValue(result)
        else {
          statusMessage = AppStrings.tr("status.line_constraint_target_not_supported", entity.label)
          return
        }
        beginConstraintValueEntry(
          kind: result.kind,
          title: canvasPresentation.selectedTool.displayName,
          prompt: AppStrings.tr(
            "status.specify_constraint", canvasPresentation.selectedTool.displayName),
          targets: CanvasInteractionFeature.constraintTargetPayloads(
            from: result, fallback: targetPayloads),
          initialValueMM: value
        )
      }

    case .segmentLength:
      guard target.isLineTarget,
        let result = coreConstraintPreflightResult(
          kind: canvasPresentation.selectedTool.constraintKind,
          targets: [target.constraintJSON]
        ),
        let value = CanvasInteractionFeature.fixedMillimeterValue(result)
      else {
        statusMessage = AppStrings.tr(
          "status.segment_length_constraint_not_supported", entity.label)
        return
      }
      beginConstraintValueEntry(
        kind: canvasPresentation.selectedTool.constraintKind,
        title: canvasPresentation.selectedTool.displayName,
        prompt: AppStrings.tr(
          "status.specify_constraint", canvasPresentation.selectedTool.displayName),
        targets: CanvasInteractionFeature.constraintTargetPayloads(
          from: result, fallback: [target.constraintJSON]),
        initialValueMM: value
      )

    case .diameter:
      guard entity.supportsDiameterConstraint,
        let result = coreConstraintPreflightResult(
          kind: canvasPresentation.selectedTool.constraintKind,
          targets: [entity.entitySelectionTarget.constraintJSON]
        ),
        let value = CanvasInteractionFeature.fixedMillimeterValue(result)
      else {
        statusMessage = AppStrings.tr("status.diameter_constraint_not_supported", entity.label)
        return
      }
      beginConstraintValueEntry(
        kind: canvasPresentation.selectedTool.constraintKind,
        title: canvasPresentation.selectedTool.displayName,
        prompt: AppStrings.tr(
          "status.specify_constraint", canvasPresentation.selectedTool.displayName),
        targets: CanvasInteractionFeature.constraintTargetPayloads(
          from: result,
          fallback: [entity.entitySelectionTarget.constraintJSON]
        ),
        initialValueMM: value
      )

    case .radius:
      if ConstraintTargetPreflight.shouldEditSelectedFilletRadius(
        tool: canvasPresentation.selectedTool,
        entity: entity,
        selectedDerivedElement: selectedDerivedElement
      ),
        let derivedElement = selectedDerivedElement
      {
        beginFilletValueEntry(derivedElement: derivedElement)
        return
      }
      guard entity.supportsRadiusConstraint,
        let result = coreConstraintPreflightResult(
          kind: canvasPresentation.selectedTool.constraintKind,
          targets: [entity.entitySelectionTarget.constraintJSON]
        ),
        let value = CanvasInteractionFeature.fixedMillimeterValue(result)
      else {
        statusMessage = AppStrings.tr("status.radius_constraint_not_supported", entity.label)
        return
      }
      beginConstraintValueEntry(
        kind: canvasPresentation.selectedTool.constraintKind,
        title: canvasPresentation.selectedTool.displayName,
        prompt: AppStrings.tr(
          "status.specify_constraint", canvasPresentation.selectedTool.displayName),
        targets: CanvasInteractionFeature.constraintTargetPayloads(
          from: result,
          fallback: [entity.entitySelectionTarget.constraintJSON]
        ),
        initialValueMM: value
      )

    case .parallel, .perpendicular, .equalLength, .angle:
      if canvasPresentation.selectedTool == .angle, case .arc = entity.geometry {
        guard
          let result = coreConstraintPreflightResult(
            kind: canvasPresentation.selectedTool.constraintKind,
            targets: [entity.entitySelectionTarget.constraintJSON]
          ),
          case .fixedDegrees(let valueDegrees) = result.value
        else {
          statusMessage = AppStrings.tr("status.angle_constraint_not_supported", entity.label)
          return
        }
        beginConstraintValueEntry(
          kind: canvasPresentation.selectedTool.constraintKind,
          title: canvasPresentation.selectedTool.displayName,
          prompt: AppStrings.tr(
            "status.specify_constraint", canvasPresentation.selectedTool.displayName),
          targets: CanvasInteractionFeature.constraintTargetPayloads(
            from: result,
            fallback: [entity.entitySelectionTarget.constraintJSON]
          ),
          initialValue: valueDegrees,
          unit: "°"
        )
        return
      }
      guard target.isLineTarget else {
        statusMessage = AppStrings.tr("status.line_constraint_target_not_supported", entity.label)
        return
      }
      collectConstraintTarget(target, requiredCount: 2) { targets in
        if canvasPresentation.selectedTool == .angle {
          let targetPayloads = targets.map(\.constraintJSON)
          guard
            let result = coreConstraintPreflightResult(
              kind: canvasPresentation.selectedTool.constraintKind,
              targets: targetPayloads
            ), let value = result.value?.jsonObject
          else {
            statusMessage = AppStrings.tr("status.angle_requires_two_distinct_lines")
            return
          }
          applyConstraint(
            kind: canvasPresentation.selectedTool.constraintKind,
            targets: CanvasInteractionFeature.constraintTargetPayloads(
              from: result, fallback: targetPayloads),
            value: value
          )
          return
        }
        applyConstraint(
          kind: canvasPresentation.selectedTool.constraintKind,
          targets: targets.map(\.constraintJSON)
        )
      }

    case .tangent:
      guard
        let pointTarget = ConstraintTargetPreflight.pointTarget(
          from: target, fallbackEntity: entity)
      else {
        statusMessage = AppStrings.tr("status.tangent_target_not_supported", entity.label)
        return
      }
      collectConstraintTarget(pointTarget, requiredCount: 2) { targets in
        let targetPayloads = targets.map(\.constraintJSON)
        guard
          let result = coreConstraintPreflightResult(
            kind: canvasPresentation.selectedTool.constraintKind,
            targets: targetPayloads
          )
        else {
          statusMessage = AppStrings.tr("status.tangent_requires_connected_line_arc")
          return
        }
        applyConstraint(
          kind: canvasPresentation.selectedTool.constraintKind,
          targets: CanvasInteractionFeature.constraintTargetPayloads(
            from: result, fallback: targetPayloads)
        )
      }

    case .pointOnLine:
      guard
        let selectedTarget = ConstraintTargetPreflight.pointOrLineTarget(
          from: target, fallbackEntity: entity)
      else {
        statusMessage = AppStrings.tr("status.point_on_line_target_not_supported", entity.label)
        return
      }
      collectConstraintTarget(selectedTarget, requiredCount: 2) { targets in
        let targetPayloads = targets.map(\.constraintJSON)
        guard
          let result = coreConstraintPreflightResult(
            kind: canvasPresentation.selectedTool.constraintKind,
            targets: targetPayloads
          )
        else {
          statusMessage = AppStrings.tr("status.point_on_line_target_required")
          return
        }
        applyConstraint(
          kind: result.kind,
          targets: CanvasInteractionFeature.constraintTargetPayloads(
            from: result, fallback: targetPayloads)
        )
      }

    case .symmetric:
      if canvasPresentation.pendingConstraintTargets.count < 2 {
        guard
          let pointTarget = ConstraintTargetPreflight.pointTarget(
            from: target, fallbackEntity: entity)
        else {
          statusMessage = AppStrings.tr("status.symmetric_point_target_not_supported", entity.label)
          return
        }
        collectConstraintTarget(pointTarget, requiredCount: 3) { _ in }
        if canvasPresentation.pendingConstraintTargets.count < 2 {
          statusMessage = AppStrings.tr(
            "status.symmetric_select_points_remaining",
            2 - canvasPresentation.pendingConstraintTargets.count)
        } else {
          statusMessage = AppStrings.tr("status.symmetric_select_axis")
        }
      } else {
        guard target.isLineTarget else {
          statusMessage = AppStrings.tr("status.symmetric_axis_requires_line")
          return
        }
        canvasPresentation.appendPendingConstraintTarget(target)
        let targets = Array(canvasPresentation.pendingConstraintTargets.prefix(3))
        canvasPresentation.setPendingConstraintTargets([])
        applyConstraintUsingCoreNormalization(
          kind: canvasPresentation.selectedTool.constraintKind,
          targets: targets.map(\.constraintJSON)
        )
      }

    case .coincident:
      guard
        let pointTarget = ConstraintTargetPreflight.pointTarget(
          from: target, fallbackEntity: entity)
      else {
        statusMessage = AppStrings.tr("status.coincident_point_target_not_supported", entity.label)
        return
      }
      collectConstraintTarget(pointTarget, requiredCount: 2) { targets in
        applyConstraintUsingCoreNormalization(
          kind: canvasPresentation.selectedTool.constraintKind,
          targets: targets.map(\.constraintJSON)
        )
      }

    default:
      return
    }
  }

  func collectConstraintTarget(
    _ target: CanvasSelectionTarget,
    requiredCount: Int,
    onReady: ([CanvasSelectionTarget]) -> Void
  ) {
    if canvasPresentation.pendingConstraintTargets.last != target {
      canvasPresentation.appendPendingConstraintTarget(target)
    }
    if canvasPresentation.pendingConstraintTargets.count < requiredCount {
      statusMessage = CanvasInteractionFeature.constraintSelectionProgressMessage(
        for: canvasPresentation.selectedTool,
        selectedCount: canvasPresentation.pendingConstraintTargets.count,
        requiredCount: requiredCount
      )
      return
    }

    let selectedTargets = Array(canvasPresentation.pendingConstraintTargets.prefix(requiredCount))
    canvasPresentation.setPendingConstraintTargets([])
    onReady(selectedTargets)
  }

  private func updateFilletDraft(
    with target: CanvasSelectionTarget,
    startingSources: [String]
  ) {
    guard let addedSourceID = filletSourceEntityIDs(from: [target]).first else {
      statusMessage = AppStrings.tr("status.fillet_source_required")
      return
    }
    var sourceEntityIDs = startingSources
    if sourceEntityIDs.contains(addedSourceID) {
      statusMessage = AppStrings.tr("status.fillet_draft_already_contains")
      canvasPresentation.setEntityIDs(Set(sourceEntityIDs))
      canvasPresentation.setPrimaryEntityID(sourceEntityIDs.first)
      return
    }
    sourceEntityIDs.append(addedSourceID)
    let previousValueText =
      canvasPresentation.pendingConstraintValueDraft?.kind == "fillet"
      ? canvasPresentation.pendingConstraintValueDraft?.valueText ?? ""
      : ""
    beginFilletValueEntry(
      sourceEntityIDs: sourceEntityIDs,
      initialValueText: previousValueText,
      lastAddedSourceID: addedSourceID
    )
    if let draft = canvasPresentation.pendingConstraintValueDraft,
      draft.kind == "fillet"
    {
      canvasPresentation.setEntityIDs(Set(draft.filletSourceEntityIDs))
      canvasPresentation.setPrimaryEntityID(draft.filletSourceEntityIDs.first)
    }
  }

  func selectedLineTargetsForEqualLength() -> [CanvasSelectionTarget] {
    CanvasInteractionFeature.lineTargetsForEqualLength(entities: selectedEntities)
  }

  func coreConstraintPreflightResult(
    kind: String,
    targets: [[String: Any]]
  ) -> ConstraintPreflightResult? {
    let wireTargets = targets.compactMap(CoreConstraintTarget.init(jsonObject:))
    guard wireTargets.count == targets.count else { return nil }
    switch cadSession.preflightConstraint(kind: kind, targets: wireTargets) {
    case .success(let result):
      return result
    case .failure:
      return nil
    }
  }

  func applyConstraint(kind: String, targets: [[String: Any]], value: Any = NSNull()) {
    let request = commandFactory.makeAddConstraintCommand(
      kind: kind,
      displayName: canvasPresentation.selectedTool.displayName,
      targets: targets,
      value: value
    )
    executeDocumentCommand(request)
  }

  private func applyConstraintUsingCoreNormalization(kind: String, targets: [[String: Any]]) {
    guard let result = coreConstraintPreflightResult(kind: kind, targets: targets) else {
      presentUserCorrectableError(
        AppStrings.tr("status.constraint_preflight_failed"),
        operation: "preflightConstraint"
      )
      return
    }
    applyConstraint(
      kind: result.kind,
      targets: CanvasInteractionFeature.constraintTargetPayloads(from: result, fallback: targets)
    )
  }

  func applyConstraintUsingCoreInitialValue(kind: String, targets: [[String: Any]]) {
    guard let result = coreConstraintPreflightResult(kind: kind, targets: targets),
      let value = result.value?.jsonObject
    else {
      presentUserCorrectableError(
        AppStrings.tr("status.constraint_preflight_failed"),
        operation: "preflightConstraint"
      )
      return
    }
    applyConstraint(
      kind: result.kind,
      targets: CanvasInteractionFeature.constraintTargetPayloads(from: result, fallback: targets),
      value: value
    )
  }

  private func presentConstraintSelectionWarning(_ message: String) {
    presentUserCorrectableError(
      message,
      code: "constraintSelectionWarning",
      operation: "constraintSelection"
    )
  }
}
