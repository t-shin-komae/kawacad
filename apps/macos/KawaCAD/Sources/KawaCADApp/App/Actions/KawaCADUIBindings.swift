import CoreGraphics
import Foundation
import KawaCADOutput

protocol KawaCADUIActionHandling: AnyObject {
  // Menu / command actions.
  func createNewProject()
  func openProjectPanel()
  func saveProject()
  @discardableResult func saveProjectAsPanel() -> Bool
  func exportPDFPanel()
  func printDirectPanel()
  func selectAllEntities()
  func copySelection()
  func pasteCopiedEntity()
  func pasteCopiedEntity(at point: ModelPoint)
  func duplicateSelection()
  func undo()
  func redo()
  func deleteSelectedEntity()
  func cancelCurrentInteraction()
  func activateTool(_ tool: CanvasTool)
  func setViewMode(_ mode: CanvasViewMode)
  func reloadFromDocument()
  func addLayer()
  func smoothSelectedArcTangenciesPrototype()
  func reportUnavailable(_ feature: String)

  // Toolbar actions.
  func setActiveLayer(_ layerID: String)
  func zoomIn()
  func zoomOut()
  func zoomToFit()
  func setGridVisible(_ visible: Bool)
  func setA4ReferenceVisible(_ visible: Bool)
  func setA4ReferenceOrientation(_ orientation: OutputPrintOrientation)
  func setGridSnapEnabled(_ enabled: Bool)
  func setPointSnapEnabled(_ enabled: Bool)
  func setInspectorPanelVisible(_ visible: Bool)
  func setLayerPanelVisible(_ visible: Bool)
  func setParameterPanelVisible(_ visible: Bool)
  func setBottomWorkbenchVisible(_ visible: Bool)

  // Canvas callbacks.
  func selectEntity(_ entityID: String?)
  func toggleEntitySelection(_ entityID: String?)
  func selectEntities(_ entityIDs: Set<String>, extendingSelection: Bool)
  func selectConstraint(_ constraintID: String?)
  func selectMeasurementAnnotation(_ annotationID: String?)
  func selectFreeText(_ freeTextID: String?)
  func selectStitchStartPoint(_ stitchStartPointID: String?)
  func updateFreeText(_ freeText: ProjectFreeText) -> Bool
  func hoverConstraint(_ constraintID: String?)
  func selectTarget(_ target: CanvasSelectionTarget?)
  func handleCanvasPlacement(_ point: ModelPoint, modifiers: CanvasPlacementModifiers)
  func handleCanvasHover(_ point: ModelPoint, modifiers: CanvasPlacementModifiers)
  func handleCanvasCursor(_ point: ModelPoint?, canvasPoint: CGPoint?)
  func previewMoveEntity(_ entityID: String, delta: ModelPoint)
  func previewMoveEntities(_ entityIDs: Set<String>, delta: ModelPoint, duplicating: Bool)
  func previewMoveControlPoint(_ target: CanvasSelectionTarget, to point: ModelPoint)
  func cancelMovePreview()
  func moveEntity(_ entityID: String, delta: ModelPoint)
  func moveEntities(_ entityIDs: Set<String>, delta: ModelPoint, duplicating: Bool)
  func moveControlPoint(_ target: CanvasSelectionTarget, to point: ModelPoint)
  func moveMeasurementAnnotation(id: String, delta: ModelPoint, labelOnly: Bool)
  func moveDimensionConstraintAnnotation(constraintID: String, delta: ModelPoint, labelOnly: Bool)
  func convertMeasurementAnnotationToConstraint(id: String)
  func panCanvas(by delta: CGSize)
  func setCanvasViewport(scale: Double, panOffset: CGSize, message: String)
}

struct KawaCADUIBindings {
  struct MenuBindings {
    let createNewProject: () -> Void
    let openProjectPanel: () -> Void
    let saveProject: () -> Void
    let saveProjectAsPanel: () -> Void
    let exportPDFPanel: () -> Void
    let printDirectPanel: () -> Void
    let selectAllEntities: () -> Void
    let copySelection: () -> Void
    let pasteCopiedEntity: () -> Void
    let pasteCopiedEntityAtPoint: (ModelPoint) -> Void
    let duplicateSelection: () -> Void
    let undo: () -> Void
    let redo: () -> Void
    let deleteSelectedEntity: () -> Void
    let cancelCurrentInteraction: () -> Void
    let activateTool: (CanvasTool) -> Void
    let setViewMode: (CanvasViewMode) -> Void
    let reloadFromDocument: () -> Void
    let addLayer: () -> Void
    let smoothSelectedArcTangenciesPrototype: () -> Void
    let reportUnavailable: (String) -> Void
  }

