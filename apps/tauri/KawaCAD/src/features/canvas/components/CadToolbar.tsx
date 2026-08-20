import {
  CircleEllipsis,
  Crosshair,
  File,
  Grid3X3,
  Maximize2,
  PanelRight,
  PanelLeft,
  RectangleHorizontal,
  RectangleVertical,
  ZoomIn,
  ZoomOut,
} from "lucide-react";
import { useState } from "react";
import type { ReactNode } from "react";
import { ToolIcon } from "@/features/canvas/components/ToolIcon";
import { accessibilityIdentifiers } from "@/shared/accessibility/accessibilityIdentifiers";
import { appStrings } from "@/localization";
import type { CanvasViewMode, ConstraintStatus, Tool } from "@/features/canvas/domain/canvasDomainModels";
import type { Viewport } from "@/features/canvas/domain/cad";

type Props = {
  tool: Tool;
  layers: Array<{ id: string; name: string }>;
  activeLayer: string;
  viewMode: CanvasViewMode;
  clipboardAvailable: boolean;
  selectedCount: number;
  constraintStatuses: string[];
  zoomPercent: number;
  gridVisible: boolean;
  a4Visible: boolean;
  a4Landscape: boolean;
  snapEnabled: boolean;
  pointSnapEnabled: boolean;
  onCopy: () => void;
  onPaste: () => void;
  onDuplicate: () => void;
  onLayerChange: (id: string) => void;
  onViewModeChange: (mode: CanvasViewMode) => void;
  onViewportChange: (next: Viewport | ((current: Viewport) => Viewport)) => void;
  onGridChange: (value: boolean) => void;
  onA4Change: (value: boolean) => void;
  onA4LandscapeChange: (value: boolean) => void;
  onSnapChange: (value: boolean) => void;
  onPointSnapChange: (value: boolean) => void;
  showToolPaletteButton: boolean;
  onToggleInspector: () => void;
  onToggleTools: () => void;
};

const constraintStatusPresentation: Record<ConstraintStatus, { label: string; className: string }> = {
  unknown: { label: appStrings.constraintStatus.unknown, className: "unknown" },
  underConstrained: { label: appStrings.constraintStatus.underConstrained, className: "under-constrained" },
  fullyConstrained: { label: appStrings.constraintStatus.fullyConstrained, className: "fully-constrained" },
  overConstrained: { label: appStrings.constraintStatus.overConstrained, className: "over-constrained" },
  conflicting: { label: appStrings.constraintStatus.conflicting, className: "conflicting" },
};

export function aggregateConstraintStatus(statuses: string[]): ConstraintStatus {
  const normalizedStatuses = statuses.map((status) => {
    if (status === "satisfied") return "fullyConstrained";
    if (status === "unsatisfied") return "underConstrained";
    return status;
  });
  if (!normalizedStatuses.length) return "unknown";
  if (normalizedStatuses.includes("conflicting")) return "conflicting";
  if (normalizedStatuses.includes("overConstrained")) return "overConstrained";
  if (normalizedStatuses.every((status) => status === "fullyConstrained")) return "fullyConstrained";
  if (normalizedStatuses.includes("underConstrained")) return "underConstrained";
  return "unknown";
}

const labels = appStrings.toolNames;

type ToggleButtonProps = {
  label: string;
  testId: string;
  pressed: boolean;
  onPressedChange: (value: boolean) => void;
  children: ReactNode;
};

function ToggleButton({ label, testId, pressed, onPressedChange, children }: ToggleButtonProps) {
  return (
    <button
      className={`toolbar-icon-button toolbar-toggle${pressed ? " active" : ""}`}
      type="button"
      data-testid={testId}
      aria-label={label}
      aria-pressed={pressed}
      title={label}
      onClick={() => onPressedChange(!pressed)}
    >
      {children}
    </button>
  );
}

function SnapIcon({ children }: { children: ReactNode }) {
  return (
    <span className="toolbar-snap-icon">
      {children}
      <i aria-hidden="true" />
    </span>
  );
}

