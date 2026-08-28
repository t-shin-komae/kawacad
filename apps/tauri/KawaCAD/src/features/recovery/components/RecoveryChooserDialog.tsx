import type { RecoveryCandidate } from "@/adapters/recoveryAdapter";
import { appStrings } from "@/localization";
import { accessibilityIdentifiers } from "@/shared/accessibility/accessibilityIdentifiers";

type Props = {
  candidates: RecoveryCandidate[];
  onRestore: (id: string) => void;
  onDiscard: (id: string) => void;
  onReveal: (id: string) => void;
  onPostpone: () => void;
};

export function RecoveryChooserDialog({ candidates, onRestore, onDiscard, onReveal, onPostpone }: Props) {
  return (
    <div className="modal-backdrop" role="presentation">
      <section
        className="recovery-chooser-dialog"
        data-testid={accessibilityIdentifiers.componentRecoveryDialog}
        role="dialog"
        aria-modal="true"
        aria-labelledby="recovery-title"
      >
        <h2 id="recovery-title">{appStrings.app.recoveryChooserTitle}</h2>
        <p>{appStrings.app.recoveryChooserMessage}</p>
        <div className="recovery-candidate-list">
          {candidates.map((candidate) => (
            <article className="recovery-candidate-card" key={candidate.id}>
              <strong>
                {candidate.status === "broken"
                  ? appStrings.app.recoveryBrokenCandidate
                  : (candidate.displayName ?? appStrings.app.untitled)}
              </strong>
              <small>
                {appStrings.app.recoveryUpdatedAt(
                  candidate.originalDocumentPath ?? appStrings.app.recoveryUnsavedSource,
                  new Date(candidate.updatedAtMs).toLocaleString(),
                )}
              </small>
              {candidate.status === "broken" && <p role="alert">{candidate.details}</p>}
              <div className="button-row">
                <button
                  type="button"
                  className="primary-action"
                  disabled={candidate.status !== "recoverable"}
                  onClick={() => onRestore(candidate.id)}
                >
                  {appStrings.app.restore}
                </button>
                <button type="button" className="destructive-action" onClick={() => onDiscard(candidate.id)}>
                  {appStrings.app.discard}
                </button>
                <button type="button" onClick={() => onReveal(candidate.id)}>
                  {appStrings.app.showInFolder}
                </button>
              </div>
            </article>
          ))}
        </div>
        <div className="button-row recovery-chooser-footer">
          <button type="button" onClick={onPostpone}>
            {appStrings.app.later}
          </button>
        </div>
      </section>
    </div>
  );
}
