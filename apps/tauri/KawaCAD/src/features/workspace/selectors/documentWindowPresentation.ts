import { appStrings } from "@/localization";

export function documentWindowPresentation(name: string, path: string | undefined, isDirty: boolean) {
  const displayName = name === "Untitled" ? appStrings.app.untitled : name;
  if (!path)
    return {
      title: `${displayName} — ${appStrings.app.unsaved}`,
      accessibilityLabel: `${displayName}、${isDirty ? appStrings.app.unsavedChanges : appStrings.app.unsaved}`,
    };
  const fileName = path.split(/[\\/]/).pop() || path;
  const stem = fileName.replace(/\.[^.]*$/, "");
  const sameName = [fileName, stem].some(
    (candidate) => candidate.localeCompare(displayName, undefined, { sensitivity: "accent" }) === 0,
  );
  const title = sameName ? fileName : `${fileName} — ${displayName}`;
  return {
    title,
    accessibilityLabel: `${title}、${isDirty ? appStrings.app.unsavedChanges : appStrings.app.savedState}`,
  };
}
