import type { Layer, LineStyle, Parameter } from "@/shared/domain/coreWireTypes";
import { appStrings } from "@/localization";

export const defaultParameterValueMm = 10;
export const defaultParameterUnit = "millimeter";

export function defaultLayerName(number: number) {
  return appStrings.app.defaultLayerName(number);
}

export function defaultParameterName(number: number) {
  return appStrings.app.defaultParameterName(number);
}

export function defaultUserLayer(id: string, number: number): Layer {
  return {
    id,
    name: defaultLayerName(number),
    kind: "cutLine",
    visible: true,
    printable: true,
    style: defaultLayerStyle(),
  };
}

export function defaultLayerStyle(): LineStyle {
  return {
    stroke: { red: 0, green: 0, blue: 0, alpha: 1 },
    strokeWidthMm: 0.2,
    pattern: "solid",
  };
}

export function defaultParameter(id: string, number: number): Parameter {
  return {
    id,
    name: defaultParameterName(number),
    valueMm: defaultParameterValueMm,
    unit: defaultParameterUnit,
    memo: "",
  };
}
