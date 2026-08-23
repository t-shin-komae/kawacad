import AppKit
import SwiftUI

/// Native-menu component. It observes only the feature states that influence
/// command availability, just as React components subscribe to hook results.
struct KawaCADCommands: Commands {
  let actions: AppActionHandlers
  @ObservedObject private var cadSession: CadSessionState
  @ObservedObject private var annotationSelection: AnnotationSelectionState
  @ObservedObject private var canvasPresentation: CanvasPresentationState
  @ObservedObject private var documentPresentation: DocumentPresentationState
  @ObservedObject private var inspectorPresentation: InspectorPresentationState
  @ObservedObject private var workspacePreferences: WorkspacePreferencesState
  @ObservedObject private var workspaceLayout: WorkspaceLayoutState

  init(
    actions: AppActionHandlers,
    cadSession: CadSessionState,
    annotationSelection: AnnotationSelectionState,
    canvasPresentation: CanvasPresentationState,
    documentPresentation: DocumentPresentationState,
    inspectorPresentation: InspectorPresentationState,
    workspacePreferences: WorkspacePreferencesState,
    workspaceLayout: WorkspaceLayoutState
  ) {
    self.actions = actions
    self.cadSession = cadSession
    self.annotationSelection = annotationSelection
    self.canvasPresentation = canvasPresentation
    self.documentPresentation = documentPresentation
    self.inspectorPresentation = inspectorPresentation
    self.workspacePreferences = workspacePreferences
    self.workspaceLayout = workspaceLayout
  }

  private var uiBindings: KawaCADUIBindings { actions.uiBindings }

