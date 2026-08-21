import AppKit
import KawaCADOutput

/// Converts AppKit pointer events into the small input value consumed by the
/// existing Canvas interaction methods.
struct CanvasPointerInput {
  let point: CGPoint
  let clickCount: Int
  let togglesSelection: Bool
  let modifiers: CanvasPlacementModifiers
}

enum CanvasInteractionCommand {
  case setPartOrigin(ModelPoint)
  case placePoint(ModelPoint, CanvasPlacementModifiers)
  case selectConstraintTarget(CanvasSelectionTarget?)
  case previewMoveEntities(Set<String>, ModelPoint, Bool)
  case previewMoveControlPoint(CanvasSelectionTarget, ModelPoint)
  case previewMoveEntity(String, ModelPoint)
  case moveEntities(Set<String>, ModelPoint, Bool)
  case moveControlPoint(CanvasSelectionTarget, ModelPoint)
  case moveEntity(String, ModelPoint)
  case cancelMovePreview
  case selectEntities(Set<String>, Bool)
  case moveMeasurementAnnotation(String, ModelPoint, Bool)
  case moveDimensionConstraintAnnotation(String, ModelPoint, Bool)
  case updateFreeText(ProjectFreeText)
  case panCanvas(CGSize)
  case setCanvasViewport(Double, CGSize, String)
  case copySelection
  case pasteCopiedEntity(ModelPoint?)
  case duplicateSelection
  case deleteSelection
  case convertMeasurementToConstraint(String)
  case smoothSelectedArcTangencies
  case selectAllEntities
}

struct CanvasMagnifyInput {
  let currentScale: Double
  let magnification: CGFloat
  let anchorPoint: CGPoint
  let anchorModelPoint: ModelPoint
  let canvasBounds: CGRect
  let orientation: OutputPrintOrientation
  let message: String
}

struct CanvasContextMenuAvailability {
  let hasMeasurement: Bool
  let hasDimensionConstraint: Bool
  let hasConstraintMarker: Bool
  let hasFreeText: Bool
  let hasEntity: Bool
  let selectedSingleEntityIsArc: Bool
}

enum CanvasContextMenuExecution {
  case command(CanvasInteractionCommand)
  case editFreeText(String?)
}

