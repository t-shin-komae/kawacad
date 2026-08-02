import Combine

/// UI-only selection owner for non-entity canvas annotations. Exactly one of
/// these can be active, matching React's independent
/// `useAnnotationSelection` hook.
final class AnnotationSelectionState: ObservableObject {
  private enum Selection: Equatable {
    case constraint(String)
    case measurement(String)
    case freeText(String)
    case stitchStartPoint(String)
  }

  @Published private var selection: Selection?

  var selectedConstraintID: String? {
    selectionID(for: .constraint)
  }

  var selectedMeasurementAnnotationID: String? {
    selectionID(for: .measurement)
  }

  var selectedFreeTextID: String? {
    selectionID(for: .freeText)
  }

  var selectedStitchStartPointID: String? {
    selectionID(for: .stitchStartPoint)
  }

  func setSelectedConstraintID(_ id: String?) {
    setSelection(.constraint, id: id)
  }

  func setSelectedMeasurementAnnotationID(_ id: String?) {
    setSelection(.measurement, id: id)
  }

  func setSelectedFreeTextID(_ id: String?) {
    setSelection(.freeText, id: id)
  }

  func setSelectedStitchStartPointID(_ id: String?) {
    setSelection(.stitchStartPoint, id: id)
  }

  func clear() {
    selection = nil
  }

  private enum Kind {
    case constraint
    case measurement
    case freeText
    case stitchStartPoint
  }

  private func selectionID(for kind: Kind) -> String? {
    switch (kind, selection) {
    case (.constraint, .constraint(let id)?),
      (.measurement, .measurement(let id)?),
      (.freeText, .freeText(let id)?),
      (.stitchStartPoint, .stitchStartPoint(let id)?):
      return id
    default:
      return nil
    }
  }

  private func setSelection(_ kind: Kind, id: String?) {
    guard let id else {
      if selectionID(for: kind) != nil {
        selection = nil
      }
      return
    }
    switch kind {
    case .constraint:
      selection = .constraint(id)
    case .measurement:
      selection = .measurement(id)
    case .freeText:
      selection = .freeText(id)
    case .stitchStartPoint:
      selection = .stitchStartPoint(id)
    }
  }
}
