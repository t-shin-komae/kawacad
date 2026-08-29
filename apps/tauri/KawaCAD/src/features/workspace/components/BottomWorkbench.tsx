import { aggregateConstraintStatus } from "@/features/canvas/components/CadToolbar";
import { geometryOf, type RawEntity } from "@/features/canvas/domain/cad";
import type { ReactNode } from "react";
import {
  AlertTriangle,
  CircleAlert,
  CircleCheck,
  CircleDot,
  CircleHelp,
  Hash,
  Link2,
  OctagonAlert,
  type LucideIcon,
} from "lucide-react";
import { accessibilityIdentifiers } from "@/shared/accessibility/accessibilityIdentifiers";
import { appStrings } from "@/localization";
import type { ConstraintStatus } from "@/features/canvas/domain/canvasDomainModels";

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

function constraintStatusIcon(status: ConstraintStatus): LucideIcon {
  switch (status) {
    case "fullyConstrained":
      return CircleCheck;
    case "underConstrained":
      return AlertTriangle;
    case "overConstrained":
      return CircleAlert;
    case "conflicting":
      return OctagonAlert;
    case "unknown":
      return CircleHelp;
  }
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
  const constraintStatus: ConstraintStatus = constraints.length
    ? aggregateConstraintStatus(constraints.map((item) => item.status))
    : "unknown";
  const ConstraintStatusIcon = constraintStatusIcon(constraintStatus);

  return (
    <section
      className="bottom-workbench"
      data-testid={accessibilityIdentifiers.statusBottomWorkbench}
      data-component-id={accessibilityIdentifiers.componentBottomWorkbench}
      aria-label={appStrings.accessibility.summary}
    >
      <SummarySection title={appStrings.workbench.selection} icon="selection">
        {selectedEntity ? (
          <>
            <strong>{entityKindLabel(selectedEntity)}</strong>
            <small>{entityKindLabel(selectedEntity)}</small>
            <span>
              {appStrings.workbench.layer} {layerName}
            </span>
          </>
        ) : (
          <>
            <strong>{appStrings.workbench.noneSelected}</strong>
            <small>{appStrings.workbench.selectOnCanvas}</small>
          </>
        )}
      </SummarySection>
      <SummarySection title={appStrings.workbench.constraint} icon="constraints">
        <div className="constraint-status-summary">
          <ConstraintStatusIcon size={13} strokeWidth={2.2} aria-hidden="true" />
          <strong>
            {constraints.length ? appStrings.constraintStatus[constraintStatus] : appStrings.workbench.noConstraints}
          </strong>
        </div>
        <small>{appStrings.workbench.itemCount(constraints.length)}</small>
        <span>
          {constraints.length
            ? (appStrings.constraintKindNames[constraints[0].kind as keyof typeof appStrings.constraintKindNames] ??
              constraints[0].kind)
            : appStrings.workbench.noConstraints}
        </span>
      </SummarySection>
      <SummarySection title={appStrings.workbench.parameter} icon="parameters">
        {parameter ? (
          <>
            <strong>
              {parameter.name} {parameter.valueMm.toFixed(2)} {parameter.unit === "millimeter" ? "mm" : parameter.unit}
            </strong>
            <small>{appStrings.workbench.parameterSummary(usedParameterCount, unusedParameterCount)}</small>
          </>
        ) : (
          <>
            <strong>{appStrings.workbench.noParameters}</strong>
            <small>{appStrings.workbench.unusedZero}</small>
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