struct CanvasContextMenuResolver {
  static func items(for availability: CanvasContextMenuAvailability) -> [CanvasContextMenuItem] {
    if availability.hasMeasurement {
      return [
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.convert_measurement_to_constraint"),
          action: .convertMeasurementToConstraint),
        .separator,
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.delete_measurement_annotation"),
          action: .deleteSelection,
          isDestructive: true),
      ]
    }
    if availability.hasDimensionConstraint || availability.hasConstraintMarker {
      return [
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.delete_constraint"),
          action: .deleteSelection,
          isDestructive: true)
      ]
    }
    if availability.hasFreeText {
      return [
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.edit_free_text"), action: .editFreeText),
        .separator,
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.delete_free_text"),
          action: .deleteSelection,
          isDestructive: true),
      ]
    }
    if availability.hasEntity {
      var items = [
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.copy_selection"), action: .copySelection),
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.duplicate_selection"), action: .duplicateSelection),
        .separator,
        CanvasContextMenuItem(
          title: AppStrings.tr("canvas.menu.delete_selection"),
          action: .deleteSelection,
          isDestructive: true),
      ]
      if availability.selectedSingleEntityIsArc {
        items.insert(.separator, at: 2)
        items.insert(
          CanvasContextMenuItem(
            title: AppStrings.tr("canvas.menu.smooth_arc_tangencies_prototype"),
            action: .smoothArcTangenciesPrototype),
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
}

struct CanvasInteractionResult {
  let command: CanvasInteractionCommand?
  let selectionCommands: [CanvasSelectionCommand]
  let inlineFreeTextID: String?
  let nextDragState: CanvasDragState?
  let shouldRedraw: Bool

  init(
    command: CanvasInteractionCommand?,
    selectionCommands: [CanvasSelectionCommand] = [],
    inlineFreeTextID: String? = nil,
    nextDragState: CanvasDragState? = nil,
    shouldRedraw: Bool
  ) {
    self.command = command
    self.selectionCommands = selectionCommands
    self.inlineFreeTextID = inlineFreeTextID
    self.nextDragState = nextDragState
    self.shouldRedraw = shouldRedraw
  }
}

struct CanvasMouseDownInput {
  let isInsideCanvas: Bool
  let selectedTool: CanvasTool
  let isSettingPartOrigin: Bool
  let modifiers: CanvasPlacementModifiers
  let placementPoint: ModelPoint
  let linePoint: ModelPoint
  let constraintTarget: CanvasSelectionTarget?
  let selectionInput: CanvasSelectionInput?

  init(
    isInsideCanvas: Bool,
    selectedTool: CanvasTool,
    isSettingPartOrigin: Bool,
    modifiers: CanvasPlacementModifiers,
    placementPoint: ModelPoint,
    linePoint: ModelPoint,
    constraintTarget: CanvasSelectionTarget?,
    selectionInput: CanvasSelectionInput? = nil
  ) {
    self.isInsideCanvas = isInsideCanvas
    self.selectedTool = selectedTool
    self.isSettingPartOrigin = isSettingPartOrigin
    self.modifiers = modifiers
    self.placementPoint = placementPoint
    self.linePoint = linePoint
    self.constraintTarget = constraintTarget
    self.selectionInput = selectionInput
  }
}

struct CanvasDragInput {
  let state: CanvasDragState
  let currentPoint: CGPoint
  let currentModelPoint: ModelPoint
  let modifiers: CanvasPlacementModifiers
  let marqueeSelection: Set<String>
}

struct CanvasInteraction {
  static func pointerInput(for event: NSEvent, in view: NSView) -> CanvasPointerInput {
    CanvasPointerInput(
      point: view.convert(event.locationInWindow, from: nil),
      clickCount: event.clickCount,
      togglesSelection: event.modifierFlags.contains(.shift),
      modifiers: CanvasPlacementModifiers(event: event)
    )
  }

  static func mouseDownResult(for input: CanvasMouseDownInput) -> CanvasInteractionResult {
    guard input.isInsideCanvas else {
      return CanvasInteractionResult(command: nil, shouldRedraw: false)
    }
    if input.isSettingPartOrigin {
      return CanvasInteractionResult(
        command: .setPartOrigin(input.placementPoint),
        shouldRedraw: true
      )
    }

    switch input.selectedTool {
    case .select:
      return CanvasInteractionResult(command: nil, shouldRedraw: false)
    case .line:
      return CanvasInteractionResult(
        command: .placePoint(input.linePoint, input.modifiers),
        shouldRedraw: false
      )
    case .point, .circle, .roundHole, .stitchStartPoint, .arc, .freeText, .centerLine,
      .horizontalCenterLine, .verticalCenterLine:
      return CanvasInteractionResult(
        command: .placePoint(input.placementPoint, input.modifiers),
        shouldRedraw: false
      )
    case .offset, .fillet, .horizontal, .vertical, .distance, .horizontalDistance,
      .verticalDistance, .lineLineDistance, .segmentLength,
      .coincident, .symmetric, .diameter, .radius, .fixed,
      .parallel, .perpendicular, .tangent, .equalLength, .angle, .pointOnLine,
      .measureDistance, .measureSegmentLength, .measureAngle, .measureRadius, .measureDiameter,
      .measureArcSweepAngle:
      return CanvasInteractionResult(
        command: .selectConstraintTarget(input.constraintTarget),
        shouldRedraw: false
      )
    }
  }

  static func dragResult(for input: CanvasDragInput) -> CanvasInteractionResult {
    switch input.state {
    case .entities(let entityIDs, let anchorEntityID, let startPoint, _, _):
      let duplicating = input.modifiers.duplicatesOnDrag
      let nextState = CanvasDragState.entities(
        entityIDs: entityIDs,
        anchorEntityID: anchorEntityID,
        startPoint: startPoint,
        currentPoint: input.currentModelPoint,
        duplicating: duplicating
      )
      let command: CanvasInteractionCommand
      if entityIDs.count == 1, let entityID = entityIDs.first, !duplicating {
        command = .previewMoveEntity(
          entityID,
          CanvasInteractionState.delta(
            from: startPoint,
            to: input.currentModelPoint
          ))
      } else {
        command = .previewMoveEntities(
          entityIDs,
          CanvasInteractionState.delta(from: startPoint, to: input.currentModelPoint),
          duplicating
        )
      }
      return CanvasInteractionResult(command: command, nextDragState: nextState, shouldRedraw: true)
    case .controlPoint(let target, let startPoint, _):
      return CanvasInteractionResult(
        command: .previewMoveControlPoint(target, input.currentModelPoint),
        nextDragState: .controlPoint(
          target: target,
          startPoint: startPoint,
          currentPoint: input.currentModelPoint
        ),
        shouldRedraw: true
      )
    case .marquee(let startPoint, _, let extendingSelection):
      return CanvasInteractionResult(
        command: nil,
        nextDragState: .marquee(
          startPoint: startPoint,
          currentPoint: input.currentPoint,
          extendingSelection: extendingSelection
        ),
        shouldRedraw: true
      )
    }
  }

  static func endDragResult(for input: CanvasDragInput) -> CanvasInteractionResult {
    switch input.state {
    case .entities(let entityIDs, _, let startPoint, let currentPoint, _):
      let delta = CanvasInteractionState.delta(from: startPoint, to: currentPoint)
      let command: CanvasInteractionCommand
      if CanvasInteractionState.hasMeaningfulModelMovement(from: startPoint, to: currentPoint) {
        if entityIDs.count == 1, let entityID = entityIDs.first, !input.modifiers.duplicatesOnDrag {
          command = .moveEntity(entityID, delta)
        } else {
          command = .moveEntities(entityIDs, delta, input.modifiers.duplicatesOnDrag)
        }
      } else {
        command = .cancelMovePreview
      }
      return CanvasInteractionResult(command: command, shouldRedraw: true)
    case .controlPoint(let target, let startPoint, let currentPoint):
      let command: CanvasInteractionCommand =
        CanvasInteractionState.hasMeaningfulPointMovement(from: startPoint, to: currentPoint)
        ? .moveControlPoint(target, currentPoint)
        : .cancelMovePreview
      return CanvasInteractionResult(command: command, shouldRedraw: true)
    case .marquee(let startPoint, let currentPoint, let extendingSelection):
      let rect = CanvasInteractionState.normalizedRect(from: startPoint, to: currentPoint)
      let command =
        rect.width > 3 || rect.height > 3
        ? CanvasInteractionCommand.selectEntities(input.marqueeSelection, extendingSelection)
        : nil
      return CanvasInteractionResult(command: command, shouldRedraw: true)
    }
  }
}
