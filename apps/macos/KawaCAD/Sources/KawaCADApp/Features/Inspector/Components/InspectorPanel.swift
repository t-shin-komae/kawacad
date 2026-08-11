import SwiftUI

struct InspectorPanel: View {
  let appState: InspectorFeatureModel

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 10) {
        Picker(
          AppStrings.tr("accessibility.inspector_tabs"),
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
        .labelsHidden()
        .accessibilityLabel(Text(AppStrings.tr("accessibility.inspector_tabs")))

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
            InspectorLayerTab()
          case .sharedStyles:
            InspectorStylesTab()
          case .parameters:
            InspectorParametersTab()
          case .parts:
            InspectorPartsTab()
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
    InspectorSection(title: AppStrings.tr("inspector.selection"), symbolName: "cursorarrow") {
      if let selectedConstraint {
        SelectedConstraintEditor(constraint: selectedConstraint)
      } else if let selectedMeasurementAnnotation = appState.selectedMeasurementAnnotation {
        SelectedMeasurementEditor(measurement: selectedMeasurementAnnotation)
      } else if let selectedFreeText = appState.selectedFreeText {
        FreeTextEditor(freeText: selectedFreeText)
      } else if let selectedStitchStartPoint = appState.selectedStitchStartPoint {
        SelectedStitchStartPointEditor(stitchStartPoint: selectedStitchStartPoint)
      } else if appState.selectedEntities.count > 1 {
        MultiSelectionSummary()
      } else if let selectedEntity = appState.selectedEntity {
        EntityEditor(entity: selectedEntity)
      } else {
        Text(AppStrings.tr("inspector.no_selection"))
          .font(.system(size: 12))
          .foregroundStyle(LeatherColors.secondaryInk)
      }
    }

    InspectorSection(title: AppStrings.tr("inspector.constraint"), symbolName: "link") {
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

    InspectorSection(title: AppStrings.tr("inspector.measurement_and_notes"), symbolName: "ruler") {
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

    DocumentOverview()
  }

  private var selectedConstraint: ProjectConstraint? {
    appState.selectedConstraintID.flatMap { selectedID in
      appState.constraints.first(where: { $0.id == selectedID })
    }
  }
}
