import { useEffect, useRef, useState } from "react";
import { Link2, MousePointer2, Ruler } from "lucide-react";
import { geometryOf, type PointMm, type RawEntity } from "@/features/canvas/domain/cad";
import { TextEntryDialog, type TextEntryField } from "@/shared/components/TextEntryDialog";
import {
  initialInspectorFeatureState,
  revealInspectorSearchForCurrentTab,
  setInspectorTab,
  type InspectorTab,
} from "@/features/inspector/selectors/inspectorFeature";
import {
  layerColorPresets,
  layerStrokeWidthPresets,
  matchingLayerColorPreset,
  matchingLayerStrokeWidthPreset,
} from "@/features/inspector/domain/stylePresets";
import { parseDecimal } from "@/shared/state/syncedField";
import { appStrings } from "@/localization";
import { InspectorLayerTab } from "@/features/inspector/components/InspectorLayerTab";
import { InspectorParametersTab } from "@/features/inspector/components/InspectorParametersTab";
import { InspectorPartsTab } from "@/features/parts/components/InspectorPartsTab";
import { InspectorStylesTab } from "@/features/inspector/components/InspectorStylesTab";
import {
  DocumentOverview,
  EntityEditor,
  FreeTextEditor,
  ParameterEditor,
  SelectedConstraintEditor,
  SelectedMeasurementEditor,
  SelectedStitchStartPointEditor,
  StyleFields,
  defaultStyle,
} from "@/features/inspector/components/InspectorSelectionEditors";
import { PartEditor } from "@/features/parts/components/InspectorPartEditors";
import { InspectorSection } from "@/shared/components/InspectorPrimitives";
import type { Constraint, DerivedElement, LineStyle, Part, PartLibraryEntry } from "@/shared/domain/coreWireTypes";
import type { InspectorViewModel, Measurement } from "@/features/inspector/domain/inspectorViewModel";

export type PendingTextEntry = {
  title: string;
  fields: TextEntryField[];
  onConfirm: (values: Record<string, string>) => void;
};
export type { Constraint, DerivedElement, LineStyle, Part, PartLibraryEntry } from "@/shared/domain/coreWireTypes";
export type { InspectorViewModel, Measurement } from "@/features/inspector/domain/inspectorViewModel";
export type Props = InspectorViewModel;
const tabs: Array<[InspectorTab, string]> = [
  ["selection", appStrings.inspector.tabs.selection],
  ["layers", appStrings.inspector.tabs.layers],
  ["styles", appStrings.inspector.tabs.styles],
  ["parameters", appStrings.inspector.tabs.parameters],
  ["parts", appStrings.inspector.tabs.parts],
];
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

