import { useState } from "react";
import { appErrorCategoryTitle, type AppErrorPresentation } from "@/features/workspace/selectors/appErrorPresentation";
import { appStrings } from "@/localization";

type Props = {
  presentation: AppErrorPresentation;
  onDismiss: () => void;
};

export function AppErrorBanner({ presentation, onDismiss }: Props) {
  const [detailsExpanded, setDetailsExpanded] = useState(false);

  return (
    <aside className="document-warning-banner app-error-banner" role="alert">
      <span>
        <strong>{appErrorCategoryTitle(presentation.identity.category)}</strong>
        <span>{presentation.message}</span>
        {presentation.recoverySuggestion && <small>{presentation.recoverySuggestion}</small>}
        {presentation.occurrenceCount > 1 && <small>× {presentation.occurrenceCount}</small>}
        {detailsExpanded && presentation.details && <code>{presentation.details}</code>}
      </span>
      {presentation.details && (
        <button type="button" onClick={() => setDetailsExpanded((expanded) => !expanded)}>
          {appStrings.common.details}
        </button>
      )}
      <button type="button" onClick={onDismiss}>
        {appStrings.common.close}
      </button>
    </aside>
  );
}
