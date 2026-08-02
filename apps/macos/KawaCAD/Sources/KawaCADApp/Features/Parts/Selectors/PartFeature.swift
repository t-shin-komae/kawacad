/// Pure part-selection and naming calculations.
enum PartFeature {
  static func canvasEntityIDs(
    for part: ProjectPart?,
    entities: [CanvasEntity]
  ) -> Set<String> {
    guard let part else { return [] }
    return Set(
      entities.compactMap { entity in
        if part.entityIDs.contains(entity.id)
          || entity.derivedElementID.map(part.derivedElementIDs.contains) == true
        {
          return entity.id
        }
        return nil
      })
  }

  static func selectedNormalEntityIDs(
    selectedEntityIDs: Set<String>,
    entities: [CanvasEntity]
  ) -> [String] {
    entities
      .filter { selectedEntityIDs.contains($0.id) && $0.derivedElementID == nil }
      .map(\.id)
      .sorted()
  }

  static func uniqueName(
    sourceName: String,
    existingNames: Set<String>,
    copiesSourceName: Bool
  ) -> String {
    let base =
      copiesSourceName
      ? AppStrings.tr("part.copy_name", sourceName)
      : sourceName
    guard existingNames.contains(base) else { return base }
    var suffix = 2
    while existingNames.contains("\(base) \(suffix)") {
      suffix += 1
    }
    return "\(base) \(suffix)"
  }
}
