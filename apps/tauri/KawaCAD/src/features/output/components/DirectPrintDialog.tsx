import { useEffect, useState } from "react";
import { documentAdapter } from "@/adapters/documentAdapter";
import {
  PDFPreview,
  type Orientation,
  type OutputDocumentModel,
  type OutputOptions,
  type OutputWarning,
} from "@/features/output/components/PDFExportDialog";
import { appStrings } from "@/localization";

type Printer = { id: string; displayName: string; selectable: boolean };
type PreparedPrint = { preparedPrintId: string; outputDocumentModel: OutputDocumentModel; warnings: OutputWarning[] };

type Props = {
  initialOrientation: Orientation;
  options?: OutputOptions;
  onOptionsChange?: (options: OutputOptions) => void;
  onDestinationChange?: (destination: "pdf" | "directPrint") => void;
  onClose: () => void;
  onPrinted: () => void;
};

// This module is owned by one Webview and survives closing/reopening the sheet.
// The backend keeps a per-Webview watermark, so a component-local counter is insufficient.
let nextPreparedPrintGeneration = 0;

function initialOptions(orientation: Orientation): OutputOptions {
  return { orientation, includeDimensionLabels: true, includeScaleGuide: true, rotationDeg: 0 };
}

/** Direct printing only sends a backend-prepared artifact; the browser never opens a print dialog. */
export function DirectPrintDialog({
  initialOrientation,
  options: externalOptions,
  onOptionsChange,
  onDestinationChange,
  onClose,
  onPrinted,
}: Props) {
  const [ownedOptions, setOwnedOptions] = useState(() => initialOptions(initialOrientation));
  const options = externalOptions ?? ownedOptions;
  const [printers, setPrinters] = useState<Printer[]>([]);
  const [printerId, setPrinterId] = useState("");
  const [prepared, setPrepared] = useState<PreparedPrint>();
  const [preparationRevision, setPreparationRevision] = useState(0);
  const [loading, setLoading] = useState(true);
  const [printing, setPrinting] = useState(false);
  const [error, setError] = useState<string>();
  const [warningsAcknowledged, setWarningsAcknowledged] = useState(false);

  useEffect(() => {
    let active = true;
    void documentAdapter
      .command<{ status: "available" | "unsupportedPlatform" | "unavailable"; reason?: string }>(
        "direct_print_availability",
      )
      .then(async (availability) => {
        if (availability.status !== "available")
          throw new Error(availability.reason ?? appStrings.output.directPrintUnavailable);
        const result = await documentAdapter.command<Printer[]>("list_printers");
        if (!active) return;
        const selectable = result.filter((printer) => printer.selectable);
        setPrinters(selectable);
        setPrinterId(selectable[0]?.id ?? "");
        if (selectable.length === 0) setError(appStrings.output.printerUnavailable);
      })
      .catch((reason) => {
        if (active) setError(appStrings.output.directPrintUnavailableWithReason(reason));
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
    const requestGeneration = ++nextPreparedPrintGeneration;
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
        if (active) setError(appStrings.output.buildFailed(String(reason)));
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
      if (preparedPrintId) void documentAdapter.command("discard_prepared_direct_print", { preparedPrintId });
    };
  }, [options, preparationRevision, printerId]);

  const warnings = prepared?.warnings ?? [];
  const canPrint = Boolean(prepared && !loading && !printing && (warnings.length === 0 || warningsAcknowledged));
  const changeOptions = (update: Partial<OutputOptions>) => {
    const next = { ...options, ...update };
    onOptionsChange?.(next);
    if (!externalOptions) setOwnedOptions(next);
  };
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
      setPreparationRevision((revision) => revision + 1);
      setError(appStrings.output.directPrintFailedWithReason(reason));
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
            <h2 id="direct-print-title">{appStrings.output.directPrintTitle}</h2>
            <p>{appStrings.output.directPrintHelp}</p>
          </div>
          <button type="button" onClick={onClose} disabled={printing} aria-label={appStrings.common.close}>
            {appStrings.common.close}
          </button>
        </header>
        <div className="pdf-export-body">
          <div className="pdf-export-settings">
            <dl className="pdf-export-summary">
              <div>
                <dt>{appStrings.output.printer}</dt>
                <dd>
                  {printerId
                    ? printers.find((printer) => printer.id === printerId)?.displayName
                    : appStrings.output.choosePrinter}
                </dd>
              </div>
              {onDestinationChange ? (
                <div>
                  <dt>{appStrings.output.destination}</dt>
                  <dd>
                    <select
                      aria-label={appStrings.output.destination}
                      value="directPrint"
                      onChange={(event) => onDestinationChange(event.target.value as "pdf" | "directPrint")}
                    >
                      <option value="pdf">{appStrings.output.pdf}</option>
                      <option value="directPrint">{appStrings.output.directPrint}</option>
                    </select>
                  </dd>
                </div>
              ) : null}
              <div>
                <dt>{appStrings.output.paper}</dt>
                <dd>{appStrings.output.paperValue}</dd>
              </div>
              <div>
                <dt>{appStrings.output.scale}</dt>
                <dd>{appStrings.output.scaleActualSize}</dd>
              </div>
              <div>
                <dt>{appStrings.output.pageCount}</dt>
                <dd>
                  {loading
                    ? appStrings.output.calculating
                    : appStrings.output.pages(prepared?.outputDocumentModel.pageCount ?? 0)}
                </dd>
              </div>
            </dl>
            <fieldset disabled={printing || loading}>
              <legend>{appStrings.output.settings}</legend>
              <label>
                {appStrings.output.printer}
                <select value={printerId} onChange={(event) => setPrinterId(event.target.value)}>
                  <option value="">{appStrings.output.choosePrinter}</option>
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
                {appStrings.output.includeDimensions}
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={options.includeScaleGuide}
                  onChange={(event) => changeOptions({ includeScaleGuide: event.target.checked })}
                />
                {appStrings.output.includeScaleGuide}
              </label>
            </fieldset>
            {error ? (
              <p className="pdf-export-error" role="alert">
                {error}
              </p>
            ) : null}
            {warnings.length > 0 ? (
              <section className="pdf-export-warnings" aria-label={appStrings.output.warningLabel}>
                <strong>{appStrings.output.warningCount(warnings.length)}</strong>
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
                  {appStrings.output.warningsAcknowledged}
                </label>
              </section>
            ) : null}
            <div className="button-row pdf-export-actions">
              <button type="button" onClick={onClose} disabled={printing}>
                {appStrings.common.cancel}
              </button>
              <button type="button" className="primary-action" onClick={() => void print()} disabled={!canPrint}>
                {printing ? appStrings.output.printing : appStrings.output.printNext}
              </button>
            </div>
          </div>
          <PDFPreview pages={prepared?.outputDocumentModel.pages ?? []} loading={loading} />
        </div>
      </section>
    </div>
  );
}
