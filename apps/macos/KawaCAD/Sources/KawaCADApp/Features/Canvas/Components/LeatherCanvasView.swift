import AppKit
import KawaCADOutput
import SwiftUI

struct MeasurementAnnotationDragState {
  let annotationID: String
  let labelOnly: Bool
  let startPoint: ModelPoint
  var currentPoint: ModelPoint
}

struct DimensionConstraintAnnotationDragState {
  let constraintID: String
  let labelOnly: Bool
  let startPoint: ModelPoint
  var currentPoint: ModelPoint
}

struct FreeTextDragState {
  let freeTextID: String
  let startPoint: ModelPoint
  var currentPoint: ModelPoint
}

final class LeatherCanvasView: NSView {
  var entities: [CanvasEntity] = []
  var canvasProjection: LeatherCanvasProjection = .empty
  var documentConstraints: [ProjectConstraint] = []
  var freeTexts: [ProjectFreeText] = []
  var stitchStartPoints: [ProjectStitchStartPoint] = []
  var measurementAnnotations: [ProjectMeasurementAnnotation] = []
  var measurementEvaluations: [MeasurementEvaluation] = []
  var dimensionConstraintAnnotations: [ProjectDimensionConstraintAnnotation] = []
  var parameters: [ProjectParameter] = []
  var derivedElements: [ProjectDerivedElement] = []
  var layers: [ProjectLayer] = []
  var sharedStyles: [ProjectSharedStyle] = []
  var coincidentPointGroups: [CoincidentPointGroup] = []
  var selectedEntityID: String?
  var selectedEntityIDs: Set<String> = []
  var filletDraftEntityIDs: Set<String> = []
  var filletDraftClosed: Bool?
  var selectedConstraintID: String?
  var selectedMeasurementAnnotationID: String?
  var selectedFreeTextID: String?
  var selectedStitchStartPointID: String?
  var selectedPartOrigin: ModelPoint?
  var highlightedPartEntityIDs: Set<String> = []
  var highlightedPartFreeTextIDs: Set<String> = []
  var highlightedPartMeasurementAnnotationIDs: Set<String> = []
  var highlightedPartStitchStartPointIDs: Set<String> = []
  var isSettingPartOrigin: Bool = false
  var freeTextInlineEditRequestID: String?
  var hoveredConstraintID: String?
  var pendingConstraintTargets: [CanvasSelectionTarget] = []
  var hoveredConstraintTarget: CanvasSelectionTarget?
  var constraintHoverPoint: CGPoint?
  var viewMode: CanvasViewMode = .editDisplay
  var selectedTool: CanvasTool = .select
  var draftStartPoint: ModelPoint?
  var draftArcStartPoint: ModelPoint?
  var draftCurrentPoint: ModelPoint?
  var draftArcSweepAngleRad: Double?
  var gridVisible: Bool = true
  var a4ReferenceVisible: Bool = true
  var a4ReferenceOrientation: OutputPrintOrientation = .portrait
  var gridSnapEnabled: Bool = true
  var pointSnapEnabled: Bool = true
  var outputPreviewModel: OutputDocumentModel?
  var zoomScale: Double = 1.0
  var panOffset: CGSize = .zero
  var onSelectEntity: ((String?) -> Void)?
  var onToggleEntitySelection: ((String?) -> Void)?
  var onSelectEntities: ((Set<String>, Bool) -> Void)?
  var onSelectConstraint: ((String?) -> Void)?
  var onSelectMeasurementAnnotation: ((String?) -> Void)?
  var onSelectFreeText: ((String?) -> Void)?
  var onSelectStitchStartPoint: ((String?) -> Void)?
  var onSetPartOrigin: ((ModelPoint) -> Void)?
  var onUpdateFreeText: ((ProjectFreeText) -> Bool)?
  var onFreeTextInlineEditRequestHandled: ((String) -> Void)?
  var onHoverConstraint: ((String?) -> Void)?
  var onSelectTarget: ((CanvasSelectionTarget?) -> Void)?
  var onPlacePoint: ((ModelPoint, CanvasPlacementModifiers) -> Void)?
  var onHoverPoint: ((ModelPoint, CanvasPlacementModifiers) -> Void)?
  var onCursorPoint: ((ModelPoint?, CGPoint?) -> Void)?
  var onPreviewMoveEntity: ((String, ModelPoint) -> Void)?
  var onPreviewMoveEntities: ((Set<String>, ModelPoint, Bool) -> Void)?
  var onPreviewMoveControlPoint: ((CanvasSelectionTarget, ModelPoint) -> Void)?
  var onCancelMovePreview: (() -> Void)?
  var onMoveEntity: ((String, ModelPoint) -> Void)?
  var onMoveEntities: ((Set<String>, ModelPoint, Bool) -> Void)?
  var onMoveControlPoint: ((CanvasSelectionTarget, ModelPoint) -> Void)?
  var onMoveMeasurementAnnotation: ((String, ModelPoint, Bool) -> Void)?
  var onMoveDimensionConstraintAnnotation: ((String, ModelPoint, Bool) -> Void)?
  var onConvertMeasurementAnnotationToConstraint: ((String) -> Void)?
  var onSmoothSelectedArcTangenciesPrototype: (() -> Void)?
  var onCancelInteraction: (() -> Void)?
  var onActivateTool: ((CanvasTool) -> Void)?
  var onDeleteSelection: (() -> Void)?
  var onPanCanvas: ((CGSize) -> Void)?
  var onSetCanvasViewport: ((Double, CGSize, String) -> Void)?
  var onCopySelection: (() -> Void)?
  var onPasteCopiedEntity: (() -> Void)?
  var onPasteCopiedEntityAtPoint: ((ModelPoint) -> Void)?
  var onDuplicateSelection: (() -> Void)?
  var onSelectAllEntities: (() -> Void)?

