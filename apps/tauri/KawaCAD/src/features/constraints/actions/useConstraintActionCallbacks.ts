import { useCallback, useEffect, useRef } from "react";
import { appStrings } from "@/localization";
import { documentAdapter } from "@/adapters/documentAdapter";
import type { Tool } from "@/features/canvas/domain/canvasDomainModels";
import { coreConstraintTarget } from "@/features/canvas/domain/cad";
import {
  constraintKinds,
  id,
  measurementKinds,
  targetCount,
  toolNames as names,
} from "@/features/canvas/domain/workspaceTools";
import type {
  ConstraintPreflight,
  DerivedPreflight,
  HudPosition,
  PendingConstraintValue,
  PendingDerivedValue,
} from "@/features/canvas/state/useCanvasPresentation";
import type { PointMm, ConstraintTarget } from "@/features/canvas/domain/cad";
import type { State } from "@/shared/domain/coreWireTypes";
import type { DerivedValue, OffsetSourceOption } from "@/features/constraints/components/DerivedValueDialog";
import { derivedValueInitialText } from "@/features/constraints/domain/derivedValueDefaults";
import type { ConstraintActionInput } from "@/features/constraints/actions/constraintActionTypes";

type ConstraintActionDependencies = Pick<
  ConstraintActionInput,
  | "state"
  | "command"
  | "applyState"
  | "presentOperationFailure"
  | "setPendingConstraintValue"
  | "setPendingDerivedValue"
  | "setMessage"
  | "setSelected"
  | "activeLayer"
  | "activeStyle"
  | "selected"
  | "tool"
  | "pendingDerivedValue"
> & {
  selectTool: (tool: Tool) => void;
};

