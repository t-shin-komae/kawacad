import { useEffect, useRef, useState } from "react";
import { documentAdapter } from "@/adapters/documentAdapter";
import {
  PDFPreview,
  type Orientation,
  type OutputDocumentModel,
  type OutputOptions,
  type OutputWarning,
} from "@/features/output/components/PDFExportDialog";

type Printer = { id: string; displayName: string; selectable: boolean };
type PreparedPrint = { preparedPrintId: string; outputDocumentModel: OutputDocumentModel; warnings: OutputWarning[] };

type Props = {
  initialOrientation: Orientation;
  onClose: () => void;
  onPrinted: () => void;
};

function initialOptions(orientation: Orientation): OutputOptions {
  return { orientation, includeDimensionLabels: true, includeScaleGuide: true, rotationDeg: 0 };
}

/** Direct printing only sends a backend-prepared artifact; the browser never opens a print dialog. */
export function DirectPrintDialog({ initialOrientation, onClose, onPrinted }: Props) {
  const [options, setOptions] = useState(() => initialOptions(initialOrientation));
  const [printers, setPrinters] = useState<Printer[]>([]);
  const [printerId, setPrinterId] = useState("");
  const [prepared, setPrepared] = useState<PreparedPrint>();
  const [loading, setLoading] = useState(true);
  const [printing, setPrinting] = useState(false);
  const [error, setError] = useState<string>();
  const [warningsAcknowledged, setWarningsAcknowledged] = useState(false);
  const generation = useRef(0);

  useEffect(() => {
    let active = true;
    void documentAdapter
      .command<{ status: "available" | "unsupportedPlatform" | "unavailable"; reason?: string }>(
        "direct_print_availability",
      )
      .then(async (availability) => {
        if (availability.status !== "available") throw new Error(availability.reason ?? "直接印刷は利用できません。");
        const result = await documentAdapter.command<Printer[]>("list_printers");
        if (!active) return;
        const selectable = result.filter((printer) => printer.selectable);
        setPrinters(selectable);
        setPrinterId(selectable[0]?.id ?? "");
        if (selectable.length === 0) setError("利用可能なプリンタがありません。");
      })
      .catch((reason) => {
        if (active) setError(`直接印刷を利用できません: ${String(reason)}`);
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    if (!printerId) return;
    let active = true;
    let preparedPrintId: string | undefined;
    const requestGeneration = ++generation.current;
    setLoading(true);
    setPrepared(undefined);
    setWarningsAcknowledged(false);
    setError(undefined);
    void documentAdapter
      .command<PreparedPrint>("prepare_direct_print", {
        request: {
          printerId,
          options: {
            orientation: options.orientation,
            includeDimensionLabels: options.includeDimensionLabels,
            includeScaleGuide: options.includeScaleGuide,
          },
          generation: requestGeneration,
        },
      })
      .then((result) => {
        preparedPrintId = result.preparedPrintId;
        if (active) setPrepared(result);
        else void documentAdapter.command("discard_prepared_direct_print", { preparedPrintId });
      })
      .catch((reason) => {
        if (active) setError(`出力内容を生成できません: ${String(reason)}`);
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
      if (preparedPrintId) void documentAdapter.command("discard_prepared_direct_print", { preparedPrintId });
    };
  }, [options, printerId]);

  const warnings = prepared?.warnings ?? [];
  const canPrint = Boolean(prepared && !loading && !printing && (warnings.length === 0 || warningsAcknowledged));
  const changeOptions = (update: Partial<OutputOptions>) => setOptions((current) => ({ ...current, ...update }));
  const print = async () => {
    if (!prepared || !canPrint) return;
    setPrinting(true);
    setError(undefined);
    try {
      await documentAdapter.command("run_prepared_direct_print", { preparedPrintId: prepared.preparedPrintId });
      onPrinted();
      onClose();
    } catch (reason) {
      setPrepared(undefined);
      setError(`印刷ジョブを開始できません: ${String(reason)}`);
    } finally {
      setPrinting(false);
    }
  };

  return (
    <div className="modal-backdrop" role="presentation" onMouseDown={printing ? undefined : onClose}>
      <section
        className="pdf-export-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="direct-print-title"
        onMouseDown={(event) => event.stopPropagation()}
      >
        <header className="pdf-export-header">
          <div>
            <h2 id="direct-print-title">直接印刷</h2>
            <p>A4固定・100%実寸・片面で、印刷ダイアログを表示せずに送信します。</p>
          </div>
          <button type="button" onClick={onClose} disabled={printing} aria-label="閉じる">
            閉じる
          </button>
        </header>
        <div className="pdf-export-body">
          <div className="pdf-export-settings">
            <dl className="pdf-export-summary">
              <div>
                <dt>プリンタ</dt>
                <dd>
                  {printerId ? printers.find((printer) => printer.id === printerId)?.displayName : "選択してください"}
                </dd>
              </div>
              <div>
                <dt>用紙</dt>
                <dd>A4・100%・片面</dd>
              </div>
              <div>
                <dt>ページ数</dt>
                <dd>{loading ? "算出中" : `${prepared?.outputDocumentModel.pageCount ?? 0} ページ`}</dd>
              </div>
            </dl>
            <fieldset disabled={printing || loading}>
              <legend>出力設定</legend>
              <label>
                プリンタ
                <select value={printerId} onChange={(event) => setPrinterId(event.target.value)}>
                  <option value="">選択してください</option>
                  {printers.map((printer) => (
                    <option key={printer.id} value={printer.id}>
                      {printer.displayName}
                    </option>
                  ))}
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
                    disabled={loading || printing}
                    onChange={(event) => setWarningsAcknowledged(event.target.checked)}
                  />
                  警告内容を確認しました
                </label>
              </section>
            ) : null}
            <div className="button-row pdf-export-actions">
              <button type="button" onClick={onClose} disabled={printing}>
                キャンセル
              </button>
              <button type="button" onClick={() => void print()} disabled={!canPrint}>
                {printing ? "印刷中…" : "印刷を開始"}
              </button>
            </div>
          </div>
          <PDFPreview pages={prepared?.outputDocumentModel.pages ?? []} loading={loading} />
        </div>
      </section>
    </div>
  );
}