  var body: some Commands {
    CommandGroup(replacing: .appInfo) {
      Button(AppStrings.tr("menu.about")) {
        KawaCADAboutPanel.present()
      }
      Divider()
      Button(AppStrings.tr("menu.open_source_licenses")) {
        KawaCADLicensesPanel.present()
      }
    }

    CommandGroup(replacing: .newItem) {
      Button(AppStrings.tr("menu.new_project")) { uiBindings.menu.createNewProject() }
        .keyboardShortcut("n", modifiers: [.command])

      Button(AppStrings.tr("menu.open")) { uiBindings.menu.openProjectPanel() }
        .keyboardShortcut("o", modifiers: [.command])

      Divider()

      Button(AppStrings.tr("menu.save")) { uiBindings.menu.saveProject() }
        .keyboardShortcut("s", modifiers: [.command])
        .disabled(!actions.document.canSaveProject)

      Button(AppStrings.tr("menu.save_as")) { uiBindings.menu.saveProjectAsPanel() }
        .keyboardShortcut("s", modifiers: [.command, .shift])
        .disabled(!actions.document.canSaveProject)

      Divider()

      Button(AppStrings.tr("menu.export_pdf")) { uiBindings.menu.exportPDFPanel() }
        .disabled(!actions.output.canExportPDF)

      Button(AppStrings.tr("menu.direct_print")) { uiBindings.menu.printDirectPanel() }
        .disabled(!actions.output.canDirectPrint)
    }

    CommandGroup(replacing: .undoRedo) {
      Button(AppStrings.tr("menu.undo")) { uiBindings.menu.undo() }
        .keyboardShortcut("z", modifiers: [.command])
        .disabled(!actions.document.canUndo)

      Button(AppStrings.tr("menu.redo")) { uiBindings.menu.redo() }
        .keyboardShortcut("z", modifiers: [.command, .shift])
        .disabled(!actions.document.canRedo)
    }

    CommandGroup(replacing: .pasteboard) {
      Button(AppStrings.tr("menu.cut")) {
        if !sendTextEditingAction(#selector(NSText.cut(_:))) {
          uiBindings.menu.reportUnavailable(AppStrings.tr("menu.cut"))
        }
      }
      .keyboardShortcut("x", modifiers: [.command])

      Button(AppStrings.tr("menu.copy")) {
        if !sendTextEditingAction(#selector(NSText.copy(_:))) {
          uiBindings.menu.copySelection()
        }
      }
      .keyboardShortcut("c", modifiers: [.command])

      Button(AppStrings.tr("menu.paste")) {
        if !sendTextEditingAction(#selector(NSText.paste(_:))) {
          uiBindings.menu.pasteCopiedEntity()
        }
      }
      .keyboardShortcut("v", modifiers: [.command])

      Button(AppStrings.tr("menu.duplicate")) { uiBindings.menu.duplicateSelection() }
        .keyboardShortcut("d", modifiers: [.command])
        .disabled(!actions.canvas.canDuplicateSelection)

      Divider()

      Button(AppStrings.tr("menu.delete")) { uiBindings.menu.deleteSelectedEntity() }
        .keyboardShortcut(.delete, modifiers: [])
        .disabled(!actions.canvas.canDeleteSelection)

      Divider()

      Button(AppStrings.tr("menu.select_all")) {
        if !sendTextEditingAction(#selector(NSText.selectAll(_:))) {
          uiBindings.menu.selectAllEntities()
        }
      }
      .keyboardShortcut("a", modifiers: [.command])

      Divider()

      Button(AppStrings.tr("menu.cancel_or_clear_selection")) {
        uiBindings.menu.cancelCurrentInteraction()
      }
      .keyboardShortcut(.escape, modifiers: [])
      .disabled(!actions.canvas.canCancelCurrentInteraction)
    }

    CommandGroup(after: .pasteboard) {
      Button(AppStrings.tr("menu.find_in_inspector")) {
        actions.inspector.revealInspectorSearchForCurrentTab()
      }
      .keyboardShortcut("f", modifiers: [.command])
      .disabled(
        inspectorPresentation.tab == .selection
          || !workspacePreferences.inspectorPanelVisible
      )
    }

    CommandMenu(AppStrings.tr("menu.drawing")) {
      Button(AppStrings.tr("tool.select")) { uiBindings.menu.activateTool(.select) }
        .keyboardShortcut("1", modifiers: [.command])
      Button(AppStrings.tr("tool.point")) { uiBindings.menu.activateTool(.point) }
        .keyboardShortcut("2", modifiers: [.command])
      Button(AppStrings.tr("tool.line")) { uiBindings.menu.activateTool(.line) }
        .keyboardShortcut("3", modifiers: [.command])
      Button(AppStrings.tr("tool.circle")) { uiBindings.menu.activateTool(.circle) }
        .keyboardShortcut("4", modifiers: [.command])
      Button(AppStrings.tr("tool.round_hole")) { uiBindings.menu.activateTool(.roundHole) }
      Button(AppStrings.tr("tool.arc")) { uiBindings.menu.activateTool(.arc) }
      Button(AppStrings.tr("tool.stitch_start_point")) {
        uiBindings.menu.activateTool(.stitchStartPoint)
      }
      Button(AppStrings.tr("tool.free_text")) { uiBindings.menu.activateTool(.freeText) }
      Divider()
      Button(AppStrings.tr("tool.center_line")) {
        uiBindings.menu.activateTool(.centerLine)
      }
      .keyboardShortcut("5", modifiers: [.command])
      Divider()
      Button(AppStrings.tr("tool.offset")) { uiBindings.menu.activateTool(.offset) }
      Button(AppStrings.tr("tool.fillet")) { uiBindings.menu.activateTool(.fillet) }
    }

    CommandMenu(AppStrings.tr("menu.constraint")) {
      Button(AppStrings.tr("tool.coincident")) { uiBindings.menu.activateTool(.coincident) }
      Button(AppStrings.tr("tool.horizontal")) { uiBindings.menu.activateTool(.horizontal) }
        .keyboardShortcut("h", modifiers: [.command, .shift])
      Button(AppStrings.tr("tool.vertical")) { uiBindings.menu.activateTool(.vertical) }
        .keyboardShortcut("v", modifiers: [.command, .shift])
      Button(AppStrings.tr("tool.parallel")) { uiBindings.menu.activateTool(.parallel) }
      Button(AppStrings.tr("tool.perpendicular")) {
        uiBindings.menu.activateTool(.perpendicular)
      }
      Button(AppStrings.tr("tool.tangent")) { uiBindings.menu.activateTool(.tangent) }
      Button(AppStrings.tr("tool.equal_length")) {
        uiBindings.menu.activateTool(.equalLength)
      }
      Button(AppStrings.tr("tool.angle")) { uiBindings.menu.activateTool(.angle) }
      Button(AppStrings.tr("tool.symmetric")) { uiBindings.menu.activateTool(.symmetric) }
      Button(AppStrings.tr("tool.point_on_line")) { uiBindings.menu.activateTool(.pointOnLine) }
      Button(AppStrings.tr("tool.fixed")) { uiBindings.menu.activateTool(.fixed) }
      Divider()
      Button(AppStrings.tr("menu.smooth_arc_tangencies_prototype")) {
        uiBindings.menu.smoothSelectedArcTangenciesPrototype()
      }
      .disabled(
        DerivedElementFeature.selectedArcEntityID(
          selectedEntityID: actions.canvas.selectedEntityID,
          selectedEntityIDs: actions.canvas.selectedEntityIDs,
          entities: actions.document.entities
        ) == nil
      )
    }

    CommandMenu(AppStrings.tr("menu.measurement")) {
      Button(AppStrings.tr("tool.distance")) { uiBindings.menu.activateTool(.distance) }
      Button(AppStrings.tr("tool.horizontal_distance")) {
        uiBindings.menu.activateTool(.horizontalDistance)
      }
      Button(AppStrings.tr("tool.vertical_distance")) {
        uiBindings.menu.activateTool(.verticalDistance)
      }
      Button(AppStrings.tr("tool.line_line_distance")) {
        uiBindings.menu.activateTool(.lineLineDistance)
      }
      Button(AppStrings.tr("tool.segment_length")) {
        uiBindings.menu.activateTool(.segmentLength)
      }
      Button(AppStrings.tr("tool.diameter")) { uiBindings.menu.activateTool(.diameter) }
      Button(AppStrings.tr("tool.radius")) { uiBindings.menu.activateTool(.radius) }
      Divider()
      Button(AppStrings.tr("tool.measure_distance")) {
        uiBindings.menu.activateTool(.measureDistance)
      }
      Button(AppStrings.tr("tool.measure_segment_length")) {
        uiBindings.menu.activateTool(.measureSegmentLength)
      }
      Button(AppStrings.tr("tool.measure_angle")) { uiBindings.menu.activateTool(.measureAngle) }
      Button(AppStrings.tr("tool.measure_radius")) { uiBindings.menu.activateTool(.measureRadius) }
      Button(AppStrings.tr("tool.measure_diameter")) {
        uiBindings.menu.activateTool(.measureDiameter)
      }
      Button(AppStrings.tr("tool.measure_arc_sweep_angle")) {
        uiBindings.menu.activateTool(.measureArcSweepAngle)
      }
    }

    CommandMenu(AppStrings.tr("menu.layer")) {
      Button(AppStrings.tr("menu.add_layer")) { uiBindings.menu.addLayer() }
        .keyboardShortcut("l", modifiers: [.command, .shift])
        .disabled(!actions.document.canEditLayers)
    }

    CommandMenu(AppStrings.tr("menu.view")) {
      Button(AppStrings.tr("menu.edit_display_mode")) {
        uiBindings.menu.setViewMode(.editDisplay)
      }
      .keyboardShortcut("1", modifiers: [.command, .option])

      Button(AppStrings.tr("menu.output_preview_mode")) {
        uiBindings.menu.setViewMode(.outputPreview)
      }
      .keyboardShortcut("2", modifiers: [.command, .option])

      Button(AppStrings.tr("menu.toggle_a4_orientation")) {
        uiBindings.toolbar.setA4ReferenceOrientation(
          workspacePreferences.a4ReferenceOrientation == .portrait ? .landscape : .portrait
        )
      }

      Button(AppStrings.tr("toolbar.zoom_to_fit")) { uiBindings.toolbar.zoomToFit() }

      Divider()

      Button(
        showHideTitle(
          isVisible: workspacePreferences.inspectorPanelVisible,
          label: AppStrings.tr("menu.inspector")
        )
      ) {
        if workspaceLayout.windowLayoutMode == .compact {
          actions.workspace.showCompactDrawer(.inspector)
        } else {
          uiBindings.toolbar.setInspectorPanelVisible(
            !workspacePreferences.inspectorPanelVisible
          )
        }
      }

      Button(
        showHideTitle(
          isVisible: workspacePreferences.bottomWorkbenchVisible,
          label: AppStrings.tr("menu.bottom_summary")
        )
      ) {
        uiBindings.toolbar.setBottomWorkbenchVisible(
          !workspacePreferences.bottomWorkbenchVisible
        )
      }

      Divider()

      Button(AppStrings.tr("menu.reset_layout")) {
        actions.workspace.resetLayoutPreferences()
      }

      Button(AppStrings.tr("menu.reload")) { uiBindings.menu.reloadFromDocument() }
        .keyboardShortcut("r", modifiers: [.command])
    }

  }
}

private func sendTextEditingAction(_ selector: Selector) -> Bool {
  guard NSApp.keyWindow?.firstResponder is NSTextView else {
    return false
  }
  return NSApp.sendAction(selector, to: nil, from: nil)
}

private func showHideTitle(isVisible: Bool, label: String) -> String {
  AppStrings.tr(
    "menu.show_hide",
    isVisible ? AppStrings.tr("menu.hide") : AppStrings.tr("menu.show"),
    label
  )
}
