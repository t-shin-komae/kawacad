import Foundation

/// Pure Inspector presentation calculations, corresponding to
/// `inspectorFeature.ts`.
enum InspectorFeature {
  static func selectionSignature(
    selectedEntityID: String?,
    selectedEntityIDs: Set<String>,
    selectedConstraintID: String?,
    selectedMeasurementAnnotationID: String?,
    selectedFreeTextID: String?,
    selectedStitchStartPointID: String?
  ) -> String {
    let components = [
      selectedEntityID ?? "",
      selectedEntityIDs.sorted().joined(separator: ","),
      selectedConstraintID ?? "",
      selectedMeasurementAnnotationID ?? "",
      selectedFreeTextID ?? "",
      selectedStitchStartPointID ?? "",
    ]
    return components.allSatisfy(\.isEmpty)
      ? ""
      : components.joined(separator: "|")
  }

  static func shouldShowSearch(itemCount: Int, explicitlyVisible: Bool, query: String) -> Bool {
    itemCount >= 8 || explicitlyVisible || !normalizeSearch(query).isEmpty
  }

  static func filter<T>(
    _ items: [T],
    query: String,
    terms: (T) -> [String]
  ) -> [T] {
    let normalizedQuery = normalizeSearch(query)
    guard !normalizedQuery.isEmpty else {
      return items
    }
    return items.filter { item in
      terms(item).contains { value in
        normalizeSearch(value).contains(normalizedQuery)
      }
    }
  }

  private static func normalizeSearch(_ value: String) -> String {
    value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
