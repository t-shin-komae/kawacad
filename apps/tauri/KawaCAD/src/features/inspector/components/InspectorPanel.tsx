import { useEffect, useState } from "react";
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
import { openConstraintValueEntry } from "@/features/parts/components/InspectorPartEditors";
import { PartEditor } from "@/features/parts/components/InspectorPartEditors";

export type Constraint = { id: string; kind: string; status: string; value?: Record<string, number | string> };
export type Measurement = { id: string; kind: string; visible: boolean };
export type LineStyle = {
  stroke: { red: number; green: number; blue: number; alpha: number };
  strokeWidthMm: number;
  pattern: string;
};
export type Part = {
  id: string;
  name: string;
  quantity: number;
  visible: boolean;
  printable: boolean;
  originMm: PointMm;
  entityIds: string[];
  outlineEntityIds: string[];
  holeEntityIdGroups: string[][];
  derivedElementIds: string[];
  freeTextIds: string[];
  measurementAnnotationIds: string[];
};
export type PartLibraryEntry = { id: string; name: string; libraryJson: string; sourcePart: Part };
type ConstraintValue = { fixedMm?: number; parameter?: string };
export type PendingTextEntry = {
  title: string;
  fields: TextEntryField[];
  onConfirm: (values: Record<string, string>) => void;
};
type OffsetCurve = { sourceEntityIds: string[]; distance: ConstraintValue; direction: string };
type Fillet = { sourceEntityIds: string[]; radius: ConstraintValue; closed?: boolean };
export type DerivedElement = {
  id: string;
  layerId?: string | null;
  styleId?: string | null;
  kind: { offsetCurve?: OffsetCurve; fillet?: Fillet };
};

