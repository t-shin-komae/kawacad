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
  private(set) var renderInput: LeatherCanvasRenderInput
  private(set) var interactionInput: LeatherCanvasInteractionInput
  var commandExecutor: CanvasInteractionCommandExecutor
  var interactionController = CanvasInteractionController()
  var trackingArea: NSTrackingArea?
  let inlineFreeTextEditor = CanvasInlineTextEditorController()
  private var pointerInsideCanvas = false
  private var hasCursorTarget = false
  private var lastPointerPoint: CGPoint?
  private var registeredCursorKind: CanvasCursorKind?

  func interactionSnapshot() -> CanvasInteractionSnapshot {
    interactionController.snapshot
  }

  init(
    frame frameRect: NSRect,
    renderInput: LeatherCanvasRenderInput,
    interactionInput: LeatherCanvasInteractionInput,
    actionGroups: LeatherCanvasActionGroups
  ) {
    self.renderInput = renderInput
    self.interactionInput = interactionInput
    self.commandExecutor = CanvasInteractionCommandExecutor(actions: actionGroups)
    super.init(frame: frameRect)
    configureAccessibility()
  }

  required init?(coder: NSCoder) {
    return nil
  }

  override var isFlipped: Bool { true }
  override var acceptsFirstResponder: Bool { true }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    window?.acceptsMouseMovedEvents = true
  }

  private var cursorKind: CanvasCursorKind {
    CanvasCursorPolicy.cursor(
      for: CanvasCursorState(
        tool: selectedTool,
        outputPreview: isOutputPreviewMode,
        pointerInsideCanvas: pointerInsideCanvas,
        hasTarget: hasCursorTarget,
        inlineTextEditing: inlineFreeTextEditor.isEditing,
        settingPartOrigin: isSettingPartOrigin,
        movingContent: isMovingCanvasContent
      ))
  }

  override func resetCursorRects() {
    super.resetCursorRects()
    if let lastPointerPoint {
      let pageRect = pageRect(in: bounds)
      updatePointerState(at: lastPointerPoint, in: pageRect)
    }
    let kind = cursorKind
    addCursorRect(bounds, cursor: kind.nsCursor)
    registeredCursorKind = kind
    if pointerInsideCanvas {
      kind.nsCursor.set()
    }
  }

  override func cursorUpdate(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    let pageRect = pageRect(in: bounds)
    updatePointerState(at: point, in: pageRect)
    updateCursor()
  }

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

  private var isMovingCanvasContent: Bool {
    let snapshot = interactionSnapshot()
    let movingGeometry: Bool
    switch snapshot.dragState {
    case .entities, .controlPoint:
      movingGeometry = true
    case .marquee, nil:
      movingGeometry = false
    }
    return movingGeometry || snapshot.measurementDragState != nil
      || snapshot.dimensionConstraintDragState != nil || snapshot.freeTextDragState != nil
  }

  private func updateCursor() {
    let kind = cursorKind
    // Apply the current semantic state immediately. Rebuilding AppKit cursor
    // rects is only necessary when that state changes; doing it on every
    // mouse move races the asynchronous cursor-rect update against this set().
    if pointerInsideCanvas {
      kind.nsCursor.set()
    }
    guard registeredCursorKind != kind else { return }
    registeredCursorKind = kind
    window?.invalidateCursorRects(for: self)
  }

  private func refreshCursorTarget(at point: CGPoint, in pageRect: CGRect) {
    guard pointerInsideCanvas else {
      hasCursorTarget = false
      return
    }
    if selectedTool == .select {
      let input = selectionInput(
        at: point,
        in: pageRect,
        togglesSelection: false,
        modifiers: CanvasPlacementModifiers(),
        clickCount: 1
      )
      hasCursorTarget =
        input.measurementHit != nil || input.dimensionHit != nil
        || input.controlPointTarget != nil || input.constraintMarkerID != nil
        || input.stitchStartPointID != nil || input.freeTextID != nil || input.entityID != nil
      return
    }
    guard selectedTool.isConstraintTool || selectedTool.isMeasurementTool else {
      hasCursorTarget = false
      return
    }
    let target = preferredConstraintTarget(at: point, in: pageRect)
    hasCursorTarget = target.map { isValidConstraintTarget($0, for: selectedTool) } ?? false
  }

  private func updatePointerState(at point: CGPoint, in pageRect: CGRect) {
    lastPointerPoint = point
    pointerInsideCanvas = canvasBoundsRect(in: pageRect).contains(point)
    refreshCursorTarget(at: point, in: pageRect)
  }

  private var canvasInteractionDescription: String {
    if case .marquee(let startPoint, let currentPoint, _) = interactionSnapshot().dragState {
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
      options: [
        .activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect,
      ],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(area)
    trackingArea = area
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    let pageRect = pageRect(in: bounds)
    let plan = CanvasRenderPlan(gridVisible: gridVisible, outputPreview: isOutputPreviewMode)
    CanvasRenderer().draw(
      plan: plan,
      pageRect: pageRect,
      dirtyRect: dirtyRect,
      canvasBounds: bounds,
      on: self
    )
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
    let pointerInput = CanvasInteraction.pointerInput(for: event, in: self)
    let point = pointerInput.point
    let pageRect = pageRect(in: bounds)
    updateCursorPoint(for: point, in: pageRect)
    updateHoveredConstraintMarker(for: point, in: pageRect)
    updateHoveredConstraintTarget(for: point, in: pageRect)
    let interactionResult = interactionController.mouseDownResult(
      for: CanvasMouseDownInput(
        isInsideCanvas: canvasBoundsRect(in: pageRect).contains(point),
        selectedTool: selectedTool,
        isSettingPartOrigin: isSettingPartOrigin,
        modifiers: pointerInput.modifiers,
        placementPoint: placementModelPoint(
          for: point,
          in: pageRect,
          modifiers: pointerInput.modifiers
        ),
        linePoint: lineToolModelPoint(
          for: point,
          in: pageRect,
          modifiers: pointerInput.modifiers
        ),
        constraintTarget: preferredConstraintTarget(at: point, in: pageRect),
        selectionInput: selectedTool == .select
          ? selectionInput(
            at: point,
            in: pageRect,
            togglesSelection: pointerInput.togglesSelection,
            modifiers: pointerInput.modifiers,
            clickCount: pointerInput.clickCount
          )
          : nil
      )
    )

    commandExecutor.execute(interactionResult)
    if let freeTextID = interactionResult.inlineFreeTextID {
      beginInlineFreeTextEditor(id: freeTextID, in: pageRect)
    }
    if interactionResult.shouldRedraw {
      needsDisplay = true
    }
    updateCursor()
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
    let command = CanvasInteractionController.keyboardCommand(
      for: CanvasKeyboardInput(
        isEscape: event.keyCode == 53 || event.charactersIgnoringModifiers == "\u{1B}",
        isPlainTextSelectShortcut: event.isPlainTextShortcut("v"),
        isDelete: event.keyCode == 51 || event.keyCode == 117,
        selectedTool: selectedTool,
        hasCancellationTarget: hasCanvasCancellationTarget
      )
    )
    switch command {
    case .activateSelectTool:
      commandExecutor.execute(command)
    case .cancelInteraction:
      interactionController.handleKeyboardCommand(command)
      commandExecutor.execute(command)
      needsDisplay = true
    case .deleteSelection:
      commandExecutor.execute(command)
    case .unhandled:
      super.keyDown(with: event)
    }
    if command != .unhandled {
      needsDisplay = true
    }
  }

  private var hasCanvasCancellationTarget: Bool {
    interactionController.hasCancellationTarget(
      isSettingPartOrigin: isSettingPartOrigin,
      measurementAnnotationSelected: selectedMeasurementAnnotationID != nil,
      freeTextSelected: selectedFreeTextID != nil,
      draftStartPoint: draftStartPoint,
      draftCurrentPoint: draftCurrentPoint,
      draftArcStartPoint: draftArcStartPoint,
      pendingConstraintTargets: pendingConstraintTargets,
      selectedEntityID: selectedEntityID,
      selectedEntityIDs: selectedEntityIDs,
      selectedConstraintID: selectedConstraintID
    )
  }

  func drawSelectedPartOrigin(in pageRect: CGRect) {
    guard !isOutputPreviewMode, let selectedPartOrigin else { return }
    let point = coordinateSpace(in: pageRect).canvasPoint(for: selectedPartOrigin)
    let radius =
      isSettingPartOrigin
      ? CanvasVisualHierarchy.originRadius
      : CanvasVisualHierarchy.originRadius - 2
    let marker = NSBezierPath(
      ovalIn: CGRect(
        x: point.x - radius,
        y: point.y - radius,
        width: radius * 2,
        height: radius * 2
      ))
    CanvasVisualHierarchy.originFill.setFill()
    marker.fill()
    CanvasVisualHierarchy.originStroke.setStroke()
    marker.lineWidth = CanvasVisualHierarchy.originLineWidth
    marker.stroke()
    let path = NSBezierPath()
    path.move(to: CGPoint(x: point.x - radius, y: point.y))
    path.line(to: CGPoint(x: point.x + radius, y: point.y))
    path.move(to: CGPoint(x: point.x, y: point.y - radius))
    path.line(to: CGPoint(x: point.x, y: point.y + radius))
    path.lineWidth =
      isSettingPartOrigin
      ? CanvasVisualHierarchy.originLineWidth + 1
      : CanvasVisualHierarchy.originLineWidth
    CanvasVisualHierarchy.originStroke.setStroke()
    path.stroke()

    let ring = NSBezierPath(
      ovalIn: CGRect(
        x: point.x - radius / 2,
        y: point.y - radius / 2,
        width: radius,
        height: radius
      ))
    CanvasVisualHierarchy.originStroke.setStroke()
    ring.lineWidth = CanvasVisualHierarchy.originLineWidth
    ring.stroke()
  }

  override func mouseDragged(with event: NSEvent) {
    if interactionSnapshot().measurementDragState != nil {
      let point = convert(event.locationInWindow, from: nil)
      let pageRect = pageRect(in: bounds)
      let modelPoint = placementModelPoint(
        for: point, in: pageRect, modifiers: CanvasPlacementModifiers(event: event))
      interactionController.updateMeasurementDrag(to: modelPoint)
      updateCursor()
      needsDisplay = true
      return
    }
    if interactionSnapshot().dimensionConstraintDragState != nil {
      let point = convert(event.locationInWindow, from: nil)
      let pageRect = pageRect(in: bounds)
      let modelPoint = placementModelPoint(
        for: point, in: pageRect, modifiers: CanvasPlacementModifiers(event: event))
      interactionController.updateDimensionDrag(to: modelPoint)
      updateCursor()
      needsDisplay = true
      return
    }
    if interactionSnapshot().freeTextDragState != nil {
      let point = convert(event.locationInWindow, from: nil)
      let pageRect = pageRect(in: bounds)
      dragFreeTextInteraction(
        to: point, in: pageRect, modifiers: CanvasPlacementModifiers(event: event))
      updateCursor()
      return
    }

    guard selectedTool == .select, interactionSnapshot().dragState != nil else {
      return
    }
    let point = convert(event.locationInWindow, from: nil)
    let pageRect = pageRect(in: bounds)
    dragSelectInteraction(
      to: point, in: pageRect, modifiers: CanvasPlacementModifiers(event: event))
    updateCursor()
  }

  override func mouseUp(with event: NSEvent) {
    if interactionSnapshot().measurementDragState != nil {
      commandExecutor.execute(interactionController.finishMeasurementDragResult())
      updateCursor()
      needsDisplay = true
      return
    }
    if interactionSnapshot().dimensionConstraintDragState != nil {
      commandExecutor.execute(interactionController.finishDimensionDragResult())
      updateCursor()
      needsDisplay = true
      return
    }
    if interactionSnapshot().freeTextDragState != nil {
      endFreeTextInteraction()
      updateCursor()
      return
    }

    guard interactionSnapshot().dragState != nil else {
      return
    }
    let point = convert(event.locationInWindow, from: nil)
    endSelectInteraction(
      at: point, in: pageRect(in: bounds), modifiers: CanvasPlacementModifiers(event: event))
    updateCursor()
  }

  override func scrollWheel(with event: NSEvent) {
    guard event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty else {
      super.scrollWheel(with: event)
      return
    }
    let delta = CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY)
    guard let command = CanvasInteractionController.panCommand(delta: delta) else { return }
    commandExecutor.execute(command)
  }

  override func magnify(with event: NSEvent) {
    let anchorPoint = convert(event.locationInWindow, from: nil)
    let oldPageRect = pageRect(in: bounds)
    let anchorModelPoint = modelPoint(for: anchorPoint, in: oldPageRect)
    commandExecutor.execute(
      CanvasInteractionController.magnifyCommand(
        for: CanvasMagnifyInput(
          currentScale: zoomScale,
          magnification: event.magnification,
          anchorPoint: anchorPoint,
          anchorModelPoint: anchorModelPoint,
          canvasBounds: bounds,
          orientation: a4ReferenceOrientation,
          message: AppStrings.tr("canvas.status.changed_zoom")
        )))
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

    interactionController.setContextMenu(modelPoint: nil, freeTextID: nil)
    selectContextMenuTarget(at: point, in: pageRect)
    interactionController.setContextMenu(
      modelPoint: modelPoint(for: point, in: pageRect),
      freeTextID: interactionSnapshot().contextMenuFreeTextID
    )
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
    let result = interactionController.selectionResult(
      for: selectionInput(
        at: point,
        in: pageRect,
        togglesSelection: togglesSelection,
        modifiers: modifiers,
        clickCount: clickCount
      )
    )
    commandExecutor.execute(result.commands)
    if let freeTextID = result.inlineFreeTextID {
      beginInlineFreeTextEditor(id: freeTextID, in: pageRect)
    }
    refreshAccessibilityState()
  }

  private func selectionInput(
    at point: CGPoint,
    in pageRect: CGRect,
    togglesSelection: Bool,
    modifiers: CanvasPlacementModifiers,
    clickCount: Int
  ) -> CanvasSelectionInput {
    let measurementHit = measurementAnnotationHit(at: point, in: pageRect)
    let dimensionHit = dimensionConstraintAnnotationHit(at: point, in: pageRect)
    let controlPoint = controlPointTarget(at: point, in: pageRect, includeEditHandles: true)
    let constraintMarker = constraintMarker(at: point, in: pageRect)
    let stitchStartPointHit = stitchStartPoint(at: point, in: pageRect)
    let freeTextHit = freeText(at: point, in: pageRect)
    let entityTarget = entity(
      at: point,
      in: pageRect,
      preferring: selectedEntityIDs
    )?.entitySelectionTarget
    let modelPoint = placementModelPoint(
      for: point,
      in: pageRect,
      modifiers: modifiers,
      excluding: controlPoint ?? entityTarget
    )
    return CanvasSelectionInput(
      point: point,
      modelPoint: modelPoint,
      clickCount: clickCount,
      togglesSelection: togglesSelection,
      modifiers: modifiers,
      selectedEntityIDs: selectedEntityIDs,
      measurementHit: measurementHit.map { ($0.annotation.id, $0.labelOnly) },
      dimensionHit: dimensionHit.map { ($0.constraint.id, $0.labelOnly) },
      controlPointTarget: controlPoint,
      constraintMarkerID: constraintMarker?.constraintID,
      stitchStartPointID: stitchStartPointHit?.id,
      freeTextID: freeTextHit?.id,
      entityID: entityTarget?.entityID
    )
  }

  private func beginInlineFreeTextEditor(id: String, in pageRect: CGRect) {
    guard let freeText = freeTexts.first(where: { $0.id == id }) else {
      return
    }
    inlineFreeTextEditor.beginEditing(
      freeText, context: inlineTextEditorContext(in: pageRect), in: self)
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
    guard let dragState = interactionSnapshot().dragState else { return }
    let modelPoint = placementModelPoint(for: point, in: pageRect, modifiers: modifiers)
    let result = interactionController.dragResult(
      for: CanvasDragInput(
        state: dragState,
        currentPoint: point,
        currentModelPoint: modelPoint,
        modifiers: modifiers,
        marqueeSelection: []
      )
    )
    commandExecutor.execute(result)
    refreshAccessibilityState()
    needsDisplay = true
  }

  func dragFreeTextInteraction(
    to point: CGPoint,
    in pageRect: CGRect,
    modifiers: CanvasPlacementModifiers = CanvasPlacementModifiers()
  ) {
    guard !isOutputPreviewMode, interactionSnapshot().freeTextDragState != nil else {
      return
    }
    updateCursorPoint(for: point, in: pageRect)
    let modelPoint = placementModelPoint(for: point, in: pageRect, modifiers: modifiers)
    interactionController.updateFreeTextDrag(to: modelPoint)
    needsDisplay = true
  }

  private func endFreeTextInteraction() {
    let draggedID = interactionSnapshot().freeTextDragState?.freeTextID
    let freeText = draggedID.flatMap { id in freeTexts.first(where: { $0.id == id }) }
    commandExecutor.execute(interactionController.finishFreeTextDragResult(freeText: freeText))
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
    guard let dragState = interactionSnapshot().dragState else {
      return
    }
    interactionController.clearDragState()
    interactionController.clearSnap()
    updateCursorPoint(for: point, in: pageRect)
    let marqueeSelection: Set<String>
    if case .marquee(let startPoint, let currentPoint, _) = dragState {
      marqueeSelection = marqueeCandidateIDs(startPoint: startPoint, currentPoint: currentPoint)
    } else {
      marqueeSelection = []
    }
    let result = interactionController.endDragResult(
      for: CanvasDragInput(
        state: dragState,
        currentPoint: point,
        currentModelPoint: placementModelPoint(
          for: point,
          in: pageRect,
          modifiers: modifiers
        ),
        modifiers: modifiers,
        marqueeSelection: marqueeSelection
      )
    )
    commandExecutor.execute(result)
    refreshAccessibilityState()
    needsDisplay = true
  }

  func contextMenuItems(at point: CGPoint, in pageRect: CGRect) -> [CanvasContextMenuItem] {
    guard !isOutputPreviewMode else {
      return []
    }
    return CanvasContextMenuResolver.items(
      for: CanvasContextMenuAvailability(
        hasMeasurement: measurementAnnotationHit(at: point, in: pageRect) != nil,
        hasDimensionConstraint: dimensionConstraintAnnotationHit(at: point, in: pageRect) != nil,
        hasConstraintMarker: constraintMarker(at: point, in: pageRect) != nil,
        hasFreeText: freeText(at: point, in: pageRect) != nil,
        hasEntity: entity(at: point, in: pageRect) != nil,
        selectedSingleEntityIsArc: selectedSingleEntityIsArc
      ))
  }

  private func selectContextMenuTarget(at point: CGPoint, in pageRect: CGRect) {
    if let hit = measurementAnnotationHit(at: point, in: pageRect) {
      commandExecutor.selectMeasurementAnnotation(hit.annotation.id)
      return
    }
    if let hit = dimensionConstraintAnnotationHit(at: point, in: pageRect) {
      commandExecutor.selectConstraint(hit.constraint.id)
      return
    }
    if let marker = constraintMarker(at: point, in: pageRect) {
      commandExecutor.selectConstraint(marker.constraintID)
      return
    }
    if let freeText = freeText(at: point, in: pageRect) {
      interactionController.setContextMenu(
        modelPoint: interactionSnapshot().contextMenuModelPoint,
        freeTextID: freeText.id
      )
      commandExecutor.selectFreeText(freeText.id)
      return
    }
    guard let target = entity(at: point, in: pageRect)?.entitySelectionTarget else {
      return
    }
    if !selectedEntityIDs.contains(target.entityID), selectedEntityID != target.entityID {
      commandExecutor.selectEntity(target.entityID)
    }
  }

  @objc private func runContextMenuItem(_ sender: NSMenuItem) {
    guard let rawAction = sender.representedObject as? String,
      let action = CanvasContextMenuAction(rawValue: rawAction)
    else {
      return
    }
    guard
      let execution = interactionController.contextMenuExecution(
        for: action,
        selectedMeasurementID: selectedMeasurementAnnotationID,
        selectedFreeTextID: selectedFreeTextID
      )
    else { return }
    switch execution {
    case .command(let command):
      commandExecutor.execute(command)
    case .editFreeText(let id):
      guard let id, let freeText = freeTexts.first(where: { $0.id == id }) else { return }
      inlineFreeTextEditor.beginEditing(
        freeText,
        context: inlineTextEditorContext(in: pageRect(in: bounds)),
        in: self
      )
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
    updatePointerState(at: point, in: pageRect)
    updateCursorPoint(for: point, in: pageRect)
    updateHoveredConstraintMarker(for: point, in: pageRect)
    updateHoveredConstraintTarget(for: point, in: pageRect)
    updateCursor()
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
    commandExecutor.hoverPoint(modelPoint, modifiers: modifiers)
  }

  override func mouseEntered(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    let pageRect = pageRect(in: bounds)
    updatePointerState(at: point, in: pageRect)
    updateCursorPoint(for: point, in: pageRect)
    updateHoveredConstraintMarker(for: point, in: pageRect)
    updateHoveredConstraintTarget(for: point, in: pageRect)
    updateCursor()
  }

  override func mouseExited(with event: NSEvent) {
    pointerInsideCanvas = false
    hasCursorTarget = false
    lastPointerPoint = nil
    commandExecutor.clearHoverConstraint()
    commandExecutor.updateCursorPoint(nil, nil)
    interactionController.clearHover()
    updateCursor()
    needsDisplay = true
  }

  private func updateCursorPoint(for point: CGPoint, in pageRect: CGRect) {
    guard canvasBoundsRect(in: pageRect).contains(point) else {
      interactionController.clearSnap()
      commandExecutor.updateCursorPoint(nil, nil)
      interactionController.clearHover()
      needsDisplay = true
      return
    }

    commandExecutor.updateCursorPoint(snappedModelPoint(for: point, in: pageRect), point)
    needsDisplay = true
  }

  private func updateHoveredConstraintTarget(for point: CGPoint, in pageRect: CGRect) {
    guard !isOutputPreviewMode else {
      interactionController.clearHover()
      needsDisplay = true
      return
    }
    guard selectedTool.isConstraintTool || selectedTool.isMeasurementTool,
      canvasBoundsRect(in: pageRect).contains(point)
    else {
      interactionController.clearHover()
      needsDisplay = true
      return
    }
    let target = preferredConstraintTarget(at: point, in: pageRect)
    let resolvedTarget = target.flatMap {
      isValidConstraintTarget($0, for: selectedTool) ? $0 : nil
    }
    interactionController.updateHover(target: resolvedTarget, at: point)
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

  func configure(
    renderInput: LeatherCanvasRenderInput,
    interactionInput: LeatherCanvasInteractionInput,
    actionGroups: LeatherCanvasActionGroups
  ) {
    self.renderInput = renderInput
    self.interactionInput = interactionInput
    self.commandExecutor = CanvasInteractionCommandExecutor(actions: actionGroups)
    if let lastPointerPoint {
      let pageRect = pageRect(in: bounds)
      updatePointerState(at: lastPointerPoint, in: pageRect)
    }
    updateCursor()
  }

}

extension LeatherCanvasView: CanvasRenderPassDrawing {
  func drawCanvasBackground(dirtyRect: CGRect, canvasBounds: CGRect) {
    LeatherColors.canvasBackground.setFill()
    dirtyRect.fill()
    drawA4Page(in: canvasBounds)
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
