import Foundation

enum CanvasContextMenuAction: String, Hashable {
  case copySelection
  case pasteCopiedEntity
  case duplicateSelection
  case deleteSelection
  case convertMeasurementToConstraint
  case editFreeText
  case smoothArcTangenciesPrototype
  case selectAllEntities
}

struct CanvasContextMenuItem: Hashable {
  let title: String
  let action: CanvasContextMenuAction?
  var isDestructive: Bool = false

  static let separator = CanvasContextMenuItem(title: "", action: nil)
}