export type Props = {
  selectedCount: number;
  documentSummary: {
    viewMode: string;
    activeLayerName: string;
    visibleEntityCount: number;
    constraintCount: number;
    parameterCount: number;
  };
  selectedEntityIds?: string[];
  selectedEntities?: RawEntity[];
  selectedEntity?: RawEntity;
  selectedDerivedElement?: DerivedElement;
  selectedFreeText?: { id: string; content: string; positionMm: PointMm; fontSizeMm: number };
  selectedConstraint?: Constraint;
  selectedMeasurement?: Measurement;
  selectedStitchStartPoint?: { id: string; targetEntityId: string };
  constraints: Constraint[];
  measurements: Measurement[];
  freeTexts: Array<{ id: string; content: string; positionMm: PointMm; fontSizeMm: number }>;
  parameters: Array<{ id: string; name: string; valueMm: number; unit: string; memo: string }>;
  layers: Array<{ id: string; name: string; visible: boolean; printable: boolean; kind: string; style: LineStyle }>;
  activeLayerId: string;
  sharedStyles: Array<{ id: string; name: string; style: LineStyle }>;
  parts: Part[];
  arrangementPartIds: Set<string>;
  partLibrary: PartLibraryEntry[];
  roundHoles: Array<{ id: string; entityId: string; kind: string }>;
  onCommand: (kind: string, payload: unknown, success: string) => void;
  onApplyStyle: (styleId?: string) => void;
  onDeleteSelection: () => void;
  onCreatePart: () => void;
  onAddParameter: () => void;
  onAddLayer: () => void;
  onActiveLayerChange: (id: string) => void;
  onRenameLayer: (id: string, name: string) => void;
  onDeleteLayer: (layer: { id: string; name: string }) => void;
  onSetPartQuantity: (id: string, quantity: number) => void;
  onSelectPart: (part: Part) => void;
  onToggleArrangementPart: (id: string) => void;
  onAlignParts: (alignment: string) => void;
  onDistributeParts: (axis: string) => void;
  onAddPartToLibrary: (part: Part) => void;
  onInsertPartFromLibrary: (entry: PartLibraryEntry) => void;
  onRemovePartFromLibrary: (entry: PartLibraryEntry) => void;
  onBeginSetPartOrigin?: (part: Part) => void;
  onConstrainSegmentLength?: (entityId: string) => void;
  onSelectMeasurement?: (id: string) => void;
  onConvertMeasurement?: (id: string) => void;
};
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
  const hasSelection = Boolean(
    selectedCount ||
    props.selectedConstraint ||
    props.selectedFreeText ||
    props.selectedMeasurement ||
    props.selectedStitchStartPoint,
  );
  const selectionSummary = selectedCount
    ? appStrings.inspector.selectionSummary(selectedCount)
    : props.selectedConstraint
      ? appStrings.inspector.selectedConstraint
      : props.selectedMeasurement
        ? appStrings.inspector.selectedMeasurement
        : props.selectedStitchStartPoint
          ? appStrings.inspector.selectedStitchStart
          : props.selectedFreeText
            ? appStrings.inspector.selectedText
            : appStrings.inspector.noneSelected;
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
  useEffect(() => {
    const revealSearch = () => setFeature((current) => revealInspectorSearchForCurrentTab(current));
    window.addEventListener("kawa-cad-find-inspector", revealSearch);
    return () => window.removeEventListener("kawa-cad-find-inspector", revealSearch);
  }, []);
  useEffect(() => {
    if (feature.inspectorTab !== "selection") setPendingSelectionChange(true);
    else setPendingSelectionChange(false);
  }, [feature.inspectorTab, selectionKey]);
  return (
    <aside className="inspector" aria-label={appStrings.inspector.ariaLabel}>
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
        <div className="inspector-selection-change" role="status">
          <span>{appStrings.inspector.selectionChanged}</span>
          <button
            onClick={() => {
              setFeature((state) => setInspectorTab(state, "selection"));
              setPendingSelectionChange(false);
            }}
          >
            {appStrings.inspector.showSelection}
          </button>
        </div>
      )}
      <div className="inspector-content">
        {feature.inspectorTab === "selection" && (
          <>
            <section>
              <h2>
                <MousePointer2 aria-hidden="true" />
                {appStrings.inspector.selection}
              </h2>
              {hasSelection && selectedCount <= 1 && <p className="inspector-selection-context">{selectionSummary}</p>}
              {props.selectedConstraint ? (
                <SelectedConstraintEditor
                  constraint={props.selectedConstraint}
                  parameters={parameters}
                  onCommand={onCommand}
                />
              ) : props.selectedMeasurement ? (
                <SelectedMeasurementEditor
                  measurement={props.selectedMeasurement}
                  onCommand={onCommand}
                  onConvert={props.onConvertMeasurement}
                />
              ) : props.selectedStitchStartPoint ? (
                <SelectedStitchStartPointEditor stitchStartPoint={props.selectedStitchStartPoint} />
              ) : props.selectedFreeText ? (
                <FreeTextEditor freeText={props.selectedFreeText} onCommand={onCommand} />
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
              <div className="button-row">
                <button disabled={!hasSelection} onClick={props.onDeleteSelection}>
                  {appStrings.contextMenu.delete}
                </button>
                <button disabled={!selectedCount} onClick={props.onCreatePart}>
                  {appStrings.inspector.parts}
                </button>
              </div>
            </section>
            <section>
              <h2>
                <Link2 aria-hidden="true" />
                {appStrings.inspector.constraint}
              </h2>
              {constraints.length ? (
                constraints.map((item) => (
                  <div className="row" key={item.id}>
                    <span>
                      {constraintLabel(item.kind)}
                      <small>
                        {appStrings.constraintStatusNames[
                          item.status as keyof typeof appStrings.constraintStatusNames
                        ] ?? item.status}{" "}
                        {valueLabel(item.value)}
                      </small>
                    </span>
                    <div className="button-row">
                      {item.value && (
                        <button onClick={() => openConstraintValueEntry(item, onCommand, openTextEntry)}>
                          {appStrings.inspector.value}
                        </button>
                      )}
                      <button
                        onClick={() =>
                          onCommand(
                            "deleteConstraint",
                            item.id,
                            appStrings.inspector.operationMessage.constraintDeleted,
                          )
                        }
                      >
                        {appStrings.contextMenu.delete}
                      </button>
                    </div>
                  </div>
                ))
              ) : (
                <p>{appStrings.workbench.noConstraintDescription}</p>
              )}
            </section>
            <section>
              <h2>
                <Ruler aria-hidden="true" />
                {appStrings.inspector.measurementAndNotes}
              </h2>
              {measurements.map((item) => (
                <div className="row" key={item.id}>
                  <button className="inspector-row-action" onClick={() => props.onSelectMeasurement?.(item.id)}>
                    {measurementLabel(item.kind)}
                  </button>
                  <label>
                    <input
                      type="checkbox"
                      checked={item.visible}
                      onChange={(event) =>
                        onCommand(
                          "updateMeasurementAnnotation",
                          { ...item, visible: event.target.checked },
                          appStrings.inspector.operationMessage.measurementUpdated,
                        )
                      }
                    />
                    {appStrings.inspector.display}
                  </label>
                  <button
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
                <div className="row" key={item.id}>
                  <span>{item.content}</span>
                  <button
                    onClick={() =>
                      openTextEntry(
                        appStrings.inspector.annotationEdit,
                        [{ id: "content", label: appStrings.inspector.annotation, initialValue: item.content }],
                        (values) => {
                          const content = values.content.trim();
                          if (content)
                            onCommand(
                              "updateFreeText",
                              { ...item, content },
                              appStrings.inspector.operationMessage.textUpdated,
                            );
                        },
                      )
                    }
                  >
                    {appStrings.inspector.edit}
                  </button>
                  <button
                    onClick={() =>
                      onCommand("deleteFreeText", item.id, appStrings.inspector.operationMessage.textDeleted)
                    }
                  >
                    {appStrings.contextMenu.delete}
                  </button>
                </div>
              ))}
            </section>
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
            openTextEntry={openTextEntry}
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
            props={props}
            arrangementPartIds={arrangementPartIds}
            partLibrary={partLibrary}
            renderPartEditor={(part) => (
              <PartEditor
                part={part}
                arrangementSelected={arrangementPartIds.has(part.id)}
                onCommand={onCommand}
                onSetQuantity={props.onSetPartQuantity}
                onSelect={() => props.onSelectPart(part)}
                onToggleArrangement={() => props.onToggleArrangementPart(part.id)}
                onAddToLibrary={() => props.onAddPartToLibrary(part)}
                onBeginSetOrigin={() => props.onBeginSetPartOrigin?.(part)}
                selectedEntityIds={props.selectedEntityIds ?? []}
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
