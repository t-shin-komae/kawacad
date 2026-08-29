import { CADToolbar } from "@/features/canvas/components/CadToolbar";
import { CanvasContextMenu } from "@/features/canvas/components/CanvasContextMenu";
import { ToolPalette } from "@/features/canvas/components/ToolPalette";
import {
  CADCanvas,
  type CanvasEventHandlers,
  type CanvasInteractionModel,
} from "@/features/canvas/components/CadCanvas";
import type { CanvasRenderModel } from "@/features/canvas/selectors/canvasRendering";
import { ConstraintValueDialog } from "@/features/constraints/components/ConstraintValueDialog";
import { LayerDeletionDialog } from "@/features/document/components/LayerDeletionDialog";
import { PasteOptionsOverlay } from "@/features/document/components/PasteOptionsOverlay";
import { InspectorPanel } from "@/features/inspector/components/InspectorPanel";
import { InspectorParametersTab } from "@/features/inspector/components/InspectorParametersTab";
import { initialParametersTabState } from "@/features/inspector/selectors/inspectorFeature";
import type {
  InspectorLayer,
  InspectorParameter,
  InspectorSharedStyle,
  InspectorViewModel,
  SelectionInspectorModel,
} from "@/features/inspector/domain/inspectorViewModel";
import { OpenSourceLicensesDialog } from "@/features/licenses/components/OpenSourceLicensesDialog";
import { PDFExportDialog } from "@/features/output/components/PDFExportDialog";
import { RecoveryChooserDialog } from "@/features/recovery/components/RecoveryChooserDialog";
import { BottomWorkbench } from "@/features/workspace/components/BottomWorkbench";
import { appStrings } from "@/localization";
import type { CanvasViewMode, Tool } from "@/features/canvas/domain/canvasDomainModels";
import type { RawEntity, Viewport } from "@/features/canvas/domain/cad";
import type { CanvasProjection, LineStyle } from "@/shared/domain/coreWireTypes";

export type ComparisonFixtureName =
  | "toolbar-expanded"
  | "toolbar-condensed"
  | "tool-palette-basic"
  | "tool-palette-detailed"
  | "canvas-empty"
  | "canvas-geometry"
  | "inspector-selection"
  | "inspector-parameters-empty"
  | "summary"
  | "constraint-hud"
  | "context-menu"
  | "paste-options"
  | "licenses-dialog"
  | "recovery-dialog"
  | "layer-deletion-dialog"
  | "pdf-dialog";

const ignore = (..._args: unknown[]) => {};
const fixtureLayer = { id: "layer:fixture", name: appStrings.inspector.layerKinds.cutLine };
const fixtureStyle: LineStyle = {
  stroke: { red: 0.07, green: 0.09, blue: 0.12, alpha: 1 },
  strokeWidthMm: 0.25,
  pattern: "solid",
};
const fixtureLine: RawEntity = {
  id: "entity:fixture-line",
  layerId: fixtureLayer.id,
  styleId: "style:fixture",
  kind: {
    lineSegment: {
      start: { xMm: -80, yMm: -25 },
      end: { xMm: 80, yMm: 25 },
    },
  },
};

const fixtureViewport: Viewport = { zoom: 1, panX: 0, panY: 0 };
const fixtureProjection: CanvasProjection = {
  stitchStartPoints: [],
  measurementAnnotations: [],
  dimensionConstraints: [],
  constraintMarkers: [],
};

function FixtureFrame({
  className,
  width,
  height,
  children,
}: {
  className?: string;
  width: number;
  height: number;
  children: React.ReactNode;
}) {
  return (
    <main
      className={className ? `comparison-fixture ${className}` : "comparison-fixture"}
      style={{ width, height }}
      data-testid="comparison-fixture"
    >
      {children}
    </main>
  );
}

