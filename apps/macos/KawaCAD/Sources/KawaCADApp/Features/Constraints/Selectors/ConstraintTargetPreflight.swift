struct ConstraintTargetPreflight {
  static func supportsOffsetTarget(_ target: CanvasSelectionTarget) -> Bool {
    target.isLineTarget
      || target.entityKind == .circle
      || target.entityKind == .arc
      || target.entityKind == .centerLine
  }

  static func supportsFilletTarget(_ target: CanvasSelectionTarget) -> Bool {
    target.isLineTarget || target.entityKind == .arc
  }

  static func pointTarget(
    from target: CanvasSelectionTarget,
    fallbackEntity entity: CanvasEntity
  ) -> CanvasSelectionTarget? {
    _ = entity
    return target
  }

  static func pointOrLineTarget(
    from target: CanvasSelectionTarget,
    fallbackEntity entity: CanvasEntity
  ) -> CanvasSelectionTarget? {
    pointTarget(from: target, fallbackEntity: entity)
  }

  static func allowsDerivedTarget(
    tool: CanvasTool,
    entity: CanvasEntity,
    selectedDerivedElement: ProjectDerivedElement?
  ) -> Bool {
    tool.targetSelectionSpec.derivedTargetPolicy == .allow
      || allowsFilletRadiusEdit(
        tool: tool,
        entity: entity,
        selectedDerivedElement: selectedDerivedElement
      )
  }

  static func shouldEditSelectedFilletRadius(
    tool: CanvasTool,
    entity: CanvasEntity,
    selectedDerivedElement: ProjectDerivedElement?
  ) -> Bool {
    allowsFilletRadiusEdit(
      tool: tool,
      entity: entity,
      selectedDerivedElement: selectedDerivedElement
    )
  }

  private static func allowsFilletRadiusEdit(
    tool: CanvasTool,
    entity: CanvasEntity,
    selectedDerivedElement: ProjectDerivedElement?
  ) -> Bool {
    guard tool == .radius,
      selectedDerivedElement?.kind == .fillet,
      case .arc = entity.geometry
    else {
      return false
    }
    return true
  }
}
