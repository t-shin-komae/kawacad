import SwiftUI

struct SelectionDocumentOverviewModel {
  let viewMode: CanvasViewMode
  let activeLayerID: String
  let layers: [ProjectLayer]
  let entities: [CanvasEntity]
  let constraints: [ProjectConstraint]
  let parameters: [ProjectParameter]
}

struct SelectionMeasurementEditorModel {
  let convert: (String) -> Void
  let delete: (ProjectMeasurementAnnotation) -> Void
}

struct SelectionStitchPointEditorModel {
  let entities: [CanvasEntity]
  let delete: () -> Void
}

struct SelectionFreeTextEditorModel {
  let update: (ProjectFreeText) -> Bool
  let delete: () -> Void
}

struct SelectionConstraintEditorModel {
  let parameters: [ProjectParameter]
  let delete: (ProjectConstraint) -> Void
  let hover: (String?) -> Void
  let setDegrees: (ProjectConstraint, Double) -> Bool
  let setValue: (ProjectConstraint, Double) -> Bool
  let setParameter: (ProjectConstraint, ProjectParameter) -> Bool
}

struct SelectionMultiSelectionEditorModel {
  let selectedEntities: [CanvasEntity]
  let sharedStyles: [ProjectSharedStyle]
  let layers: [ProjectLayer]
  let canConstrainSelectedLineLengthsEqual: Bool
  let setSharedStyle: (String?) -> Bool
  let delete: () -> Void
  let constrainSelectedLineLengthsEqual: () -> Void
}

struct SelectionDerivedElementEditorModel {
  let parameters: [ProjectParameter]
  let setDirection: (ProjectDerivedElement, OffsetDirection) -> Bool
  let reverseDirection: (ProjectDerivedElement) -> Bool
  let setDistance: (ProjectDerivedElement, Double) -> Bool
  let setParameter: (ProjectDerivedElement, ProjectParameter) -> Bool
}

struct SelectionRoundHoleEditorModel {
  let selectedRoundHole: ProjectRoundHole?
  let selectedEntity: CanvasEntity?
  let setKind: (ProjectRoundHoleKind) -> Bool
  let setDiameter: (Double) -> Bool
}

struct SelectionEntityGeometryEditorModel {
  let selectedEntity: CanvasEntity?
  let constrainLineLength: () -> Void
  let setLineLength: (Double) -> Bool
  let setCircleRadius: (Double) -> Bool
  let setArc: (Double, Double, Double) -> Bool
}

struct SelectionEntityEditorModel {
  let layers: [ProjectLayer]
  let sharedStyles: [ProjectSharedStyle]
  let selectedDerivedElement: ProjectDerivedElement?
  let selectedRoundHole: ProjectRoundHole?
  let selectedEntity: CanvasEntity?
  let setLayer: (String) -> Void
  let setSharedStyle: (String?) -> Bool
  let delete: () -> Void
  let parameters: [ProjectParameter]
  let derived: SelectionDerivedElementEditorModel
  let roundHole: SelectionRoundHoleEditorModel
  let geometry: SelectionEntityGeometryEditorModel
}

struct DocumentOverview: View {
  let appState: SelectionDocumentOverviewModel

