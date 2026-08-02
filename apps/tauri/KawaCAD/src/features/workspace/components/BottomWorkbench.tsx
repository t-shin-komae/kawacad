import { geometryOf, type RawEntity } from "@/features/canvas/domain/cad";
import type { ReactNode } from "react";
import { accessibilityIdentifiers } from "@/shared/accessibility/accessibilityIdentifiers";
import { appStrings } from "@/localization";

type Layer = { id: string; name: string };
type Constraint = { id: string; kind: string; status: string; targets?: string[] };
type Parameter = { id: string; name: string; valueMm: number; unit: string };

type Props = {
  selectedEntity?: RawEntity;
  layers: Layer[];
  constraints: Constraint[];
  parameters: Parameter[];
};

function entityKindLabel(entity: RawEntity) {
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
      return appStrings.workbench.shape;
  }
}

function constraintSummary(constraints: Constraint[]) {
  if (!constraints.length) return appStrings.workbench.noConstraints;
  if (constraints.some((item) => item.status === "overConstrained")) return appStrings.workbench.overConstrained;
  if (constraints.some((item) => item.status === "unsatisfied")) return appStrings.workbench.unresolved;
  return appStrings.workbench.evaluated;
}

/** Summary equivalent to the native workbench. */
export function BottomWorkbench({ selectedEntity, layers, constraints, parameters }: Props) {
  const constraint = constraints[0];
  const parameter = parameters[0];
  const selectedLayer = selectedEntity && "layerId" in selectedEntity ? selectedEntity.layerId : undefined;
  const layerName = selectedLayer
    ? (layers.find((item) => item.id === selectedLayer)?.name ?? selectedLayer)
    : appStrings.workbench.none;

  return (
    <section
      className="bottom-workbench"
      data-testid={accessibilityIdentifiers.statusBottomWorkbench}
      aria-label={appStrings.accessibility.summary}
    >
      <SummarySection title={appStrings.workbench.selection}>
        {selectedEntity ? (
          <>
            <strong>{selectedEntity.id}</strong>
            <small>{entityKindLabel(selectedEntity)}</small>
            <span>{appStrings.workbench.layer(layerName)}</span>
          </>
        ) : (
          <>
            <strong>{appStrings.workbench.noSelection}</strong>
            <small>{appStrings.workbench.selectOnCanvas}</small>
          </>
        )}
      </SummarySection>
      <SummarySection title={appStrings.workbench.constraints}>
        <strong>{constraintSummary(constraints)}</strong>
        <small>{appStrings.workbench.itemCount(constraints.length)}</small>
        <span>
          {constraint
            ? `${constraint.kind}: ${(constraint.targets ?? []).join(" / ") || "—"}`
            : appStrings.workbench.noConstraintDescription}
        </span>
      </SummarySection>
      <SummarySection title={appStrings.workbench.parameters}>
        {parameter ? (
          <>
            <strong>
              {parameter.name} {parameter.valueMm.toFixed(2)} {parameter.unit === "millimeter" ? "mm" : parameter.unit}
            </strong>
            <small>{appStrings.workbench.itemCount(parameters.length)}</small>
          </>
        ) : (
          <>
            <strong>{appStrings.workbench.noParameters}</strong>
            <small>{appStrings.workbench.unusedParameters}</small>
          </>
        )}
      </SummarySection>
    </section>
  );
}

function SummarySection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="bottom-workbench-section" aria-label={title}>
      <h2>{title}</h2>
      <div>{children}</div>
    </section>
  );
}
