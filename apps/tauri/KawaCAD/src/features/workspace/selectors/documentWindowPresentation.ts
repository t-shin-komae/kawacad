import { appStrings } from "@/localization";

export function documentDisplayName(path: string | undefined) {
  return path?.split(/[\\/]/).pop() || appStrings.app.untitled;
}

export function documentWindowPresentation(path: string | undefined, isDirty: boolean) {
  const displayName = documentDisplayName(path);
  if (!path)
    return {
      title: `${displayName} — ${appStrings.app.unsaved}`,
      accessibilityLabel: `${displayName}、${isDirty ? appStrings.app.unsavedChanges : appStrings.app.unsaved}`,
    };
  return {
    title: displayName,
    accessibilityLabel: `${displayName}、${isDirty ? appStrings.app.unsavedChanges : appStrings.app.savedState}`,
  };
}
