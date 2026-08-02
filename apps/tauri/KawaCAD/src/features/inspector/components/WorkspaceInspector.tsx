import type { ComponentProps } from "react";
import { InspectorPanel } from "@/features/inspector/components/InspectorPanel";

type InspectorProps = ComponentProps<typeof InspectorPanel>;

type Props = {
  mode: "docked" | "compact";
  revision: number;
  inspector: InspectorProps;
};

export function WorkspaceInspector({ mode, revision, inspector }: Props) {
  const panel = <InspectorPanel key={`${mode}-inspector-${revision}`} {...inspector} />;
  return mode === "compact" ? <aside className="compact-drawer compact-inspector-drawer">{panel}</aside> : panel;
}
