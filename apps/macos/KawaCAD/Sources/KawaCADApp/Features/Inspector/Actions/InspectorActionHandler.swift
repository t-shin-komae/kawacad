extension InspectorActionHandler {
  func setInspectorTab(_ tab: InspectorTab) {
    inspectorPresentation.setTab(
      tab,
      selectionSignature: InspectorViewStateFactory.selectionSignature(
        primaryEntityID: selectedEntityID,
        entityIDs: selectedEntityIDs,
        selectedConstraintID: selectedConstraintID,
        selectedMeasurementAnnotationID: selectedMeasurementAnnotationID,
        selectedFreeTextID: selectedFreeTextID,
        selectedStitchStartPointID: selectedStitchStartPointID
      )
    )
  }

  func revealInspectorSelectionTab() {
    setInspectorTab(.selection)
  }

  func revealInspectorSearchForCurrentTab() {
    inspectorPresentation.revealSearchForCurrentTab()
  }

  func resetInspectorPresentationForLoadedDocument() {
    inspectorPresentation.reset()
  }
}
