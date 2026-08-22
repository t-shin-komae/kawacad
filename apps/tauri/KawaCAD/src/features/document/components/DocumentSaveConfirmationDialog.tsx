import { appStrings } from "@/localization";
import type { DocumentSaveChoice } from "@/features/document/state/useDocumentPresentation";

type Props = {
  reason: string;
  documentName: string;
  onChoose: (choice: DocumentSaveChoice) => void;
};

export function DocumentSaveConfirmationDialog({ reason, documentName, onChoose }: Props) {
  return (
    <div className="modal-backdrop" role="presentation">
      <section
        className="document-save-confirmation-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="document-save-confirmation-title"
      >
        <h2 id="document-save-confirmation-title">{appStrings.app.saveChangesTitle(documentName)}</h2>
        <p>{reason}</p>
        <div className="button-row document-save-confirmation-actions">
          <button type="button" onClick={() => onChoose("cancel")}>
            {appStrings.common.cancel}
          </button>
          <button type="button" className="destructive-action" onClick={() => onChoose("discard")}>
            {appStrings.app.discardChanges}
          </button>
          <button type="button" className="primary-action" autoFocus onClick={() => onChoose("save")}>
            {appStrings.app.saveChanges}
          </button>
        </div>
      </section>
    </div>
  );
}
