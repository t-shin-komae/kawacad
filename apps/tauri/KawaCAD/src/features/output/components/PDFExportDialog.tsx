import { useEffect, useRef, useState } from "react";
import { dialogAdapter } from "@/adapters/dialogAdapter";
import { documentAdapter } from "@/adapters/documentAdapter";
import { accessibilityIdentifiers } from "@/shared/accessibility/accessibilityIdentifiers";
import { appStrings } from "@/localization";
import {
  AlertTriangle,
  ArrowUpLeft,
  CheckCircle2,
  Info,
  LoaderCircle,
  PackageOpen,
  Ruler,
  SquareSplitVertical,
} from "lucide-react";

export type Orientation = "portrait" | "landscape";

export type OutputOptions = {
  orientation: Orientation;
  includeDimensionLabels: boolean;
  includeScaleGuide: boolean;
  rotationDeg: 0 | 90;
};

type PointMm = { xMm: number; yMm: number };
type OutputStyle = {
  stroke: { red: number; green: number; blue: number; alpha: number };
  strokeWidthMm: number;
  pattern: "solid" | "dashed" | "dotted" | "construction";
};
type OutputGeometry =
  | { kind: "point"; payload: { positionMm: PointMm } }
  | { kind: "lineSegment" | "centerLine"; payload: { startMm: PointMm; endMm: PointMm } }
  | { kind: "circle"; payload: { centerMm: PointMm; radiusMm: number } }
  | {
      kind: "arc";
      payload: { centerMm: PointMm; radiusMm: number; startAngleRad: number; sweepAngleRad: number };
    };
type OutputGraphic = { geometry: OutputGeometry; style: OutputStyle };
type OutputText = { content: string; positionMm: PointMm; fontSizeMm: number };
type OutputGuide = { startMm: PointMm; endMm: PointMm; label: string; labelPositionMm: PointMm };
export type OutputPage = {
  gridColumn: number;
  gridRow: number;
  widthMm: number;
  heightMm: number;
  rotationDeg: 0 | 90;
  printableAreaMm: { leftMm: number; rightMm: number; topMm: number; bottomMm: number };
  graphics: OutputGraphic[];
  texts: OutputText[];
  guide?: OutputGuide | null;
};
export type OutputDocumentModel = { pageCount: number; pages: OutputPage[] } & Record<string, unknown>;
export type OutputWarning = {
  kind?: "emptyDocument" | "outOfPrintableBounds" | "pageBoundaryCrossing" | "actualScaleNotGuaranteed";
  message: string;
};
type PreparedPDF = { outputDocumentModel: OutputDocumentModel; warnings: OutputWarning[] };