  var body: some View {
    InspectorSection(title: AppStrings.tr("inspector.document_overview"), symbolName: "doc.text") {
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

  private var activeLayerName: String {
    appState.layers.first(where: { $0.id == appState.activeLayerID })?.name
      ?? AppStrings.tr("workbench.none")
  }
}

struct SelectedMeasurementEditor: View {
  let appState: SelectionMeasurementEditorModel
  let measurement: ProjectMeasurementAnnotation

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      DetailRow(label: AppStrings.tr("inspector.kind"), value: measurement.kind)
      HStack(spacing: 8) {
        Button {
          appState.convert(measurement.id)
        } label: {
          Text(AppStrings.tr("canvas.menu.convert_measurement_to_constraint"))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .leatherControlHeight()
        Button(role: .destructive) {
          appState.delete(measurement)
        } label: {
          Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
      }
    }
  }
}

struct SelectedStitchStartPointEditor: View {
  let appState: SelectionStitchPointEditorModel
  let stitchStartPoint: ProjectStitchStartPoint

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      DetailRow(
        label: AppStrings.tr("inspector.kind"), value: AppStrings.tr("tool.stitch_start_point"))
      DetailRow(label: AppStrings.tr("inspector.stitch_target"), value: targetLabel)
      Button(role: .destructive) {
        appState.delete()
      } label: {
        Label(AppStrings.tr("common.delete"), systemImage: "trash")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .leatherControlHeight()
    }
  }

  private var targetLabel: String {
    appState.entities.first(where: { $0.id == stitchStartPoint.targetID })?.kind.displayName
      ?? AppStrings.tr("inspector.geometry")
  }
}

struct EntityEditor: View {
  let appState: SelectionEntityEditorModel
  let entity: CanvasEntity

  var body: some View {
    DetailRow(label: AppStrings.tr("inspector.kind"), value: entity.kind.displayName)
    Picker(
      AppStrings.tr("inspector.layer"),
      selection: Binding(
        get: { entity.layerID ?? "" },
        set: { appState.setLayer($0) }
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
        onChange: { appState.setSharedStyle($0) }
      )
      DerivedElementEditor(appState: appState.derived, derivedElement: derivedElement)
    } else {
      SharedStyleSelectionField(
        selectedStyleID: entity.styleID,
        sharedStyles: appState.sharedStyles,
        onChange: { appState.setSharedStyle($0) }
      )
      if let roundHole = appState.selectedRoundHole {
        RoundHoleEditor(appState: appState.roundHole, roundHole: roundHole, entity: entity)
      }
      EntityGeometryEditor(appState: appState.geometry, entity: entity)
    }

    Button(role: .destructive) {
      appState.delete()
    } label: {
      Label(AppStrings.tr("common.delete"), systemImage: "trash")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
    .leatherControlHeight()
  }
}

struct PartEditor: View {
  let part: ProjectPart
  let appState: PartInspectorModel

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      Toggle(
        AppStrings.tr("inspector.part_arrangement_target"),
        isOn: Binding(
          get: { appState.data.arrangementSelectedPartIDs.contains(part.id) },
          set: { _ in appState.actions.togglePartArrangementSelection(part) }
        )
      )
      .toggleStyle(.checkbox)

      HStack(spacing: 10) {
        Toggle(
          AppStrings.tr("inspector.part_visible"),
          isOn: Binding(
            get: { part.visible },
            set: {
              _ in
              _ = appState.actions.updatePartSettings(part.withSettings(visible: !part.visible))
            }
          ))
        Toggle(
          AppStrings.tr("inspector.part_printable"),
          isOn: Binding(
            get: { part.printable },
            set: { _ in
              _ = appState.actions.updatePartSettings(part.withSettings(printable: !part.printable))
            }
          ))
      }
      .toggleStyle(.checkbox)
      .font(.system(size: LeatherDesignMetrics.Typography.body))

      Stepper(
        AppStrings.tr("inspector.part_quantity", part.quantity),
        value: Binding(
          get: { part.quantity },
          set: { _ = appState.actions.updatePartSettings(part.withSettings(quantity: $0)) }
        ),
        in: 1...999
      )
      .font(.system(size: LeatherDesignMetrics.Typography.body))

      SyncedTextField(
        placeholder: AppStrings.tr("inspector.part_name"),
        sourceValue: part.name,
        onCommit: { value in
          appState.actions.updatePart(part.withMetadata(name: value, originMM: part.originMM))
        },
        font: .system(size: 12, weight: .medium)
      )

      HStack(spacing: 8) {
        partCoordinateField(AppStrings.tr("inspector.part_origin_x_mm"), value: part.originMM.xMM) {
          value in
          _ = appState.actions.movePart(
            part,
            ModelPoint(xMM: value - part.originMM.xMM, yMM: 0)
          )
        }
        partCoordinateField(AppStrings.tr("inspector.part_origin_y_mm"), value: part.originMM.yMM) {
          value in
          _ = appState.actions.movePart(
            part,
            ModelPoint(xMM: 0, yMM: value - part.originMM.yMM)
          )
        }
      }

