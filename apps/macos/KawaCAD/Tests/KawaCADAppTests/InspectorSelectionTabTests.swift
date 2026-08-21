import SwiftUI
import Testing

@testable import KawaCADApp

@Test("Selection editor は Inspector 全体ではなく必要な入力だけで構築できる")
@MainActor
func selection_editor_accepts_focused_model() {
  let annotation = ProjectMeasurementAnnotation(
    id: "measurement:test",
    rawKind: "distance",
    kind: "距離",
    targets: [],
    targetsJSON: "[]",
    labelOffsetMM: .zero,
    overallOffsetMM: .zero,
    visible: true
  )
  let model = SelectionMeasurementEditorModel(
    convert: { _ in },
    delete: { _ in }
  )
  let editor = SelectedMeasurementEditor(appState: model, measurement: annotation)

  _ = editor.body
}

@Test("Selection tab は巨大な AppCoordinator ではなく専用モデルだけで構築できる")
@MainActor
func selection_tab_accepts_focused_model() {
  let model = SelectionInspectorModel(
    data: SelectionInspectorData(
      viewMode: .editDisplay,
      activeLayerID: "",
      layers: [],
      sharedStyles: [],
      parameters: [],
      entities: [],
      constraints: [],
      measurementAnnotations: [],
      freeTexts: [],
      selectedEntity: nil,
      selectedEntities: [],
      selectedFreeText: nil,
      selectedStitchStartPoint: nil,
      selectedConstraintID: nil,
      selectedMeasurementAnnotation: nil,
      selectedDerivedElement: nil,
      selectedRoundHole: nil,
      canConstrainSelectedLineLengthsEqual: false
    ),
    actions: SelectionInspectorActions(
      setSelectedEntitiesSharedStyle: { _ in false },
      setSelectedEntityLayer: { _ in },
      deleteSelectedEntity: {},
      updateFreeText: { _ in false },
      deleteSelectedFreeText: {},
      deleteConstraint: { _ in },
      selectConstraint: { _ in },
      selectFreeText: { _ in },
      selectMeasurementAnnotation: { _ in },
      deleteMeasurementAnnotation: { _ in },
      convertMeasurementAnnotationToConstraint: { _ in },
      hoverConstraint: { _ in },
      constrainSelectedLineLengthsEqual: {},
      setConstraintDegrees: { _, _ in false },
      setConstraintValue: { _, _ in false },
      setConstraintParameter: { _, _ in false },
      setDerivedElementDirection: { _, _ in false },
      reverseDerivedElementDirection: { _ in false },
      setDerivedElementDistance: { _, _ in false },
      setDerivedElementParameter: { _, _ in false },
      setSelectedRoundHoleKind: { _ in false },
      setSelectedRoundHoleDiameter: { _ in false },
      constrainSelectedLineLength: {},
      setSelectedLineLength: { _ in false },
      setSelectedCircleRadius: { _ in false },
      setSelectedArc: { _, _, _ in false }
    )
  )

  _ = InspectorSelectionTab(model: model).body
}