export function useConstraintActionCallbacks(dependencies: ConstraintActionDependencies) {
  const {
    state,
    command,
    applyState,
    presentOperationFailure,
    setPendingConstraintValue,
    setPendingDerivedValue,
    setMessage,
    setSelected,
    activeLayer,
    activeStyle,
    selected,
    tool,
    pendingDerivedValue,
    selectTool,
  } = dependencies;
  const activeStyleId = activeStyle || null;
  const pendingFilletHudPosition = useRef<HudPosition>();
  const needsConstraintValue = (candidate: Tool) =>
    [
      "distance",
      "horizontalDistance",
      "verticalDistance",
      "lineLineDistance",
      "segmentLength",
      "diameter",
      "radius",
      "angle",
    ].includes(candidate);
  const commitConstraint = useCallback(
    async (
      candidate: Tool,
      preflight: ConstraintPreflight,
      value: Record<string, number | string | undefined> | undefined,
    ) => {
      try {
        const constraintId = id("constraint");
        const payload = {
          id: constraintId,
          kind: preflight.kind,
          targets: preflight.normalizedTargets,
          value: value ?? null,
          status: "unknown",
        };
        const next = await documentAdapter.command<State>("apply_command", {
          command: { kind: "addConstraint", payload },
        });
        applyState(next);
        setMessage(
          needsConstraintValue(candidate)
            ? appStrings.app.dimensionConstraintAdded
            : appStrings.status.constraintAdded(names[candidate]),
        );
        setPendingConstraintValue(undefined);
        setSelected(new Set());
        selectTool("select");
      } catch (error) {
        presentOperationFailure(new Error(appStrings.status.constraintAddFailed(error)), "addConstraint", candidate);
      }
    },
    [applyState, command, selectTool],
  );
  const applyConstraint = useCallback(
    async (candidate: Tool, targets: ConstraintTarget[], hudPosition?: HudPosition) => {
      const rawKind = constraintKinds[candidate] ?? candidate;
      try {
        const preflight = await documentAdapter.command<ConstraintPreflight>("preflight_constraint", {
          kind: rawKind,
          targets: targets.map(coreConstraintTarget),
        });
        if (needsConstraintValue(candidate)) {
          setPendingConstraintValue({ candidate, preflight, hudPosition });
          setMessage(appStrings.status.specifyConstraintValue(names[candidate]));
          return;
        }
        await commitConstraint(candidate, preflight, preflight.value);
      } catch (error) {
        presentOperationFailure(new Error(appStrings.status.constraintAddFailed(error)), "addConstraint", candidate);
      }
    },
    [commitConstraint],
  );
  const constrainSegmentLengthFromInspector = useCallback(
    async (entityId: string) => {
      try {
        const preflight = await documentAdapter.command<ConstraintPreflight>("preflight_constraint", {
          kind: "segmentLength",
          targets: [{ entity: entityId }],
        });
        const constraintId = id("constraint");
        const next = await documentAdapter.command<State>("apply_command", {
          command: {
            kind: "addConstraint",
            payload: {
              id: constraintId,
              kind: preflight.kind,
              targets: preflight.normalizedTargets,
              value: preflight.value ?? null,
              status: "unknown",
            },
          },
        });
        applyState(next);
        setMessage(appStrings.app.currentSegmentLengthConstrained);
      } catch (error) {
        presentOperationFailure(new Error(appStrings.status.segmentLengthConstraintFailed(error)), "setSegmentLength");
      }
    },
    [applyState, command],
  );
  const applyMeasurement = useCallback(
    async (candidate: Tool, targets: ConstraintTarget[]) => {
      const kind = measurementKinds[candidate];
      if (!kind) return;
      await command(
        "addMeasurementAnnotation",
        {
          id: id("measurement"),
          kind,
          targets: targets.map(coreConstraintTarget),
          labelOffsetMm: { xMm: 0, yMm: 0 },
          overallOffsetMm: { xMm: 0, yMm: 0 },
          visible: true,
        },
        appStrings.app.measurementAdded(names[candidate]),
      );
      setSelected(new Set());
      selectTool("select");
    },
    [command, selectTool],
  );
  const applyDerived = useCallback(
    async (
      candidate: Tool,
      ids: string[],
      previous?: PendingDerivedValue,
      clickPoint?: PointMm,
      hudPosition?: HudPosition,
    ) => {
      try {
        if (candidate === "offset") {
          const preflight = await documentAdapter.command<DerivedPreflight>("preflight_derived_element", {
            kind: "offsetCurve",
            hitEntityId: ids[0],
            selectedEntityIds: ids,
            clickPoint: clickPoint ?? previous?.clickPoint ?? null,
          });
          if (!preflight.offsetOptions.length) throw new Error(appStrings.app.noOffsetTarget);
          setPendingDerivedValue({
            candidate: "offset",
            preflight,
            clickPoint: clickPoint ?? previous?.clickPoint,
            hudPosition: hudPosition ?? previous?.hudPosition,
            valueText: previous?.valueText ?? derivedValueInitialText("offset"),
            entryMode: previous?.entryMode ?? "fixed",
            parameterId: previous?.parameterId ?? state?.parameters[0]?.id ?? "",
          });
          setMessage(appStrings.status.specifyOffsetValue);
        } else {
          const preflight = await documentAdapter.command<DerivedPreflight>("preflight_derived_element", {
            kind: "fillet",
            hitEntityId: null,
            selectedEntityIds: ids,
            clickPoint: null,
          });
          if (preflight.sourceEntityIds.length < 2) throw new Error(appStrings.app.filletSourceRequired);
          setPendingDerivedValue({
            candidate: "fillet",
            preflight,
            hudPosition: hudPosition ?? previous?.hudPosition,
            valueText: previous?.valueText ?? derivedValueInitialText("fillet"),
            entryMode: previous?.entryMode ?? "fixed",
            parameterId: previous?.parameterId ?? state?.parameters[0]?.id ?? "",
          });
          setMessage(appStrings.status.specifyFilletRadius);
        }
      } catch (error) {
        presentOperationFailure(
          new Error(appStrings.status.derivedElementAddFailed(names[candidate], error)),
          "addDerivedElement",
          candidate,
        );
      }
    },
    [state?.parameters],
  );
  const commitDerived = useCallback(
    async (pending: PendingDerivedValue, value: DerivedValue, option?: OffsetSourceOption) => {
      try {
        if (pending.candidate === "offset") {
          if (!option) throw new Error(appStrings.app.noOffsetTarget);
          await command(
            "addDerivedElement",
            {
              id: id("derived"),
              layerId: activeLayer,
              styleId: activeStyleId,
              kind: {
                offsetCurve: {
                  sourceEntityIds: option.sourceEntityIds,
                  ...(option.sourceResolvedEntityIds?.length
                    ? { sourceResolvedEntityIds: option.sourceResolvedEntityIds }
                    : {}),
                  distance: value,
                  direction: option.direction,
                },
              },
            },
            appStrings.app.offsetAdded,
          );
        } else {
          const existing = state?.derivedElements.find(
            (item) => item.id === pending.preflight.updateDerivedElementId && item.kind.fillet,
          );
          const existingFillet = existing?.kind.fillet;
          const sourcesUnchanged =
            existingFillet?.sourceEntityIds.join("\u0000") === pending.preflight.sourceEntityIds.join("\u0000") &&
            Boolean(existingFillet.closed) === pending.preflight.closed;
          if (existing && sourcesUnchanged) {
            await command("setDerivedRadius", { derivedElementId: existing.id, value }, appStrings.app.filletUpdated);
          } else if (existing) {
            await command(
              "compound",
              [
                {
                  kind: "setFilletSources",
                  payload: {
                    derivedElementId: existing.id,
                    sourceEntityIds: pending.preflight.sourceEntityIds,
                    closed: pending.preflight.closed,
                  },
                },
                { kind: "setDerivedRadius", payload: { derivedElementId: existing.id, value } },
              ],
              appStrings.app.filletUpdated,
            );
          } else {
            await command(
              "addDerivedElement",
              {
                id: id("derived"),
                layerId: activeLayer,
                kind: {
                  fillet: {
                    sourceEntityIds: pending.preflight.sourceEntityIds,
                    radius: value,
                    closed: pending.preflight.closed,
                  },
                },
              },
              appStrings.app.filletAdded,
            );
          }
        }
        setPendingDerivedValue(undefined);
        setSelected(new Set());
        selectTool("select");
      } catch (error) {
        presentOperationFailure(
          new Error(appStrings.status.derivedElementAddFailed(names[pending.candidate], error)),
          "addDerivedElement",
          pending.candidate,
        );
      }
    },
    [activeLayer, activeStyleId, command, selectTool, state?.derivedElements],
  );
  const useSelectedTargets = useCallback(
    (candidate: Tool, next: Set<string>, clickPoint?: PointMm, hudPosition?: HudPosition) => {
      const required = targetCount[candidate] ?? 1;
      if (next.size < required) {
        setMessage(appStrings.status.remainingTargets(names[candidate], required - next.size));
        return;
      }
      if (candidate === "offset") void applyDerived(candidate, [...next], undefined, clickPoint, hudPosition);
      if (candidate === "fillet") pendingFilletHudPosition.current = hudPosition;
    },
    [applyDerived],
  );
  useEffect(() => {
    if (tool === "fillet" && selected.size >= 2 && !pendingDerivedValue) {
      const hudPosition = pendingFilletHudPosition.current;
      pendingFilletHudPosition.current = undefined;
      void applyDerived("fillet", [...selected], undefined, undefined, hudPosition);
    }
  }, [applyDerived, pendingDerivedValue, selected, tool]);
  const rewindFilletDraft = useCallback(() => {
    if (pendingDerivedValue?.candidate !== "fillet") return;
    const sourceEntityIds = pendingDerivedValue.preflight.sourceEntityIds.slice(0, -1);
    if (sourceEntityIds.length < 2) {
      setPendingDerivedValue(undefined);
      setSelected(new Set(sourceEntityIds));
      setMessage(appStrings.status.selectFilletTargets);
      return;
    }
    setSelected(new Set(sourceEntityIds));
    void applyDerived("fillet", sourceEntityIds, pendingDerivedValue);
  }, [applyDerived, pendingDerivedValue]);

  return {
    commitConstraint,
    applyConstraint,
    constrainSegmentLengthFromInspector,
    applyMeasurement,
    applyDerived,
    commitDerived,
    useSelectedTargets,
    rewindFilletDraft,
  };
}
