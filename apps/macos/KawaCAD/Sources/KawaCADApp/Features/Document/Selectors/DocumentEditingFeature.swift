/// Pure document-editing calculations, corresponding to selection and paste
/// helpers kept outside React components and hooks.
enum DocumentEditingFeature {
  static func isValidHexColor(_ input: String) -> Bool {
    let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard value.count == 7, value.first == "#" else {
      return false
    }
    return value.dropFirst().allSatisfy { $0.isHexDigit }
  }

  static func pointsApproximatelyEqual(
    _ lhs: ModelPoint,
    _ rhs: ModelPoint,
    toleranceMM: Double = 0.001
  ) -> Bool {
    abs(lhs.xMM - rhs.xMM) < toleranceMM
      && abs(lhs.yMM - rhs.yMM) < toleranceMM
  }

  static func canPasteAtCursor(
    _ point: ModelPoint,
    sourceAnchor: ModelPoint,
    sourceBounds: ModelBounds?,
    lastPasteCursorPoint: ModelPoint?
  ) -> Bool {
    guard !pointsApproximatelyEqual(point, sourceAnchor) else { return false }
    if let sourceBounds {
      let pastedBounds = sourceBounds.translatedBy(
        dxMM: point.xMM - sourceAnchor.xMM,
        dyMM: point.yMM - sourceAnchor.yMM
      )
      guard !pastedBounds.intersects(sourceBounds) else { return false }
    }
    guard let lastPasteCursorPoint else { return true }
    return !pointsApproximatelyEqual(point, lastPasteCursorPoint)
  }

  static func selectionReference(
    entityIDs: Set<String>,
    entities: [CanvasEntity]
  ) -> CoreSelectionReference {
    let selected = entities.filter { entityIDs.contains($0.id) }
    return CoreSelectionReference(
      entityIds: selected.filter { $0.derivedElementID == nil }.map(\.id).sorted(),
      derivedElementIds: Array(Set(selected.compactMap(\.derivedElementID))).sorted(),
      constraintIds: [],
      measurementAnnotationIds: [],
      stitchStartPointIds: [],
      freeTextIds: []
    )
  }

  static func selectionReference(
    entityIDs: [String],
    derivedElementIDs: [String],
    constraintID: String?,
    measurementAnnotationID: String?,
    stitchStartPointID: String?,
    freeTextID: String?
  ) -> CoreSelectionReference {
    CoreSelectionReference(
      entityIds: entityIDs.sorted(),
      derivedElementIds: derivedElementIDs.sorted(),
      constraintIds: constraintID.map { [$0] } ?? [],
      measurementAnnotationIds: measurementAnnotationID.map { [$0] } ?? [],
      stitchStartPointIds: stitchStartPointID.map { [$0] } ?? [],
      freeTextIds: freeTextID.map { [$0] } ?? []
    )
  }

  static func uniqueCopyName(
    sourceName: String,
    existingNames: Set<String>
  ) -> String {
    let base = AppStrings.tr("part.copy_name", sourceName)
    guard existingNames.contains(base) else { return base }
    var suffix = 2
    while existingNames.contains("\(base) \(suffix)") {
      suffix += 1
    }
    return "\(base) \(suffix)"
  }

  static func moveCompletionMessage(
    entities: [CanvasEntity],
    duplicating: Bool
  ) -> String {
    let action = AppStrings.tr(
      duplicating ? "status.duplicate_completed" : "status.move_completed"
    )
    if entities.count == 1, let entity = entities.first {
      return AppStrings.tr("status.entity_action_single", entity.label, action)
    }
    return AppStrings.tr("status.entity_action_multiple", entities.count, action)
  }
}