type Props = {
  documentName: string;
  initialOrientation: Orientation;
  options?: OutputOptions;
  onOptionsChange?: (options: OutputOptions) => void;
  onDestinationChange?: (destination: "pdf" | "directPrint") => void;
  directPrintAvailable?: boolean;
  onClose: () => void;
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
export function PDFExportDialog({
  documentName,
  initialOrientation,
  options: externalOptions,
  onOptionsChange,
  onDestinationChange,
  directPrintAvailable = false,
  onClose,
  onSaved,
}: Props) {
  const [ownedOptions, setOwnedOptions] = useState(() => initialOptions(initialOrientation));
  const options = externalOptions ?? ownedOptions;
  const [prepared, setPrepared] = useState<PreparedPDF>();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string>();
  const request = useRef(0);

  useEffect(() => {
    const currentRequest = ++request.current;
    setLoading(true);
    setPrepared(undefined);
    setError(undefined);
    void documentAdapter
      .command<PreparedPDF>("prepare_pdf_output", { options })
      .then((result) => {
        if (currentRequest !== request.current) return;
        setPrepared(result);
      })
      .catch((reason) => {
        if (currentRequest === request.current) {
          setPrepared(undefined);
          setError(appStrings.output.buildFailed(String(reason)));
        }
      })
      .finally(() => {
        if (currentRequest === request.current) setLoading(false);
      });
  }, [options]);

  const outputDocumentModel = prepared?.outputDocumentModel;
  const warnings = prepared?.warnings ?? [];
  const pageCount = outputDocumentModel?.pageCount ?? 0;
  const canSave = Boolean(outputDocumentModel && pageCount > 0 && !loading && !saving);
  const saveLabel = warnings.length > 0 ? appStrings.output.warningSaveNext : appStrings.output.saveNext;
  const changeOptions = (update: Partial<OutputOptions>) => {
    const next = { ...options, ...update };
    onOptionsChange?.(next);
    if (!externalOptions) setOwnedOptions(next);
  };
  const save = async () => {
    if (!outputDocumentModel || !canSave) return;
    const path = await dialogAdapter.save({
      defaultPath: pdfFileName(documentName),
      filters: [{ name: "PDF", extensions: ["pdf"] }],
    });
    if (!path) return;
    setSaving(true);
    setError(undefined);
    try {
      await documentAdapter.command("save_prepared_pdf", { outputDocumentModel, path });
      onSaved(path);
      onClose();
    } catch (reason) {
      setError(appStrings.output.saveFailed(reason));
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
        <div className="pdf-export-body">
          <div className="pdf-export-settings">
            <header className="pdf-export-header">
              <h2 id="pdf-export-title">{appStrings.output.pdfTitle}</h2>
              <p>{appStrings.output.pdfHelp}</p>
            </header>
            <dl className="pdf-export-summary">
              <div>
                <dt>{appStrings.output.destination}</dt>
                <dd>
                  {onDestinationChange ? (
                    <select
                      aria-label={appStrings.output.destination}
                      value="pdf"
                      onChange={(event) => onDestinationChange(event.target.value as "pdf" | "directPrint")}
                    >
                      <option value="pdf">{appStrings.output.pdf}</option>
                      {directPrintAvailable ? (
                        <option value="directPrint">{appStrings.output.directPrint}</option>
                      ) : null}
                    </select>
                  ) : (
                    appStrings.output.pdf
                  )}
                </dd>
              </div>
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
                <dd>{loading ? appStrings.output.calculating : appStrings.output.pages(pageCount)}</dd>
              </div>
            </dl>
            <fieldset disabled={saving}>
              <legend>{appStrings.output.settings}</legend>
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
            <section className="pdf-export-status" aria-live="polite">
              <h3>{appStrings.output.status}</h3>
              {loading ? (
                <p>
                  <LoaderCircle aria-hidden="true" size={16} /> {appStrings.output.buildLoading}
                </p>
              ) : error ? (
                <p>
                  <Info aria-hidden="true" size={16} /> {error}
                </p>
              ) : pageCount === 0 ? (
                <p>
                  <Info aria-hidden="true" size={16} /> {appStrings.output.noOutput}
                </p>
              ) : warnings.length > 0 ? (
                <p>
                  <AlertTriangle aria-hidden="true" size={16} /> {appStrings.output.warningCount(warnings.length)}
                </p>
              ) : (
                <p>
                  <CheckCircle2 aria-hidden="true" size={16} /> {appStrings.output.ready}
                </p>
              )}
            </section>
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
                    <li key={`${warning.message}-${index}`}>
                      <WarningIcon warning={warning} />
                      {warning.message}
                    </li>
                  ))}
                </ul>
              </section>
            ) : null}
            {pageCount === 0 && !loading && !error ? (
              <p className="pdf-export-error" role="alert">
                {appStrings.output.noOutput}
              </p>
            ) : null}
            <div className="button-row pdf-export-actions">
              <button type="button" onClick={onClose} disabled={saving}>
                {appStrings.common.cancel}
              </button>
              <button
                type="button"
                className="primary-action"
                data-testid={accessibilityIdentifiers.pdfExportSave}
                onClick={() => void save()}
                disabled={!canSave}
              >
                {saving ? appStrings.output.saving : saveLabel}
              </button>
            </div>
          </div>
          <PDFPreview pages={outputDocumentModel?.pages ?? []} loading={loading} />
        </div>
      </section>
    </div>
  );
}