  var trackingArea: NSTrackingArea?
  var interactionState = CanvasInteractionState()
  var dragState: CanvasDragState? {
    get { interactionState.dragState }
    set { interactionState.dragState = newValue }
  }
  var snapIndicatorPoint: ModelPoint?
  var snapSuppressionPoint: ModelPoint?
  var contextMenuModelPoint: ModelPoint?
  var contextMenuFreeTextID: String?
  var measurementDragState: MeasurementAnnotationDragState?
  var dimensionConstraintDragState: DimensionConstraintAnnotationDragState?
  var freeTextDragState: FreeTextDragState?
  let inlineFreeTextEditor = CanvasInlineTextEditorController()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    configureAccessibility()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    configureAccessibility()
  }

  override var isFlipped: Bool { true }
  override var acceptsFirstResponder: Bool { true }

  func refreshAccessibilityState() {
    setAccessibilityValue(canvasAccessibilityValue)
  }

  private func configureAccessibility() {
    setAccessibilityElement(true)
    setAccessibilityRole(.group)
    setAccessibilityIdentifier(AccessibilityIdentifier.workspaceCanvas)
    setAccessibilityLabel(AppStrings.tr("accessibility.canvas"))
    refreshAccessibilityState()
  }

  private var canvasAccessibilityValue: String {
    CanvasAccessibility.value(
      selectedTool: selectedTool,
      viewMode: viewMode,
      entityCount: entities.count,
      selectedEntityCount: selectedEntityIDs.count,
      pendingConstraintTargetCount: pendingConstraintTargets.count,
      interactionDescription: canvasInteractionDescription
    )
  }

  private var canvasInteractionDescription: String {
    if case .marquee(let startPoint, let currentPoint, _) = dragState {
      let mode = CanvasMarqueeSelectionMode(startPoint: startPoint, currentPoint: currentPoint)
      return AppStrings.tr(
        mode == .contained
          ? "accessibility.canvas.interaction.marquee_contained"
          : "accessibility.canvas.interaction.marquee_crossing",
        marqueeCandidateIDs(startPoint: startPoint, currentPoint: currentPoint).count
      )
    }
    if !filletDraftEntityIDs.isEmpty {
      return AppStrings.tr(
        "accessibility.canvas.interaction.fillet_draft",
        filletDraftEntityIDs.count,
        max(0, filletDraftEntityIDs.count - (filletDraftClosed == true ? 0 : 1)),
        filletDraftClosed == true
          ? AppStrings.tr("fillet.draft.closed") : AppStrings.tr("fillet.draft.open")
      )
    }
    if draftArcStartPoint != nil {
      return AppStrings.tr("accessibility.canvas.interaction.arc_end")
    }
    if draftStartPoint != nil {
      return AppStrings.tr("accessibility.canvas.interaction.next_point")
    }
    if !pendingConstraintTargets.isEmpty {
      return AppStrings.tr("accessibility.canvas.interaction.constraint_target")
    }
    return AppStrings.tr("accessibility.canvas.interaction.idle")
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let trackingArea {
      removeTrackingArea(trackingArea)
    }
    let area = NSTrackingArea(
      rect: bounds,
      options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(area)
    trackingArea = area
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    NSColor.underPageBackgroundColor.setFill()
    dirtyRect.fill()

    let pageRect = pageRect(in: bounds)
    drawA4Page(in: bounds)
    if gridVisible && !isOutputPreviewMode {
      drawGrid(in: bounds, pageRect: pageRect)
    }
    if !isOutputPreviewMode {
      drawCoordinateReference(in: pageRect)
    }
    drawEntities(in: pageRect)
    drawStitchStartPoints(in: pageRect)
    drawFreeTexts(in: pageRect)
    drawSelectedPartOrigin(in: pageRect)
    drawOutputPreviewTexts(in: pageRect)
    drawOutputPreviewPages()
    if !isOutputPreviewMode {
      drawSelectedConstraintTargets(in: pageRect)
      drawConstraintTargetFeedback(in: pageRect)
      drawCoincidentPointGroups(in: pageRect)
      drawDimensionConstraints(in: pageRect)
      drawMeasurementAnnotations(in: pageRect)
      drawConstraintMarkers(in: pageRect)
      drawDraftPreview(in: pageRect)
      drawSelectionMarquee()
      drawDragFeedback()
      drawSnapIndicator(in: pageRect)
    }
  }

  func outputPreviewPageRects(in rect: CGRect) -> [CGRect] {
    guard isOutputPreviewMode,
      let outputPreviewModel
    else {
      return []
    }
    let pageRect = pageRect(in: rect)
    let coordinateSpace = coordinateSpace(in: pageRect)
    return outputPreviewModel.pages.map { page in
      let pageCenter = ModelPoint(
        xMM: Double(page.gridColumn) * page.widthMm,
        yMM: Double(page.gridRow) * page.heightMm
      )
      let topLeft = coordinateSpace.canvasPoint(
        for: ModelPoint(
          xMM: pageCenter.xMM - page.widthMm / 2.0,
          yMM: pageCenter.yMM + page.heightMm / 2.0
        ))
      return CGRect(
        x: topLeft.x,
        y: topLeft.y,
        width: page.widthMm * coordinateSpace.scale,
        height: page.heightMm * coordinateSpace.scale
      )
    }
  }

  override func mouseDown(with event: NSEvent) {
    guard !isOutputPreviewMode else {
      return
    }
    if inlineFreeTextEditor.isEditing, event.clickCount < 2 {
      inlineFreeTextEditor.endEditing(commit: true, in: self)
    }
    window?.makeFirstResponder(self)
    let point = convert(event.locationInWindow, from: nil)
    let pageRect = pageRect(in: bounds)
    updateCursorPoint(for: point, in: pageRect)
    updateHoveredConstraintMarker(for: point, in: pageRect)
    updateHoveredConstraintTarget(for: point, in: pageRect)
    guard canvasBoundsRect(in: pageRect).contains(point) else {
      return
    }
    if isSettingPartOrigin {
      let modifiers = CanvasPlacementModifiers(event: event)
      onSetPartOrigin?(placementModelPoint(for: point, in: pageRect, modifiers: modifiers))
      needsDisplay = true
      return
    }

    switch selectedTool {
    case .select:
      let togglesSelection = event.modifierFlags.contains(.shift)
      beginSelectInteraction(
        at: point,
        in: pageRect,
        togglesSelection: togglesSelection,
        modifiers: CanvasPlacementModifiers(event: event),
        clickCount: event.clickCount
      )
    case .line:
      let modifiers = CanvasPlacementModifiers(event: event)
      onPlacePoint?(lineToolModelPoint(for: point, in: pageRect, modifiers: modifiers), modifiers)
    case .point, .circle, .roundHole, .stitchStartPoint, .arc, .freeText, .centerLine,
      .horizontalCenterLine, .verticalCenterLine:
      let modifiers = CanvasPlacementModifiers(event: event)
      onPlacePoint?(placementModelPoint(for: point, in: pageRect, modifiers: modifiers), modifiers)
    case .offset, .fillet, .horizontal, .vertical, .distance, .horizontalDistance,
      .verticalDistance, .lineLineDistance, .segmentLength,
      .coincident, .symmetric, .diameter, .radius, .fixed,
      .parallel, .perpendicular, .tangent, .equalLength, .angle, .pointOnLine,
      .measureDistance, .measureSegmentLength, .measureAngle, .measureRadius, .measureDiameter,
      .measureArcSweepAngle:
      onSelectTarget?(preferredConstraintTarget(at: point, in: pageRect))
    }
  }

  private func preferredConstraintTarget(at point: CGPoint, in pageRect: CGRect)
    -> CanvasSelectionTarget?
  {
    hitTesting(in: pageRect).preferredConstraintTarget(
      at: point,
      pendingTargets: pendingConstraintTargets
    )
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 || event.charactersIgnoringModifiers == "\u{1B}" {
      if selectedTool != .select && !hasCanvasCancellationTarget {
        onActivateTool?(.select)
      } else {
        dragState = nil
        measurementDragState = nil
        dimensionConstraintDragState = nil
        freeTextDragState = nil
        snapIndicatorPoint = nil
        onCancelInteraction?()
      }
      needsDisplay = true
      return
    }
    if event.isPlainTextShortcut("v") {
      onActivateTool?(.select)
      needsDisplay = true
      return
    }
    if event.keyCode == 51 || event.keyCode == 117 {
      onDeleteSelection?()
      return
    }
    super.keyDown(with: event)
  }

  private var hasCanvasCancellationTarget: Bool {
    if isSettingPartOrigin { return true }
    if measurementDragState != nil
      || dimensionConstraintDragState != nil
      || freeTextDragState != nil
      || selectedMeasurementAnnotationID != nil
      || selectedFreeTextID != nil
    {
      return true
    }
    return interactionState.hasCancellationTarget(
      draftStartPoint: draftStartPoint,
      draftCurrentPoint: draftCurrentPoint,
      draftArcStartPoint: draftArcStartPoint,
      pendingConstraintTargets: pendingConstraintTargets,
      selectedEntityID: selectedEntityID,
      selectedEntityIDs: selectedEntityIDs,
      selectedConstraintID: selectedConstraintID
    )
  }

  private func drawSelectedPartOrigin(in pageRect: CGRect) {
    guard !isOutputPreviewMode, let selectedPartOrigin else { return }
    let point = coordinateSpace(in: pageRect).canvasPoint(for: selectedPartOrigin)
    let radius: CGFloat = isSettingPartOrigin ? 8 : 6
    let path = NSBezierPath()
    path.move(to: CGPoint(x: point.x - radius, y: point.y))
    path.line(to: CGPoint(x: point.x + radius, y: point.y))
    path.move(to: CGPoint(x: point.x, y: point.y - radius))
    path.line(to: CGPoint(x: point.x, y: point.y + radius))
    path.lineWidth = isSettingPartOrigin ? 2.5 : 2
    NSColor.systemOrange.setStroke()
    path.stroke()

    let ring = NSBezierPath(
      ovalIn: CGRect(
        x: point.x - radius / 2,
        y: point.y - radius / 2,
        width: radius,
        height: radius
      ))
    ring.lineWidth = 1.5
    ring.stroke()
  }

  override func mouseDragged(with event: NSEvent) {
    if let measurementDragState {
      let point = convert(event.locationInWindow, from: nil)
      let pageRect = pageRect(in: bounds)
      let modelPoint = placementModelPoint(
        for: point, in: pageRect, modifiers: CanvasPlacementModifiers(event: event))
      self.measurementDragState = MeasurementAnnotationDragState(
        annotationID: measurementDragState.annotationID,
        labelOnly: measurementDragState.labelOnly,
        startPoint: measurementDragState.startPoint,
        currentPoint: modelPoint
      )
      needsDisplay = true
      return
    }
    if let dimensionConstraintDragState {
      let point = convert(event.locationInWindow, from: nil)
      let pageRect = pageRect(in: bounds)
      let modelPoint = placementModelPoint(
        for: point, in: pageRect, modifiers: CanvasPlacementModifiers(event: event))
      self.dimensionConstraintDragState = DimensionConstraintAnnotationDragState(
        constraintID: dimensionConstraintDragState.constraintID,
        labelOnly: dimensionConstraintDragState.labelOnly,
        startPoint: dimensionConstraintDragState.startPoint,
        currentPoint: modelPoint
      )
      needsDisplay = true
      return
    }
    if freeTextDragState != nil {
      let point = convert(event.locationInWindow, from: nil)
      let pageRect = pageRect(in: bounds)
      dragFreeTextInteraction(
        to: point, in: pageRect, modifiers: CanvasPlacementModifiers(event: event))
      return
    }

    guard selectedTool == .select, dragState != nil else {
      return
    }
    let point = convert(event.locationInWindow, from: nil)
    let pageRect = pageRect(in: bounds)
    dragSelectInteraction(
      to: point, in: pageRect, modifiers: CanvasPlacementModifiers(event: event))
  }

  override func mouseUp(with event: NSEvent) {
    if let measurementDragState {
      self.measurementDragState = nil
      let delta = CanvasInteractionState.delta(
        from: measurementDragState.startPoint,
        to: measurementDragState.currentPoint
      )
      if abs(delta.xMM) > 0.0001 || abs(delta.yMM) > 0.0001 {
        onMoveMeasurementAnnotation?(
          measurementDragState.annotationID,
          delta,
          measurementDragState.labelOnly
        )
      }
      needsDisplay = true
      return
    }
    if let dimensionConstraintDragState {
      self.dimensionConstraintDragState = nil
      let delta = CanvasInteractionState.delta(
        from: dimensionConstraintDragState.startPoint,
        to: dimensionConstraintDragState.currentPoint
      )
      if abs(delta.xMM) > 0.0001 || abs(delta.yMM) > 0.0001 {
        onMoveDimensionConstraintAnnotation?(
          dimensionConstraintDragState.constraintID,
          delta,
          dimensionConstraintDragState.labelOnly
        )
      }
      needsDisplay = true
      return
    }
    if let freeTextDragState {
      endFreeTextInteraction(freeTextDragState)
      return
    }

    guard dragState != nil else {
      return
    }
    let point = convert(event.locationInWindow, from: nil)
    endSelectInteraction(
      at: point, in: pageRect(in: bounds), modifiers: CanvasPlacementModifiers(event: event))
  }

  override func scrollWheel(with event: NSEvent) {
    guard event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty else {
      super.scrollWheel(with: event)
      return
    }
    let delta = CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY)
    guard abs(delta.width) > 0.01 || abs(delta.height) > 0.01 else {
      return
    }
    onPanCanvas?(delta)
  }

  override func magnify(with event: NSEvent) {
    let anchorPoint = convert(event.locationInWindow, from: nil)
    let oldPageRect = pageRect(in: bounds)
    let anchorModelPoint = modelPoint(for: anchorPoint, in: oldPageRect)
    let nextScale = min(max(zoomScale * (1.0 + Double(event.magnification)), 0.5), 3.0)
    let basePageRect = pageRect(in: bounds, zoomScale: nextScale, panOffset: .zero)
    let baseAnchorPoint = CanvasCoordinateSpace(
      pageRect: basePageRect,
      orientation: a4ReferenceOrientation
    ).canvasPoint(for: anchorModelPoint)
    let nextPanOffset = CGSize(
      width: anchorPoint.x - baseAnchorPoint.x,
      height: anchorPoint.y - baseAnchorPoint.y
    )
    onSetCanvasViewport?(nextScale, nextPanOffset, AppStrings.tr("canvas.status.changed_zoom"))
  }

  override func rightMouseDown(with event: NSEvent) {
    guard !isOutputPreviewMode else {
      return
    }
    window?.makeFirstResponder(self)
    let point = convert(event.locationInWindow, from: nil)
    let pageRect = pageRect(in: bounds)
    guard canvasBoundsRect(in: pageRect).contains(point) else {
      return
    }

    contextMenuFreeTextID = nil
    selectContextMenuTarget(at: point, in: pageRect)
    contextMenuModelPoint = modelPoint(for: point, in: pageRect)
    let items = contextMenuItems(at: point, in: pageRect)
    guard !items.isEmpty else {
      return
    }
    let menu = NSMenu()
    for item in items {
      if item.action == nil {
        menu.addItem(.separator())
        continue
      }
      let menuItem = NSMenuItem(
        title: item.title,
        action: #selector(runContextMenuItem(_:)),
        keyEquivalent: ""
      )
      menuItem.target = self
      menuItem.representedObject = item.action?.rawValue
      if item.isDestructive {
        menuItem.attributedTitle = NSAttributedString(
          string: item.title,
          attributes: [.foregroundColor: NSColor.systemRed]
        )
      }
      menu.addItem(menuItem)
    }
    NSMenu.popUpContextMenu(menu, with: event, for: self)
  }

  func beginSelectInteraction(
    at point: CGPoint,
    in pageRect: CGRect,
    togglesSelection: Bool = false,
    modifiers: CanvasPlacementModifiers = CanvasPlacementModifiers(),
    clickCount: Int = 1
  ) {
    guard !isOutputPreviewMode else {
      return
    }
    if let hit = measurementAnnotationHit(at: point, in: pageRect) {
      let modelPoint = placementModelPoint(for: point, in: pageRect, modifiers: modifiers)
      measurementDragState = MeasurementAnnotationDragState(
        annotationID: hit.annotation.id,
        labelOnly: hit.labelOnly,
        startPoint: modelPoint,
        currentPoint: modelPoint
      )
      onSelectMeasurementAnnotation?(hit.annotation.id)
      return
    }
    if let hit = dimensionConstraintAnnotationHit(at: point, in: pageRect) {
      let modelPoint = placementModelPoint(for: point, in: pageRect, modifiers: modifiers)
      dimensionConstraintDragState = DimensionConstraintAnnotationDragState(
        constraintID: hit.constraint.id,
        labelOnly: hit.labelOnly,
        startPoint: modelPoint,
        currentPoint: modelPoint
      )
      onSelectConstraint?(hit.constraint.id)
      return
    }

    let controlPoint = controlPointTarget(at: point, in: pageRect, includeEditHandles: true)
    let constraintMarker = constraintMarker(at: point, in: pageRect)
    let stitchStartPointHit = stitchStartPoint(at: point, in: pageRect)
    let freeTextHit = freeText(at: point, in: pageRect)
    let entityTarget = entity(
      at: point,
      in: pageRect,
      preferring: selectedEntityIDs
    )?.entitySelectionTarget
    if let target = controlPoint {
      let modelPoint = placementModelPoint(
        for: point, in: pageRect, modifiers: modifiers, excluding: target)
      dragState = .controlPoint(target: target, startPoint: modelPoint, currentPoint: modelPoint)
      if togglesSelection {
        onToggleEntitySelection?(target.entityID)
      } else {
        onSelectEntity?(target.entityID)
      }
    } else if let constraintMarker {
      dragState = nil
      onSelectConstraint?(constraintMarker.constraintID)
    } else if let stitchStartPointHit {
      dragState = nil
      onSelectStitchStartPoint?(stitchStartPointHit.id)
    } else if let freeTextHit {
      dragState = nil
      onSelectFreeText?(freeTextHit.id)
      if clickCount >= 2 {
        inlineFreeTextEditor.beginEditing(
          freeTextHit, context: inlineTextEditorContext(in: pageRect), in: self)
      } else {
        let modelPoint = placementModelPoint(for: point, in: pageRect, modifiers: modifiers)
        freeTextDragState = FreeTextDragState(
          freeTextID: freeTextHit.id,
          startPoint: modelPoint,
          currentPoint: modelPoint
        )
      }
    } else if let target = entityTarget {
      let modelPoint = placementModelPoint(
        for: point, in: pageRect, modifiers: modifiers, excluding: target)
      let draggingIDs =
        selectedEntityIDs.contains(target.entityID)
        ? selectedEntityIDs
        : [target.entityID]
      dragState = .entities(
        entityIDs: draggingIDs,
        anchorEntityID: target.entityID,
        startPoint: modelPoint,
        currentPoint: modelPoint,
        duplicating: modifiers.duplicatesOnDrag
      )
      if togglesSelection {
        onToggleEntitySelection?(target.entityID)
      } else if selectedEntityIDs.contains(target.entityID), selectedEntityIDs.count > 1 {
        onSelectEntities?(selectedEntityIDs, false)
      } else {
        onSelectEntity?(target.entityID)
      }
    } else {
      dragState = .marquee(
        startPoint: point,
        currentPoint: point,
        extendingSelection: togglesSelection
      )
      refreshAccessibilityState()
      if !togglesSelection {
        onSelectEntity?(nil)
        onSelectMeasurementAnnotation?(nil)
        onSelectFreeText?(nil)
        onSelectStitchStartPoint?(nil)
      }
    }
  }

  func dragSelectInteraction(
    to point: CGPoint,
    in pageRect: CGRect,
    modifiers: CanvasPlacementModifiers = CanvasPlacementModifiers()
  ) {
    guard !isOutputPreviewMode else {
      return
    }
    updateCursorPoint(for: point, in: pageRect)
    updateHoveredConstraintMarker(for: point, in: pageRect)
    guard canvasBoundsRect(in: pageRect).contains(point) else {
      return
    }
    let modelPoint = placementModelPoint(for: point, in: pageRect, modifiers: modifiers)
    switch dragState {
    case .entities(let entityIDs, let anchorEntityID, let startPoint, _, _):
      let duplicating = modifiers.duplicatesOnDrag
      dragState = .entities(
        entityIDs: entityIDs,
        anchorEntityID: anchorEntityID,
        startPoint: startPoint,
        currentPoint: modelPoint,
        duplicating: duplicating
      )
      let delta = CanvasInteractionState.delta(from: startPoint, to: modelPoint)
      if let onPreviewMoveEntities {
        onPreviewMoveEntities(entityIDs, delta, duplicating)
      } else if entityIDs.count == 1, let entityID = entityIDs.first, !duplicating {
        onPreviewMoveEntity?(entityID, delta)
      }
    case .controlPoint(let target, let startPoint, _):
      dragState = .controlPoint(target: target, startPoint: startPoint, currentPoint: modelPoint)
      onPreviewMoveControlPoint?(target, modelPoint)
    case .marquee(let startPoint, _, let extendingSelection):
      dragState = .marquee(
        startPoint: startPoint,
        currentPoint: point,
        extendingSelection: extendingSelection
      )
    case .none:
      break
    }
    refreshAccessibilityState()
    needsDisplay = true
  }

  func dragFreeTextInteraction(
    to point: CGPoint,
    in pageRect: CGRect,
    modifiers: CanvasPlacementModifiers = CanvasPlacementModifiers()
  ) {
    guard !isOutputPreviewMode,
      let freeTextDragState
    else {
      return
    }
    updateCursorPoint(for: point, in: pageRect)
    let modelPoint = placementModelPoint(for: point, in: pageRect, modifiers: modifiers)
    self.freeTextDragState = FreeTextDragState(
      freeTextID: freeTextDragState.freeTextID,
      startPoint: freeTextDragState.startPoint,
      currentPoint: modelPoint
    )
    needsDisplay = true
  }

  private func endFreeTextInteraction(_ freeTextDragState: FreeTextDragState) {
    self.freeTextDragState = nil
    let delta = CanvasInteractionState.delta(
      from: freeTextDragState.startPoint,
      to: freeTextDragState.currentPoint
    )
    if CanvasInteractionState.hasMeaningfulModelMovement(
      from: freeTextDragState.startPoint,
      to: freeTextDragState.currentPoint
    ), let freeText = freeTexts.first(where: { $0.id == freeTextDragState.freeTextID }) {
      _ = onUpdateFreeText?(
        freeText.withPosition(
          freeText.positionMM.translatedBy(dxMM: delta.xMM, dyMM: delta.yMM)
        )
      )
    }
    needsDisplay = true
  }

  func endSelectInteraction(
    at point: CGPoint,
    in pageRect: CGRect,
    modifiers: CanvasPlacementModifiers = CanvasPlacementModifiers()
  ) {
    guard !isOutputPreviewMode else {
      return
    }
    guard let dragState else {
      return
    }
    self.dragState = nil
    snapIndicatorPoint = nil
    updateCursorPoint(for: point, in: pageRect)
    switch dragState {
    case .entities(let entityIDs, _, let startPoint, let currentPoint, _):
      let duplicating = modifiers.duplicatesOnDrag
      let delta = CanvasInteractionState.delta(from: startPoint, to: currentPoint)
      if CanvasInteractionState.hasMeaningfulModelMovement(from: startPoint, to: currentPoint) {
        if let onMoveEntities {
          onMoveEntities(entityIDs, delta, duplicating)
        } else if entityIDs.count == 1, let entityID = entityIDs.first, !duplicating {
          onMoveEntity?(entityID, delta)
        }
      } else {
        onCancelMovePreview?()
      }
    case .controlPoint(let target, let startPoint, let currentPoint):
      if CanvasInteractionState.hasMeaningfulPointMovement(from: startPoint, to: currentPoint) {
        onMoveControlPoint?(target, currentPoint)
      } else {
        onCancelMovePreview?()
      }
    case .marquee(let startPoint, let currentPoint, let extendingSelection):
      let rect = CanvasInteractionState.normalizedRect(from: startPoint, to: currentPoint)
      guard rect.width > 3 || rect.height > 3 else {
        break
      }
      let selectedIDs = marqueeCandidateIDs(startPoint: startPoint, currentPoint: currentPoint)
      onSelectEntities?(selectedIDs, extendingSelection)
    }
    refreshAccessibilityState()
    needsDisplay = true
  }

  func contextMenuItems(at point: CGPoint, in pageRect: CGRect) -> [CanvasContextMenuItem] {
    guard !isOutputPreviewMode else {
      return []
    }
    if measurementAnnotationHit(at: point, in: pageRect) != nil {
      return [
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.convert_measurement_to_constraint"),
          action: .convertMeasurementToConstraint),
        CanvasContextMenuItem.separator,
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.delete_measurement_annotation"),
          action: .deleteSelection, isDestructive: true),
      ]
    }
    if dimensionConstraintAnnotationHit(at: point, in: pageRect) != nil {
      return [
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.delete_constraint"), action: .deleteSelection,
          isDestructive: true)
      ]
    }
    if constraintMarker(at: point, in: pageRect) != nil {
      return [
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.delete_constraint"), action: .deleteSelection,
          isDestructive: true)
      ]
    }
    if freeText(at: point, in: pageRect) != nil {
      return [
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.edit_free_text"), action: .editFreeText),
        CanvasContextMenuItem.separator,
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.delete_free_text"), action: .deleteSelection,
          isDestructive: true),
      ]
    }
    if entity(at: point, in: pageRect) != nil {
      var items = [
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.copy_selection"), action: .copySelection),
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.duplicate_selection"), action: .duplicateSelection),
        CanvasContextMenuItem.separator,
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.delete_selection"), action: .deleteSelection,
          isDestructive: true),
      ]
      if selectedSingleEntityIsArc {
        items.insert(CanvasContextMenuItem.separator, at: 2)
        items.insert(
          CanvasContextMenuItem(
            title: AppStrings.tr("canvas.menu.smooth_arc_tangencies_prototype"),
            action: .smoothArcTangenciesPrototype
          ),
          at: 2
        )
      }
      return items
    }
    return [
      CanvasContextMenuItem(
        title: AppStrings.tr("canvas.menu.paste_copied"), action: .pasteCopiedEntity),
      CanvasContextMenuItem(
        title: AppStrings.tr("canvas.menu.select_all"), action: .selectAllEntities),
    ]
  }

  private func selectContextMenuTarget(at point: CGPoint, in pageRect: CGRect) {
    if let hit = measurementAnnotationHit(at: point, in: pageRect) {
      onSelectMeasurementAnnotation?(hit.annotation.id)
      return
    }
    if let hit = dimensionConstraintAnnotationHit(at: point, in: pageRect) {
      onSelectConstraint?(hit.constraint.id)
      return
    }
    if let marker = constraintMarker(at: point, in: pageRect) {
      onSelectConstraint?(marker.constraintID)
      return
    }
    if let freeText = freeText(at: point, in: pageRect) {
      contextMenuFreeTextID = freeText.id
      onSelectFreeText?(freeText.id)
      return
    }
    guard let target = entity(at: point, in: pageRect)?.entitySelectionTarget else {
      return
    }
    if !selectedEntityIDs.contains(target.entityID), selectedEntityID != target.entityID {
      onSelectEntity?(target.entityID)
    }
  }

  @objc private func runContextMenuItem(_ sender: NSMenuItem) {
    guard let rawAction = sender.representedObject as? String,
      let action = CanvasContextMenuAction(rawValue: rawAction)
    else {
      return
    }
    switch action {
    case .copySelection:
      onCopySelection?()
    case .pasteCopiedEntity:
      if let contextMenuModelPoint {
        onPasteCopiedEntityAtPoint?(contextMenuModelPoint)
      } else {
        onPasteCopiedEntity?()
      }
      self.contextMenuModelPoint = nil
    case .duplicateSelection:
      onDuplicateSelection?()
    case .deleteSelection:
      onDeleteSelection?()
      contextMenuFreeTextID = nil
    case .editFreeText:
      if let freeText = contextMenuFreeText ?? selectedFreeText {
        inlineFreeTextEditor.beginEditing(
          freeText, context: inlineTextEditorContext(in: pageRect(in: bounds)), in: self)
      }
      contextMenuFreeTextID = nil
    case .convertMeasurementToConstraint:
      if let selectedMeasurementAnnotationID {
        onConvertMeasurementAnnotationToConstraint?(selectedMeasurementAnnotationID)
      }
    case .smoothArcTangenciesPrototype:
      onSmoothSelectedArcTangenciesPrototype?()
    case .selectAllEntities:
      onSelectAllEntities?()
    }
  }

  private var selectedSingleEntityIsArc: Bool {
    guard selectedEntityIDs.count == 1,
      let selectedID = selectedEntityID,
      selectedEntityIDs.contains(selectedID),
      let entity = entities.first(where: { $0.id == selectedID })
    else {
      return false
    }
    if case .arc = entity.geometry {
      return true
    }
    return false
  }

  override func mouseMoved(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    let pageRect = pageRect(in: bounds)
    updateCursorPoint(for: point, in: pageRect)
    updateHoveredConstraintMarker(for: point, in: pageRect)
    updateHoveredConstraintTarget(for: point, in: pageRect)
    guard !isOutputPreviewMode else {
      return
    }
    guard canvasBoundsRect(in: pageRect).contains(point) else {
      return
    }
    guard draftStartPoint != nil else {
      return
    }
    let modifiers = CanvasPlacementModifiers(event: event)
    let modelPoint =
      selectedTool == .line
      ? lineToolModelPoint(for: point, in: pageRect, modifiers: modifiers)
      : placementModelPoint(for: point, in: pageRect, modifiers: modifiers)
    onHoverPoint?(modelPoint, modifiers)
  }

  override func mouseExited(with event: NSEvent) {
    onHoverConstraint?(nil)
    onCursorPoint?(nil, nil)
    hoveredConstraintTarget = nil
    constraintHoverPoint = nil
    needsDisplay = true
  }

  private func updateCursorPoint(for point: CGPoint, in pageRect: CGRect) {
    guard canvasBoundsRect(in: pageRect).contains(point) else {
      snapIndicatorPoint = nil
      snapSuppressionPoint = nil
      onCursorPoint?(nil, nil)
      hoveredConstraintTarget = nil
      constraintHoverPoint = nil
      needsDisplay = true
      return
    }

    onCursorPoint?(snappedModelPoint(for: point, in: pageRect), point)
    needsDisplay = true
  }

  private func updateHoveredConstraintTarget(for point: CGPoint, in pageRect: CGRect) {
    guard !isOutputPreviewMode else {
      hoveredConstraintTarget = nil
      constraintHoverPoint = nil
      needsDisplay = true
      return
    }
    guard selectedTool.isConstraintTool || selectedTool.isMeasurementTool,
      canvasBoundsRect(in: pageRect).contains(point)
    else {
      hoveredConstraintTarget = nil
      constraintHoverPoint = nil
      needsDisplay = true
      return
    }
    let target = preferredConstraintTarget(at: point, in: pageRect)
    hoveredConstraintTarget = target.flatMap {
      isValidConstraintTarget($0, for: selectedTool) ? $0 : nil
    }
    constraintHoverPoint = hoveredConstraintTarget == nil ? nil : point
    needsDisplay = true
  }

  private func isValidConstraintTarget(_ target: CanvasSelectionTarget, for tool: CanvasTool)
    -> Bool
  {
    CanvasHitTesting(
      displayEntities: visibleEntities,
      derivedElements: derivedElements,
      selectedTool: tool,
      coordinateSpace: coordinateSpace(in: pageRect(in: bounds))
    ).isValidConstraintTarget(target, pendingTargetCount: pendingConstraintTargets.count)
  }

}

