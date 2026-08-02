import Foundation

extension ConstraintActionHandler {
  func smoothSelectedArcTangenciesPrototype() {
    guard cadSession.hasDocument else {
      statusMessage = AppStrings.tr("status.document_disconnected")
      return
    }
    guard
      let arcEntityID = DerivedElementFeature.selectedArcEntityID(
        selectedEntityID: selectedEntityID,
        selectedEntityIDs: selectedEntityIDs,
        entities: entities
      )
    else {
      statusMessage = AppStrings.tr("status.smooth_arc_tangencies_select_arc")
      return
    }
    executeDocumentCommand(
      commandFactory.makeSmoothArcTangenciesCommand(arcEntityID: arcEntityID)
    )
  }
}