export function InspectorPanel(props: Props) {
  const [feature, setFeature] = useState(initialInspectorFeatureState);
  const [pendingTextEntry, setPendingTextEntry] = useState<PendingTextEntry>();
  const [pendingSelectionChange, setPendingSelectionChange] = useState(false);
  const {
    selectedCount,
    selectedEntity,
    constraints,
    measurements,
    freeTexts,
    parameters,
    layers,
    sharedStyles,
    parts,
    arrangementPartIds,
    partLibrary,
    roundHoles,
    onCommand,
  } = props;
  const selectedEntities = props.selectedEntities ?? (selectedEntity ? [selectedEntity] : []);
  const selectedGeometryLabels = [...new Set(selectedEntities.map(geometryLabel))];
  const selectedLayerIDs = [
    ...new Set(selectedEntities.map((entity) => ("layerId" in entity ? entity.layerId : null))),
  ];
  const selectedLayerLabels = selectedLayerIDs.map((id) =>
    id ? (layers.find((layer) => layer.id === id)?.name ?? id) : appStrings.inspector.noValue,
  );
  const [bulkStyleID, setBulkStyleID] = useState("");
  const openTextEntry = (title: string, fields: TextEntryField[], onConfirm: PendingTextEntry["onConfirm"]) => {
    setPendingTextEntry({ title, fields, onConfirm });
  };
  const selectionKey = [
    selectedCount,
    ...(props.selectedEntityIds ?? []),
    props.selectedConstraint?.id,
    props.selectedMeasurement?.id,
    props.selectedFreeText?.id,
    props.selectedStitchStartPoint?.id,
  ].join("|");
  const previousSelectionKey = useRef(selectionKey);
  useEffect(() => {
    const revealSearch = () => setFeature((current) => revealInspectorSearchForCurrentTab(current));
    window.addEventListener("kawa-cad-find-inspector", revealSearch);
    return () => window.removeEventListener("kawa-cad-find-inspector", revealSearch);
  }, []);
  useEffect(() => {
    props.onTabChange?.(feature.inspectorTab);
    if (feature.inspectorTab === "selection") setPendingSelectionChange(false);
  }, [feature.inspectorTab, props.onTabChange]);
  useEffect(() => {
    const selectionChanged = previousSelectionKey.current !== selectionKey;
    previousSelectionKey.current = selectionKey;
    if (selectionChanged && feature.inspectorTab !== "selection") setPendingSelectionChange(true);
  }, [feature.inspectorTab, selectionKey]);
  return (
    <aside className="inspector" aria-label={appStrings.inspector.ariaLabel}>
      <div className="inspector-header">
        <nav className="inspector-tabs" role="tablist" aria-label={appStrings.inspector.tabList}>
          {tabs.map(([id, label]) => (
            <button
              key={id}
              role="tab"
              aria-selected={feature.inspectorTab === id}
              className={feature.inspectorTab === id ? "active" : ""}
              onClick={() => {
                setFeature((state) => setInspectorTab(state, id));
                if (id === "selection") setPendingSelectionChange(false);
              }}
            >
              {label}
            </button>
          ))}
        </nav>
        {pendingSelectionChange && (
          <div aria-live="polite" className="inspector-selection-change-status">
            <button
              type="button"
              className="inspector-selection-change"
              aria-label={appStrings.inspector.showSelection}
              onClick={() => {
                setFeature((state) => setInspectorTab(state, "selection"));
                setPendingSelectionChange(false);
              }}
            >
              <span>{appStrings.inspector.selectionChanged}</span>
              <strong>{appStrings.inspector.showSelection}</strong>
            </button>
          </div>
        )}
      </div>
      <div className="inspector-content">
        {feature.inspectorTab === "selection" && (
          <>
            <InspectorSection title={appStrings.inspector.selection} icon={MousePointer2}>
              {props.selectedConstraint ? (
                <SelectedConstraintEditor
                  constraint={props.selectedConstraint}
                  parameters={parameters}
                  onCommand={onCommand}
                  onDelete={props.onDeleteSelection}
                />
              ) : props.selectedMeasurement ? (
                <SelectedMeasurementEditor
                  measurement={props.selectedMeasurement}
                  onConvert={props.onConvertMeasurement}
                  onDelete={props.onDeleteSelection}
                />
              ) : props.selectedStitchStartPoint ? (
                <SelectedStitchStartPointEditor targetEntity={props.selectedStitchTargetEntity} />
              ) : props.selectedFreeText ? (
                <FreeTextEditor
                  freeText={props.selectedFreeText}
                  onCommand={onCommand}
                  onDelete={props.onDeleteSelection}
                />
              ) : selectedCount > 1 ? (
                <div className="inspector-card multi-selection-summary">
                  <strong>{appStrings.inspector.selectionSummary(selectedCount)}</strong>
                  <div className="detail-row">
                    <span>{appStrings.inspector.selectedGeometry}</span>
                    <strong>{selectedGeometryLabels.join("、")}</strong>
                  </div>
                  <div className="detail-row">
                    <span>{appStrings.inspector.selectedLayer}</span>
                    <strong>{selectedLayerLabels.join("、")}</strong>
                  </div>
                  <label>
                    {appStrings.inspector.bulkStyle}
                    <select value={bulkStyleID} onChange={(event) => setBulkStyleID(event.target.value)}>
                      <option value="">{appStrings.inspector.noValue}</option>
                      {sharedStyles.map((style) => (
                        <option key={style.id} value={style.id}>
                          {style.name}
                        </option>
                      ))}
                    </select>
                  </label>
                  <button disabled={!bulkStyleID} onClick={() => props.onApplyStyle(bulkStyleID)}>
                    {appStrings.inspector.applyBulkStyle}
                  </button>
                </div>
              ) : selectedEntity ? (
                <EntityEditor
                  entity={selectedEntity}
                  derivedElement={props.selectedDerivedElement}
                  layers={layers}
                  sharedStyles={sharedStyles}
                  parameters={parameters}
                  roundHole={roundHoles.find((item) => item.entityId === selectedEntity.id)}
                  onCommand={onCommand}
                  onConstrainSegmentLength={props.onConstrainSegmentLength}
                />
              ) : (
                <p>{appStrings.inspector.nothingSelected}</p>
              )}
              {selectedEntity && (
                <button className="inspector-destructive-button" onClick={props.onDeleteSelection}>
                  {appStrings.contextMenu.delete}
                </button>
              )}
            </InspectorSection>
            <InspectorSection title={appStrings.inspector.constraint} icon={Link2}>
              {constraints.length ? (
                constraints.map((item) => (
                  <div className="row inspector-list-row" key={item.id}>
                    <button className="inspector-row-action" onClick={() => props.onSelectConstraint?.(item.id)}>
                      <span>{constraintLabel(item.kind)}</span>
                      <small>
                        {appStrings.constraintStatusNames[
                          item.status as keyof typeof appStrings.constraintStatusNames
                        ] ?? item.status}{" "}
                        {valueLabel(item.value)}
                      </small>
                    </button>
                    <button
                      aria-label={`${constraintLabel(item.kind)} ${appStrings.contextMenu.delete}`}
                      onClick={() =>
                        onCommand("deleteConstraint", item.id, appStrings.inspector.operationMessage.constraintDeleted)
                      }
                    >
                      {appStrings.contextMenu.delete}
                    </button>
                  </div>
                ))
              ) : (
                <p>{appStrings.workbench.noConstraintDescription}</p>
              )}
            </InspectorSection>
            <InspectorSection title={appStrings.inspector.measurementAndNotes} icon={Ruler}>
              {measurements.map((item) => (
                <div className="row inspector-list-row" key={item.id}>
                  <button className="inspector-row-action" onClick={() => props.onSelectMeasurement?.(item.id)}>
                    {measurementLabel(item.kind)}
                  </button>
                  {!item.visible && <small>{appStrings.inspector.hidden}</small>}
                  <button
                    aria-label={`${measurementLabel(item.kind)} ${appStrings.inspector.measurementConstraint}`}
                    onClick={() => props.onConvertMeasurement?.(item.id)}
                  >
                    {appStrings.inspector.measurementConstraint}
                  </button>
                  <button
                    aria-label={`${measurementLabel(item.kind)} ${appStrings.contextMenu.delete}`}
                    onClick={() =>
                      onCommand(
                        "deleteMeasurementAnnotation",
                        item.id,
                        appStrings.inspector.operationMessage.annotationDeleted,
                      )
                    }
                  >
                    {appStrings.contextMenu.delete}
                  </button>
                </div>
              ))}
              {freeTexts.map((item) => (
                <div className="row inspector-list-row" key={item.id}>
                  <button className="inspector-row-action" onClick={() => props.onSelectFreeText?.(item.id)}>
                    {item.content}
                  </button>
                  <small>{appStrings.toolNames.freeText}</small>
                </div>
              ))}
            </InspectorSection>
            <DocumentOverview summary={props.documentSummary} />
          </>
        )}
        {feature.inspectorTab === "layers" && (
          <InspectorLayerTab
            props={props}
            feature={feature}
            updateFeature={(update) => setFeature(update)}
            renderStyleFields={(style, onChange) => <StyleFields style={style} onChange={onChange} />}
          />
        )}
        {feature.inspectorTab === "styles" && (
          <InspectorStylesTab
            props={props}
            feature={feature}
            updateFeature={(update) => setFeature(update)}
            defaultStyle={defaultStyle}
            renderStyleFields={(style, onChange) => <StyleFields style={style} onChange={onChange} />}
          />
        )}
        {feature.inspectorTab === "parameters" && (
          <InspectorParametersTab
            props={props}
            feature={feature}
            updateFeature={(update) => setFeature(update)}
            renderParameterEditor={(parameter) => <ParameterEditor parameter={parameter} onCommand={onCommand} />}
          />
        )}
        {feature.inspectorTab === "parts" && (
          <InspectorPartsTab
            selectedCount={props.selectedCount}
            parts={props.parts}
            arrangementPartIds={arrangementPartIds}
            partLibrary={partLibrary}
            onCreatePart={props.onCreatePart}
            onSelectPart={props.onSelectPart}
            onAlignParts={props.onAlignParts}
            onDistributeParts={props.onDistributeParts}
            onInsertPartFromLibrary={props.onInsertPartFromLibrary}
            onRemovePartFromLibrary={props.onRemovePartFromLibrary}
            renderPartEditor={(part) => (
              <PartEditor
                part={part}
                arrangementSelected={arrangementPartIds.has(part.id)}
                onCommand={onCommand}
                onSelect={() => props.onSelectPart(part)}
                onToggleArrangement={() => props.onToggleArrangementPart(part.id)}
                onAddToLibrary={() => props.onAddPartToLibrary(part)}
                onBeginSetOrigin={() => props.onBeginSetPartOrigin?.(part)}
              />
            )}
          />
        )}
      </div>
      {pendingTextEntry && (
        <TextEntryDialog
          title={pendingTextEntry.title}
          fields={pendingTextEntry.fields}
          onConfirm={(values) => {
            pendingTextEntry.onConfirm(values);
            setPendingTextEntry(undefined);
          }}
          onCancel={() => setPendingTextEntry(undefined)}
        />
      )}
    </aside>
  );
}
