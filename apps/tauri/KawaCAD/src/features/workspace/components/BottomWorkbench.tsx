import { geometryOf, type RawEntity } from "@/features/canvas/domain/cad";
import type { ReactNode } from "react";
import { CircleDot, Hash, Link2, type LucideIcon } from "lucide-react";
import { accessibilityIdentifiers } from "@/shared/accessibility/accessibilityIdentifiers";
import { appStrings } from "@/localization";

type Layer = { id: string; name: string };
type Constraint = {
  id: string;
  kind: string;
  status: string;
  targets?: string[];
  value?: Record<string, number | string>;
};
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

const sectionIcons: Record<string, LucideIcon> = {
  selection: CircleDot,
  constraints: Link2,
  parameters: Hash,
};

/** Summary equivalent to the native workbench. */
export function BottomWorkbench({ selectedEntity, layers, constraints, parameters }: Props) {
  const parameter = parameters[0];
  const usedParameterIDs = new Set(
    constraints.flatMap((item) => (typeof item.value?.parameter === "string" ? [item.value.parameter] : [])),
  );
  const usedParameterCount = parameters.filter((item) => usedParameterIDs.has(item.id)).length;
  const unusedParameterCount = parameters.length - usedParameterCount;
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
      <SummarySection title={appStrings.workbench.selection} icon="selection">
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
      <SummarySection title={appStrings.workbench.constraints} icon="constraints">
        <strong>{constraintSummary(constraints)}</strong>
        <small>{appStrings.workbench.itemCount(constraints.length)}</small>
        <span>
          {constraints.length
            ? constraints.map((item) => `${item.kind}: ${(item.targets ?? []).join(" / ") || "—"}`).join("、")
            : appStrings.workbench.noConstraintDescription}
        </span>
      </SummarySection>
      <SummarySection title={appStrings.workbench.parameters} icon="parameters">
        {parameter ? (
          <>
            <strong>
              {parameter.name} {parameter.valueMm.toFixed(2)} {parameter.unit === "millimeter" ? "mm" : parameter.unit}
            </strong>
            <small>
              使用 {usedParameterCount} 件 / 未使用 {unusedParameterCount} 件
            </small>
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

function SummarySection({ title, icon, children }: { title: string; icon: string; children: ReactNode }) {
  const Icon = sectionIcons[icon] ?? CircleDot;
  return (
    <section className="bottom-workbench-section" aria-label={title}>
      <h2>
        <Icon size={12} strokeWidth={1.8} aria-hidden="true" />
        {title}
      </h2>
      <div>{children}</div>
    </section>
  );
}
