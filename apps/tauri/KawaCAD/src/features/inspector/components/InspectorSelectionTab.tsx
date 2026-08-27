import { Link2, MousePointer2, Ruler } from "lucide-react";
import { geometryOf, type RawEntity } from "@/features/canvas/domain/cad";
import { appStrings } from "@/localization";
import { aggregateConstraintStatus } from "@/features/canvas/components/CadToolbar";
import { InspectorSection } from "@/shared/components/InspectorPrimitives";
import {
  DocumentOverview,
  EntityEditor,
  FreeTextEditor,
  MultiSelectionSummary,
  SelectedConstraintEditor,
  SelectedMeasurementEditor,
  SelectedStitchStartPointEditor,
} from "@/features/inspector/components/InspectorSelectionEditors";
import type { SelectionInspectorModel } from "@/features/inspector/domain/inspectorViewModel";

type InspectorSelectionTabProps = SelectionInspectorModel;

function valueLabel(value?: Record<string, number | string>) {
  if (typeof value?.fixedMm === "number") return value.fixedMm.toFixed(2) + " mm";
  if (typeof value?.fixedDegrees === "number") return value.fixedDegrees.toFixed(1) + "°";
  return typeof value?.parameter === "string" ? value.parameter : "";
}

function geometryLabel(entity: RawEntity) {
  switch (geometryOf(entity)?.tag) {
    case "point":
      return appStrings.toolNames.point;
    case "lineSegment":
      return appStrings.toolNames.line;
    case "centerLine":
      return appStrings.toolNames.centerLine;
    case "circle":
      return appStrings.toolNames.circle;
    case "arc":
      return appStrings.toolNames.arc;
    default:
      return appStrings.inspector.geometry;
  }
}

function constraintLabel(kind: string) {
  return appStrings.constraintKindNames[kind as keyof typeof appStrings.constraintKindNames] ?? kind;
}

function measurementLabel(kind: string) {
  return appStrings.measurementKindNames[kind as keyof typeof appStrings.measurementKindNames] ?? kind;
}

export function InspectorSelectionTab({ model }: { model: InspectorSelectionTabProps }) {
  const {
    selectedCount,
    selectedEntity,
    selectedEntities = selectedEntity ? [selectedEntity] : [],
    selectedConstraint,
    selectedMeasurement,
    selectedStitchStartPoint,
    selectedStitchTargetEntity,
    selectedFreeText,
    selectedDerivedElement,
    constraints,
    measurements,
    freeTexts,
    parameters,
    layers,
    sharedStyles,
    roundHoles,
    documentSummary,
    actions,
  } = model;
  const selectedGeometryLabels = [...new Set(selectedEntities.map(geometryLabel))];
  const selectedLayerIDs = [
    ...new Set(selectedEntities.map((entity) => ("layerId" in entity ? entity.layerId : null))),
  ];
  const selectedLayerLabels = selectedLayerIDs.map((id) =>
    id ? (layers.find((layer) => layer.id === id)?.name ?? id) : appStrings.inspector.noValue,
  );
  return (
    <>
      <InspectorSection title={appStrings.inspector.selection} icon={MousePointer2}>
        {selectedConstraint ? (
          <SelectedConstraintEditor
            constraint={selectedConstraint}
            parameters={parameters}
            actions={actions}
            onDelete={actions.deleteConstraint}
          />
        ) : selectedMeasurement ? (
          <SelectedMeasurementEditor
            measurement={selectedMeasurement}
            onConvert={actions.convertMeasurement}
            onDelete={actions.deleteMeasurement}
          />
        ) : selectedStitchStartPoint ? (
          <SelectedStitchStartPointEditor targetEntity={selectedStitchTargetEntity} />
        ) : selectedFreeText ? (
          <FreeTextEditor freeText={selectedFreeText} actions={actions} onDelete={actions.deleteFreeText} />
        ) : selectedCount > 1 ? (
          <MultiSelectionSummary
            selectedCount={selectedCount}
            geometryLabels={selectedGeometryLabels}
            layerLabels={selectedLayerLabels}
            sharedStyles={sharedStyles}
            onApplyStyle={actions.applyStyle}
          />
        ) : selectedEntity ? (
          <EntityEditor
            entity={selectedEntity}
            derivedElement={selectedDerivedElement}
            layers={layers}
            sharedStyles={sharedStyles}
            parameters={parameters}
            roundHole={roundHoles.find((item) => item.entityId === selectedEntity.id)}
            actions={actions}
            onDelete={actions.deleteEntity}
          />
        ) : (
          <div className="inspector-empty-state">
            <strong>{appStrings.inspector.noSelection}</strong>
            <p>{appStrings.inspector.noSelectionHint}</p>
          </div>
        )}
      </InspectorSection>
      {constraints.length > 0 && (
        <InspectorSection title={appStrings.inspector.constraint} icon={Link2}>
          {constraints.map((item) => (
            <div className="row inspector-list-row" key={item.id}>
              <button className="inspector-row-action" onClick={() => actions.selectConstraint(item.id)}>
                <span>{constraintLabel(item.kind)}</span>
                <small>
                  {appStrings.constraintStatus[aggregateConstraintStatus([item.status])] ?? item.status}{" "}
                  {valueLabel(item.value)}
                </small>
              </button>
              <button
                aria-label={`${constraintLabel(item.kind)} ${appStrings.contextMenu.delete}`}
                onClick={() =>
                  actions.deleteConstraint(item.id, appStrings.inspector.operationMessage.constraintDeleted)
                }
              >
                {appStrings.contextMenu.delete}
              </button>
            </div>
          ))}
        </InspectorSection>
      )}
      {(measurements.length > 0 || freeTexts.length > 0) && (
        <InspectorSection title={appStrings.inspector.measurementAndNotes} icon={Ruler}>
          {measurements.map((item) => (
            <div className="row inspector-list-row" key={item.id}>
              <button className="inspector-row-action" onClick={() => actions.selectMeasurement(item.id)}>
                {measurementLabel(item.kind)}
              </button>
              {!item.visible && <small>{appStrings.inspector.hidden}</small>}
              <button
                aria-label={`${measurementLabel(item.kind)} ${appStrings.inspector.measurementConstraint}`}
                onClick={() => actions.convertMeasurement(item.id)}
              >
                {appStrings.inspector.measurementConstraint}
              </button>
              <button
                aria-label={`${measurementLabel(item.kind)} ${appStrings.contextMenu.delete}`}
                onClick={() =>
                  actions.deleteMeasurement(item.id, appStrings.inspector.operationMessage.annotationDeleted)
                }
              >
                {appStrings.contextMenu.delete}
              </button>
            </div>
          ))}
          {freeTexts.map((item) => (
            <div className="row inspector-list-row" key={item.id}>
              <button className="inspector-row-action" onClick={() => actions.selectFreeText(item.id)}>
                {item.content}
              </button>
              <small>{appStrings.toolNames.freeText}</small>
            </div>
          ))}
        </InspectorSection>
      )}
      <DocumentOverview summary={documentSummary} />
    </>
  );
}
