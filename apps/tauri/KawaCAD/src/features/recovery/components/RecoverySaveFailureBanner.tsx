import { useState } from "react";
import { appStrings } from "@/localization";

type Props = { details: string; onRetry: () => void; onDismiss: () => void };

export function RecoverySaveFailureBanner({ details, onRetry, onDismiss }: Props) {
  const [expanded, setExpanded] = useState(false);
  return (
    <aside className="document-warning-banner app-error-banner" role="alert">
      <span>
        <strong>{appStrings.app.recoverySaveFailedTitle}</strong>
        {expanded && <small>{details}</small>}
      </span>
      <button type="button" onClick={onRetry}>
        {appStrings.common.retry}
      </button>
      <button type="button" onClick={() => setExpanded((current) => !current)}>
        {appStrings.common.details}
      </button>
      <button type="button" onClick={onDismiss}>
        {appStrings.common.close}
      </button>
    </aside>
  );
}
