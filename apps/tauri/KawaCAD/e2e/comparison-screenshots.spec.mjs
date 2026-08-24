import { mkdir } from "node:fs/promises";
import path from "node:path";
import { test as base, expect } from "@playwright/test";
import { CoreBridge } from "./core-bridge.mjs";
import { preparedPDF, recoveryCandidates } from "./comparison-screenshot-fixtures.mjs";

const appRoot = path.resolve(import.meta.dirname, "..");
const repoRoot = path.resolve(appRoot, "../../..");
const screenshotDirectory = process.env.KAWACAD_SCREENSHOT_OUTPUT_DIR
  ? path.resolve(process.env.KAWACAD_SCREENSHOT_OUTPUT_DIR)
  : path.join(repoRoot, "test-results/comparison-screenshots/screenshots");
const primary = process.platform === "darwin" ? "Meta" : "Control";
const displayPointsPerMillimeter = 72 / 25.4;
const comparisonLineStart = [-35 * displayPointsPerMillimeter, 0];
const comparisonLineEnd = [35 * displayPointsPerMillimeter, 0];
const inlineTextPositionOffset = [-10 * displayPointsPerMillimeter, 10 * displayPointsPerMillimeter];
const inlineTextHitOffset = [-9 * displayPointsPerMillimeter, 9 * displayPointsPerMillimeter];
const wideScreenshotViewport = { width: 1800, height: 900 };

const test = base.extend({
  screenshotScenario: async ({}, use) => {
    await use({ recoveryCandidates: [] });
  },
  core: [
    async ({ page, screenshotScenario }, use) => {
      const core = new CoreBridge();
      await core.start();
      await page.addInitScript(() => {
        window.localStorage.setItem("leather.layout.toolPanelWidth", "240");
      });
      await page.exposeFunction("__leatherE2EInvoke", (command, args) => {
        if (command === "recovery_candidates") return structuredClone(screenshotScenario.recoveryCandidates);
        if (command === "prepare_pdf_output") return structuredClone(preparedPDF);
        if (command === "direct_print_availability") return { status: "unavailable" };
        if (command === "discard_current_recovery_snapshot" || command === "reveal_recovery_snapshot") {
          return undefined;
        }
        return core.invoke(command, args);
      });
      await page.addInitScript({ path: new URL("./tauri-bridge-init.js", import.meta.url).pathname });
      await use(core);
      await core.close();
    },
    { auto: true },
  ],
  browserErrors: [
    async ({ page }, use) => {
      const errors = [];
      page.on("pageerror", (error) => errors.push(`pageerror: ${error.message}`));
      page.on("console", (message) => {
        if (message.type() === "error") errors.push(`console.error: ${message.text()}`);
      });
      await use(errors);
      expect(errors).toEqual([]);
    },
    { auto: true },
  ],
});

test.use({
  viewport: { width: 1280, height: 800 },
  deviceScaleFactor: 1,
  locale: "ja-JP",
  timezoneId: "Asia/Tokyo",
  colorScheme: "light",
});

test.beforeAll(async () => {
  await mkdir(screenshotDirectory, { recursive: true });
});

async function openWorkspace(page) {
  await page.goto("/");
  await expect(page.getByTestId("leather.workspace.canvas")).toBeVisible();
  await expect(page.getByTestId("leather.workspace.status-bar")).toContainText("0 図形");
  await expect(page.getByRole("status")).toContainText("ツールを選択して作図してください。");
  await page.evaluate(async () => {
    await document.fonts.ready;
  });
}

async function clickTool(page, name) {
  const palette = page.getByRole("complementary", { name: "ツールパレット" });
  await palette.getByRole("button", { name, exact: true }).click();
}

async function clickModelPoint(page, xMm, yMm) {
  const canvas = page.getByTestId("leather.workspace.canvas");
  const box = await canvas.boundingBox();
  if (!box) throw new Error("CAD canvas has no layout box");
  await page.mouse.click(box.x + box.width / 2 + xMm, box.y + box.height / 2 - yMm);
}

