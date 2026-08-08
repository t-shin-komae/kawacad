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
type OutputPage = {
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
    setPrepared(undefined);
    setError(undefined);
    setWarningsAcknowledged(false);
    void documentAdapter
      .command<PreparedPDF>("prepare_pdf_output", { options })
      .then((result) => {
        if (currentRequest !== request.current) return;
        setPrepared(result);
      })
      .catch((reason) => {
        if (currentRequest === request.current) {
          setPrepared(undefined);
          setError(`出力内容を生成できません: ${String(reason)}`);
        }
      })
      .finally(() => {
        if (currentRequest === request.current) setLoading(false);
      });
  }, [options]);

  const outputDocumentModel = prepared?.outputDocumentModel;
  const warnings = prepared?.warnings ?? [];
  const pageCount = outputDocumentModel?.pageCount ?? 0;
  const canSave = Boolean(
    outputDocumentModel && pageCount > 0 && !loading && !saving && (warnings.length === 0 || warningsAcknowledged),
  );
  const changeOptions = (update: Partial<OutputOptions>) => setOptions((current) => ({ ...current, ...update }));
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
          <PDFPreview pages={outputDocumentModel?.pages ?? []} loading={loading} />
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
              <PDFPreviewPage page={page} pageNumber={index + 1} />
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

function PDFPreviewPage({ page, pageNumber }: { page: OutputPage; pageNumber: number }) {
  const pageClassName = page.widthMm > page.heightMm ? "pdf-page landscape" : "pdf-page";
  return (
    <svg
      className={pageClassName}
      data-testid={`pdf-preview-page-${pageNumber}`}
      data-rotation-deg={page.rotationDeg}
      viewBox={`0 0 ${page.widthMm} ${page.heightMm}`}
      role="img"
      aria-label={`PDF ${pageNumber}ページ目`}
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
