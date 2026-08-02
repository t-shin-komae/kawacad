import Testing

@testable import KawaCADApp

struct AnnotationSelectionStateTests {
  @Test
  func annotation_selection_is_mutually_exclusive() {
    let selection = AnnotationSelectionState()

    selection.setSelectedFreeTextID("free-text:note")
    #expect(selection.selectedFreeTextID == "free-text:note")

    selection.setSelectedMeasurementAnnotationID("measurement:width")
    #expect(selection.selectedFreeTextID == nil)
    #expect(selection.selectedMeasurementAnnotationID == "measurement:width")
    #expect(selection.selectedConstraintID == nil)
    #expect(selection.selectedStitchStartPointID == nil)
  }

  @Test
  func clearing_a_different_annotation_kind_preserves_the_current_selection() {
    let selection = AnnotationSelectionState()
    selection.setSelectedConstraintID("constraint:width")

    selection.setSelectedFreeTextID(nil)
    #expect(selection.selectedConstraintID == "constraint:width")

    selection.clear()
    #expect(selection.selectedConstraintID == nil)
  }
}