  struct ToolbarBindings {
    let setActiveLayer: (String) -> Void
    let zoomIn: () -> Void
    let zoomOut: () -> Void
    let zoomToFit: () -> Void
    let setGridVisible: (Bool) -> Void
    let setA4ReferenceVisible: (Bool) -> Void
    let setA4ReferenceOrientation: (OutputPrintOrientation) -> Void
    let setGridSnapEnabled: (Bool) -> Void
    let setPointSnapEnabled: (Bool) -> Void
    let setInspectorPanelVisible: (Bool) -> Void
    let setLayerPanelVisible: (Bool) -> Void
    let setParameterPanelVisible: (Bool) -> Void
    let setBottomWorkbenchVisible: (Bool) -> Void
  }

  struct CanvasBindings {
    let selectEntity: (String?) -> Void
    let toggleEntitySelection: (String?) -> Void
    let selectEntities: (Set<String>, Bool) -> Void
    let selectConstraint: (String?) -> Void
    let selectMeasurementAnnotation: (String?) -> Void
    let selectFreeText: (String?) -> Void
    let selectStitchStartPoint: (String?) -> Void
    let updateFreeText: (ProjectFreeText) -> Bool
    let hoverConstraint: (String?) -> Void
    let selectTarget: (CanvasSelectionTarget?) -> Void
    let handleCanvasPlacement: (ModelPoint, CanvasPlacementModifiers) -> Void
    let handleCanvasHover: (ModelPoint, CanvasPlacementModifiers) -> Void
    let handleCanvasCursor: (ModelPoint?, CGPoint?) -> Void
    let previewMoveEntity: (String, ModelPoint) -> Void
    let previewMoveEntities: (Set<String>, ModelPoint, Bool) -> Void
    let previewMoveControlPoint: (CanvasSelectionTarget, ModelPoint) -> Void
    let cancelMovePreview: () -> Void
    let moveEntity: (String, ModelPoint) -> Void
    let moveEntities: (Set<String>, ModelPoint, Bool) -> Void
    let moveControlPoint: (CanvasSelectionTarget, ModelPoint) -> Void
    let moveMeasurementAnnotation: (String, ModelPoint, Bool) -> Void
    let moveDimensionConstraintAnnotation: (String, ModelPoint, Bool) -> Void
    let convertMeasurementAnnotationToConstraint: (String) -> Void
    let panCanvas: (CGSize) -> Void
    let setCanvasViewport: (Double, CGSize, String) -> Void
  }

  let menu: MenuBindings
  let toolbar: ToolbarBindings
  let canvas: CanvasBindings