async function rightClickModelPoint(page, xMm, yMm) {
  const canvas = page.getByTestId("leather.workspace.canvas");
  const box = await canvas.boundingBox();
  if (!box) throw new Error("CAD canvas has no layout box");
  await page.mouse.click(box.x + box.width / 2 + xMm, box.y + box.height / 2 - yMm, { button: "right" });
}

async function drawLine(page, start, end) {
  const statusBar = page.getByTestId("leather.workspace.status-bar");
  await clickTool(page, "線分");
  await expect(statusBar).toContainText("線分:");
  await clickModelPoint(page, ...start);
  await expect(statusBar).toContainText("線分の次の点");
  await clickModelPoint(page, ...end);
  await expect(statusBar).toContainText("1 図形");
}

async function selectOnlyEntity(page) {
  await clickTool(page, "選択");
  await page.keyboard.press(`${primary}+a`);
  await expect(page.locator(".selection-entity-editor")).toBeVisible();
}

async function saveScreenshot(page, fileName, options = {}) {
  await page.screenshot({
    path: path.join(screenshotDirectory, fileName),
    type: "jpeg",
    quality: 80,
    animations: "disabled",
    caret: "hide",
    scale: "css",
    ...options,
  });
}

async function setViewportAndNotify(page, viewport) {
  await page.setViewportSize(viewport);
  await page.evaluate(() => window.dispatchEvent(new Event("resize")));
}

const screenshotThemes = [
  { id: "light", colorScheme: "light" },
  { id: "dark", colorScheme: "dark" },
];
const screenshotLayouts = [
  { id: "compact", viewport: { width: 1024, height: 700 } },
  { id: "regular", viewport: { width: 1280, height: 800 } },
  { id: "wide", viewport: { width: 1600, height: 900 } },
];