function WarningIcon({ warning }: { warning: OutputWarning }) {
  const Icon =
    warning.kind === "emptyDocument"
      ? PackageOpen
      : warning.kind === "outOfPrintableBounds"
        ? ArrowUpLeft
        : warning.kind === "pageBoundaryCrossing"
          ? SquareSplitVertical
          : warning.kind === "actualScaleNotGuaranteed"
            ? Ruler
            : AlertTriangle;
  return <Icon aria-hidden="true" size={14} />;
}

export function PDFPreview({ pages, loading }: { pages: OutputPage[]; loading: boolean }) {
  return (
    <section className="pdf-export-preview" aria-live="polite" aria-busy={loading}>
      <header className="pdf-export-preview-header">
        <h3>{appStrings.output.finalPreview}</h3>
        <span>{loading ? appStrings.output.calculating : appStrings.output.pages(pages.length)}</span>
      </header>
      {pages.length ? (
        <ol className="pdf-export-pages">
          {pages.map((page, index) => (
            <li key={`${page.gridColumn}-${page.gridRow}`}>
              <PDFPreviewPage page={page} pageNumber={index + 1} />
              <span className="pdf-page-number" aria-hidden="true">
                {index + 1}
              </span>
            </li>
          ))}
        </ol>
      ) : (
        <p>{loading ? appStrings.output.generating : appStrings.output.noOutput}</p>
      )}
      {loading && pages.length > 0 ? (
        <div className="pdf-export-preview-updating">{appStrings.output.updating}</div>
      ) : null}
    </section>
  );
}

function PDFPreviewPage({ page, pageNumber }: { page: OutputPage; pageNumber: number }) {
  const pageClassName = page.widthMm > page.heightMm ? "pdf-page landscape" : "pdf-page";
  return (
    <svg
      className={pageClassName}
      data-testid={`pdf-preview-page-${pageNumber}`}
      data-rotation-deg={page.rotationDeg}
      viewBox={`0 0 ${page.widthMm} ${page.heightMm}`}
      role="img"
      aria-label={appStrings.output.pdfPageLabel(pageNumber)}
    >
      <rect width={page.widthMm} height={page.heightMm} className="pdf-page-background" />
      <PrintableArea page={page} />
      {page.graphics.map((graphic, index) => (
        <OutputGraphicPreview key={index} graphic={graphic} page={page} />
      ))}
      {page.texts.map((text, index) => (
        <OutputTextPreview key={`${text.content}-${index}`} text={text} page={page} />
      ))}
      {page.guide ? <OutputGuidePreview guide={page.guide} page={page} /> : null}
    </svg>
  );
}

function PrintableArea({ page }: { page: OutputPage }) {
  const area = page.printableAreaMm;
  const upperLeft = pagePoint(page, { xMm: area.leftMm, yMm: area.topMm }, false);
  const lowerRight = pagePoint(page, { xMm: area.rightMm, yMm: area.bottomMm }, false);
  return (
    <rect
      className="pdf-printable-area"
      data-testid="pdf-printable-area"
      x={Math.min(upperLeft.x, lowerRight.x)}
      y={Math.min(upperLeft.y, lowerRight.y)}
      width={Math.abs(lowerRight.x - upperLeft.x)}
      height={Math.abs(lowerRight.y - upperLeft.y)}
    />
  );
}

