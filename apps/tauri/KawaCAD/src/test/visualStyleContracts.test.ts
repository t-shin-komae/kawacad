import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

declare global {
  interface ImportMeta {
    glob(pattern: string, options: { eager: boolean; query: string; import: string }): Record<string, string>;
  }
}

const styles = readFileSync("src/app/styles.css", "utf8");
const canvasRendering = Object.values(
  import.meta.glob("../features/canvas/selectors/canvasRendering.ts", {
    eager: true,
    query: "?raw",
    import: "default",
  }),
)[0];

function rule(selector: string): string {
  const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return styles.match(new RegExp(`${escaped}\\s*\\{([\\s\\S]*?)\\}`, "u"))?.[1] ?? "";
}

describe("visual style contracts", () => {
  it("#165 keeps the shared design vocabulary in one token layer", () => {
    expect(styles).toContain("--font-size-body: 13px");
    expect(styles).toContain("--space-panel: 16px");
    expect(styles).toContain("--radius-pill: 999px");
    expect(styles).toContain("--icon-size-toolbar: 22px");
    expect(styles).toContain("--border-width-selected: 1.2px");
    expect(styles).toContain("--font-family-ui:");
  });

  it("#66 keeps the shared control, card, panel, and focus tokens", () => {
    expect(styles).toContain("--control-height: 24px");
    expect(styles).toContain("--card-radius: 8px");
    expect(styles).toContain("--panel-padding: 16px");
    expect(styles).toContain("--focus-ring: 2px solid #0a84ff");
  });

  it("#67 keeps inspector navigation fixed and uses Swift-matched spacing", () => {
    expect(rule(".inspector-header")).toContain("padding: 16px");
    expect(rule(".inspector-header")).toContain("background: var(--dialog-fill)");
    expect(rule(".inspector-content")).toContain("overflow: auto");
    expect(rule(".inspector-tabs button")).toContain("min-height: 28px");
    expect(rule(".inspector-tabs")).toContain("background: var(--control-fill)");
    expect(rule(".inspector-section-content")).toContain("padding: 0 4px 0 24px");
  });

  it("#68 keeps toolbar controls on the Swift icon and control sizes", () => {
    expect(rule(".toolbar-tool-icon")).toMatch(
      /width: var\(--icon-size-toolbar\);[\s\S]*height: var\(--icon-size-toolbar\)/u,
    );
    expect(rule(".toolbar-control-group > button")).toContain("min-height: var(--control-height)");
    expect(rule(".toolbar-icon-button")).toMatch(
      /min-width: var\(--control-height\) !important;[\s\S]*height: var\(--control-height\)/u,
    );
  });

  it("#69 keeps palette controls, two-column threshold, and button geometry", () => {
    expect(rule(".palette-select,\n.palette-input")).toContain("height: var(--control-compact-height)");
    const toolButton = rule(".tool-grid button");
    expect(toolButton).toContain("min-height: var(--palette-tool-height)");
    expect(toolButton).toContain("background: rgba(255, 255, 255, 0.36)");
    expect(toolButton).toContain("font-size: var(--font-size-section)");
    expect(toolButton).toContain("line-height: 15px");
    expect(styles).toContain("@container palette (min-width: 220px)");
    expect(styles).toContain("grid-template-columns: repeat(2, minmax(92px, 120px))");
  });

  it("#70 keeps annotation and constraint marker typography and state colors", () => {
    expect(canvasRendering).toContain('"600 10px -apple-system, BlinkMacSystemFont, sans-serif"');
    expect(canvasRendering).toContain('hovered ? "rgba(255,249,230,1)" : "rgba(12,96,88,.94)"');
    expect(canvasRendering).toContain('hovered ? "rgba(221,86,21,.90)" : "rgba(12,96,88,.94)"');
    expect(canvasRendering).toContain("selectedMeasurementAnnotationId");
    expect(canvasRendering).toContain("selectedConstraintId");
    expect(canvasRendering).toContain('"#dd5615"');
    expect(canvasRendering).toContain('"#0c6058"');
  });

  it("#164 gives selected geometry a non-color boundary cue", () => {
    expect(canvasRendering).toContain("context.setLineDash([5, 3])");
    expect(canvasRendering).toContain("context.setLineDash([]);");
  });

  it("#71 keeps the inline editor minimum width, padding, focus border, and background", () => {
    const inlineEditor = rule(".canvas-inline-text-editor");
    expect(inlineEditor).toContain("min-width: 180px");
    expect(inlineEditor).toContain("padding: 3px 4px");
    expect(inlineEditor).toContain("border: 1px solid var(--accent)");
    expect(inlineEditor).toContain("background: rgba(245, 245, 247, 0.94)");
  });

  it("#178 keeps the canvas operation guide in a reserved non-drawable band", () => {
    const guideBand = rule(".canvas-operation-guide-band");
    expect(guideBand).toMatch(/position: absolute;[\s\S]*top: 0;[\s\S]*height: 42px;/u);
    expect(guideBand).toContain("pointer-events: auto");
    const guide = rule(".canvas-operation-guide");
    expect(guide).toContain("pointer-events: none");
    expect(guide).toContain("max-width: calc(100% - 32px)");
  });

  it("#72 keeps the context menu on its native-sized spacing contract", () => {
    expect(rule(".canvas-context-menu")).toMatch(/min-width: 120px;[\s\S]*padding: 6px/u);
    expect(rule(".canvas-context-menu button")).toMatch(/min-height: 26px;[\s\S]*font-size: 12px/u);
  });

  it("#73 keeps value entry as a compact floating HUD", () => {
    const floatingDialog = rule(
      ".floating-value-backdrop .constraint-value-dialog,\n.derived-value-floating .constraint-value-dialog",
    );
    expect(floatingDialog).toContain("padding: 8px");
    expect(floatingDialog).toContain("border-radius: 6px");
    expect(floatingDialog).toContain("pointer-events: auto");
    expect(rule(".floating-value-backdrop .floating-constraint-value-dialog")).toContain("width: 190px");
    expect(rule(".floating-value-backdrop .floating-constraint-value-dialog.has-parameters")).toContain("width: 236px");
  });

  it("#74 keeps recovery and error banners on the shared card treatment", () => {
    expect(rule(".recovery-banner")).toMatch(
      /border-radius: var\(--card-radius\);[\s\S]*box-shadow: var\(--panel-shadow\);[\s\S]*padding: 12px/u,
    );
    expect(rule(".document-warning-banner")).toContain("padding: 12px");
    expect(rule(".app-error-banner > span")).toMatch(/font-size: 12px;[\s\S]*font-weight: 600/u);
  });

  it("#75 keeps paste placement as a compact capsule with selected state", () => {
    expect(rule(".paste-options")).toMatch(/min-height: 28px;[\s\S]*transform: translate\(-50%, -50%\)/u);
    expect(rule(".paste-options .paste-options-menu-button")).toContain("border-radius: 999px");
  });

  it("#76 keeps confirmation modal and destructive action visually distinct", () => {
    expect(rule(".constraint-value-backdrop")).toContain("background: rgba(0, 0, 0, 0.2)");
    expect(styles).toContain("button.destructive-action {\n  border-color: var(--destructive-action);");
    expect(styles).toContain("button.primary-action {\n  border-color: var(--accent);");
  });

  it("#77 keeps bottom summary and status bar dimensions and typography", () => {
    expect(rule(".statusbar")).toMatch(/min-height: 36px;[\s\S]*font-size: 11px/u);
    expect(rule(".bottom-workbench")).toMatch(/min-height: 84px;[\s\S]*padding: 8px 12px/u);
    expect(rule(".bottom-workbench-section h2")).toMatch(/font-size: 11px;[\s\S]*font-weight: 600/u);
  });

  it("#78 keeps minimum window and panel dimensions", () => {
    expect(rule("body")).toMatch(/min-width: 1024px;[\s\S]*min-height: 700px/u);
    expect(styles).toContain("--tool-palette-width: 176px");
    expect(styles).toContain("width: min(260px, calc(100% - 20px))");
  });

  it("#79 keeps the license window at the Swift size with scrolling content", () => {
    const licenseDialog = rule(".licenses-dialog");
    expect(licenseDialog).toContain("width: min(680px, calc(100vw - 32px))");
    expect(licenseDialog).toContain("min-width: min(620px, calc(100vw - 32px))");
    expect(licenseDialog).toContain("height: min(520px, calc(100vh - 32px))");
    expect(rule(".licenses-dialog-body")).toContain("overflow: auto");
  });
});
