import { appStrings } from "@/localization";

export type AppErrorCategory = "userCorrectable" | "operationFailure" | "systemInternal";

export type AppErrorIdentity = {
  category: AppErrorCategory;
  code: string;
  operation: string;
  commandKind?: string;
  constraintKind?: string;
  targetIds: string[];
};

export type AppErrorPresentation = {
  id: string;
  identity: AppErrorIdentity;
  message: string;
  details?: string;
  recoverySuggestion?: string;
  occurrenceCount: number;
};

type ErrorContext = {
  category?: AppErrorCategory;
  code?: string;
  operation: string;
  commandKind?: string;
  constraintKind?: string;
  targetIds?: string[];
  recoverySuggestion?: string;
};

function recordValue(value: unknown): Record<string, unknown> | undefined {
  return typeof value === "object" && value !== null ? (value as Record<string, unknown>) : undefined;
}

function errorRecord(error: unknown) {
  const record = recordValue(error);
  if (record) return record;
  if (typeof error !== "string") return undefined;
  try {
    return recordValue(JSON.parse(error));
  } catch {
    return undefined;
  }
}

function errorText(error: unknown) {
  if (error instanceof Error) return String(error);
  const record = errorRecord(error);
  if (typeof error === "string" && !record) return error;
  return typeof record?.message === "string" ? record.message : String(error);
}

export function makeAppErrorPresentation(error: unknown, context: ErrorContext): AppErrorPresentation {
  const errorData = errorRecord(error);
  const detailsRecord = recordValue(errorData?.details);
  const category = context.category ?? "operationFailure";
  const code = context.code ?? (typeof errorData?.code === "string" ? errorData.code : category);
  const commandKind =
    context.commandKind ?? (typeof detailsRecord?.commandKind === "string" ? detailsRecord.commandKind : undefined);
  const constraintKind =
    context.constraintKind ??
    (typeof detailsRecord?.constraintKind === "string" ? detailsRecord.constraintKind : undefined);
  const targetIds = (
    context.targetIds ??
    (Array.isArray(detailsRecord?.targetIds)
      ? detailsRecord.targetIds.filter((value): value is string => typeof value === "string")
      : [])
  ).sort();
  const identity: AppErrorIdentity = {
    category,
    code,
    operation: context.operation,
    commandKind,
    constraintKind,
    targetIds,
  };
  const id = [
    identity.category,
    identity.code,
    identity.operation,
    identity.commandKind ?? "",
    identity.constraintKind ?? "",
    identity.targetIds.join(","),
  ].join("|");

  return {
    id,
    identity,
    message: errorText(error),
    details:
      typeof errorData?.details === "string"
        ? errorData.details
        : errorData?.details
          ? JSON.stringify(errorData.details)
          : undefined,
    recoverySuggestion: context.recoverySuggestion,
    occurrenceCount: 1,
  };
}

export function mergeAppErrorPresentation(
  current: AppErrorPresentation | undefined,
  next: AppErrorPresentation,
): AppErrorPresentation {
  return current?.id === next.id ? { ...next, occurrenceCount: current.occurrenceCount + 1 } : next;
}

export function appErrorCategoryTitle(category: AppErrorCategory) {
  return appStrings.error.category[category];
}