function OutputGraphicPreview({ graphic, page }: { graphic: OutputGraphic; page: OutputPage }) {
  const style = outputStyle(graphic.style);
  const { geometry } = graphic;
  if (geometry.kind === "point") {
    const point = pagePoint(page, geometry.payload.positionMm);
    return <circle data-testid="pdf-output-point" cx={point.x} cy={point.y} r={0.5} {...style} />;
  }
  if (geometry.kind === "lineSegment" || geometry.kind === "centerLine") {
    const start = pagePoint(page, geometry.payload.startMm);
    const end = pagePoint(page, geometry.payload.endMm);
    return <line data-testid="pdf-output-line" x1={start.x} y1={start.y} x2={end.x} y2={end.y} {...style} />;
  }
  if (geometry.kind === "circle") {
    const center = pagePoint(page, geometry.payload.centerMm);
    return (
      <circle data-testid="pdf-output-circle" cx={center.x} cy={center.y} r={geometry.payload.radiusMm} {...style} />
    );
  }
  if (geometry.kind !== "arc") return null;
  const { centerMm, radiusMm, startAngleRad, sweepAngleRad } = geometry.payload;
  if (Math.abs(sweepAngleRad) >= Math.PI * 2 - 0.001) {
    const center = pagePoint(page, centerMm);
    return <circle data-testid="pdf-output-arc" cx={center.x} cy={center.y} r={radiusMm} {...style} />;
  }
  const rotation = page.rotationDeg === 90 ? Math.PI / 2 : 0;
  const start = polarPoint(centerMm, radiusMm, startAngleRad + rotation);
  const end = polarPoint(centerMm, radiusMm, startAngleRad + sweepAngleRad + rotation);
  const startPoint = pagePoint(page, start, false);
  const endPoint = pagePoint(page, end, false);
  const largeArc = Math.abs(sweepAngleRad) > Math.PI ? 1 : 0;
  const sweep = sweepAngleRad >= 0 ? 0 : 1;
  return (
    <path
      data-testid="pdf-output-arc"
      d={`M ${startPoint.x} ${startPoint.y} A ${radiusMm} ${radiusMm} 0 ${largeArc} ${sweep} ${endPoint.x} ${endPoint.y}`}
      {...style}
    />
  );
}

function OutputTextPreview({ text, page }: { text: OutputText; page: OutputPage }) {
  const point = pagePoint(page, text.positionMm);
  return (
    <text data-testid="pdf-output-text" x={point.x} y={point.y} fontSize={text.fontSizeMm} textAnchor="middle">
      {text.content}
    </text>
  );
}

function OutputGuidePreview({ guide, page }: { guide: OutputGuide; page: OutputPage }) {
  const start = pagePoint(page, guide.startMm);
  const end = pagePoint(page, guide.endMm);
  return (
    <g className="pdf-output-guide" data-testid="pdf-output-guide">
      <line x1={start.x} y1={start.y} x2={end.x} y2={end.y} />
    </g>
  );
}

function pagePoint(page: OutputPage, point: PointMm, applyRotation = true) {
  const rotated = applyRotation && page.rotationDeg === 90 ? { xMm: -point.yMm, yMm: point.xMm } : point;
  return { x: page.widthMm / 2 + rotated.xMm, y: page.heightMm / 2 - rotated.yMm };
}

function polarPoint(center: PointMm, radius: number, angle: number): PointMm {
  return { xMm: center.xMm + radius * Math.cos(angle), yMm: center.yMm + radius * Math.sin(angle) };
}

function outputStyle(style: OutputStyle) {
  const { stroke, strokeWidthMm, pattern } = style;
  const dashArray = pattern === "solid" ? undefined : { dashed: "6 3", dotted: "1 2", construction: "3 2" }[pattern];
  return {
    fill: "none",
    stroke: `rgba(${Math.round(stroke.red * 255)}, ${Math.round(stroke.green * 255)}, ${Math.round(stroke.blue * 255)}, ${stroke.alpha})`,
    strokeWidth: strokeWidthMm,
    strokeDasharray: dashArray,
  };
}
