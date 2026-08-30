import SwiftUI

struct InspectorSelectionTab: View {
  let model: SelectionInspectorModel

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      InspectorSection(title: AppStrings.tr("inspector.selection"), symbolName: "cursorarrow") {
        if let selectedConstraint {
          SelectedConstraintEditor(
            appState: model.constraintEditorModel,
            constraint: selectedConstraint
          )
        } else if let selectedMeasurementAnnotation = model.data.selectedMeasurementAnnotation {
          SelectedMeasurementEditor(
            appState: model.measurementEditorModel,
            measurement: selectedMeasurementAnnotation
          )
        } else if let selectedFreeText = model.data.selectedFreeText {
          FreeTextEditor(appState: model.freeTextEditorModel, freeText: selectedFreeText)
        } else if let selectedStitchStartPoint = model.data.selectedStitchStartPoint {
          SelectedStitchStartPointEditor(
            appState: model.stitchPointEditorModel,
            stitchStartPoint: selectedStitchStartPoint
          )
        } else if model.data.selectedEntities.count > 1 {
          MultiSelectionSummary(appState: model.multiSelectionEditorModel)
        } else if let selectedEntity = model.data.selectedEntity {
          EntityEditor(appState: model.entityEditorModel, entity: selectedEntity)
        } else {
          VStack(alignment: .leading, spacing: 4) {
            Text(AppStrings.tr("inspector.no_selection"))
              .font(.system(size: 12, weight: .semibold))
            Text(AppStrings.tr("inspector.no_selection_hint"))
              .font(.system(size: 12))
              .foregroundStyle(LeatherColors.secondaryInk)
          }
        }
      }

      if !model.data.constraints.isEmpty {
        InspectorSection(title: AppStrings.tr("inspector.constraint"), symbolName: "link") {
          ForEach(model.data.constraints) { constraint in
            HStack(spacing: 8) {
              Button {
                model.actions.selectConstraint(constraint.id)
              } label: {
                VStack(alignment: .leading, spacing: 3) {
                  Text(constraint.kind)
                    .font(.system(size: 12, weight: .semibold))
                  Text(constraint.status.displayName)
                    .font(.system(size: LeatherDesignMetrics.Typography.label))
                    .foregroundStyle(LeatherColors.secondaryInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
              }
              .buttonStyle(.plain)
              Button(role: .destructive) {
                model.actions.deleteConstraint(constraint)
              } label: {
                Image(systemName: "trash")
              }
              .buttonStyle(.borderless)
            }
          }
        }
      }

      if !model.data.measurementAnnotations.isEmpty || !model.data.freeTexts.isEmpty {
        InspectorSection(
          title: AppStrings.tr("inspector.measurement_and_notes"),
          symbolName: "ruler"
        ) {
          ForEach(model.data.measurementAnnotations) { annotation in
            HStack(spacing: 8) {
              Button {
                model.actions.selectMeasurementAnnotation(annotation.id)
              } label: {
                Text(annotation.kind)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .buttonStyle(.plain)
              if !annotation.visible {
                Text(AppStrings.tr("inspector.hidden"))
                  .font(.system(size: LeatherDesignMetrics.Typography.label))
                  .foregroundStyle(LeatherColors.secondaryInk)
              }
              Button {
                model.actions.convertMeasurementAnnotationToConstraint(annotation.id)
              } label: {
                Image(systemName: "link")
              }
              .buttonStyle(.borderless)
              Button(role: .destructive) {
                model.actions.deleteMeasurementAnnotation(annotation)
              } label: {
                Image(systemName: "trash")
              }
              .buttonStyle(.borderless)
            }
          }
          ForEach(model.data.freeTexts) { freeText in
            HStack(spacing: 8) {
              Button {
                model.actions.selectFreeText(freeText.id)
              } label: {
                Text(freeText.content)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .buttonStyle(.plain)
              Text(AppStrings.tr("tool.free_text"))
                .font(.system(size: LeatherDesignMetrics.Typography.label))
                .foregroundStyle(LeatherColors.secondaryInk)
            }
          }
        }
      }

      DocumentOverview(appState: model.documentOverviewModel)
    }
  }

  private var selectedConstraint: ProjectConstraint? {
    model.data.selectedConstraintID.flatMap { selectedID in
      model.data.constraints.first(where: { $0.id == selectedID })
    }
  }
}