      Button {
        appState.actions.beginSettingPartOrigin(part)
      } label: {
        Label(
          AppStrings.tr(
            appState.data.isSettingPartOrigin
              ? "inspector.cancel_part_origin_setting"
              : "inspector.set_part_origin_on_canvas"),
          systemImage: "scope"
        )
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .leatherControlHeight()

      DetailRow(
        label: AppStrings.tr("inspector.part_derived_members"),
        value: "\(part.derivedElementIDs.count)")
      DetailRow(
        label: AppStrings.tr("inspector.part_text_members"), value: "\(part.freeTextIDs.count)")
      DetailRow(
        label: AppStrings.tr("inspector.part_measurement_members"),
        value: "\(part.measurementAnnotationIDs.count)")

      Button {
        appState.actions.selectPartContents(part)
      } label: {
        Label(AppStrings.tr("inspector.select_part_contents"), systemImage: "cursorarrow.rays")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .leatherControlHeight()

      HStack(spacing: 8) {
        Button {
          _ = appState.actions.movePart(part, ModelPoint(xMM: -10, yMM: 0))
        } label: {
          Image(systemName: "arrow.left")
        }
        Button {
          _ = appState.actions.movePart(part, ModelPoint(xMM: 0, yMM: 10))
        } label: {
          Image(systemName: "arrow.up")
        }
        Button {
          _ = appState.actions.movePart(part, ModelPoint(xMM: 0, yMM: -10))
        } label: {
          Image(systemName: "arrow.down")
        }
        Button {
          _ = appState.actions.movePart(part, ModelPoint(xMM: 10, yMM: 0))
        } label: {
          Image(systemName: "arrow.right")
        }
      }
      .buttonStyle(.bordered)
      .leatherControlHeight()
      .help(AppStrings.tr("inspector.move_part_10mm"))

      Button {
        appState.actions.duplicatePart(part)
      } label: {
        Label(AppStrings.tr("inspector.duplicate_part"), systemImage: "plus.square.on.square")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .leatherControlHeight()

      Button {
        appState.actions.addPartToLibrary(part)
      } label: {
        Label(AppStrings.tr("inspector.add_part_to_library"), systemImage: "books.vertical.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .leatherControlHeight()

      Divider()

      Text(AppStrings.tr("inspector.part_fixed_help"))
        .font(.system(size: LeatherDesignMetrics.Typography.label))
        .foregroundStyle(LeatherColors.secondaryInk)

      Button(role: .destructive) {
        appState.actions.deletePart(part)
      } label: {
        Label(AppStrings.tr("inspector.ungroup_part"), systemImage: "square.stack.3d.down.right")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .leatherControlHeight()
    }
  }

  private func partCoordinateField(
    _ label: String,
    value: Double,
    onCommit: @escaping (Double) -> Void
  ) -> some View {
    SyncedTextField(
      placeholder: label,
      sourceValue: CommonFieldParsers.displayString(for: value, maximumFractionDigits: 2),
      onCommitResult: { text in
        switch CommonFieldParsers.decimalValue(text) {
        case .success(let value):
          onCommit(value)
          return .success(
            canonicalValue: CommonFieldParsers.displayString(for: value, maximumFractionDigits: 2))
        case .failure(let message):
          return .failure(message)
        }
      },
      font: .system(size: 11, design: .monospaced)
    )
  }
}

struct InspectorDisclosureRow<Content: View>: View {
  let title: String
  let subtitle: String
  let metadata: String
  let isSelected: Bool
  let onSelect: () -> Void
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button(action: onSelect) {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          VStack(alignment: .leading, spacing: 3) {
            Text(title)
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(LeatherColors.ink)
            Text(subtitle)
              .font(.system(size: 11))
              .foregroundStyle(LeatherColors.secondaryInk)
          }
          Spacer(minLength: 8)
          Text(metadata)
            .font(.system(size: LeatherDesignMetrics.Typography.label, weight: .medium))
            .foregroundStyle(LeatherColors.secondaryInk)
            .multilineTextAlignment(.trailing)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? LeatherColors.insetFill : LeatherColors.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(
              isSelected
                ? LeatherColors.accent.opacity(0.45) : LeatherColors.panelStroke.opacity(0.35))
        )
      }
      .buttonStyle(.plain)

      if isSelected {
        content
      }
    }
  }
}

struct FreeTextEditor: View {
  let appState: SelectionFreeTextEditorModel
  let freeText: ProjectFreeText

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      DetailRow(label: AppStrings.tr("inspector.kind"), value: AppStrings.tr("tool.free_text"))
      SyncedTextField(
        placeholder: AppStrings.tr("inspector.free_text_content"),
        sourceValue: freeText.content,
        onCommit: { value in
          appState.update(freeText.withContent(value))
        },
        font: .system(size: 12, weight: .medium)
      )

