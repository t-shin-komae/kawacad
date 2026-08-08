import { useEffect, useRef, useState } from "react";
import { dialogAdapter } from "@/adapters/dialogAdapter";
import { documentAdapter } from "@/adapters/documentAdapter";
import { accessibilityIdentifiers } from "@/shared/accessibility/accessibilityIdentifiers";

type Orientation = "portrait" | "landscape";

type OutputOptions = {
  orientation: Orientation;
  includeDimensionLabels: boolean;
  includeScaleGuide: boolean;
  rotationDeg: 0 | 90;
};

type OutputPage = { gridColumn: number; gridRow: number; widthMm: number; heightMm: number };
type OutputDocumentModel = { pageCount: number; pages: OutputPage[] } & Record<string, unknown>;
type OutputWarning = { message: string };
type PreparedPDF = { outputDocumentModel: OutputDocumentModel; warnings: OutputWarning[] };

type Props = {
  documentName: string;
  initialOrientation: Orientation;
  onClose: () => void;
  onOrientationChange: (orientation: Orientation) => void;
  onSaved: (path: string) => void;
};

function initialOptions(orientation: Orientation): OutputOptions {
  return {
    orientation,
    includeDimensionLabels: true,
    includeScaleGuide: true,
    rotationDeg: 0,
  };
}

function pdfFileName(documentName: string) {
  const baseName = documentName.trim() || "KawaCAD";
  return `${baseName.replace(/[\\/:*?"<>|]/g, "-")}.pdf`;
}

