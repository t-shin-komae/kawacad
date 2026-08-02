/// Pure derived-element selection calculations, corresponding to the
/// derived-element helpers in React's `cad.ts`.
enum DerivedElementFeature {
  static func uniqueEntityIDs(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values.filter { seen.insert($0).inserted }
  }

  static func selectedArcEntityID(
    selectedEntityID: String?,
    selectedEntityIDs: Set<String>,
    entities: [CanvasEntity]
  ) -> String? {
    let selectedIDs =
      selectedEntityIDs.isEmpty
      ? Set(selectedEntityID.map { [$0] } ?? [])
      : selectedEntityIDs
    guard selectedIDs.count == 1,
      let id = selectedIDs.first,
      let entity = entities.first(where: { $0.id == id }),
      case .arc = entity.geometry,
      entity.derivedElementID == nil
    else {
      return nil
    }
    return id
  }
}