      HStack(spacing: 8) {
        numericField(
          AppStrings.tr("inspector.x_mm"),
          value: freeText.positionMM.xMM,
          onCommit: { xMM in
            appState.update(
              freeText.withPosition(ModelPoint(xMM: xMM, yMM: freeText.positionMM.yMM))
            )
          }
        )
        numericField(
          AppStrings.tr("inspector.y_mm"),
          value: freeText.positionMM.yMM,
          onCommit: { yMM in
            appState.update(
              freeText.withPosition(ModelPoint(xMM: freeText.positionMM.xMM, yMM: yMM))
            )
          }
        )
      }

      numericField(
        AppStrings.tr("inspector.font_size_mm"),
        value: freeText.fontSizeMM,
        onCommit: { fontSizeMM in
          appState.update(freeText.withFontSize(fontSizeMM))
        }
      )

      Button(role: .destructive) {
        appState.delete()
      } label: {
        Label(AppStrings.tr("common.delete"), systemImage: "trash")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .leatherControlHeight()
    }
  }

  private func numericField(
    _ title: String,
    value: Double,
    onCommit: @escaping (Double) -> Bool
  ) -> some View {
    SyncedTextField(
      placeholder: title,
      sourceValue: String(format: "%.2f", value),
      onCommit: { text in
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
          return false
        }
        return onCommit(value)
      },
      width: 86,
      font: .system(size: 12, weight: .medium)
    )
  }
}

struct SelectedConstraintEditor: View {
  let appState: SelectionConstraintEditorModel
  let constraint: ProjectConstraint

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      DetailRow(label: AppStrings.tr("inspector.kind"), value: constraint.kind)
      Text(AppStrings.tr("inspector.constraint_targets_highlighted"))
        .font(.system(size: 11))
        .foregroundStyle(LeatherColors.secondaryInk)

      if constraint.isDimensionConstraint {
        ConstraintValueEditor(appState: appState, constraint: constraint)
      }

      Button(role: .destructive) {
        appState.delete(constraint)
      } label: {
        Label(AppStrings.tr("common.delete"), systemImage: "trash")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .leatherControlHeight()
    }
    .onAppear {
      appState.hover(nil)
    }
  }
}

struct MultiSelectionSummary: View {
  let appState: SelectionMultiSelectionEditorModel