function toolbarProps() {
  return {
    tool: "line" as Tool,
    layers: [fixtureLayer],
    activeLayer: fixtureLayer.id,
    viewMode: "editDisplay" as CanvasViewMode,
    zoomPercent: 100,
    gridVisible: true,
    a4Visible: true,
    a4Landscape: false,
    snapEnabled: true,
    pointSnapEnabled: true,
    onLayerChange: ignore,
    onViewModeChange: ignore,
    onViewportChange: ignore,
    onGridChange: ignore,
    onA4Change: ignore,
    onA4LandscapeChange: ignore,
    onSnapChange: ignore,
    onPointSnapChange: ignore,
    toolPaletteVisible: true,
    onToggleInspector: ignore,
    onToggleTools: ignore,
  };
}

function paletteProps(detailed: boolean) {
  return {
    activeStyle: "style:fixture",
    sharedStyles: [{ id: "style:fixture", name: fixtureLayer.name }],
    activeTool: "line" as Tool,
    roundDiameter: 5,
    roundKind: "keyRing",
    selectedCount: 1,
    basicOnly: !detailed,
    collapsedGroups: new Set<string>(),
    onActiveStyleChange: ignore,
    onToolChange: ignore,
    onRoundDiameterChange: ignore,
    onRoundKindChange: ignore,
    onBasicOnlyChange: ignore,
    onCollapsedGroupsChange: ignore,
    onApplyStyle: ignore,
  };
}

const canvasRenderModel: CanvasRenderModel = {
  viewport: fixtureViewport,
  outputPreview: false,
  gridVisible: true,
  a4Visible: true,
  a4Landscape: false,
  outputPages: [],
  entities: [fixtureLine],
  suppressedByFilletEntityIds: new Set(),
  layers: [{ id: fixtureLayer.id, visible: true, style: fixtureStyle }],
  sharedStyles: [{ id: "style:fixture", style: fixtureStyle }],
  selectedIds: new Set([fixtureLine.id]),
  freeTexts: [],
  highlightedFreeTextIds: new Set(),
  highlightedEntityIds: new Set([fixtureLine.id]),
  highlightedMeasurementAnnotationIds: new Set(),
  highlightedStitchStartPointIds: new Set(),
  projection: fixtureProjection,
  measurementLabels: {},
  measurementLabelOffsets: {},
  measurementArcCounterclockwise: {},
  dimensionLabels: {},
  dimensionLabelOffsets: {},
  dimensionArcCounterclockwise: {},
  coincidentPointGroups: [],
  tool: "select",
  draftPoints: [],
  dragDuplicating: false,
  dragging: false,
  snapActive: false,
  snapSuppressed: false,
};

const canvasInteractionModel: CanvasInteractionModel = {
  pendingTargetCount: 0,
  draftPointCount: 0,
  dragDuplicating: false,
  movingContent: false,
  hasHoveredCanvasTarget: false,
  snapSuppressed: false,
  toolName: appStrings.toolNames.select,
};

const canvasEvents: CanvasEventHandlers = {
  onPointerDown: ignore,
  onPointerMove: ignore,
  onPointerLeave: ignore,
  onPointerUp: ignore,
  onDoubleClick: ignore,
  onCommitFreeText: ignore,
  onCancelFreeText: ignore,
  onWheel: ignore,
  onContextMenu: ignore,
};