  init(handler: AppActionHandlers) {
    self.menu = MenuBindings(
      createNewProject: { handler.document.createNewProject() },
      openProjectPanel: { handler.document.openProjectPanel() },
      saveProject: { handler.document.saveProject() },
      saveProjectAsPanel: { _ = handler.document.saveProjectAsPanel() },
      exportPDFPanel: { handler.output.exportPDFPanel() },
      printDirectPanel: { handler.output.printDirectPanel() },
      selectAllEntities: { handler.canvas.selectAllEntities() },
      copySelection: { handler.document.copySelection() },
      pasteCopiedEntity: { handler.document.pasteCopiedEntity() },
      pasteCopiedEntityAtPoint: { handler.document.pasteCopiedEntity(at: $0) },
      duplicateSelection: { handler.document.duplicateSelection() },
      undo: { handler.document.undo() },
      redo: { handler.document.redo() },
      deleteSelectedEntity: { handler.canvas.deleteSelectedEntity() },
      cancelCurrentInteraction: { handler.canvas.cancelCurrentInteraction() },
      activateTool: { handler.canvas.activateTool($0) },
      setViewMode: { handler.canvas.setViewMode($0) },
      reloadFromDocument: { handler.document.reloadFromDocument() },
      addLayer: { handler.document.addLayer() },
      smoothSelectedArcTangenciesPrototype: {
        handler.constraints.smoothSelectedArcTangenciesPrototype()
      },
      reportUnavailable: { handler.workspace.reportUnavailable($0) }
    )

    self.toolbar = ToolbarBindings(
      setActiveLayer: { handler.document.setActiveLayer($0) },
      zoomIn: { handler.canvas.zoomIn() },
      zoomOut: { handler.canvas.zoomOut() },
      zoomToFit: { handler.canvas.zoomToFit() },
      setGridVisible: { handler.workspace.setGridVisible($0) },
      setA4ReferenceVisible: { handler.workspace.setA4ReferenceVisible($0) },
      setA4ReferenceOrientation: { handler.workspace.setA4ReferenceOrientation($0) },
      setGridSnapEnabled: { handler.workspace.setGridSnapEnabled($0) },
      setPointSnapEnabled: { handler.canvas.setPointSnapEnabled($0) },
      setInspectorPanelVisible: { handler.workspace.setInspectorPanelVisible($0) },
      setLayerPanelVisible: { handler.workspace.setLayerPanelVisible($0) },
      setParameterPanelVisible: { handler.workspace.setParameterPanelVisible($0) },
      setBottomWorkbenchVisible: { handler.workspace.setBottomWorkbenchVisible($0) }
    )

    self.canvas = CanvasBindings(
      selectEntity: { handler.canvas.selectEntity($0) },
      toggleEntitySelection: { handler.canvas.toggleEntitySelection($0) },
      selectEntities: { handler.canvas.selectEntities($0, extendingSelection: $1) },
      selectConstraint: { handler.canvas.selectConstraint($0) },
      selectMeasurementAnnotation: { handler.canvas.selectMeasurementAnnotation($0) },
      selectFreeText: { handler.canvas.selectFreeText($0) },
      selectStitchStartPoint: { handler.canvas.selectStitchStartPoint($0) },
      updateFreeText: { handler.canvas.updateFreeText($0) },
      hoverConstraint: { handler.canvas.hoverConstraint($0) },
      selectTarget: { handler.constraints.handleConstraintTargetSelection($0) },
      handleCanvasPlacement: { handler.canvas.handleCanvasPlacement($0, modifiers: $1) },
      handleCanvasHover: { handler.canvas.handleCanvasHover($0, modifiers: $1) },
      handleCanvasCursor: { handler.canvas.handleCanvasCursor($0, canvasPoint: $1) },
      previewMoveEntity: { handler.document.previewMoveEntity($0, delta: $1) },
      previewMoveEntities: { handler.document.previewMoveEntities($0, delta: $1, duplicating: $2) },
      previewMoveControlPoint: { handler.document.previewMoveControlPoint($0, to: $1) },
      cancelMovePreview: { handler.document.cancelMovePreview() },
      moveEntity: { handler.document.moveEntity($0, delta: $1) },
      moveEntities: { handler.document.moveEntities($0, delta: $1, duplicating: $2) },
      moveControlPoint: { handler.document.moveControlPoint($0, to: $1) },
      moveMeasurementAnnotation: {
        handler.canvas.moveMeasurementAnnotation(id: $0, delta: $1, labelOnly: $2)
      },
      moveDimensionConstraintAnnotation: {
        handler.canvas.moveDimensionConstraintAnnotation(constraintID: $0, delta: $1, labelOnly: $2)
      },
      convertMeasurementAnnotationToConstraint: {
        handler.canvas.convertMeasurementAnnotationToConstraint(id: $0)
      },
      panCanvas: { handler.canvas.panCanvas(by: $0) },
      setCanvasViewport: { handler.canvas.setCanvasViewport(scale: $0, panOffset: $1, message: $2) }
    )
  }