  var body: some View {
    let selectedEntities = appState.selectedEntities

    VStack(alignment: .leading, spacing: 10) {
      DetailRow(
        label: AppStrings.tr("inspector.selection_count"), value: "\(selectedEntities.count)")
      DetailRow(
        label: AppStrings.tr("inspector.kind"), value: kindSummaryText(for: selectedEntities))

      if let layerSummary = layerSummaryText(for: selectedEntities) {
        DetailRow(label: AppStrings.tr("inspector.layer"), value: layerSummary)
      }

      SharedStyleSelectionField(
        selectedStyleID: nil,
        sharedStyles: appState.sharedStyles,
        onChange: { appState.setSharedStyle($0) }
      )

      Text(AppStrings.tr("inspector.batch_actions"))
        .font(.system(size: 12))
        .foregroundStyle(LeatherColors.secondaryInk)

      HStack(spacing: 8) {
        Button(role: .destructive) {
          appState.delete()
        } label: {
          Label(AppStrings.tr("common.delete"), systemImage: "trash")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .leatherControlHeight()

        if appState.canConstrainSelectedLineLengthsEqual {
          Button {
            appState.constrainSelectedLineLengthsEqual()
          } label: {
            Label(AppStrings.tr("inspector.equal_length_constraint"), systemImage: "link")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .leatherControlHeight()
        }
      }

      Text(AppStrings.tr("inspector.single_selection_hint"))
        .font(.system(size: 11))
        .foregroundStyle(LeatherColors.secondaryInk)
    }
  }

  private func kindSummaryText(for entities: [CanvasEntity]) -> String {
    let summary = Dictionary(grouping: entities, by: { $0.kind.displayName })
      .map { key, values in "\(key) \(values.count)" }
      .sorted()
    return summary.joined(separator: " / ")
  }

  private func layerSummaryText(for entities: [CanvasEntity]) -> String? {
    let layerIDs = Set(entities.compactMap(\.layerID))
    guard !layerIDs.isEmpty else {
      return nil
    }
    if layerIDs.count == 1,
      let layerID = layerIDs.first,
      let layer = appState.layers.first(where: { $0.id == layerID })
    {
      return layer.name
    }
    return AppStrings.tr("inspector.layer_count", layerIDs.count)
  }
}

struct ConstraintValueEditor: View {
  let appState: SelectionConstraintEditorModel
  let constraint: ProjectConstraint

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      SyncedNumericFieldRow(
        label: AppStrings.tr("inspector.value"),
        sourceValue: sourceValueText,
        unit: constraint.rawKind == "angle" ? "°" : "mm",
        onCommit: commit
      )
      if constraint.rawKind != "angle", !appState.parameters.isEmpty {
        Picker(
          AppStrings.tr("inspector.parameter"),
          selection: Binding(
            get: { constraint.valueParameterID ?? "" },
            set: assignParameter
          )
        ) {
          Text(AppStrings.tr("inspector.fixed_value")).tag("")
          ForEach(appState.parameters) { parameter in
            Text(parameter.name).tag(parameter.id)
          }
        }
        .font(.system(size: 12))
      }
    }
  }

  private var sourceValueText: String {
    InspectorValueFormatting.resolvedText(
      fixedValue: constraint.valueDegrees ?? constraint.valueMM,
      parameterID: constraint.valueParameterID,
      parameters: appState.parameters
    )
  }

  private func commit(_ valueText: String) -> Bool {
    guard let value = Double(valueText) else {
      return false
    }
    if constraint.rawKind == "angle" {
      return appState.setDegrees(constraint, value)
    }
    return appState.setValue(constraint, value)
  }

  private func assignParameter(_ parameterID: String) {
    guard !parameterID.isEmpty else {
      _ = commit(sourceValueText)
      return
    }
    guard let parameter = appState.parameters.first(where: { $0.id == parameterID }) else {
      return
    }
    _ = appState.setParameter(constraint, parameter)
  }
}

struct DerivedElementEditor: View {
  let appState: SelectionDerivedElementEditorModel
  let derivedElement: ProjectDerivedElement

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      DetailRow(
        label: AppStrings.tr("inspector.derived_element"), value: derivedElement.kind.displayName)
      DetailRow(
        label: AppStrings.tr("inspector.source_count"),
        value: "\(derivedElement.sourceEntityIDs.count)")

      SyncedNumericFieldRow(
        label: valueLabel,
        sourceValue: sourceValueText,
        unit: "mm",
        onCommit: commitDistance
      )