function inspectorModel(): InspectorViewModel {
  const inspectorLayer: InspectorLayer = {
    ...fixtureLayer,
    visible: true,
    printable: true,
    kind: "cut",
    style: fixtureStyle,
  };
  const inspectorStyle: InspectorSharedStyle = {
    id: "style:fixture",
    name: fixtureLayer.name,
    style: fixtureStyle,
  };
  const parameter: InspectorParameter = {
    id: "parameter:width",
    name: appStrings.inspector.lineWidth,
    valueMm: 25,
    unit: "millimeter",
    memo: "",
  };
  const selection: SelectionInspectorModel = {
    selectedCount: 1,
    documentSummary: {
      viewMode: "editDisplay",
      activeLayerName: fixtureLayer.name,
      visibleEntityCount: 1,
      constraintCount: 0,
      parameterCount: 1,
    },
    selectedEntityIds: [fixtureLine.id],
    selectedEntities: [fixtureLine],
    selectedEntity: fixtureLine,
    constraints: [],
    measurements: [],
    freeTexts: [],
    parameters: [parameter],
    layers: [inspectorLayer],
    sharedStyles: [inspectorStyle],
    roundHoles: [],
    actions: {
      setConstraintValue: ignore,
      setConstraintParameter: ignore,
      deleteConstraint: ignore,
      deleteMeasurement: ignore,
      deleteEntity: ignore,
      updateFreeText: ignore,
      deleteFreeText: ignore,
      setDerivedDistance: ignore,
      setDerivedRadius: ignore,
      setDerivedDirection: ignore,
      setEntityLayer: ignore,
      setDerivedLayer: ignore,
      setEntityStyle: ignore,
      setDerivedStyle: ignore,
      setRoundHoleDiameter: ignore,
      setRoundHoleKind: ignore,
      setEntityMetric: ignore,
      applyStyle: ignore,
      deleteSelection: ignore,
      constrainSegmentLength: ignore,
      selectConstraint: ignore,
      selectFreeText: ignore,
      selectMeasurement: ignore,
      convertMeasurement: ignore,
    },
  };
  return {
    shell: { onTabChange: ignore },
    selection,
    layers: {
      layers: [inspectorLayer],
      activeLayerId: inspectorLayer.id,
      actions: {
        setVisibility: ignore,
        setPrintable: ignore,
        setStyle: ignore,
        addLayer: ignore,
        changeActiveLayer: ignore,
        renameLayer: ignore,
        deleteLayer: ignore,
      },
    },
    styles: {
      sharedStyles: [inspectorStyle],
      actions: { update: ignore, delete: ignore, add: ignore },
    },
    parameters: {
      parameters: [parameter],
      constraints: [],
      actions: { update: ignore, delete: ignore, add: ignore },
    },
    parts: {
      selectedCount: 1,
      parts: [],
      arrangementPartIds: new Set(),
      partLibrary: [],
      actions: {
        create: ignore,
        select: ignore,
        align: ignore,
        distribute: ignore,
        insertFromLibrary: ignore,
        removeFromLibrary: ignore,
        addToLibrary: ignore,
        toggleArrangement: ignore,
        beginSetOrigin: ignore,
        rename: ignore,
        setPosition: ignore,
        setVisibility: ignore,
        setPrintable: ignore,
        setQuantity: ignore,
        move: ignore,
        duplicate: ignore,
        delete: ignore,
      },
    },
  };
}

function inspectorParametersEmptyModel(): InspectorViewModel["parameters"] {
  return { ...inspectorModel().parameters, parameters: [] };
}

function fixtureRecoveryCandidates() {
  return [
    {
      id: "recoverable-1",
      displayName: appStrings.app.untitled,
      originalDocumentPath: "/projects/card-case.kawa",
      updatedAtMs: 1_786_582_800_000,
      status: "recoverable" as const,
    },
    {
      id: "broken-1",
      displayName: appStrings.app.recoveryBrokenCandidate,
      updatedAtMs: 1_786_582_200_000,
      status: "broken" as const,
      details: appStrings.app.recoveryChooserMessage,
    },
  ];
}

