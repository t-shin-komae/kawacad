import { appStrings } from "@/localization";

type Props = { layerName: string; affectedCount: number; onConfirm: () => void; onCancel: () => void };

export function LayerDeletionDialog({ layerName, affectedCount, onConfirm, onCancel }: Props) {
  return (
    <div className="constraint-value-backdrop" role="presentation">
      <section
        className="constraint-value-dialog layer-deletion-dialog"
        role="alertdialog"
        aria-modal="true"
        aria-label={appStrings.dialog.layerDeletion.ariaLabel}
      >
        <h2>{appStrings.dialog.layerDeletion.title(layerName)}</h2>
        <p>{appStrings.dialog.layerDeletion.impact(layerName, affectedCount)}</p>
        <div className="button-row layer-deletion-actions">
          <button type="button" onClick={onCancel}>
            {appStrings.dialog.layerDeletion.cancel}
          </button>
          <button className="destructive-action" type="button" onClick={onConfirm}>
            {appStrings.dialog.layerDeletion.delete}
          </button>
        </div>
      </section>
    </div>
  );
}