      if !appState.parameters.isEmpty {
        Picker(
          AppStrings.tr("inspector.parameter"),
          selection: Binding(
            get: { currentParameterID ?? "" },
            set: assignParameter
          )
        ) {
          Text(AppStrings.tr("inspector.fixed_value")).tag("")
          ForEach(appState.parameters) { parameter in
            Text(parameter.name).tag(parameter.id)
          }
        }
        .font(.system(size: 12))
      }

      if derivedElement.kind == .offsetCurve {
        Picker(
          AppStrings.tr("inspector.direction"),
          selection: Binding(
            get: { derivedElement.direction },
            set: { _ = appState.setDirection(derivedElement, $0) }
          )
        ) {
          ForEach(OffsetDirection.allCases) { direction in
            Text(direction.displayName).tag(direction)
          }
        }
        .font(.system(size: 12))

        Button {
          _ = appState.reverseDirection(derivedElement)
        } label: {
          Label(AppStrings.tr("inspector.reverse_direction"), systemImage: "arrow.left.arrow.right")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .font(.system(size: 12, weight: .semibold))
        .leatherControlHeight()
      }
    }
  }

  private var valueLabel: String {
    derivedElement.kind == .fillet
      ? AppStrings.tr("inspector.radius") : AppStrings.tr("inspector.distance")
  }

  private var currentParameterID: String? {
    derivedElement.kind == .fillet
      ? derivedElement.radiusParameterID : derivedElement.distanceParameterID
  }

  private var sourceValueText: String {
    InspectorValueFormatting.resolvedText(
      fixedValue: derivedElement.kind == .fillet
        ? derivedElement.radiusMM : derivedElement.distanceMM,
      parameterID: currentParameterID,
      parameters: appState.parameters
    )
  }

  private func commitDistance(_ valueText: String) -> Bool {
    guard let value = Double(valueText) else {
      return false
    }
    return appState.setDistance(derivedElement, value)
  }

  private func assignParameter(_ parameterID: String) {
    guard !parameterID.isEmpty else {
      _ = commitDistance(sourceValueText)
      return
    }
    guard let parameter = appState.parameters.first(where: { $0.id == parameterID }) else {
      return
    }
    _ = appState.setParameter(derivedElement, parameter)
  }
}

struct RoundHoleEditor: View {
  let appState: SelectionRoundHoleEditorModel
  let roundHole: ProjectRoundHole
  let entity: CanvasEntity

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Picker(
        AppStrings.tr("inspector.round_hole_kind"),
        selection: Binding(
          get: { currentRoundHole.kind },
          set: { _ = appState.setKind($0) }
        )
      ) {
        ForEach(ProjectRoundHoleKind.allCases) { kind in
          Text(kind.displayName).tag(kind)
        }
      }
      .font(.system(size: 12))

      SyncedNumericFieldRow(
        label: AppStrings.tr("inspector.diameter"),
        sourceValue: diameterText,
        unit: "mm",
        onCommit: commitDiameter
      )
    }
  }

  private var currentRoundHole: ProjectRoundHole {
    appState.selectedRoundHole ?? roundHole
  }

  private var currentEntity: CanvasEntity {
    guard let selectedEntity = appState.selectedEntity,
      selectedEntity.id == entity.id
    else {
      return entity
    }
    return selectedEntity
  }

  private var diameterText: String {
    guard case .circle(_, let radiusMM) = currentEntity.geometry else {
      return ""
    }
    return String(format: "%.2f", radiusMM * 2.0)
  }

  private func commitDiameter(_ text: String) -> Bool {
    guard let value = Double(text) else {
      return false
    }
    return appState.setDiameter(value)
  }
}

