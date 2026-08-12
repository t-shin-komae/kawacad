type Value = Record<string, number | string> | undefined;
type Parameter = { id: string; valueMm: number };

export function formatInspectorNumber(value: number | undefined): string {
  return typeof value === "number" && Number.isFinite(value) ? value.toFixed(2) : "";
}

export function resolveInspectorValue(
  value: Value,
  parameters: readonly Parameter[],
  fixedKey: "fixedMm" | "fixedDegrees" = "fixedMm",
): number | undefined {
  const fixedValue = value?.[fixedKey];
  if (typeof fixedValue === "number" && Number.isFinite(fixedValue)) return fixedValue;
  const parameterID = value?.parameter;
  if (typeof parameterID !== "string") return undefined;
  return parameters.find((parameter) => parameter.id === parameterID)?.valueMm;
}
