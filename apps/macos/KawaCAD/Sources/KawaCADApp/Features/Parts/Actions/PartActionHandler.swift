import Foundation

extension PartActionHandler {
  func createPartFromSelection() {
    let selected = selectedEntities
    guard !selected.isEmpty else {
      statusMessage = AppStrings.tr("status.part_select_closed_outline")
      return
    }
    let name = AppStrings.tr("part.default_name", parts.count + 1)
    let request = commandFactory.makeCreatePartCommand(
      name: name,
      entityIDs: selected.map(\.id)
    )
    guard executeDocumentCommand(request) else { return }
    if let createdID = currentDocumentState?.mutation?.created.partIDs.last,
      let created = parts.first(where: { $0.id == createdID })
    {
      selectPartContents(created)
    }
  }

  @discardableResult
  func updatePart(_ part: ProjectPart) -> Bool {
    let name = part.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      statusMessage = AppStrings.tr("status.part_name_origin_required")
      return false
    }
    guard
      !parts.contains(where: {
        $0.id != part.id && $0.name.trimmingCharacters(in: .whitespacesAndNewlines) == name
      })
    else {
      statusMessage = AppStrings.tr("status.part_name_unique")
      return false
    }
    return executeDocumentCommand(commandFactory.makeRenamePartCommand(partID: part.id, name: name))
  }

  @discardableResult
  func updatePartSettings(_ part: ProjectPart) -> Bool {
    guard part.quantity >= 1 else {
      statusMessage = AppStrings.tr("status.part_quantity_required")
      return false
    }
    guard let current = parts.first(where: { $0.id == part.id }) else { return false }
    if current.visible != part.visible {
      return executeDocumentCommand(
        commandFactory.makeSetPartVisibilityCommand(
          partID: part.id, visible: part.visible, name: part.name))
    }
    if current.printable != part.printable {
      return executeDocumentCommand(
        commandFactory.makeSetPartPrintableCommand(
          partID: part.id, printable: part.printable, name: part.name))
    }
    if current.quantity != part.quantity {
      return executeDocumentCommand(
        commandFactory.makeSetPartQuantityCommand(
          partID: part.id, quantity: part.quantity, name: part.name))
    }
    return true
  }

  func togglePartArrangementSelection(_ part: ProjectPart) {
    inspectorPresentation.toggleArrangementSelection(for: part.id)
  }

  func alignSelectedParts(_ alignment: String) {
    let ids = inspectorPresentation.arrangementSelectedPartIDs
      .filter { id in parts.contains(where: { $0.id == id }) }
      .sorted()
    guard ids.count >= 2 else {
      statusMessage = AppStrings.tr("status.parts_select_two")
      return
    }
    _ = executeDocumentCommand(
      commandFactory.makeAlignPartsCommand(partIDs: ids, alignment: alignment))
  }

  func distributeSelectedParts(_ axis: String) {
    let ids = inspectorPresentation.arrangementSelectedPartIDs
      .filter { id in parts.contains(where: { $0.id == id }) }
      .sorted()
    guard ids.count >= 3 else {
      statusMessage = AppStrings.tr("status.parts_select_three")
      return
    }
    _ = executeDocumentCommand(commandFactory.makeDistributePartsCommand(partIDs: ids, axis: axis))
  }

  func addPartToLibrary(_ part: ProjectPart) {
    switch cadSession.exportPartLibraryItem(partID: part.id) {
    case .success(let export):
      do {
        try partLibraryState.addOrReplace(
          PartLibraryEntry(
            id: UUID().uuidString.lowercased(),
            name: part.name,
            sourcePart: export.sourcePart,
            clipboardJSON: export.libraryJSON,
            createdAt: Date()
          ))
        statusMessage = AppStrings.tr("status.part_library_added", part.name)
      } catch {
        statusMessage = AppStrings.tr("status.part_library_save_failed", error.localizedDescription)
      }
    case .failure(let failure):
      presentCoreFailure(failure, operation: "exportPartLibraryItem")
    }
  }

  func removePartLibraryEntry(_ entry: PartLibraryEntry) {
    do {
      try partLibraryState.remove(entry)
      statusMessage = AppStrings.tr("status.part_library_removed", entry.name)
    } catch {
      statusMessage = AppStrings.tr("status.part_library_save_failed", error.localizedDescription)
    }
  }

  func insertPartFromLibrary(_ entry: PartLibraryEntry) {
    let target =
      canvasPresentation.cursorModelPoint
      ?? ModelPoint(
        xMM: (parts.map(\.originMM.xMM).max() ?? -30) + 30,
        yMM: parts.map(\.originMM.yMM).max() ?? 0
      )
    let delta = ModelPoint(
      xMM: target.xMM - entry.sourcePart.originMM.xMM,
      yMM: target.yMM - entry.sourcePart.originMM.yMM
    )
    let name = PartFeature.uniqueName(
      sourceName: entry.name,
      existingNames: Set(parts.map(\.name)),
      copiesSourceName: false
    )
    let request = commandFactory.makeInsertLibraryPartCommand(
      entry: entry, newName: name, delta: delta)
    guard executeDocumentCommand(request),
      let insertedPartID = currentDocumentState?.mutation?.created.partIDs.last,
      let inserted = parts.first(where: { $0.id == insertedPartID })
    else { return }
    selectPartContents(inserted)
  }

  func deletePart(_ part: ProjectPart) {
    guard executeDocumentCommand(commandFactory.makeDeletePartCommand(part)) else { return }
    inspectorPresentation.removeArrangementSelection(for: part.id)
    if inspectorPresentation.selectedPartID == part.id {
      inspectorPresentation.setSelectedPartID(nil)
      inspectorPresentation.setIsSettingPartOrigin(false)
    }
  }

  func selectPartContents(_ part: ProjectPart) {
    inspectorPresentation.setSelectedPartID(part.id)
    inspectorPresentation.setIsSettingPartOrigin(false)
    canvasPresentation.setEntityIDs(
      Set(
        entities.compactMap { entity in
          if part.entityIDs.contains(entity.id)
            || entity.derivedElementID.map(part.derivedElementIDs.contains) == true
          {
            return entity.id
          }
          return nil
        }))
    canvasPresentation.setPrimaryEntityID(part.outlineEntityIDs.first ?? part.entityIDs.first)
    canvasPresentation.setConstraintID(nil)
    canvasPresentation.setMeasurementAnnotationID(nil)
    canvasPresentation.setFreeTextID(nil)
    canvasPresentation.setStitchStartPointID(nil)
    statusMessage = AppStrings.tr("status.part_contents_selected", part.name, part.entityIDs.count)
  }

  func movePart(_ part: ProjectPart, delta: ModelPoint) -> Bool {
    guard delta.xMM.isFinite, delta.yMM.isFinite else { return false }
    let moved = executeDocumentCommand(commandFactory.makeMovePartCommand(part, delta: delta))
    if moved, let updated = parts.first(where: { $0.id == part.id }) {
      selectPartContents(updated)
    }
    return moved
  }

  func movePart(_ part: ProjectPart, toPosition position: ModelPoint) -> Bool {
    guard position.xMM.isFinite, position.yMM.isFinite else { return false }
    let moved = executeDocumentCommand(
      commandFactory.makeSetPartPositionCommand(part, position: position)
    )
    if moved, let updated = parts.first(where: { $0.id == part.id }) {
      selectPartContents(updated)
    }
    return moved
  }

  func duplicatePart(_ part: ProjectPart, delta: ModelPoint = ModelPoint(xMM: 10, yMM: -10)) {
    let newName = PartFeature.uniqueName(
      sourceName: part.name,
      existingNames: Set(parts.map(\.name)),
      copiesSourceName: true
    )
    let plan = commandFactory.makeDuplicatePartCommand(part, newName: newName, delta: delta)
    guard executeDocumentCommand(plan.request),
      let copiedPartID = currentDocumentState?.mutation?.created.partIDs.last,
      let copy = parts.first(where: { $0.id == copiedPartID })
    else { return }
    selectPartContents(copy)
  }

  func addSelectionToPart(_ part: ProjectPart) {
    let ids = PartFeature.selectedNormalEntityIDs(
      selectedEntityIDs: selectedEntityIDs,
      entities: entities
    ).filter { !part.entityIDs.contains($0) }
    guard !ids.isEmpty else {
      statusMessage = AppStrings.tr("status.part_select_members")
      return
    }
    guard executeDocumentCommand(commandFactory.makeAddEntitiesToPartCommand(part, entityIDs: ids))
    else { return }
    if let updated = parts.first(where: { $0.id == part.id }) { selectPartContents(updated) }
  }

  func removeSelectionFromPart(_ part: ProjectPart) {
    let ids = PartFeature.selectedNormalEntityIDs(
      selectedEntityIDs: selectedEntityIDs,
      entities: entities
    ).filter { part.entityIDs.contains($0) }
    guard !ids.isEmpty else {
      statusMessage = AppStrings.tr("status.part_select_members")
      return
    }
    guard
      executeDocumentCommand(commandFactory.makeRemoveEntitiesFromPartCommand(part, entityIDs: ids))
    else { return }
    inspectorPresentation.setSelectedPartID(part.id)
    canvasPresentation.setEntityIDs([])
    canvasPresentation.setPrimaryEntityID(nil)
  }

  func setPartBoundaryFromSelection(_ part: ProjectPart) {
    let ids = PartFeature.selectedNormalEntityIDs(
      selectedEntityIDs: selectedEntityIDs,
      entities: entities
    )
    guard !ids.isEmpty else {
      statusMessage = AppStrings.tr("status.part_select_boundary")
      return
    }
    guard executeDocumentCommand(commandFactory.makeSetPartBoundaryCommand(part, entityIDs: ids))
    else { return }
    if let updated = parts.first(where: { $0.id == part.id }) { selectPartContents(updated) }
  }

  func beginSettingPartOrigin(_ part: ProjectPart) {
    inspectorPresentation.setSelectedPartID(part.id)
    inspectorPresentation.togglePartOriginSetting()
    statusMessage =
      inspectorPresentation.isSettingPartOrigin
      ? AppStrings.tr("status.part_origin_click_canvas", part.name)
      : AppStrings.tr("status.part_origin_setting_cancelled")
  }

  func setSelectedPartOrigin(_ point: ModelPoint) {
    guard
      let part = WorkspaceViewStateFactory.selectedInspectorPart(
        selectedPartID: inspectorPresentation.selectedPartID,
        parts: parts
      )
    else {
      inspectorPresentation.setIsSettingPartOrigin(false)
      return
    }
    if movePart(part, toPosition: point) {
      inspectorPresentation.setIsSettingPartOrigin(false)
      inspectorPresentation.setSelectedPartID(part.id)
      statusMessage = AppStrings.tr("status.part_origin_set", part.name)
    }
  }

}