/** PDF output settings. The prepared model remains stable while the OS save panel is open. */
export function PDFExportDialog({ documentName, initialOrientation, onClose, onOrientationChange, onSaved }: Props) {
  const [options, setOptions] = useState(() => initialOptions(initialOrientation));
  const [prepared, setPrepared] = useState<PreparedPDF>();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string>();
  const [warningsAcknowledged, setWarningsAcknowledged] = useState(false);
  const request = useRef(0);

  useEffect(() => {
    const currentRequest = ++request.current;
    setLoading(true);
    setError(undefined);
    setWarningsAcknowledged(false);
    void documentAdapter
      .command<PreparedPDF>("prepare_pdf_output", { options })
      .then((result) => {
        if (currentRequest !== request.current) return;
        setPrepared(result);
      })
      .catch((reason) => {
        if (currentRequest === request.current) setError(`出力内容を生成できません: ${String(reason)}`);
      })
      .finally(() => {
        if (currentRequest === request.current) setLoading(false);
      });
  }, [options]);

  const warnings = prepared?.warnings ?? [];
  const pageCount = prepared?.outputDocumentModel.pageCount ?? 0;
  const canSave = Boolean(
    prepared && pageCount > 0 && !loading && !saving && (warnings.length === 0 || warningsAcknowledged),
  );
  const changeOptions = (update: Partial<OutputOptions>) => setOptions((current) => ({ ...current, ...update }));
  const save = async () => {
    if (!prepared || !canSave) return;
    const path = await dialogAdapter.save({
      defaultPath: pdfFileName(documentName),
      filters: [{ name: "PDF", extensions: ["pdf"] }],
    });
    if (!path) return;
    setSaving(true);
    setError(undefined);
    try {
      await documentAdapter.command("save_prepared_pdf", { outputDocumentModel: prepared.outputDocumentModel, path });
      onSaved(path);
      onClose();
    } catch (reason) {
      setError(`PDFを保存できません: ${String(reason)}`);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="modal-backdrop" role="presentation" onMouseDown={saving ? undefined : onClose}>
      <section
        className="pdf-export-dialog"
        data-testid={accessibilityIdentifiers.pdfExportDialog}
        role="dialog"
        aria-modal="true"
        aria-labelledby="pdf-export-title"
        onMouseDown={(event) => event.stopPropagation()}
      >
        <header className="pdf-export-header">
          <div>
            <h2 id="pdf-export-title">PDF出力</h2>
            <p>A4固定・100%実寸で出力します。</p>
          </div>
          <button type="button" onClick={onClose} disabled={saving} aria-label="閉じる">
            閉じる
          </button>
        </header>
        <div className="pdf-export-body">
          <div className="pdf-export-settings">
            <dl className="pdf-export-summary">
              <div>
                <dt>出力先</dt>
                <dd>PDF</dd>
              </div>
              <div>
                <dt>用紙</dt>
                <dd>A4・100%</dd>
              </div>
              <div>
                <dt>ページ数</dt>
                <dd>{loading ? "算出中" : `${pageCount} ページ`}</dd>
              </div>
            </dl>
            <fieldset disabled={saving}>
              <legend>出力設定</legend>
              <label>
                用紙向き
                <select
                  value={options.orientation}
                  onChange={(event) => {
                    const orientation = event.target.value as Orientation;
                    changeOptions({ orientation });
                    onOrientationChange(orientation);
                  }}
                >
                  <option value="portrait">縦向き</option>
                  <option value="landscape">横向き</option>
                </select>
              </label>
              <label>
                回転
                <select
                  value={options.rotationDeg}
                  onChange={(event) => changeOptions({ rotationDeg: Number(event.target.value) as 0 | 90 })}
                >
                  <option value={0}>0°</option>
                  <option value={90}>90°</option>
                </select>
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={options.includeDimensionLabels}
                  onChange={(event) => changeOptions({ includeDimensionLabels: event.target.checked })}
                />
                寸法数値を出力に含める
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={options.includeScaleGuide}
                  onChange={(event) => changeOptions({ includeScaleGuide: event.target.checked })}
                />
                50mmガイドを出力に含める
              </label>
            </fieldset>
            {error ? (
              <p className="pdf-export-error" role="alert">
                {error}
              </p>
            ) : null}
            {warnings.length > 0 ? (
              <section className="pdf-export-warnings" aria-label="出力警告">
                <strong>警告 {warnings.length} 件</strong>
                <ul>
                  {warnings.map((warning, index) => (
                    <li key={`${warning.message}-${index}`}>{warning.message}</li>
                  ))}
                </ul>
                <label>
                  <input
                    type="checkbox"
                    checked={warningsAcknowledged}
                    disabled={loading || saving}
                    onChange={(event) => setWarningsAcknowledged(event.target.checked)}
                  />
                  警告内容を確認しました
                </label>
              </section>
            ) : null}
            {pageCount === 0 && !loading && !error ? (
              <p className="pdf-export-error" role="alert">
                出力対象がありません。
              </p>
            ) : null}
            <div className="button-row pdf-export-actions">
              <button type="button" onClick={onClose} disabled={saving}>
                キャンセル
              </button>
              <button
                type="button"
                data-testid={accessibilityIdentifiers.pdfExportSave}
                onClick={() => void save()}
                disabled={!canSave}
              >
                {saving ? "PDF保存中…" : "保存へ進む"}
              </button>
            </div>
          </div>
          <PDFPreview pages={prepared?.outputDocumentModel.pages ?? []} loading={loading} />
        </div>
      </section>
    </div>
  );
}

function PDFPreview({ pages, loading }: { pages: OutputPage[]; loading: boolean }) {
  return (
    <section className="pdf-export-preview" aria-live="polite" aria-busy={loading}>
      <h3>最終プレビュー</h3>
      {pages.length ? (
        <ol className="pdf-export-pages">
          {pages.map((page, index) => (
            <li key={`${page.gridColumn}-${page.gridRow}`}>
              <div className={page.widthMm > page.heightMm ? "pdf-page landscape" : "pdf-page"}>{index + 1}</div>
              <span>
                {page.gridColumn}, {page.gridRow}
              </span>
            </li>
          ))}
        </ol>
      ) : (
        <p>{loading ? "出力内容を生成中…" : "出力対象がありません。"}</p>
      )}
      {loading && pages.length > 0 ? <div className="pdf-export-preview-updating">設定を反映中…</div> : null}
    </section>
  );
}