struct EntityGeometryEditor: View {
  let appState: SelectionEntityGeometryEditorModel
  let entity: CanvasEntity

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      switch currentEntity.geometry {
      case .line(_, let end, _):
        SyncedNumericFieldRow(
          label: AppStrings.tr("inspector.segment_length"),
          sourceValue: lineLengthText,
          unit: "mm",
          onCommit: commitLineLength
        )
        Button {
          appState.constrainLineLength()
        } label: {
          Label(AppStrings.tr("inspector.constrain_current_length"), systemImage: "link")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .font(.system(size: 12, weight: .semibold))
        .leatherControlHeight()
        DetailRow(
          label: AppStrings.tr("inspector.end_point"),
          value: "\(format(end.xMM)), \(format(end.yMM))")

      case .circle:
        SyncedNumericFieldRow(
          label: AppStrings.tr("inspector.radius"),
          sourceValue: circleRadiusText,
          unit: "mm",
          onCommit: commitCircleRadius
        )

      case .arc:
        SyncedNumericFieldRow(
          label: AppStrings.tr("inspector.radius"),
          sourceValue: arcRadiusText,
          unit: "mm",
          onCommit: commitArcRadius
        )
        SyncedNumericFieldRow(
          label: AppStrings.tr("inspector.sweep_angle"),
          sourceValue: arcSweepText,
          unit: "°",
          onCommit: commitArcSweep
        )
        SyncedNumericFieldRow(
          label: AppStrings.tr("inspector.start_angle"),
          sourceValue: arcStartText,
          unit: "°",
          onCommit: commitArcStart
        )

      default:
        EmptyView()
      }
    }
  }

  private var lineLengthText: String {
    guard case .line(let start, let end, _) = currentEntity.geometry else {
      return ""
    }
    return format(hypot(end.xMM - start.xMM, end.yMM - start.yMM))
  }

  private var circleRadiusText: String {
    guard case .circle(_, let radiusMM) = currentEntity.geometry else {
      return ""
    }
    return format(radiusMM)
  }

  private var arcRadiusText: String {
    guard case .arc(_, let radiusMM, _, _) = currentEntity.geometry else {
      return ""
    }
    return format(radiusMM)
  }

  private var arcSweepText: String {
    guard case .arc(_, _, _, let sweepAngleRad) = currentEntity.geometry else {
      return ""
    }
    return format(radiansToDegrees(sweepAngleRad))
  }

  private var arcStartText: String {
    guard case .arc(_, _, let startAngleRad, _) = currentEntity.geometry else {
      return ""
    }
    return format(radiansToDegrees(startAngleRad))
  }

  private var currentArcValues: (radius: Double, start: Double, sweep: Double)? {
    switch currentEntity.geometry {
    case .arc(_, let radiusMM, let startAngleRad, let sweepAngleRad):
      return (radiusMM, startAngleRad, sweepAngleRad)
    default:
      return nil
    }
  }

  private func commitLineLength(_ text: String) -> Bool {
    guard isCurrentSelection else {
      return true
    }
    guard let value = Double(text) else {
      return false
    }
    return appState.setLineLength(value)
  }

  private func commitCircleRadius(_ text: String) -> Bool {
    guard isCurrentSelection else {
      return true
    }
    guard let value = Double(text) else {
      return false
    }
    return appState.setCircleRadius(value)
  }

  private func commitArcRadius(_ text: String) -> Bool {
    guard isCurrentSelection else {
      return true
    }
    guard let value = Double(text), let currentArcValues else {
      return false
    }
    return appState.setArc(value, currentArcValues.start, currentArcValues.sweep)
  }

  private func commitArcSweep(_ text: String) -> Bool {
    guard isCurrentSelection else {
      return true
    }
    guard let value = Double(text), let currentArcValues else {
      return false
    }
    return appState.setArc(
      currentArcValues.radius, currentArcValues.start, degreesToRadians(value))
  }

  private func commitArcStart(_ text: String) -> Bool {
    guard isCurrentSelection else {
      return true
    }
    guard let value = Double(text), let currentArcValues else {
      return false
    }
    return appState.setArc(
      currentArcValues.radius, degreesToRadians(value), currentArcValues.sweep)
  }

  private func format(_ value: Double) -> String {
    String(format: "%.2f", value)
  }

  private var currentEntity: CanvasEntity {
    guard let selectedEntity = appState.selectedEntity,
      selectedEntity.id == entity.id
    else {
      return entity
    }
    return selectedEntity
  }

  private var isCurrentSelection: Bool {
    appState.selectedEntity?.id == entity.id
  }
}