/** The toolbar renders one stable control tree; CSS container queries hide lower-priority controls by available width. */
export function CADToolbar({
  tool,
  layers,
  activeLayer,
  viewMode,
  clipboardAvailable,
  selectedCount,
  constraintStatuses,
  zoomPercent,
  gridVisible,
  a4Visible,
  a4Landscape,
  snapEnabled,
  pointSnapEnabled,
  onCopy,
  onPaste,
  onDuplicate,
  onLayerChange,
  onViewModeChange,
  onViewportChange,
  onGridChange,
  onA4Change,
  onA4LandscapeChange,
  onSnapChange,
  onPointSnapChange,
  showToolPaletteButton,
  onToggleInspector,
  onToggleTools,
}: Props) {
  const [overflowOpen, setOverflowOpen] = useState(false);
  const constraintStatus = aggregateConstraintStatus(constraintStatuses);
  const constraintBadge = constraintStatusPresentation[constraintStatus];
  const zoomToFit = () => onViewportChange({ zoom: 1, panX: 0, panY: 0 });
  const zoomOut = () => onViewportChange((value) => ({ ...value, zoom: Math.max(0.5, value.zoom / 1.25) }));
  const zoomIn = () => onViewportChange((value) => ({ ...value, zoom: Math.min(3, value.zoom * 1.25) }));

  return (
    <nav className="cad-toolbar" aria-label={appStrings.accessibility.cadToolbar}>
      {showToolPaletteButton && (
        <button
          className="toolbar-icon-button toolbar-tools-button"
          type="button"
          data-testid={accessibilityIdentifiers.toolbarTools}
          onClick={onToggleTools}
          aria-label={appStrings.accessibility.showTools}
          title={appStrings.accessibility.showTools}
        >
          <PanelLeft />
        </button>
      )}
      {showToolPaletteButton && <span className="toolbar-divider toolbar-tool-palette-divider" aria-hidden="true" />}
      <div className="toolbar-tool-cluster">
        <span className="toolbar-tool">
          <span className="toolbar-tool-icon">
            <ToolIcon tool={tool} size={18} />
          </span>
          {labels[tool]}
        </span>
        <div className="toolbar-control-group toolbar-edit-actions" aria-label={appStrings.accessibility.editSelection}>
          <button
            type="button"
            data-testid={accessibilityIdentifiers.toolbarCopySelection}
            onClick={onCopy}
            disabled={!selectedCount}
          >
            {appStrings.toolbar.copySelection}
          </button>
          <button
            type="button"
            data-testid={accessibilityIdentifiers.toolbarPasteSelection}
            onClick={onPaste}
            disabled={!clipboardAvailable}
          >
            {appStrings.toolbar.pasteSelection}
          </button>
          <button
            type="button"
            data-testid={accessibilityIdentifiers.toolbarDuplicateSelection}
            onClick={onDuplicate}
            disabled={!selectedCount}
          >
            {appStrings.toolbar.duplicateSelection}
          </button>
        </div>
      </div>
      <span className="toolbar-divider toolbar-primary-divider" aria-hidden="true" />
      <label className="toolbar-layer" data-testid={accessibilityIdentifiers.toolbarDrawingLayer}>
        {appStrings.toolbar.drawingLayer}
        <select value={activeLayer} onChange={(event) => onLayerChange(event.target.value)}>
          {layers.map((layer) => (
            <option key={layer.id} value={layer.id}>
              {layer.name}
            </option>
          ))}
        </select>
      </label>
      <span
        className={`constraint-badge ${constraintBadge.className}`}
        title={appStrings.accessibility.constraintStatus}
      >
        {constraintBadge.label}
      </span>
      <span className="toolbar-metric">{appStrings.toolbarMetrics.zoom(zoomPercent)}</span>
      <div className="toolbar-control-group" aria-label={appStrings.accessibility.zoom}>
        <button
          className="toolbar-icon-button"
          type="button"
          data-testid={accessibilityIdentifiers.toolbarZoomToFit}
          aria-label={appStrings.toolbar.zoomToFit}
          title={appStrings.toolbar.zoomToFit}
          onClick={zoomToFit}
        >
          <Maximize2 />
        </button>
        <button
          className="toolbar-icon-button toolbar-zoom-secondary"
          type="button"
          data-testid={accessibilityIdentifiers.toolbarZoomOut}
          aria-label={appStrings.toolbar.zoomOut}
          title={appStrings.toolbar.zoomOut}
          onClick={zoomOut}
        >
          <ZoomOut />
        </button>
        <button
          className="toolbar-icon-button toolbar-zoom-secondary"
          type="button"
          data-testid={accessibilityIdentifiers.toolbarZoomIn}
          aria-label={appStrings.toolbar.zoomIn}
          title={appStrings.toolbar.zoomIn}
          onClick={zoomIn}
        >
          <ZoomIn />
        </button>
      </div>
      <div className="toolbar-control-group toolbar-display-toggles" aria-label={appStrings.accessibility.displayAids}>
        <ToggleButton
          label={appStrings.toolbar.grid}
          testId={accessibilityIdentifiers.toolbarGrid}
          pressed={gridVisible}
          onPressedChange={onGridChange}
        >
          <Grid3X3 />
        </ToggleButton>
        <ToggleButton
          label={appStrings.toolbar.a4Reference}
          testId={accessibilityIdentifiers.toolbarA4Reference}
          pressed={a4Visible}
          onPressedChange={onA4Change}
        >
          <File />
        </ToggleButton>
        <ToggleButton
          label={appStrings.toolbar.a4Landscape}
          testId={
            a4Landscape
              ? accessibilityIdentifiers.toolbarLandscapeOrientation
              : accessibilityIdentifiers.toolbarPortraitOrientation
          }
          pressed={a4Landscape}
          onPressedChange={onA4LandscapeChange}
        >
          {a4Landscape ? <RectangleHorizontal /> : <RectangleVertical />}
        </ToggleButton>
        <ToggleButton
          label={appStrings.toolbar.gridSnap}
          testId={accessibilityIdentifiers.toolbarGridSnap}
          pressed={snapEnabled}
          onPressedChange={onSnapChange}
        >
          <SnapIcon>
            <Grid3X3 />
          </SnapIcon>
        </ToggleButton>
        <ToggleButton
          label={appStrings.toolbar.pointSnap}
          testId={accessibilityIdentifiers.toolbarPointSnap}
          pressed={pointSnapEnabled}
          onPressedChange={onPointSnapChange}
        >
          <SnapIcon>
            <Crosshair />
          </SnapIcon>
        </ToggleButton>
      </div>
      <span className="toolbar-spacer" />
      <button
        className="toolbar-icon-button toolbar-inspector-button"
        type="button"
        data-testid={accessibilityIdentifiers.toolbarInspector}
        onClick={onToggleInspector}
        aria-label={appStrings.accessibility.showInspector}
        title={appStrings.accessibility.showInspector}
      >
        <PanelRight />
      </button>
      <div
        className="view-mode-segment"
        role="group"
        data-testid={accessibilityIdentifiers.toolbarViewMode}
        aria-label={appStrings.accessibility.viewMode}
      >
        <button
          type="button"
          className={viewMode === "editDisplay" ? "active" : ""}
          aria-pressed={viewMode === "editDisplay"}
          onClick={() => onViewModeChange("editDisplay")}
        >
          {appStrings.viewModeNames.editDisplay}
        </button>
        <button
          type="button"
          className={viewMode === "outputPreview" ? "active" : ""}
          aria-pressed={viewMode === "outputPreview"}
          onClick={() => onViewModeChange("outputPreview")}
        >
          {appStrings.viewModeNames.outputPreview}
        </button>
      </div>
      <div className="toolbar-overflow">
        <button
          className="toolbar-icon-button toolbar-overflow-button"
          type="button"
          data-testid={accessibilityIdentifiers.toolbarOverflow}
          aria-label={appStrings.accessibility.moreActions}
          aria-expanded={overflowOpen}
          title={appStrings.accessibility.moreActions}
          onClick={() => setOverflowOpen((value) => !value)}
        >
          <CircleEllipsis />
        </button>
        {overflowOpen && (
          <div className="toolbar-overflow-menu" role="menu">
            <div className="toolbar-overflow-secondary">
              <button
                type="button"
                role="menuitem"
                onClick={() => {
                  onCopy();
                  setOverflowOpen(false);
                }}
                disabled={!selectedCount}
              >
                {appStrings.toolbar.copySelection}
              </button>
              <button
                type="button"
                role="menuitem"
                onClick={() => {
                  onPaste();
                  setOverflowOpen(false);
                }}
                disabled={!clipboardAvailable}
              >
                {appStrings.toolbar.pasteSelection}
              </button>
              <button
                type="button"
                role="menuitem"
                onClick={() => {
                  onDuplicate();
                  setOverflowOpen(false);
                }}
                disabled={!selectedCount}
              >
                {appStrings.toolbar.duplicateSelection}
              </button>
              <label className="toolbar-overflow-layer">
                {appStrings.toolbar.drawingLayer}
                <select value={activeLayer} onChange={(event) => onLayerChange(event.target.value)}>
                  {layers.map((layer) => (
                    <option key={layer.id} value={layer.id}>
                      {layer.name}
                    </option>
                  ))}
                </select>
              </label>
              <span className="toolbar-overflow-divider" aria-hidden="true" />
            </div>
            <button
              type="button"
              role="menuitem"
              onClick={() => {
                zoomOut();
                setOverflowOpen(false);
              }}
            >
              {appStrings.toolbar.zoomOut}
            </button>
            <button
              type="button"
              role="menuitem"
              onClick={() => {
                zoomIn();
                setOverflowOpen(false);
              }}
            >
              {appStrings.toolbar.zoomIn}
            </button>
            <button
              type="button"
              role="menuitem"
              onClick={() => {
                onGridChange(!gridVisible);
                setOverflowOpen(false);
              }}
            >
              {appStrings.toolbar.grid}
            </button>
            <button
              type="button"
              role="menuitem"
              onClick={() => {
                onA4Change(!a4Visible);
                setOverflowOpen(false);
              }}
            >
              {appStrings.toolbar.a4Reference}
            </button>
            <button
              type="button"
              role="menuitem"
              onClick={() => {
                onA4LandscapeChange(!a4Landscape);
                setOverflowOpen(false);
              }}
            >
              {appStrings.toolbar.a4Landscape}
            </button>
            <button
              type="button"
              role="menuitem"
              onClick={() => {
                onSnapChange(!snapEnabled);
                setOverflowOpen(false);
              }}
            >
              {appStrings.toolbar.gridSnap}
            </button>
            <button
              type="button"
              role="menuitem"
              onClick={() => {
                onPointSnapChange(!pointSnapEnabled);
                setOverflowOpen(false);
              }}
            >
              {appStrings.toolbar.pointSnap}
            </button>
          </div>
        )}
      </div>
    </nav>
  );
}
