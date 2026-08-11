import SwiftUI

struct InspectorPanel: View {
  let appState: InspectorFeatureModel

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 10) {
        Picker(
          AppStrings.tr("inspector.selection"),
          selection: Binding(
            get: { appState.inspectorTab },
            set: appState.setInspectorTab
          )
        ) {
          ForEach(InspectorTab.allCases) { tab in
            Text(tab.title).tag(tab)
          }
        }
        .pickerStyle(.segmented)

        if appState.inspectorHasPendingSelectionChange {
          Button {
            appState.revealInspectorSelectionTab()
          } label: {
            HStack(spacing: 8) {
              Text(AppStrings.tr("inspector.selection_changed"))
              Spacer(minLength: 8)
              Text(AppStrings.tr("inspector.show_selection"))
            }
            .font(.system(size: 11, weight: .semibold))
          }
          .buttonStyle(.bordered)
        }
      }
      .padding(16)
      .background {
        MacVisualEffectBackground(style: .content)
      }

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          switch appState.inspectorTab {
          case .selection:
            selectionTabContent
          case .layers:
            layersTabContent
          case .sharedStyles:
            sharedStylesTabContent
          case .parameters:
            parametersTabContent
          case .parts:
            partsTabContent
          }
        }
        .padding(16)
        .environmentObject(appState)
      }
    }
    .background {
      MacVisualEffectBackground(style: .content)
    }
  }

  @ViewBuilder
  private var selectionTabContent: some View {
    CardSection(title: AppStrings.tr("inspector.selection"), symbolName: "cursorarrow") {
      if let selectedConstraint {
        SelectedConstraintSection(constraint: selectedConstraint)
      } else if let selectedMeasurementAnnotation = appState.selectedMeasurementAnnotation {
        VStack(alignment: .leading, spacing: 10) {
          DetailRow(
            label: AppStrings.tr("inspector.kind"), value: selectedMeasurementAnnotation.kind)
          HStack(spacing: 8) {
            Button {
              appState.convertMeasurementAnnotationToConstraint(selectedMeasurementAnnotation.id)
            } label: {
              Text(AppStrings.tr("canvas.menu.convert_measurement_to_constraint"))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Button(role: .destructive) {
              appState.deleteMeasurementAnnotation(selectedMeasurementAnnotation)
            } label: {
              Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
          }
        }
      } else if let selectedFreeText = appState.selectedFreeText {
        FreeTextEditorSection(freeText: selectedFreeText)
      } else if appState.selectedEntities.count > 1 {
        MultiSelectionSummarySection()
        SharedStyleSelectionField(
          selectedStyleID: nil,
          sharedStyles: appState.sharedStyles,
          onChange: { appState.setSelectedEntitiesSharedStyle($0) }
        )
      } else if let selectedEntity = appState.selectedEntity {
        DetailRow(label: AppStrings.tr("inspector.kind"), value: selectedEntity.kind.displayName)
        Picker(
          AppStrings.tr("inspector.layer"),
          selection: Binding(
            get: { selectedEntity.layerID ?? "" },
            set: { appState.setSelectedEntityLayer($0) }
          )
        ) {
          ForEach(appState.layers) { layer in
            Text(layer.name).tag(layer.id)
          }
        }
        .font(.system(size: 12))

        if let derivedElement = appState.selectedDerivedElement {
          SharedStyleSelectionField(
            selectedStyleID: derivedElement.styleID,
            sharedStyles: appState.sharedStyles,
            onChange: { appState.setSelectedEntitiesSharedStyle($0) }
          )
          OffsetDerivedElementEditor(derivedElement: derivedElement)
        } else {
          SharedStyleSelectionField(
            selectedStyleID: selectedEntity.styleID,
            sharedStyles: appState.sharedStyles,
            onChange: { appState.setSelectedEntitiesSharedStyle($0) }
          )
          if let roundHole = appState.selectedRoundHole {
            RoundHoleEditorSection(roundHole: roundHole, entity: selectedEntity)
          }
          EntityGeometryEditor(entity: selectedEntity)
        }

        Button(role: .destructive) {
          appState.deleteSelectedEntity()
        } label: {
          Label(AppStrings.tr("common.delete"), systemImage: "trash")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
      } else {
        Text(AppStrings.tr("inspector.no_selection"))
          .font(.system(size: 12))
          .foregroundStyle(LeatherColors.secondaryInk)
      }
    }

    CardSection(title: AppStrings.tr("inspector.constraint"), symbolName: "link") {
      if appState.constraints.isEmpty {
        Text(AppStrings.tr("workbench.no_constraints"))
          .font(.system(size: 12))
          .foregroundStyle(LeatherColors.secondaryInk)
      } else {
        ForEach(appState.constraints) { constraint in
          HStack(spacing: 8) {
            Button {
              appState.selectConstraint(constraint.id)
            } label: {
              VStack(alignment: .leading, spacing: 3) {
                Text(constraint.kind)
                  .font(.system(size: 12, weight: .semibold))
                Text(constraint.status.displayName)
                  .font(.system(size: 10))
                  .foregroundStyle(LeatherColors.secondaryInk)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Button(role: .destructive) {
              appState.deleteConstraint(constraint)
            } label: {
              Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
          }
        }
      }
    }

    CardSection(title: AppStrings.tr("inspector.measurement_and_notes"), symbolName: "ruler") {
      ForEach(appState.measurementAnnotations) { annotation in
        HStack(spacing: 8) {
          Button {
            appState.selectMeasurementAnnotation(annotation.id)
          } label: {
            Text(annotation.kind)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.plain)
          if !annotation.visible {
            Text(AppStrings.tr("inspector.hidden"))
              .font(.system(size: 10))
              .foregroundStyle(LeatherColors.secondaryInk)
          }
          Button {
            appState.convertMeasurementAnnotationToConstraint(annotation.id)
          } label: {
            Image(systemName: "link")
          }
          .buttonStyle(.borderless)
          Button(role: .destructive) {
            appState.deleteMeasurementAnnotation(annotation)
          } label: {
            Image(systemName: "trash")
          }
          .buttonStyle(.borderless)
        }
      }
      ForEach(appState.freeTexts) { freeText in
        HStack(spacing: 8) {
          Button {
            appState.selectFreeText(freeText.id)
          } label: {
            Text(freeText.content)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.plain)
          Text(AppStrings.tr("tool.free_text"))
            .font(.system(size: 10))
            .foregroundStyle(LeatherColors.secondaryInk)
        }
      }
    }

    CardSection(title: AppStrings.tr("inspector.document_overview"), symbolName: "doc.text") {
      DetailRow(
        label: AppStrings.tr("inspector.visible_mode"), value: appState.viewMode.displayName)
      DetailRow(label: AppStrings.tr("inspector.active_layer"), value: activeLayerName)
      DetailRow(
        label: AppStrings.tr("inspector.visible_entities"), value: "\(appState.entities.count)")
      DetailRow(
        label: AppStrings.tr("inspector.constraint_count"), value: "\(appState.constraints.count)")
      DetailRow(
        label: AppStrings.tr("inspector.parameter_count"), value: "\(appState.parameters.count)")
    }
  }

  @ViewBuilder
  private var layersTabContent: some View {
    CardSection(title: AppStrings.tr("inspector.layer"), symbolName: "square.3.layers.3d") {
      Picker(
        AppStrings.tr("toolbar.drawing_layer"),
        selection: Binding(
          get: { appState.activeLayerID },
          set: { appState.setActiveLayer($0) }
        )
      ) {
        ForEach(appState.layers) { layer in
          Text(layer.name).tag(layer.id)
        }
      }
      .font(.system(size: 12))

      if appState.shouldShowLayerInspectorSearch {
        TextField(
          AppStrings.tr("inspector.search_placeholder"),
          text: Binding(
            get: { appState.inspectorLayerSearchQuery },
            set: appState.setInspectorLayerSearchQuery
          )
        )
        .textFieldStyle(.roundedBorder)
      }

      ForEach(appState.filteredInspectorLayers) { layer in
        InspectorSectionRow(
          title: layer.name,
          subtitle: layer.kind.displayName,
          metadata: layer.visible
            ? AppStrings.tr("inspector.layer_visible") : AppStrings.tr("inspector.layer_hidden"),
          isSelected: appState.inspectorSelectedLayerID == layer.id,
          onSelect: { appState.setInspectorSelectedLayerID(layer.id) }
        ) {
          LayerEditorRow(
            layer: layer,
            canDelete: appState.layers.count > 1,
            onRename: { newName in appState.renameLayer(layer, newName) },
            onToggleVisibility: { appState.setLayerVisibility(layer, !layer.visible) },
            onTogglePrintable: { appState.setLayerPrintable(layer, !layer.printable) },
            onStyleChange: { updatedLayer in appState.setLayerStyle(updatedLayer) },
            onDelete: { appState.deleteLayer(layer) }
          )
        }
      }

      Button {
        appState.addLayer()
      } label: {
        Label(AppStrings.tr("inspector.add_layer"), systemImage: "plus")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .font(.system(size: 12, weight: .semibold))
    }
  }

  @ViewBuilder
  private var sharedStylesTabContent: some View {
    CardSection(title: AppStrings.tr("inspector.shared_styles"), symbolName: "paintbrush") {
      if appState.shouldShowSharedStyleInspectorSearch {
        TextField(
          AppStrings.tr("inspector.search_placeholder"),
          text: Binding(
            get: { appState.inspectorSharedStyleSearchQuery },
            set: appState.setInspectorSharedStyleSearchQuery
          )
        )
        .textFieldStyle(.roundedBorder)
      }

      if appState.filteredInspectorSharedStyles.isEmpty {
        Text(AppStrings.tr("inspector.no_shared_styles"))
          .font(.system(size: 12))
          .foregroundStyle(LeatherColors.secondaryInk)
      } else {
        ForEach(appState.filteredInspectorSharedStyles) { style in
          InspectorSectionRow(
            title: style.name,
            subtitle: style.linePattern.displayName,
            metadata: style.colorHex,
            isSelected: appState.inspectorSelectedSharedStyleID == style.id,
            onSelect: { appState.setInspectorSelectedSharedStyleID(style.id) }
          ) {
            StyleEditorRow(
              style: style,
              namePlaceholder: AppStrings.tr("inspector.shared_style_name_placeholder"),
              onChange: { appState.updateSharedStyle($0) },
              accessoryButtons: EmptyView(),
              deleteButton: Button(action: { appState.deleteSharedStyle(style) }) {
                Image(systemName: "trash")
                  .frame(width: 24, height: 24)
              }
              .buttonStyle(.borderless)
              .foregroundStyle(LeatherColors.destructive)
            )
          }
        }
      }

      Button {
        appState.addSharedStyle()
      } label: {
        Label(AppStrings.tr("inspector.add_shared_style"), systemImage: "plus")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .font(.system(size: 12, weight: .semibold))
    }
  }

  @ViewBuilder
  private var parametersTabContent: some View {
    CardSection(title: AppStrings.tr("inspector.parameters"), symbolName: "number") {
      if appState.shouldShowParameterInspectorSearch {
        TextField(
          AppStrings.tr("inspector.search_placeholder"),
          text: Binding(
            get: { appState.inspectorParameterSearchQuery },
            set: appState.setInspectorParameterSearchQuery
          )
        )
        .textFieldStyle(.roundedBorder)
      }

      if appState.filteredInspectorParameters.isEmpty {
        Text(AppStrings.tr("inspector.no_named_parameters"))
          .font(.system(size: 12))
          .foregroundStyle(LeatherColors.secondaryInk)
      } else {
        ForEach(appState.filteredInspectorParameters) { parameter in
          InspectorSectionRow(
            title: parameter.name,
            subtitle: String(format: "%.2f %@", parameter.valueMM, parameter.unitLabel),
            metadata: parameter.isUnused
              ? AppStrings.tr("inspector.parameter_unused")
              : AppStrings.tr("inspector.parameter_usage", parameter.usageCount),
            isSelected: appState.inspectorSelectedParameterID == parameter.id,
            onSelect: { appState.setInspectorSelectedParameterID(parameter.id) }
          ) {
            ParameterEditorRow(parameter: parameter)
          }
        }
      }

      Button {
        appState.addParameter()
      } label: {
        Label(AppStrings.tr("inspector.add"), systemImage: "plus")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .font(.system(size: 12, weight: .semibold))
    }
  }

  @ViewBuilder
  private var partsTabContent: some View {
    CardSection(title: AppStrings.tr("inspector.parts"), symbolName: "square.stack.3d.up") {
      if appState.parts.isEmpty {
        Text(AppStrings.tr("inspector.no_parts"))
          .font(.system(size: 12))
          .foregroundStyle(LeatherColors.secondaryInk)
      } else {
        ForEach(appState.parts) { part in
          InspectorSectionRow(
            title: part.name,
            subtitle: AppStrings.tr(
              "inspector.part_structure",
              part.outlineEntityIDs.count,
              part.holeEntityIDGroups.count
            ),
            metadata: AppStrings.tr(
              "inspector.part_quantity_members", part.quantity, part.entityIDs.count),
            isSelected: appState.inspectorSelectedPartID == part.id,
            onSelect: { appState.selectPartContents(part) }
          ) {
            PartEditorRow(part: part)
          }
        }
      }

      if !appState.parts.isEmpty {
        Divider()
        Text(AppStrings.tr("inspector.part_arrangement_help"))
          .font(.system(size: 10))
          .foregroundStyle(LeatherColors.secondaryInk)
        HStack(spacing: 6) {
          ForEach(
            [
              ("left", "align.horizontal.left"),
              ("horizontalCenter", "align.horizontal.center"),
              ("right", "align.horizontal.right"),
              ("bottom", "align.vertical.bottom"),
              ("verticalCenter", "align.vertical.center"),
              ("top", "align.vertical.top"),
            ], id: \.0
          ) { item in
            Button {
              appState.alignSelectedParts(item.0)
            } label: {
              Image(systemName: item.1)
            }
          }
        }
        .buttonStyle(.bordered)
        .disabled(appState.arrangementSelectedPartIDs.count < 2)
        HStack(spacing: 8) {
          Button(AppStrings.tr("inspector.distribute_horizontal")) {
            appState.distributeSelectedParts("horizontal")
          }
          Button(AppStrings.tr("inspector.distribute_vertical")) {
            appState.distributeSelectedParts("vertical")
          }
        }
        .buttonStyle(.bordered)
        .disabled(appState.arrangementSelectedPartIDs.count < 3)
      }

      Button {
        appState.createPartFromSelection()
      } label: {
        Label(
          AppStrings.tr("inspector.create_part_from_selection"),
          systemImage: "square.stack.3d.up.badge.plus"
        )
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .font(.system(size: 12, weight: .semibold))
      .disabled(appState.selectedEntities.isEmpty)
    }

    CardSection(title: AppStrings.tr("inspector.part_library"), symbolName: "books.vertical") {
      if appState.partLibraryEntries.isEmpty {
        Text(AppStrings.tr("inspector.part_library_empty"))
          .font(.system(size: 12))
          .foregroundStyle(LeatherColors.secondaryInk)
      } else {
        ForEach(appState.partLibraryEntries) { entry in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(entry.name).font(.system(size: 12, weight: .semibold))
              Text(AppStrings.tr("inspector.part_library_quantity", entry.sourcePart.quantity))
                .font(.system(size: 10))
                .foregroundStyle(LeatherColors.secondaryInk)
            }
            Spacer()
            Button {
              appState.insertPartFromLibrary(entry)
            } label: {
              Image(systemName: "plus.square.on.square")
            }
            Button(role: .destructive) {
              appState.removePartLibraryEntry(entry)
            } label: {
              Image(systemName: "trash")
            }
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  private var activeLayerName: String {
    appState.layers.first(where: { $0.id == appState.activeLayerID })?.name
      ?? AppStrings.tr("workbench.none")
  }

  private var selectedConstraint: ProjectConstraint? {
    appState.selectedConstraintID.flatMap { selectedID in
      appState.constraints.first(where: { $0.id == selectedID })
    }
  }
}