export function ComparisonFixture({ name }: { name: ComparisonFixtureName }) {
  switch (name) {
    case "toolbar-expanded":
      return (
        <FixtureFrame className="comparison-fixture-toolbar" width={1532} height={54}>
          <CADToolbar {...toolbarProps()} />
        </FixtureFrame>
      );
    case "toolbar-condensed":
      return (
        <FixtureFrame className="comparison-fixture-toolbar" width={900} height={54}>
          <CADToolbar {...toolbarProps()} />
        </FixtureFrame>
      );
    case "tool-palette-basic":
      return (
        <FixtureFrame className="comparison-fixture-palette" width={240} height={800}>
          <ToolPalette {...paletteProps(false)} />
        </FixtureFrame>
      );
    case "tool-palette-detailed":
      return (
        <FixtureFrame className="comparison-fixture-palette" width={240} height={800}>
          <ToolPalette {...paletteProps(true)} />
        </FixtureFrame>
      );
    case "canvas-empty":
      return (
        <FixtureFrame className="comparison-fixture-canvas" width={800} height={520}>
          <CADCanvas
            renderModel={{
              ...canvasRenderModel,
              entities: [],
              selectedIds: new Set(),
              highlightedEntityIds: new Set(),
            }}
            interactionModel={{ ...canvasInteractionModel, toolName: appStrings.toolNames.select }}
            events={canvasEvents}
          />
        </FixtureFrame>
      );
    case "canvas-geometry":
      return (
        <FixtureFrame className="comparison-fixture-canvas" width={800} height={520}>
          <CADCanvas renderModel={canvasRenderModel} interactionModel={canvasInteractionModel} events={canvasEvents} />
        </FixtureFrame>
      );
    case "inspector-selection":
      return (
        <FixtureFrame className="comparison-fixture-inspector" width={520} height={820}>
          <InspectorPanel {...inspectorModel()} />
        </FixtureFrame>
      );
    case "inspector-parameters-empty":
      return (
        <FixtureFrame className="comparison-fixture-inspector-parameters" width={520} height={280}>
          <InspectorParametersTab
            model={inspectorParametersEmptyModel()}
            state={initialParametersTabState}
            updateState={ignore}
            renderParameterEditor={() => null}
          />
        </FixtureFrame>
      );
    case "summary":
      return (
        <FixtureFrame className="comparison-fixture-summary" width={1032} height={84}>
          <BottomWorkbench
            selectedEntity={fixtureLine}
            layers={[fixtureLayer]}
            constraints={[]}
            parameters={[
              { id: "parameter:width", name: appStrings.inspector.lineWidth, valueMm: 25, unit: "millimeter" },
            ]}
          />
        </FixtureFrame>
      );
    case "constraint-hud":
      return (
        <ConstraintValueDialog
          label={appStrings.toolNames.segmentLength}
          initialValue={{ fixedMm: 60 }}
          parameters={[]}
          degrees={false}
          floating
          onConfirm={ignore}
          onCancel={ignore}
        />
      );
    case "context-menu":
      return (
        <FixtureFrame className="comparison-fixture-overlay" width={520} height={240}>
          <CanvasContextMenu
            position={{ x: 180, y: 90, point: { xMm: 0, yMm: 0 } }}
            selectionKind="constraint"
            hasSelection
            canPaste={false}
            onCopy={ignore}
            onPaste={ignore}
            onDuplicate={ignore}
            onDelete={ignore}
            onConvertMeasurement={ignore}
            onEditFreeText={ignore}
            canSmoothArcTangencies={false}
            onSmoothArcTangencies={ignore}
            onSelectAll={ignore}
            onDismiss={ignore}
          />
        </FixtureFrame>
      );
    case "paste-options":
      return (
        <FixtureFrame className="comparison-fixture-overlay" width={520} height={240}>
          <PasteOptionsOverlay
            activeMode="cursor"
            canPlaceAtCursor
            positionMm={{ xMm: 0, yMm: 0 }}
            viewport={fixtureViewport}
            onSelectMode={ignore}
            onDismiss={ignore}
          />
        </FixtureFrame>
      );
    case "licenses-dialog":
      return <OpenSourceLicensesDialog onClose={ignore} />;
    case "recovery-dialog":
      return (
        <RecoveryChooserDialog
          candidates={fixtureRecoveryCandidates()}
          onRestore={ignore}
          onDiscard={ignore}
          onReveal={ignore}
          onPostpone={ignore}
        />
      );
    case "layer-deletion-dialog":
      return (
        <LayerDeletionDialog
          layerName={appStrings.app.defaultLayerName(1)}
          affectedCount={1}
          onConfirm={ignore}
          onCancel={ignore}
        />
      );
    case "pdf-dialog":
      return (
        <PDFExportDialog
          documentName={appStrings.document.untitled}
          initialOrientation="portrait"
          onClose={ignore}
          onSaved={ignore}
        />
      );
  }
}
