import { CircleDot, FileOutput, Info, MapPin, MousePointer2 } from "lucide-react";
import type { CanvasViewMode } from "@/features/canvas/domain/canvasDomainModels";
import type { PointMm } from "@/features/canvas/domain/cad";
import { accessibilityIdentifiers } from "@/shared/accessibility/accessibilityIdentifiers";
import { appStrings } from "@/localization";

type Props = {
  visibleEntityCount: number;
  selectedCount: number;
  cursorPoint?: PointMm;
  viewMode: CanvasViewMode;
  outputWarningCount: number;
  outputPageCount: number;
  message: string;
  summaryVisible: boolean;
  onToggleSummary: () => void;
};

export function CanvasStatusBar({
  visibleEntityCount,
  selectedCount,
  cursorPoint,
  viewMode,
  outputWarningCount,
  outputPageCount,
  message,
  summaryVisible,
  onToggleSummary,
}: Props) {
  return (
    <footer className="statusbar" data-testid={accessibilityIdentifiers.workspaceStatusBar}>
      <span>
        <span className="statusbar-item">
          <CircleDot size={12} strokeWidth={1.8} aria-hidden="true" />
          {appStrings.app.statusGeometry(visibleEntityCount)}
        </span>{" "}
        ·{" "}
        <span className="statusbar-item">
          <MousePointer2 size={12} strokeWidth={1.8} aria-hidden="true" />
          {selectedCount ? appStrings.app.statusSelection(selectedCount) : appStrings.app.statusNoSelection}
        </span>{" "}
        ·{" "}
        <span className="statusbar-item">
          <MapPin size={12} strokeWidth={1.8} aria-hidden="true" />
          {cursorPoint
            ? appStrings.app.statusCoordinates(cursorPoint.xMm, cursorPoint.yMm)
            : appStrings.app.statusNoCoordinates}
        </span>
      </span>
      {viewMode === "outputPreview" && (
        <span>
          <FileOutput size={12} strokeWidth={1.8} aria-hidden="true" />{" "}
          {outputWarningCount
            ? appStrings.app.outputWarnings(outputWarningCount)
            : appStrings.app.outputPages(outputPageCount)}
        </span>
      )}
      <span className="statusbar-item statusbar-message" role="status" aria-live="polite">
        <Info size={12} strokeWidth={1.8} aria-hidden="true" />
        {message}
      </span>
      <button
        type="button"
        className="statusbar-summary-toggle"
        aria-label={summaryVisible ? appStrings.app.statusSummaryHide : appStrings.app.statusSummaryShow}
        onClick={onToggleSummary}
      >
        {summaryVisible ? appStrings.app.statusSummaryHide : appStrings.app.statusSummaryShow}
      </button>
    </footer>
  );
}
