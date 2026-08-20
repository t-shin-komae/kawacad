import SwiftUI

struct DocumentOverview: View {
  @EnvironmentObject private var appState: InspectorFeatureModel

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
  @EnvironmentObject private var appState: InspectorFeatureModel
  let measurement: ProjectMeasurementAnnotation

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      DetailRow(label: AppStrings.tr("inspector.kind"), value: measurement.kind)
      HStack(spacing: 8) {
        Button {
          appState.convertMeasurementAnnotationToConstraint(measurement.id)
        } label: {
          Text(AppStrings.tr("canvas.menu.convert_measurement_to_constraint"))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        Button(role: .destructive) {
          appState.deleteMeasurementAnnotation(measurement)
        } label: {
          Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
      }
    }
  }
}

struct SelectedStitchStartPointEditor: View {
  @EnvironmentObject private var appState: InspectorFeatureModel
  let stitchStartPoint: ProjectStitchStartPoint

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      DetailRow(
        label: AppStrings.tr("inspector.kind"), value: AppStrings.tr("tool.stitch_start_point"))
      DetailRow(label: AppStrings.tr("inspector.stitch_target"), value: targetLabel)
      Button(role: .destructive) {
        appState.deleteSelectedEntity()
      } label: {
        Label(AppStrings.tr("common.delete"), systemImage: "trash")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
    }
  }

  private var targetLabel: String {
    appState.entities.first(where: { $0.id == stitchStartPoint.targetID })?.kind.displayName
      ?? AppStrings.tr("inspector.geometry")
  }
}

struct EntityEditor: View {
  @EnvironmentObject private var appState: InspectorFeatureModel
  let entity: CanvasEntity