extension CGPoint {
  func offsetBy(dx: CGFloat, dy: CGFloat) -> CGPoint {
    CGPoint(x: x + dx, y: y + dy)
  }
}

struct CanvasLineStyle {
  let color: NSColor
  let lineWidth: CGFloat
  let pattern: LinePattern
  let dashPattern: [CGFloat]?

  init(
    color: NSColor,
    lineWidth: CGFloat,
    pattern: LinePattern,
    dashPattern: [CGFloat]? = nil
  ) {
    self.color = color
    self.lineWidth = lineWidth
    self.pattern = pattern
    self.dashPattern = dashPattern
  }

  func distinguished(for entity: CanvasEntity) -> CanvasLineStyle {
    if entity.isSuppressedByFillet {
      return CanvasLineStyle(
        color: color.withAlphaComponent(0.26),
        lineWidth: max(1, lineWidth * 0.75),
        pattern: .dashed,
        dashPattern: [lineWidth * 3.0, lineWidth * 2.4]
      )
    }
    guard entity.isCenterLine else {
      return self
    }
    return CanvasLineStyle(
      color: NSColor(calibratedRed: 0.075, green: 0.365, blue: 0.612, alpha: 0.88),
      lineWidth: max(1, lineWidth * 0.9),
      pattern: .construction,
      dashPattern: [
        lineWidth * 6.0,
        lineWidth * 2.0,
        lineWidth * 1.2,
        lineWidth * 2.0,
      ]
    )
  }
}

extension NSColor {
  convenience init(hex: String) {
    let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    var rgb: UInt64 = 0
    Scanner(string: value).scanHexInt64(&rgb)

    self.init(
      calibratedRed: CGFloat((rgb >> 16) & 0xFF) / 255.0,
      green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
      blue: CGFloat(rgb & 0xFF) / 255.0,
      alpha: 1.0
    )
  }
}

extension NSEvent {
  fileprivate func isPlainTextShortcut(_ key: String) -> Bool {
    let disallowedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
    guard modifierFlags.intersection(disallowedModifiers).isEmpty else {
      return false
    }
    return charactersIgnoringModifiers?.lowercased() == key
  }
}