  init(handler: some KawaCADUIActionHandling) {
    self.menu = MenuBindings(
      createNewProject: { handler.createNewProject() },
      openProjectPanel: { handler.openProjectPanel() },
      saveProject: { handler.saveProject() },
      saveProjectAsPanel: { _ = handler.saveProjectAsPanel() },
      exportPDFPanel: { handler.exportPDFPanel() },
      printDirectPanel: { handler.printDirectPanel() },
      selectAllEntities: { handler.selectAllEntities() },
      copySelection: { handler.copySelection() },
      pasteCopiedEntity: { handler.pasteCopiedEntity() },
      pasteCopiedEntityAtPoint: { handler.pasteCopiedEntity(at: $0) },
      duplicateSelection: { handler.duplicateSelection() },
      undo: { handler.undo() },
      redo: { handler.redo() },
      deleteSelectedEntity: { handler.deleteSelectedEntity() },
      cancelCurrentInteraction: { handler.cancelCurrentInteraction() },
      activateTool: { handler.activateTool($0) },
      setViewMode: { handler.setViewMode($0) },
      reloadFromDocument: { handler.reloadFromDocument() },
      addLayer: { handler.addLayer() },
      smoothSelectedArcTangenciesPrototype: { handler.smoothSelectedArcTangenciesPrototype() },
      reportUnavailable: { handler.reportUnavailable($0) }
    )

    self.toolbar = ToolbarBindings(
      setActiveLayer: { handler.setActiveLayer($0) },
      zoomIn: { handler.zoomIn() },
      zoomOut: { handler.zoomOut() },
      zoomToFit: { handler.zoomToFit() },
      setGridVisible: { handler.setGridVisible($0) },
      setA4ReferenceVisible: { handler.setA4ReferenceVisible($0) },
      setA4ReferenceOrientation: { handler.setA4ReferenceOrientation($0) },
      setGridSnapEnabled: { handler.setGridSnapEnabled($0) },
      setPointSnapEnabled: { handler.setPointSnapEnabled($0) },
      setInspectorPanelVisible: { handler.setInspectorPanelVisible($0) },
      setLayerPanelVisible: { handler.setLayerPanelVisible($0) },
      setParameterPanelVisible: { handler.setParameterPanelVisible($0) },
      setBottomWorkbenchVisible: { handler.setBottomWorkbenchVisible($0) }
    )

    self.canvas = CanvasBindings(
      selectEntity: { handler.selectEntity($0) },
      toggleEntitySelection: { handler.toggleEntitySelection($0) },
      selectEntities: { handler.selectEntities($0, extendingSelection: $1) },
      selectConstraint: { handler.selectConstraint($0) },
      selectMeasurementAnnotation: { handler.selectMeasurementAnnotation($0) },
      selectFreeText: { handler.selectFreeText($0) },
      selectStitchStartPoint: { handler.selectStitchStartPoint($0) },
      updateFreeText: { handler.updateFreeText($0) },
      hoverConstraint: { handler.hoverConstraint($0) },
      selectTarget: { handler.selectTarget($0) },
      handleCanvasPlacement: { handler.handleCanvasPlacement($0, modifiers: $1) },
      handleCanvasHover: { handler.handleCanvasHover($0, modifiers: $1) },
      handleCanvasCursor: { handler.handleCanvasCursor($0, canvasPoint: $1) },
      previewMoveEntity: { handler.previewMoveEntity($0, delta: $1) },
      previewMoveEntities: { handler.previewMoveEntities($0, delta: $1, duplicating: $2) },
      previewMoveControlPoint: { handler.previewMoveControlPoint($0, to: $1) },
      cancelMovePreview: { handler.cancelMovePreview() },
      moveEntity: { handler.moveEntity($0, delta: $1) },
      moveEntities: { handler.moveEntities($0, delta: $1, duplicating: $2) },
      moveControlPoint: { handler.moveControlPoint($0, to: $1) },
      moveMeasurementAnnotation: {
        handler.moveMeasurementAnnotation(id: $0, delta: $1, labelOnly: $2)
      },
      moveDimensionConstraintAnnotation: {
        handler.moveDimensionConstraintAnnotation(constraintID: $0, delta: $1, labelOnly: $2)
      },
      convertMeasurementAnnotationToConstraint: {
        handler.convertMeasurementAnnotationToConstraint(id: $0)
      },
      panCanvas: { handler.panCanvas(by: $0) },
      setCanvasViewport: { handler.setCanvasViewport(scale: $0, panOffset: $1, message: $2) }
    )
  }
}

extension AppActionHandlers {
  var uiBindings: KawaCADUIBindings {
    KawaCADUIBindings(handler: self)
  }
}