test.describe("Swift and Tauri visual comparison", () => {
  for (const theme of screenshotThemes) {
    test(`captures representative ${theme.id} theme states at every layout width`, async ({ page, core }) => {
      await page.emulateMedia({ colorScheme: theme.colorScheme });

      for (const layout of screenshotLayouts) {
        await core.invoke("new_document", { name: "Untitled" });
        await setViewportAndNotify(page, layout.viewport);
        await openWorkspace(page);
        await expect(page.locator(`.app-shell.layout-${layout.id}`)).toBeVisible();
        await saveScreenshot(page, `tauri-${theme.id}-${layout.id}-empty.jpg`);

        if (layout.id === "compact") {
          await page.getByTestId("leather.toolbar.tools").click();
          await expect(page.getByRole("complementary", { name: "ツール", exact: true })).toBeVisible();
          await saveScreenshot(page, `tauri-${theme.id}-${layout.id}-tools-drawer.jpg`);

          await page.getByTestId("leather.toolbar.inspector").click();
          await expect(page.getByRole("complementary", { name: "インスペクタ" })).toBeVisible();
          await saveScreenshot(page, `tauri-${theme.id}-${layout.id}-inspector-drawer.jpg`);
          await page.keyboard.press("Escape");
        } else if (layout.id === "regular") {
          const inspector = page.getByRole("complementary", { name: "インスペクタ" });
          if ((await inspector.count()) > 0) {
            await page.getByTestId("leather.toolbar.inspector").click();
            await expect(inspector).toHaveCount(0);
          }
          await drawLine(page, comparisonLineStart, comparisonLineEnd);
          await page.getByTestId("leather.toolbar.inspector").click();
          await expect(inspector).toBeVisible();
          await selectOnlyEntity(page);
          await saveScreenshot(page, `tauri-${theme.id}-${layout.id}-selected-inspector.jpg`);
        } else {
          await page.evaluate(() => {
            window.dispatchEvent(new CustomEvent("kawa-cad-menu", { detail: "exportPDF" }));
          });
          await expect(page.getByRole("dialog", { name: "PDF" })).toBeVisible();
          await saveScreenshot(page, `tauri-${theme.id}-${layout.id}-dialog.jpg`);
        }
      }
    });
  }

  test("captures the initial workspace and its detailed summary", async ({ page }) => {
    await openWorkspace(page);
    await saveScreenshot(page, "tauri-browser-initial.jpg");

    await page.getByRole("button", { name: "詳細ツールを表示", exact: true }).click();
    await page.getByRole("button", { name: "サマリーを表示", exact: true }).click();
    await expect(page.getByRole("region", { name: "サマリー" })).toBeVisible();
    await saveScreenshot(page, "tauri-detailed-tools-summary.jpg");
  });

  test("captures the wide toolbar and each display aid toggle", async ({ page }) => {
    await page.addInitScript(() => {
      window.localStorage.setItem("leather.layout.toolPanelWidth", "260");
    });
    await setViewportAndNotify(page, wideScreenshotViewport);
    await openWorkspace(page);
    await expect(page.locator(".app-shell.layout-wide")).toBeVisible();

    const grid = page.getByTestId("leather.toolbar.grid");
    const a4Reference = page.getByTestId("leather.toolbar.a4-reference");
    const portrait = page.getByTestId("leather.toolbar.orientation.portrait");
    const gridSnap = page.getByTestId("leather.toolbar.grid-snap");
    const pointSnap = page.getByTestId("leather.toolbar.point-snap");
    for (const toggle of [grid, a4Reference, portrait, gridSnap, pointSnap]) {
      await expect(toggle).toBeVisible();
    }
    await saveScreenshot(page, "tauri-wide-toolbar.jpg");

    await grid.click();
    await expect(grid).toHaveAttribute("aria-pressed", "false");
    await saveScreenshot(page, "tauri-wide-grid-off.jpg");
    await grid.click();
    await expect(grid).toHaveAttribute("aria-pressed", "true");

    await a4Reference.click();
    await expect(a4Reference).toHaveAttribute("aria-pressed", "false");
    await saveScreenshot(page, "tauri-wide-a4-reference-off.jpg");
    await a4Reference.click();
    await expect(a4Reference).toHaveAttribute("aria-pressed", "true");

    await portrait.click();
    const landscape = page.getByTestId("leather.toolbar.orientation.landscape");
    await expect(landscape).toBeVisible();
    await expect(landscape).toHaveAttribute("aria-pressed", "true");
    await saveScreenshot(page, "tauri-wide-a4-landscape.jpg");
    await landscape.click();
    await expect(page.getByTestId("leather.toolbar.orientation.portrait")).toBeVisible();

    await gridSnap.click();
    await expect(gridSnap).toHaveAttribute("aria-pressed", "false");
    await saveScreenshot(page, "tauri-wide-grid-snap-off.jpg");
    await gridSnap.click();
    await expect(gridSnap).toHaveAttribute("aria-pressed", "true");

    await pointSnap.click();
    await expect(pointSnap).toHaveAttribute("aria-pressed", "false");
    await saveScreenshot(page, "tauri-wide-point-snap-off.jpg");
  });

  test("captures constraints, context actions, and paste placement", async ({ page }) => {
    await openWorkspace(page);
    await drawLine(page, [-120, 0], [60, 0]);
    await page.keyboard.press(`${primary}+a`);

    await clickTool(page, "線分長");
    await clickModelPoint(page, 0, 0);
    const constraintDialog = page.getByRole("dialog", { name: "線分長" });
    await expect(constraintDialog.getByRole("textbox", { name: "値 (mm)" })).toHaveValue("60.00");
    await saveScreenshot(page, "tauri-constraint-hud.jpg");
    await constraintDialog.getByRole("button", { name: "キャンセル", exact: true }).click();

    await clickTool(page, "選択");
    await rightClickModelPoint(page, 0, 0);
    const contextMenu = page.getByRole("menu");
    await expect(contextMenu.getByRole("menuitem", { name: "削除", exact: true })).toBeVisible();
    await saveScreenshot(page, "tauri-context-menu.jpg");
    await clickModelPoint(page, -150, 150);
    await expect(contextMenu).toHaveCount(0);

    await page.keyboard.press(`${primary}+a`);
    await page.keyboard.press(`${primary}+c`);
    await page.keyboard.press(`${primary}+v`);
    const pasteOptions = page.getByRole("group", { name: "ペーストオプション" });
    await expect(pasteOptions).toBeVisible();
    await expect(page.getByTestId("leather.workspace.status-bar")).toContainText("2 図形");
    await saveScreenshot(page, "tauri-paste-options.jpg");
    await page.keyboard.press("Escape");
    await expect(pasteOptions).toHaveCount(0);
  });

  test("captures the free-text default", async ({ page }) => {
    await openWorkspace(page);
    await clickTool(page, "テキスト");
    await clickModelPoint(page, ...inlineTextPositionOffset);
    const inlineText = page.getByRole("textbox", { name: "テキストを編集" });
    await expect(inlineText).toHaveValue("注記");
    await inlineText.press("Enter");
    await expect(inlineText).toHaveCount(0);
    await saveScreenshot(page, "tauri-free-text-default.jpg");
  });

  test("captures inline text editing, compact drawers, and licenses", async ({ page, core }) => {
    await openWorkspace(page);
    await clickTool(page, "テキスト");
    await clickModelPoint(page, ...inlineTextPositionOffset);
    const initialEditor = page.getByRole("textbox", { name: "テキストを編集" });
    await expect(initialEditor).toHaveValue("注記");
    await initialEditor.press("Enter");
    await expect.poll(async () => (await core.invoke("document_state")).freeTexts).toHaveLength(1);

    await clickTool(page, "選択");
    await rightClickModelPoint(page, ...inlineTextHitOffset);
    await page.getByRole("menuitem", { name: "テキストを編集", exact: true }).click();
    const inlineText = page.getByRole("textbox", { name: "テキストを編集" });
    await expect(inlineText).toHaveValue("注記");
    await expect(page.getByRole("spinbutton", { name: "フォントサイズ (mm)" })).toHaveValue("4.00");
    await saveScreenshot(page, "tauri-inline-text-editor.jpg");
    await inlineText.press("Enter");
    await expect(inlineText).toHaveCount(0);

    await setViewportAndNotify(page, { width: 1280, height: 800 });
    await expect.poll(() => page.locator(".app-shell").getAttribute("class")).toContain("layout-regular");
    await setViewportAndNotify(page, { width: 1024, height: 700 });
    await expect.poll(() => page.locator(".app-shell").getAttribute("class")).toContain("layout-compact");
    await page.getByTestId("leather.toolbar.tools").click();
    await expect(page.getByRole("complementary", { name: "ツール", exact: true })).toBeVisible();
    await saveScreenshot(page, "tauri-compact-tools-drawer.jpg");

    await page.getByTestId("leather.toolbar.inspector").click();
    await expect(page.getByRole("complementary", { name: "インスペクタ" })).toBeVisible();
    await saveScreenshot(page, "tauri-compact-inspector-drawer.jpg");

    await setViewportAndNotify(page, { width: 1280, height: 800 });
    await expect(page.locator(".app-shell.layout-regular")).toBeVisible();
    await page.evaluate(() => {
      window.dispatchEvent(new CustomEvent("kawa-cad-menu", { detail: "openLicenses" }));
    });
    const licenses = page.getByRole("dialog", { name: "OSSライセンス" });
    await expect(licenses).toContainText("@tauri-apps/api");
    await saveScreenshot(page, "tauri-oss-licenses.jpg");
  });

  test("captures layer deletion confirmation and verifies the post-delete state", async ({ page, core }) => {
    await openWorkspace(page);
    await page.getByRole("tab", { name: "レイヤー", exact: true }).click();
    await page.getByRole("button", { name: "レイヤーを追加", exact: true }).click();

    const addDialog = page.getByRole("dialog", { name: "レイヤーを追加" });
    await addDialog.getByLabel("レイヤー名").fill("検証レイヤー");
    await addDialog.getByRole("button", { name: "適用", exact: true }).click();

    const createdState = await core.invoke("document_state");
    const defaultLayer = createdState.layers.find((layer) => layer.id === "layer:cut-line");
    const addedLayer = createdState.layers.find((layer) => layer.name === "検証レイヤー");
    expect(defaultLayer).toBeDefined();
    expect(addedLayer).toBeDefined();

    const drawingLayer = page.getByTestId("leather.toolbar.drawing-layer").locator("select");
    await drawingLayer.selectOption(addedLayer.id, { force: true });
    await drawLine(page, [-45, 30], [15, 10]);
    await drawingLayer.selectOption(defaultLayer.id, { force: true });

    const layerCard = page.locator(".inspector-disclosure").filter({ hasText: "検証レイヤー" });
    await expect(layerCard).toHaveCount(1);
    await layerCard.locator(".inspector-disclosure-summary").click();
    await layerCard.getByRole("button", { name: "削除", exact: true }).click();

    const alert = page.getByRole("alertdialog", { name: "レイヤー削除の確認" });
    await expect(alert).toContainText("1件の図形または派生要素");
    await saveScreenshot(page, "tauri-layer-deletion-confirmation.jpg");

    await alert.getByRole("button", { name: "削除", exact: true }).click();
    await expect(alert).toHaveCount(0);
    const deletedState = await core.invoke("document_state");
    expect(deletedState.layers.some((layer) => layer.id === addedLayer.id)).toBe(false);
    expect(deletedState.entities).toHaveLength(1);
    expect(deletedState.entities[0].layerId).toBe(defaultLayer.id);
  });

  test("captures each populated inspector management tab", async ({ page, core }) => {
    await setViewportAndNotify(page, wideScreenshotViewport);
    await openWorkspace(page);

    await page.getByRole("tab", { name: "レイヤー", exact: true }).click();
    await page.getByRole("button", { name: "レイヤーを追加", exact: true }).click();
    let dialog = page.getByRole("dialog", { name: "レイヤーを追加" });
    await dialog.getByLabel("レイヤー名").fill("検証レイヤー");
    await dialog.getByRole("button", { name: "適用", exact: true }).click();
    let disclosure = page.locator(".inspector-disclosure").filter({ hasText: "検証レイヤー" }).first();
    await disclosure.locator(".inspector-disclosure-summary").click();
    await expect(disclosure.locator(".inspector-editor-surface")).toBeVisible();
    await saveScreenshot(page, "tauri-inspector-layers.jpg");

    await page.getByRole("tab", { name: "共有スタイル", exact: true }).click();
    const firstStyle = (await core.invoke("document_state")).sharedStyles[0];
    disclosure = page.locator(".inspector-disclosure").filter({ hasText: firstStyle.name }).first();
    await disclosure.locator(".inspector-disclosure-summary").click();
    await expect(disclosure.getByRole("textbox", { name: `${firstStyle.name} の名前`, exact: true })).toBeVisible();
    await saveScreenshot(page, "tauri-inspector-shared-styles.jpg");

    await page.getByRole("tab", { name: "パラメータ", exact: true }).click();
    await page.getByRole("button", { name: "追加", exact: true }).click();
    dialog = page.getByRole("dialog");
    await dialog.getByLabel("パラメータ名").fill("幅");
    await dialog.getByLabel("値 (mm)").fill("25");
    await dialog.getByRole("button", { name: "適用", exact: true }).click();
    disclosure = page.locator(".inspector-disclosure").filter({ hasText: "幅" }).first();
    await disclosure.locator(".inspector-disclosure-summary").click();
    await expect(disclosure.locator(".parameter-editor")).toBeVisible();
    await saveScreenshot(page, "tauri-inspector-parameters.jpg");

    for (const [start, end] of [
      [
        [-40, -20],
        [40, -20],
      ],
      [
        [40, -20],
        [0, 40],
      ],
      [
        [0, 40],
        [-40, -20],
      ],
    ]) {
      await clickTool(page, "線分");
      await clickModelPoint(page, ...start);
      await clickModelPoint(page, ...end);
    }
    await expect(page.getByTestId("leather.workspace.status-bar")).toContainText("3 図形");
    await page.keyboard.press(`${primary}+a`);
    await page.getByRole("tab", { name: "パーツ", exact: true }).click();
    await page.getByRole("button", { name: "選択図形からパーツを作成", exact: true }).click();
    dialog = page.getByRole("dialog");
    await dialog.getByLabel("パーツ名").fill("本体");
    await dialog.getByRole("button", { name: "適用", exact: true }).click();
    await expect.poll(async () => (await core.invoke("document_state")).parts).toHaveLength(1);
    await clickTool(page, "選択");
    await page.getByRole("tab", { name: "選択", exact: true }).click();
    await page.getByRole("tab", { name: "パーツ", exact: true }).click();
    disclosure = page.locator(".inspector-disclosure").filter({ hasText: "本体" }).first();
    await disclosure.locator(".inspector-disclosure-summary").click();
    await expect(disclosure.locator(".part-editor")).toBeVisible();
    await saveScreenshot(page, "tauri-inspector-parts.jpg");
  });

  const selectionScenarios = [
    {
      name: "line",
      kind: "線分",
      draw: async (page) => drawLine(page, [-85, 0], [85, 0]),
    },
    {
      name: "circle",
      kind: "円",
      draw: async (page) => {
        await clickTool(page, "円");
        await clickModelPoint(page, 0, 0);
        await clickModelPoint(page, 70, 0);
      },
    },
    {
      name: "arc",
      kind: "円弧",
      draw: async (page) => {
        await clickTool(page, "円弧");
        await clickModelPoint(page, 0, 0);
        await clickModelPoint(page, 70, 0);
        await clickModelPoint(page, 0, 70);
      },
    },
    {
      name: "point",
      kind: "点",
      detailed: true,
      draw: async (page) => {
        await clickTool(page, "点");
        await clickModelPoint(page, 0, 0);
      },
    },
    {
      name: "center-line",
      kind: "中心線",
      detailed: true,
      draw: async (page) => {
        await clickTool(page, "中心線");
        await clickModelPoint(page, -85, 0);
        await clickModelPoint(page, 85, 0);
      },
    },
  ];

  for (const scenario of selectionScenarios) {
    test(`captures the selected ${scenario.name} inspector`, async ({ page }) => {
      await setViewportAndNotify(page, wideScreenshotViewport);
      await openWorkspace(page);
      if (scenario.detailed) await page.getByRole("button", { name: "詳細ツールを表示", exact: true }).click();
      await scenario.draw(page);
      if (scenario.detailed) await page.getByRole("button", { name: "基本ツールだけを表示", exact: true }).click();
      await selectOnlyEntity(page);
      await expect(page.locator(".selection-entity-editor")).toContainText(scenario.kind);
      await saveScreenshot(page, `tauri-selection-${scenario.name}.jpg`);
    });
  }

  test("captures recoverable and broken recovery candidates", async ({ page, screenshotScenario }) => {
    screenshotScenario.recoveryCandidates = recoveryCandidates;
    await openWorkspace(page);

    const dialog = page.getByRole("dialog", { name: "復旧できる編集中データがあります" });
    await expect(dialog).toContainText("カードケース");
    await expect(dialog).toContainText("破損した復旧候補");
    await expect(dialog.getByRole("button", { name: "復旧して開く" })).toHaveCount(2);
    await expect(dialog.getByRole("button", { name: "復旧して開く" }).last()).toBeDisabled();
    await saveScreenshot(page, "tauri-recovery-candidates.jpg");
  });

  test("captures PDF settings, warning action, and final preview", async ({ page }) => {
    await openWorkspace(page);
    await page.evaluate(() => {
      window.dispatchEvent(new CustomEvent("kawa-cad-menu", { detail: "exportPDF" }));
    });

    const dialog = page.getByRole("dialog", { name: "PDF" });
    await expect(dialog).toContainText("1ページ");
    await expect(dialog.getByRole("region", { name: "出力警告" })).toContainText("ページ境界をまたぐ形状があります。");
    await expect(dialog.getByRole("img", { name: "PDF 1ページ目" })).toBeVisible();
    await expect(dialog.getByRole("button", { name: "警告を確認して保存へ進む", exact: true })).toBeEnabled();
    await saveScreenshot(page, "tauri-pdf-output-settings.jpg");
  });
});
