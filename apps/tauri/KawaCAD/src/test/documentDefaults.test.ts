import { describe, expect, it } from "vitest";
import {
  defaultLayerName,
  defaultLayerStyle,
  defaultParameter,
  defaultParameterName,
  defaultParameterUnit,
  defaultParameterValueMm,
  defaultUserLayer,
} from "@/features/document/domain/documentDefaults";

describe("document creation defaults", () => {
  it("matches the Swift layer defaults", () => {
    expect(defaultLayerName(3)).toBe("レイヤー 3");
    expect(defaultUserLayer("layer:user-id", 3)).toEqual({
      id: "layer:user-id",
      name: "レイヤー 3",
      kind: "cutLine",
      visible: true,
      printable: true,
      style: {
        stroke: { red: 0, green: 0, blue: 0, alpha: 1 },
        strokeWidthMm: 0.2,
        pattern: "solid",
      },
    });
    expect(defaultLayerStyle()).toEqual(defaultUserLayer("layer:user-id", 3).style);
  });

  it("matches the Swift parameter defaults", () => {
    expect(defaultParameterName(2)).toBe("param_2");
    expect(defaultParameter("parameter:id", 2)).toEqual({
      id: "parameter:id",
      name: "param_2",
      valueMm: 10,
      unit: "millimeter",
      memo: "",
    });
    expect(defaultParameterValueMm).toBe(10);
    expect(defaultParameterUnit).toBe("millimeter");
  });
});
