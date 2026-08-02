import { ToolIcon } from "@/features/canvas/components/ToolIcon";
import { ChevronDown, ChevronRight, Maximize2, Minimize2, Paintbrush, PanelLeft } from "lucide-react";
import { useEffect, useState } from "react";
import { appStrings } from "@/localization";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
import { parseDecimal } from "@/shared/state/syncedField";

type SharedStyle = { id: string; name: string };
type Props = {
  activeStyle: string;
  sharedStyles: SharedStyle[];
  activeTool: Tool;
  roundDiameter: number;
  roundKind: string;
  selectedCount: number;
  basicOnly: boolean;
  collapsedGroups: Set<string>;
  onActiveStyleChange: (id: string) => void;
  onToolChange: (tool: Tool) => void;
  onRoundDiameterChange: (value: number) => void;
  onRoundKindChange: (value: string) => void;
  onBasicOnlyChange: (value: boolean) => void;
  onCollapsedGroupsChange: (groups: Set<string>) => void;
  onApplyStyle: () => void;
};

export const toolGroups: ReadonlyArray<readonly [string, readonly Tool[]]> = [
  [
    "drawing",
    [
      "select",
      "point",
      "line",
      "circle",
      "roundHole",
      "arc",
      "freeText",
      "stitchStartPoint",
      "centerLine",
      "horizontalCenterLine",
      "verticalCenterLine",
    ],
  ],
  ["derived", ["offset", "fillet"]],
  [
    "constraint",
    [
      "coincident",
      "horizontal",
      "vertical",
      "parallel",
      "perpendicular",
      "tangent",
      "equalLength",
      "angle",
      "symmetric",
      "pointOnLine",
      "fixed",
    ],
  ],
  [
    "dimension",
    ["distance", "horizontalDistance", "verticalDistance", "lineLineDistance", "segmentLength", "diameter", "radius"],
  ],
  [
    "measurement",
    [
      "measureDistance",
      "measureSegmentLength",
      "measureAngle",
      "measureRadius",
      "measureDiameter",
      "measureArcSweepAngle",
    ],
  ],
];
const labels = appStrings.toolNames;
const groupLabels = appStrings.palette.groupNames;
export const basicTools = new Set<Tool>([
  "select",
  "line",
  "circle",
  "arc",
  "roundHole",
  "freeText",
  "stitchStartPoint",
  "offset",
  "fillet",
  "distance",
  "horizontalDistance",
  "verticalDistance",
  "segmentLength",
  "diameter",
  "radius",
]);
export const allPaletteTools = toolGroups.flatMap(([, tools]) => tools);
export const detailedTools = new Set<Tool>(allPaletteTools.filter((tool) => !basicTools.has(tool)));
export const toolGroupPreferenceIds: Record<string, string> = {
  drawing: "drawing",
  derived: "derived",
  constraint: "constraint",
  dimension: "dimension",
  measurement: "measurement",
};
export const defaultCollapsedToolGroups = new Set<string>();
function DisclosureIcon({ expanded }: { expanded: boolean }) {
  const Icon = expanded ? ChevronDown : ChevronRight;
  return <Icon className="palette-disclosure" size={10} strokeWidth={2} aria-hidden="true" />;
}

function PaletteActionIcon({ kind }: { kind: "expand" | "brush" }) {
  const Icon = kind === "brush" ? Paintbrush : Maximize2;
  return <Icon className="palette-action-icon" size={12} strokeWidth={1.7} aria-hidden="true" />;
}

