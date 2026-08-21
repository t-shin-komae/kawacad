import { defaultSharedStyle } from "@/features/inspector/domain/sharedStyleDefaults";
import { appStrings } from "@/localization";
import type { PointMm } from "@/features/canvas/domain/cad";
import type { Part, PartLibraryEntry } from "@/shared/domain/coreWireTypes";
import type {
  LayerInspectorActions,
  ParameterInspectorActions,
  PartInspectorActions,
  SelectionInspectorActions,
  StyleInspectorActions,
} from "@/features/inspector/domain/inspectorViewModel";

type ExecuteCommand = (kind: string, payload: unknown, success: string) => void;

type InspectorActionModelsInput = {
  executeCommand: ExecuteCommand;
  selection: {
    applyStyle: SelectionInspectorActions["applyStyle"];
    deleteSelection: SelectionInspectorActions["deleteSelection"];
    constrainSegmentLength: SelectionInspectorActions["constrainSegmentLength"];
    selectConstraint: SelectionInspectorActions["selectConstraint"];
    selectFreeText: SelectionInspectorActions["selectFreeText"];
    selectMeasurement: SelectionInspectorActions["selectMeasurement"];
    convertMeasurement: SelectionInspectorActions["convertMeasurement"];
  };
  layers: Pick<LayerInspectorActions, "addLayer" | "changeActiveLayer" | "renameLayer" | "deleteLayer">;
  parameters: Pick<ParameterInspectorActions, "add">;
  parts: {
    create: () => void;
    select: (part: Part) => void;
    align: (alignment: string) => void;
    distribute: (axis: string) => void;
    insertFromLibrary: (entry: PartLibraryEntry) => void;
    removeFromLibrary: (entry: PartLibraryEntry) => void;
    addToLibrary: (part: Part) => unknown;
    toggleArrangement: (id: string) => void;
    beginSetOrigin: (part: Part) => void;
  };
};

/** Maps Core commands and feature actions to the focused action model of each Inspector tab. */
export function inspectorActionModelsFor(input: InspectorActionModelsInput) {
  const execute = input.executeCommand;
  const selectionActions: SelectionInspectorActions = {
    setConstraintValue: (value, success) => execute("setConstraintValue", value, success),
    setConstraintParameter: (value, success) => execute("setConstraintParameter", value, success),
    deleteConstraint: (id, success) => execute("deleteConstraint", id, success),
    deleteMeasurement: (id, success) => execute("deleteMeasurementAnnotation", id, success),
    deleteEntity: () => input.selection.deleteSelection(),
    updateFreeText: (value, success) => execute("updateFreeText", value, success),
    deleteFreeText: (id, success) => execute("deleteFreeText", id, success),
    setDerivedDistance: (value, success) => execute("setDerivedDistance", value, success),
    setDerivedRadius: (value, success) => execute("setDerivedRadius", value, success),
    setDerivedDirection: (value, success) => execute("setDerivedDirection", value, success),
    setEntityLayer: (value, success) => execute("setEntityLayer", value, success),
    setDerivedLayer: (value, success) => execute("setDerivedLayer", value, success),
    setEntityStyle: (value, success) => execute("setEntitySharedStyle", value, success),
    setDerivedStyle: (value, success) => execute("setDerivedSharedStyle", value, success),
    setRoundHoleDiameter: (value, success) => execute("setRoundHoleDiameter", value, success),
    setRoundHoleKind: (value, success) => execute("setRoundHoleKind", value, success),
    setEntityMetric: (value, success) => execute("setEntityMetric", value, success),
    ...input.selection,
  };
  const layerActions: LayerInspectorActions = {
    setVisibility: (value, success) => execute("setLayerVisibility", value, success),
    setPrintable: (value, success) => execute("setLayerPrintable", value, success),
    setStyle: (value, success) => execute("setLayerStyle", value, success),
    ...input.layers,
  };
  const styleActions: StyleInspectorActions = {
    update: (value, success) =>
      execute("updateSharedStyle", { id: value.styleId, name: value.name, style: value.style }, success),
    delete: (id, success) => execute("deleteSharedStyle", id, success),
    add: (name) =>
      execute(
        "addSharedStyle",
        {
          id: `style:${crypto.randomUUID()}`,
          name,
          style: defaultSharedStyle,
        },
        appStrings.inspector.operationMessage.sharedStyleAdded,
      ),
  };
  const parameterActions: ParameterInspectorActions = {
    update: (value, success) => execute("updateParameter", value, success),
    delete: (value, success) => execute("deleteParameter", value, success),
    ...input.parameters,
  };
  const partActions: PartInspectorActions = {
    ...input.parts,
    addToLibrary: (part) => void input.parts.addToLibrary(part),
    rename: (value, success) => execute("renamePart", value, success),
    setPosition: (value, success) => execute("setPartPosition", value, success),
    setVisibility: (value, success) => execute("setPartVisibility", value, success),
    setPrintable: (value, success) => execute("setPartPrintable", value, success),
    setQuantity: (value, success) => execute("setPartQuantity", value, success),
    move: (value, success) => execute("movePart", value, success),
    duplicate: (value, success) => execute("duplicatePart", value, success),
    delete: (id, success) => execute("deletePart", id, success),
  };
  return { selectionActions, layerActions, styleActions, parameterActions, partActions };
}
