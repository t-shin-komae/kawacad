import { useEffect, useRef, useState } from "react";
import { TextEntryDialog, type TextEntryField } from "@/shared/components/TextEntryDialog";
import {
  initialInspectorShellState,
  initialLayerTabState,
  initialParametersTabState,
  initialStylesTabState,
  revealLayerSearch,
  revealParametersSearch,
  revealStylesSearch,
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
import { aggregateConstraintStatus } from "@/features/canvas/components/CadToolbar";
import { InspectorLayerTab } from "@/features/inspector/components/InspectorLayerTab";
import { InspectorParametersTab } from "@/features/inspector/components/InspectorParametersTab";
import { InspectorPartsTab } from "@/features/parts/components/InspectorPartsTab";
import { InspectorStylesTab } from "@/features/inspector/components/InspectorStylesTab";
import { ParameterEditor, StyleFields, defaultStyle } from "@/features/inspector/components/InspectorSelectionEditors";
import { InspectorSelectionTab } from "@/features/inspector/components/InspectorSelectionTab";
import { PartEditor } from "@/features/parts/components/InspectorPartEditors";
import type { Constraint, DerivedElement, LineStyle, Part, PartLibraryEntry } from "@/shared/domain/coreWireTypes";
import type {
  InspectorViewModel,
  Measurement,
  SelectionInspectorModel,
} from "@/features/inspector/domain/inspectorViewModel";
import { accessibilityIdentifiers } from "@/shared/accessibility/accessibilityIdentifiers";

export type PendingTextEntry = {
  title: string;
  fields: TextEntryField[];
  onConfirm: (values: Record<string, string>) => void;
};
export type { Constraint, DerivedElement, LineStyle, Part, PartLibraryEntry } from "@/shared/domain/coreWireTypes";
export type { InspectorViewModel, Measurement } from "@/features/inspector/domain/inspectorViewModel";
/** Selection editors intentionally depend on their own feature model, not the inspector shell. */
export type Props = SelectionInspectorModel;
const tabs: Array<[InspectorTab, string]> = [
  ["selection", appStrings.inspector.tab.selection],
  ["layers", appStrings.inspector.tab.layers],
  ["styles", appStrings.inspector.tab.sharedStyles],
  ["parameters", appStrings.inspector.tab.parameters],
  ["parts", appStrings.inspector.tab.parts],
];
export function InspectorPanel(model: InspectorViewModel) {
  const [shell, setShell] = useState(initialInspectorShellState);
  const [layerState, setLayerState] = useState(initialLayerTabState);
  const [stylesState, setStylesState] = useState(initialStylesTabState);
  const [parametersState, setParametersState] = useState(initialParametersTabState);
  const [pendingTextEntry, setPendingTextEntry] = useState<PendingTextEntry>();
  const [pendingSelectionChange, setPendingSelectionChange] = useState(false);
  const selectionKey = [
    model.selection.selectedCount,
    ...(model.selection.selectedEntityIds ?? []),
    model.selection.selectedConstraint?.id,
    model.selection.selectedMeasurement?.id,
    model.selection.selectedFreeText?.id,
    model.selection.selectedStitchStartPoint?.id,
  ].join("|");
  const previousSelectionKey = useRef(selectionKey);
  useEffect(() => {
    const revealSearch = () => {
      if (shell.inspectorTab === "layers") setLayerState(revealLayerSearch);
      if (shell.inspectorTab === "styles") setStylesState(revealStylesSearch);
      if (shell.inspectorTab === "parameters") setParametersState(revealParametersSearch);
    };
    window.addEventListener("kawa-cad-find-inspector", revealSearch);
    return () => window.removeEventListener("kawa-cad-find-inspector", revealSearch);
  }, [shell.inspectorTab]);
  useEffect(() => {
    model.shell.onTabChange(shell.inspectorTab);
    if (shell.inspectorTab === "selection") setPendingSelectionChange(false);
  }, [shell.inspectorTab, model.shell]);
  useEffect(() => {
    const selectionChanged = previousSelectionKey.current !== selectionKey;
    previousSelectionKey.current = selectionKey;
    if (selectionChanged && shell.inspectorTab !== "selection") setPendingSelectionChange(true);
  }, [shell.inspectorTab, selectionKey]);
  return (
    <aside
      className="inspector"
      data-testid={accessibilityIdentifiers.componentInspector}
      aria-label={appStrings.inspector.ariaLabel}
    >
      <div className="inspector-header">
        <nav className="inspector-tabs" role="tablist" aria-label={appStrings.inspector.tabList}>
          {tabs.map(([id, label]) => (
            <button
              key={id}
              role="tab"
              aria-selected={shell.inspectorTab === id}
              className={shell.inspectorTab === id ? "active" : ""}
              onClick={() => {
                setShell((state) => setInspectorTab(state, id));
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
                setShell((state) => setInspectorTab(state, "selection"));
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
        {shell.inspectorTab === "selection" && <InspectorSelectionTab model={model.selection} />}
        {shell.inspectorTab === "layers" && (
          <InspectorLayerTab
            model={model.layers}
            state={layerState}
            updateState={setLayerState}
            renderStyleFields={(style, onChange) => <StyleFields style={style} onChange={onChange} />}
          />
        )}
        {shell.inspectorTab === "styles" && (
          <InspectorStylesTab
            model={model.styles}
            state={stylesState}
            updateState={setStylesState}
            defaultStyle={defaultStyle}
            renderStyleFields={(style, onChange) => <StyleFields style={style} onChange={onChange} />}
          />
        )}
        {shell.inspectorTab === "parameters" && (
          <InspectorParametersTab
            model={model.parameters}
            state={parametersState}
            updateState={setParametersState}
            renderParameterEditor={(parameter) => (
              <ParameterEditor parameter={parameter} actions={model.parameters.actions} />
            )}
          />
        )}
        {shell.inspectorTab === "parts" && (
          <InspectorPartsTab
            model={model.parts}
            renderPartEditor={(part) => (
              <PartEditor
                part={part}
                arrangementSelected={model.parts.arrangementPartIds.has(part.id)}
                actions={model.parts.actions}
                onSelect={() => model.parts.actions.select(part)}
                onToggleArrangement={() => model.parts.actions.toggleArrangement(part.id)}
                onAddToLibrary={() => model.parts.actions.addToLibrary(part)}
                onBeginSetOrigin={() => model.parts.actions.beginSetOrigin(part)}
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
