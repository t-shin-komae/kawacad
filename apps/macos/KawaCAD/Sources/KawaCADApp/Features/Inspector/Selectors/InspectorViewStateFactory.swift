import Foundation

/// Pure selectors used to build Inspector display state.
enum InspectorViewStateFactory {
  static func selectionSignature(
    primaryEntityID: String?,
    entityIDs: Set<String>,
    selectedConstraintID: String?,
    selectedMeasurementAnnotationID: String?,
    selectedFreeTextID: String?,
    selectedStitchStartPointID: String?
  ) -> String {
    InspectorFeature.selectionSignature(
      selectedEntityID: primaryEntityID,
      selectedEntityIDs: entityIDs,
      selectedConstraintID: selectedConstraintID,
      selectedMeasurementAnnotationID: selectedMeasurementAnnotationID,
      selectedFreeTextID: selectedFreeTextID,
      selectedStitchStartPointID: selectedStitchStartPointID
    )
  }

  static func hasPendingSelectionChange(
    tab: InspectorTab,
    selectionSignature: String,
    acknowledgedSelectionSignature: String
  ) -> Bool {
    tab != .selection
      && !selectionSignature.isEmpty
      && selectionSignature != acknowledgedSelectionSignature
  }

  static func shouldShowSearch(
    itemCount: Int,
    explicitlyVisible: Bool,
    query: String
  ) -> Bool {
    InspectorFeature.shouldShowSearch(
      itemCount: itemCount,
      explicitlyVisible: explicitlyVisible,
      query: query
    )
  }

  static func filteredLayers(
    _ layers: [ProjectLayer],
    query: String
  ) -> [ProjectLayer] {
    InspectorFeature.filter(layers, query: query) { layer in
      [
        layer.id,
        layer.name,
        layer.kind.displayName,
        layer.visible ? "visible" : "hidden",
        layer.printable ? "printable" : "non-printable",
      ]
    }
  }

  static func filteredSharedStyles(
    _ sharedStyles: [ProjectSharedStyle],
    query: String
  ) -> [ProjectSharedStyle] {
    InspectorFeature.filter(sharedStyles, query: query) { style in
      [
        style.name,
        style.colorHex,
        style.linePattern.displayName,
        String(format: "%.2f", style.strokeWidthMM),
      ]
    }
  }

  static func filteredParameters(
    _ parameters: [ProjectParameter],
    query: String
  ) -> [ProjectParameter] {
    InspectorFeature.filter(parameters, query: query) { parameter in
      [
        parameter.name,
        parameter.memo,
        parameter.unit,
        String(format: "%.2f", parameter.valueMM),
      ]
    }
  }
}