export function ToolPalette({
  activeStyle,
  sharedStyles,
  activeTool,
  roundDiameter,
  roundKind,
  selectedCount,
  basicOnly,
  collapsedGroups,
  onActiveStyleChange,
  onToolChange,
  onRoundDiameterChange,
  onRoundKindChange,
  onBasicOnlyChange,
  onCollapsedGroupsChange,
  onApplyStyle,
}: Props) {
  const [roundDiameterText, setRoundDiameterText] = useState(String(roundDiameter));
  useEffect(() => {
    if (Number.isFinite(roundDiameter)) setRoundDiameterText(String(roundDiameter));
  }, [roundDiameter]);
  const isExpanded = (title: string, tools: readonly Tool[]) =>
    tools.includes(activeTool) || !collapsedGroups.has(title);
  const toggleGroup = (title: string) => {
    const next = new Set(collapsedGroups);
    if (next.has(title)) next.delete(title);
    else next.add(title);
    onCollapsedGroupsChange(next);
  };
  return (
    <aside className="tool-palette" aria-label={appStrings.palette.ariaLabel}>
      <header className="palette-header">
        <PanelLeft className="palette-header-icon" size={16} strokeWidth={2} aria-hidden="true" />
        <span>
          <strong>{appStrings.palette.title}</strong>
          <small>{appStrings.palette.subtitle}</small>
        </span>
      </header>
      <div className="palette-scroll">
        <section className="palette-options">
          <h2>{appStrings.palette.display}</h2>
          <button className="wide-button" onClick={() => onBasicOnlyChange(!basicOnly)}>
            {basicOnly ? (
              <Minimize2 className="palette-action-icon" size={12} strokeWidth={1.7} aria-hidden="true" />
            ) : (
              <PaletteActionIcon kind="expand" />
            )}
            {basicOnly ? appStrings.palette.showDetailed : appStrings.palette.showBasicOnly}
          </button>
        </section>
        <section className="palette-options">
          <h2>{appStrings.palette.lineStyle}</h2>
          <select
            className="palette-select"
            aria-label={appStrings.palette.lineStyleAria}
            value={activeStyle}
            onChange={(event) => onActiveStyleChange(event.target.value)}
          >
            {sharedStyles.map((style) => (
              <option key={style.id} value={style.id}>
                {style.name}
              </option>
            ))}
          </select>
          <button className="wide-button" disabled={!selectedCount || !activeStyle} onClick={onApplyStyle}>
            <PaletteActionIcon kind="brush" />
            {appStrings.palette.applyToSelection}
          </button>
        </section>
        <section className="palette-options">
          <h2>{appStrings.palette.roundHole}</h2>
          <select
            className="palette-select"
            aria-label={appStrings.palette.roundHoleKind}
            value={roundKind}
            onChange={(event) => onRoundKindChange(event.target.value)}
          >
            <option value="keyRing">{appStrings.palette.roundHoleKinds.keyRing}</option>
            <option value="rivet">{appStrings.palette.roundHoleKinds.rivet}</option>
            <option value="snapFastener">{appStrings.palette.roundHoleKinds.snapFastener}</option>
            <option value="decorative">{appStrings.palette.roundHoleKinds.decorative}</option>
          </select>
          <input
            className="palette-input"
            aria-label={appStrings.palette.roundHoleDiameter}
            type="text"
            inputMode="decimal"
            value={roundDiameterText}
            onChange={(event) => {
              setRoundDiameterText(event.target.value);
              const parsed = parseDecimal(event.target.value);
              onRoundDiameterChange(parsed.ok && parsed.value > 0 ? parsed.value : Number.NaN);
            }}
          />
        </section>
        {basicOnly && detailedTools.has(activeTool) && (
          <section className="palette-options">
            <h2>{appStrings.palette.activeDetailedTool}</h2>
            <button className="active" onClick={() => onBasicOnlyChange(false)}>
              <ToolIcon tool={activeTool} size={15} />
              <span>{labels[activeTool]}</span>
            </button>
          </section>
        )}
        {toolGroups.map(([groupID, tools]) => {
          const visibleTools = basicOnly ? tools.filter((tool) => basicTools.has(tool)) : tools;
          const expanded = isExpanded(groupID, tools);
          return visibleTools.length ? (
            <section className="tool-group" key={groupID}>
              <button className="tool-group-heading" onClick={() => toggleGroup(groupID)} aria-expanded={expanded}>
                <DisclosureIcon expanded={expanded} />
                <span>{groupLabels[groupID as keyof typeof groupLabels]}</span>
              </button>
              {expanded && (
                <div className="tool-grid">
                  {visibleTools.map((tool) => (
                    <button
                      key={tool}
                      className={tool === activeTool ? "active" : ""}
                      onClick={() => onToolChange(tool)}
                      aria-pressed={tool === activeTool}
                      title={labels[tool]}
                    >
                      <ToolIcon tool={tool} size={15} />
                      <span>{labels[tool]}</span>
                    </button>
                  ))}
                </div>
              )}
            </section>
          ) : null;
        })}
      </div>
    </aside>
  );
}