  var body: some View {
    DetailRow(label: AppStrings.tr("inspector.kind"), value: entity.kind.displayName)
    Picker(
      AppStrings.tr("inspector.layer"),
      selection: Binding(
        get: { entity.layerID ?? "" },
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
      DerivedElementEditor(derivedElement: derivedElement)
    } else {
      SharedStyleSelectionField(
        selectedStyleID: entity.styleID,
        sharedStyles: appState.sharedStyles,
        onChange: { appState.setSelectedEntitiesSharedStyle($0) }
      )
      if let roundHole = appState.selectedRoundHole {
        RoundHoleEditor(roundHole: roundHole, entity: entity)
      }
      EntityGeometryEditor(entity: entity)
    }

    Button(role: .destructive) {
      appState.deleteSelectedEntity()
    } label: {
      Label(AppStrings.tr("common.delete"), systemImage: "trash")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
  }
}

struct PartEditor: View {
  @EnvironmentObject private var appState: InspectorFeatureModel
  let part: ProjectPart

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      Toggle(
        AppStrings.tr("inspector.part_arrangement_target"),
        isOn: Binding(
          get: { appState.arrangementSelectedPartIDs.contains(part.id) },
          set: { _ in appState.togglePartArrangementSelection(part) }
        )
      )
      .toggleStyle(.checkbox)

      HStack(spacing: 10) {
        Toggle(
          AppStrings.tr("inspector.part_visible"),
          isOn: Binding(
            get: { part.visible },
            set: { _ in _ = appState.updatePartSettings(part.withSettings(visible: !part.visible)) }
          ))
        Toggle(
          AppStrings.tr("inspector.part_printable"),
          isOn: Binding(
            get: { part.printable },
            set: { _ in
              _ = appState.updatePartSettings(part.withSettings(printable: !part.printable))
            }
          ))
      }
      .toggleStyle(.checkbox)
      .font(.system(size: 10))

      Stepper(
        AppStrings.tr("inspector.part_quantity", part.quantity),
        value: Binding(
          get: { part.quantity },
          set: { _ = appState.updatePartSettings(part.withSettings(quantity: $0)) }
        ),
        in: 1...999
      )
      .font(.system(size: 11))

      SyncedTextField(
        placeholder: AppStrings.tr("inspector.part_name"),
        sourceValue: part.name,
        onCommit: { value in
          appState.updatePart(part.withMetadata(name: value, originMM: part.originMM))
        },
        font: .system(size: 12, weight: .medium)
      )

      HStack(spacing: 8) {
        partCoordinateField(AppStrings.tr("inspector.part_origin_x_mm"), value: part.originMM.xMM) {
          value in
          _ = appState.movePart(
            part,
            ModelPoint(xMM: value - part.originMM.xMM, yMM: 0)
          )
        }
        partCoordinateField(AppStrings.tr("inspector.part_origin_y_mm"), value: part.originMM.yMM) {
          value in
          _ = appState.movePart(
            part,
            ModelPoint(xMM: 0, yMM: value - part.originMM.yMM)
          )
        }
      }

      Button {
        appState.beginSettingPartOrigin(part)
      } label: {
        Label(
          AppStrings.tr(
            appState.isSettingPartOrigin
              ? "inspector.cancel_part_origin_setting"
              : "inspector.set_part_origin_on_canvas"),
          systemImage: "scope"
        )
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)

      DetailRow(
        label: AppStrings.tr("inspector.part_derived_members"),
        value: "\(part.derivedElementIDs.count)")
      DetailRow(
        label: AppStrings.tr("inspector.part_text_members"), value: "\(part.freeTextIDs.count)")
      DetailRow(
        label: AppStrings.tr("inspector.part_measurement_members"),
        value: "\(part.measurementAnnotationIDs.count)")

      Button {
        appState.selectPartContents(part)
      } label: {
        Label(AppStrings.tr("inspector.select_part_contents"), systemImage: "cursorarrow.rays")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)

      HStack(spacing: 8) {
        Button {
          _ = appState.movePart(part, ModelPoint(xMM: -10, yMM: 0))
        } label: {
          Image(systemName: "arrow.left")
        }
        Button {
          _ = appState.movePart(part, ModelPoint(xMM: 0, yMM: 10))
        } label: {
          Image(systemName: "arrow.up")
        }
        Button {
          _ = appState.movePart(part, ModelPoint(xMM: 0, yMM: -10))
        } label: {
          Image(systemName: "arrow.down")
        }
        Button {
          _ = appState.movePart(part, ModelPoint(xMM: 10, yMM: 0))
        } label: {
          Image(systemName: "arrow.right")
        }
      }
      .buttonStyle(.bordered)
      .help(AppStrings.tr("inspector.move_part_10mm"))

      Button {
        appState.duplicatePart(part)
      } label: {
        Label(AppStrings.tr("inspector.duplicate_part"), systemImage: "plus.square.on.square")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)

      Button {
        appState.addPartToLibrary(part)
      } label: {
        Label(AppStrings.tr("inspector.add_part_to_library"), systemImage: "books.vertical.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)

      Divider()

      Text(AppStrings.tr("inspector.part_fixed_help"))
        .font(.system(size: 10))
        .foregroundStyle(LeatherColors.secondaryInk)

      Button(role: .destructive) {
        appState.deletePart(part)
      } label: {
        Label(AppStrings.tr("inspector.ungroup_part"), systemImage: "square.stack.3d.down.right")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
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
            .font(.system(size: 10, weight: .medium))
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
  @EnvironmentObject private var appState: InspectorFeatureModel
  let freeText: ProjectFreeText

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      DetailRow(label: AppStrings.tr("inspector.kind"), value: AppStrings.tr("tool.free_text"))
      SyncedTextField(
        placeholder: AppStrings.tr("inspector.free_text_content"),
        sourceValue: freeText.content,
        onCommit: { value in
          appState.updateFreeText(freeText.withContent(value))
        },
        font: .system(size: 12, weight: .medium)
      )

      HStack(spacing: 8) {
        numericField(
          AppStrings.tr("inspector.x_mm"),
          value: freeText.positionMM.xMM,
          onCommit: { xMM in
            appState.updateFreeText(
              freeText.withPosition(ModelPoint(xMM: xMM, yMM: freeText.positionMM.yMM))
            )
          }
        )
        numericField(
          AppStrings.tr("inspector.y_mm"),
          value: freeText.positionMM.yMM,
          onCommit: { yMM in
            appState.updateFreeText(
              freeText.withPosition(ModelPoint(xMM: freeText.positionMM.xMM, yMM: yMM))
            )
          }
        )
      }

      numericField(
        AppStrings.tr("inspector.font_size_mm"),
        value: freeText.fontSizeMM,
        onCommit: { fontSizeMM in
          appState.updateFreeText(freeText.withFontSize(fontSizeMM))
        }
      )

      Button(role: .destructive) {
        appState.deleteSelectedFreeText()
      } label: {
        Label(AppStrings.tr("common.delete"), systemImage: "trash")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
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
  @EnvironmentObject private var appState: InspectorFeatureModel
  let constraint: ProjectConstraint

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      DetailRow(label: AppStrings.tr("inspector.kind"), value: constraint.kind)
      Text(AppStrings.tr("inspector.constraint_targets_highlighted"))
        .font(.system(size: 11))
        .foregroundStyle(LeatherColors.secondaryInk)

      if constraint.isDimensionConstraint {
        ConstraintValueEditor(constraint: constraint)
      }

      Button(role: .destructive) {
        appState.deleteConstraint(constraint)
      } label: {
        Label(AppStrings.tr("common.delete"), systemImage: "trash")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
    }
    .onAppear {
      appState.hoverConstraint(nil)
    }
  }
}

struct MultiSelectionSummary: View {
  @EnvironmentObject private var appState: InspectorFeatureModel

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
        onChange: { appState.setSelectedEntitiesSharedStyle($0) }
      )

      Text(AppStrings.tr("inspector.batch_actions"))
        .font(.system(size: 12))
        .foregroundStyle(LeatherColors.secondaryInk)

      HStack(spacing: 8) {
        Button(role: .destructive) {
          appState.deleteSelectedEntity()
        } label: {
          Label(AppStrings.tr("common.delete"), systemImage: "trash")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        if appState.canConstrainSelectedLineLengthsEqual {
          Button {
            appState.constrainSelectedLineLengthsEqual()
          } label: {
            Label(AppStrings.tr("inspector.equal_length_constraint"), systemImage: "link")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
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
  @EnvironmentObject private var appState: InspectorFeatureModel
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
      return appState.setConstraintDegrees(constraint, value)
    }
    return appState.setConstraintValue(constraint, value)
  }

  private func assignParameter(_ parameterID: String) {
    guard !parameterID.isEmpty else {
      _ = commit(sourceValueText)
      return
    }
    guard let parameter = appState.parameters.first(where: { $0.id == parameterID }) else {
      return
    }
    _ = appState.setConstraintParameter(constraint, parameter)
  }
}

struct DerivedElementEditor: View {
  @EnvironmentObject private var appState: InspectorFeatureModel
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
            set: { _ = appState.setDerivedElementDirection(derivedElement, $0) }
          )
        ) {
          ForEach(OffsetDirection.allCases) { direction in
            Text(direction.displayName).tag(direction)
          }
        }
        .font(.system(size: 12))

        Button {
          _ = appState.reverseDerivedElementDirection(derivedElement)
        } label: {
          Label(AppStrings.tr("inspector.reverse_direction"), systemImage: "arrow.left.arrow.right")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .font(.system(size: 12, weight: .semibold))
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
    return appState.setDerivedElementDistance(derivedElement, value)
  }

  private func assignParameter(_ parameterID: String) {
    guard !parameterID.isEmpty else {
      _ = commitDistance(sourceValueText)
      return
    }
    guard let parameter = appState.parameters.first(where: { $0.id == parameterID }) else {
      return
    }
    _ = appState.setDerivedElementParameter(derivedElement, parameter)
  }
}

struct RoundHoleEditor: View {
  @EnvironmentObject private var appState: InspectorFeatureModel
  let roundHole: ProjectRoundHole
  let entity: CanvasEntity

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Picker(
        AppStrings.tr("inspector.round_hole_kind"),
        selection: Binding(
          get: { currentRoundHole.kind },
          set: { _ = appState.setSelectedRoundHoleKind($0) }
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
    return appState.setSelectedRoundHoleDiameter(value)
  }
}

struct EntityGeometryEditor: View {
  @EnvironmentObject private var appState: InspectorFeatureModel
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
          appState.constrainSelectedLineLength()
        } label: {
          Label(AppStrings.tr("inspector.constrain_current_length"), systemImage: "link")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .font(.system(size: 12, weight: .semibold))
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
    return appState.setSelectedLineLength(value)
  }

  private func commitCircleRadius(_ text: String) -> Bool {
    guard isCurrentSelection else {
      return true
    }
    guard let value = Double(text) else {
      return false
    }
    return appState.setSelectedCircleRadius(value)
  }

  private func commitArcRadius(_ text: String) -> Bool {
    guard isCurrentSelection else {
      return true
    }
    guard let value = Double(text), let currentArcValues else {
      return false
    }
    return appState.setSelectedArc(value, currentArcValues.start, currentArcValues.sweep)
  }

  private func commitArcSweep(_ text: String) -> Bool {
    guard isCurrentSelection else {
      return true
    }
    guard let value = Double(text), let currentArcValues else {
      return false
    }
    return appState.setSelectedArc(
      currentArcValues.radius, currentArcValues.start, degreesToRadians(value))
  }

  private func commitArcStart(_ text: String) -> Bool {
    guard isCurrentSelection else {
      return true
    }
    guard let value = Double(text), let currentArcValues else {
      return false
    }
    return appState.setSelectedArc(
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
