import { test as base, expect } from "@playwright/test";
import { CoreBridge } from "./core-bridge.mjs";

const test = base.extend({
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
  core: [
    async ({ page }, use) => {
      const core = new CoreBridge();
      await core.start();
      await page.exposeFunction("__leatherE2EInvoke", (command, args) => core.invoke(command, args));
      await page.addInitScript({ path: new URL("./tauri-bridge-init.js", import.meta.url).pathname });
      await use(core);
      await core.close();
    },
    { auto: true },
  ],
});

const primary = process.platform === "darwin" ? "Meta" : "Control";

async function openWorkspace(page) {
  await page.goto("/");
  await expect(page.getByTestId("leather.workspace.canvas")).toBeVisible();
  await expect(page.getByTestId("leather.workspace.status-bar")).toContainText("0 図形");
}

async function clickTool(page, name) {
  await page.getByRole("button", { name, exact: true }).click();
}

async function clickOverflowAction(page, name) {
  await page.getByTestId("leather.toolbar.overflow").click();
  await page.getByRole("menuitem", { name, exact: true }).click();
}

async function clickModelPoint(page, xMm, yMm) {
  const canvas = page.getByTestId("leather.workspace.canvas");
  const box = await canvas.boundingBox();
  if (!box) throw new Error("CAD canvas has no layout box");
  await page.mouse.click(box.x + box.width / 2 + xMm, box.y + box.height / 2 - yMm);
}

async function moveModelPoint(page, xMm, yMm) {
  const canvas = page.getByTestId("leather.workspace.canvas");
  const box = await canvas.boundingBox();
  if (!box) throw new Error("CAD canvas has no layout box");
  await page.mouse.move(box.x + box.width / 2 + xMm, box.y + box.height / 2 - yMm);
}

async function dragModelPoint(page, start, end) {
  await moveModelPoint(page, ...start);
  await page.mouse.down();
  await moveModelPoint(page, ...end);
}

async function drawLine(page, start, end) {
  await clickTool(page, "線分");
  await clickModelPoint(page, ...start);
  await clickModelPoint(page, ...end);
  await expect(page.getByRole("status")).toContainText("線分を作成しました。");
}

async function acceptTextDialog(page, value) {
  const dialog = page.getByRole("dialog");
  await expect(dialog).toBeVisible();
  const field = dialog.locator("input").first();
  await field.fill(value);
  await dialog.getByRole("button", { name: "適用", exact: true }).click();
}

test.describe("Tauri React workspace through the real Core process", () => {
  // 起動直後にCore接続済みのドキュメントと、主要な作図画面の操作入口が表示されることを検証する。
  test("boots with a Core-backed document and exposes the primary workspace controls", async ({ page }) => {
    await openWorkspace(page);

    await expect(page).toHaveTitle(/無題プロジェクト/);
    await expect(page.getByRole("main")).toHaveAttribute("aria-label", /無題プロジェクト/);
    await expect(page.getByRole("application", { name: "型紙作図キャンバス" })).toBeVisible();
    await expect(page.getByRole("complementary", { name: "ツールパレット" })).toBeVisible();
    await expect(page.getByRole("complementary", { name: "インスペクタ" })).toBeVisible();
    await expect(page.getByTestId("leather.toolbar.grid")).toHaveAttribute("aria-pressed", "true");
    await expect(page.getByTestId("leather.toolbar.a4-reference")).toHaveAttribute("aria-pressed", "true");
    await expect(page.getByText("未評価", { exact: true })).toBeVisible();
  });

  // 実際に割り当てられた幅で表示密度を切り替え、代表的な画面幅で要素が画面外へはみ出さないことを検証する。
  test("keeps the responsive toolbar inside the window at every supported width", async ({ page }) => {
    for (const width of [1800, 1640, 1600, 1520, 1500, 1480, 1320, 1280, 1100, 1050, 1024, 960]) {
      await page.setViewportSize({ width, height: 800 });
      await openWorkspace(page);
      const toolbar = page.getByRole("navigation", { name: "CAD ツールバー" });
      const geometry = await toolbar.evaluate((element) => {
        const toolbarRect = element.getBoundingClientRect();
        const items = [...element.querySelectorAll("button, select, .toolbar-layer, .constraint-badge")]
          .filter((item) => {
            const style = window.getComputedStyle(item);
            const rect = item.getBoundingClientRect();
            return style.display !== "none" && rect.width > 0;
          })
          .map((item) => {
            const rect = item.getBoundingClientRect();
            return {
              label: item.getAttribute("aria-label") ?? item.textContent?.trim() ?? item.tagName,
              left: rect.left,
              right: rect.right,
            };
          });
        const overflowing = items
          .filter((item) => item.left < toolbarRect.left - 1 || item.right > toolbarRect.right + 1)
          .map((item) => item.label);
        const clipped = [...element.querySelectorAll("button")]
          .filter((item) => {
            const style = window.getComputedStyle(item);
            return style.display !== "none" && item.scrollWidth > item.clientWidth + 1;
          })
          .map((item) => item.getAttribute("aria-label") ?? item.textContent?.trim() ?? item.tagName);
        return { left: toolbarRect.left, right: toolbarRect.right, overflowing, clipped, items };
      });

      expect(geometry.left).toBeGreaterThanOrEqual(-1);
      expect(geometry.right).toBeLessThanOrEqual(width + 1);
      expect(geometry.overflowing, `ツールバーが${width}px幅からはみ出しています: ${JSON.stringify(geometry)}`).toEqual(
        [],
      );
      expect(geometry.clipped, `ツールバーの要素が${width}px幅で欠けています: ${JSON.stringify(geometry)}`).toEqual([]);
      await expect(page.getByTestId("leather.toolbar.tools")).toBeVisible();
    }
  });

  // 点と線分の作図、全選択、複製、Undo/RedoがCoreの履歴状態と一貫して動作することを検証する。
  test("creates basic geometry, selects it, duplicates it, and keeps undo/redo coherent", async ({ page, core }) => {
    await openWorkspace(page);
    await clickTool(page, "点");
    await clickModelPoint(page, -40, 30);
    await drawLine(page, [-50, -30], [50, -30]);

    await expect(page.getByTestId("leather.workspace.status-bar")).toContainText("2 図形");
    await page.keyboard.press(`${primary}+a`);
    await expect(page.getByTestId("leather.workspace.status-bar")).toContainText("2 選択");

    await page.keyboard.press(`${primary}+d`);
    await expect(page.getByTestId("leather.workspace.status-bar")).toContainText("4 図形");
    await expect((await core.invoke("document_state")).history.canUndo).toBe(true);

    await page.keyboard.press(`${primary}+z`);
    await expect(page.getByTestId("leather.workspace.status-bar")).toContainText("2 図形");
    await page.keyboard.press(`${primary}+Shift+z`);
    await expect(page.getByTestId("leather.workspace.status-bar")).toContainText("4 図形");
    await expect((await core.invoke("document_state")).history.canRedo).toBe(false);
  });

  // 円・円弧・丸穴・自由テキストの各作図ツールが、Tauriのコマンド境界を越えてCoreへ反映されることを検証する。
  test("runs the special drawing tools through the Tauri command boundary", async ({ page, core }) => {
    await openWorkspace(page);

    await clickTool(page, "円");
    await clickModelPoint(page, -45, 20);
    await clickModelPoint(page, -25, 20);

    await clickTool(page, "円弧");
    await clickModelPoint(page, 35, 20);
    await clickModelPoint(page, 55, 20);
    await clickModelPoint(page, 35, 40);

    await clickTool(page, "丸穴");
    await clickModelPoint(page, 0, 0);

    await clickTool(page, "テキスト");
    await clickModelPoint(page, -20, -45);
    await acceptTextDialog(page, "E2E note");

    const state = await core.invoke("document_state");
    expect(state.entities).toHaveLength(3);
    expect(state.roundHoles).toHaveLength(1);
    expect(state.freeTexts).toHaveLength(1);
    expect(state.freeTexts[0].content).toBe("E2E note");
  });

  // コピー後の貼り付け位置UIを表示し、Escapeで一時的な貼り付け状態だけを安全に解除できることを検証する。
  test("copies, pastes, and dismisses the paste-placement affordance", async ({ page }) => {
    await openWorkspace(page);
    await clickTool(page, "点");
    await clickModelPoint(page, 0, 0);
    await expect(page.getByTestId("leather.workspace.status-bar")).toContainText("1 図形");
    await page.keyboard.press(`${primary}+a`);
    await page.keyboard.press(`${primary}+c`);
    await expect(page.getByRole("status")).toContainText("1 件の図形をコピーしました。");

    await page.keyboard.press(`${primary}+v`);
    await expect(page.getByRole("group", { name: "貼り付け位置" })).toBeVisible();
    await expect(page.getByTestId("leather.workspace.status-bar")).toContainText("2 図形");
    await page.keyboard.press("Escape");
    await expect(page.getByRole("group", { name: "貼り付け位置" })).toHaveCount(0);
    await expect(page.getByRole("status")).toContainText("貼り付け位置の選択を閉じました。");
  });

  // 保存済みドキュメントの再読み込みと新規プロジェクト作成で、Coreの内容とファイル契約が壊れないことを検証する。
  test("saves, reloads, and opens a new project without losing the Core document contract", async ({ page, core }) => {
    await openWorkspace(page);
    await clickTool(page, "点");
    await clickModelPoint(page, 10, 10);
    await page.keyboard.press(`${primary}+s`);
    await expect(page.getByRole("status")).toContainText("プロジェクトを保存しました。");

    await clickModelPoint(page, 35, 35);
    await expect(page.getByTestId("leather.workspace.status-bar")).toContainText("2 図形");
    await page.keyboard.press(`${primary}+r`);
    await expect(page.getByTestId("leather.workspace.status-bar")).toContainText("1 図形");
    await expect((await core.invoke("document_state")).persistence.hasPath).toBe(true);

    await page.keyboard.press(`${primary}+n`);
    await acceptTextDialog(page, "New E2E project");
    await expect(page.getByRole("textbox", { name: "プロジェクト名" })).toHaveValue("New E2E project");
    await expect(page.getByTestId("leather.workspace.status-bar")).toContainText("0 図形");
  });

  // 出力プレビューへの切り替え、A4向き変更、編集表示への復帰が画面表示とCore状態の両方に反映されることを検証する。
  test("switches to output preview and keeps page feedback visible", async ({ page, core }) => {
    await openWorkspace(page);
    await drawLine(page, [-40, 0], [40, 0]);
    await page.getByRole("button", { name: "出力プレビュー", exact: true }).click();

    await expect(page.getByTestId("leather.workspace.status-bar")).toContainText("出力プレビュー: 1 ページ");
    await expect(page.getByText("出力プレビュー", { exact: true }).last()).toBeVisible();
    await expect((await core.invoke("document_state")).viewMode).toBe("outputPreview");
    await page.getByTestId("leather.toolbar.overflow").click();
    await page.getByRole("menuitem", { name: "A4横向き", exact: true }).click();
    await expect(page.getByTestId("leather.toolbar.orientation.landscape")).toHaveAttribute("aria-pressed", "true");
    await expect.poll(() => core.orientation).toBe("landscape");
    await page.evaluate(() => {
      window.dispatchEvent(new CustomEvent("kawa-cad-menu", { detail: "toggleA4Orientation" }));
    });
    await expect(page.getByTestId("leather.toolbar.orientation.portrait")).toHaveAttribute("aria-pressed", "false");
    await expect.poll(() => core.orientation).toBe("portrait");

    await page.getByRole("button", { name: "編集表示", exact: true }).click();
    await expect(page.getByTestId("leather.workspace.status-bar")).not.toContainText("出力プレビュー:");
    await expect((await core.invoke("document_state")).viewMode).toBe("editDisplay");
  });

  // 無効な拘束値を入力した場合に確定できず、Coreドキュメントが変更されないことを検証する。
  test("rejects invalid constraint input without changing the document", async ({ page, core }) => {
    await openWorkspace(page);
    await drawLine(page, [-40, 0], [40, 0]);
    await page.keyboard.press(`${primary}+a`);
    await clickTool(page, "線分長");
    await clickModelPoint(page, 0, 0);
    await expect(page.getByRole("dialog")).toBeVisible();
    const before = await core.invoke("document_state");
    const value = page.getByRole("dialog").locator("input").first();
    await value.fill("0");
    await expect(page.getByRole("dialog").getByRole("button", { name: "確定", exact: true })).toBeDisabled();
    await expect(page.getByRole("dialog")).toBeVisible();
    expect((await core.invoke("document_state")).entities).toEqual(before.entities);
    await page.keyboard.press("Escape");
    await expect(page.getByRole("dialog")).toHaveCount(0);
  });

  // 丸穴直径に0を入力した場合、直前の有効値を流用せず丸穴を作成しないことを検証する。
  test("does not create a round hole from a non-positive diameter", async ({ page, core }) => {
    await openWorkspace(page);
    const diameter = page.getByRole("textbox", { name: "丸穴の直径 (mm)" });
    await diameter.fill("0");
    await clickTool(page, "丸穴");
    await clickModelPoint(page, 0, 0);

    await expect(page.getByRole("status")).toContainText("丸穴の直径には正の有限値を入力してください。");
    expect((await core.invoke("document_state")).roundHoles).toHaveLength(0);
  });

  // プロジェクト名の空入力を拒否し、正しい名前を再入力するとCoreのドキュメント名へ反映されることを検証する。
  test("rejects an empty project name and accepts the corrected name", async ({ page, core }) => {
    await openWorkspace(page);
    const projectName = page.getByRole("textbox", { name: "プロジェクト名" });

    await projectName.fill("   ");
    await projectName.blur();
    await expect(projectName).toHaveAttribute("aria-invalid", "true");
    await expect(page.getByText("プロジェクト名を入力してください。", { exact: true })).toBeVisible();

    await projectName.fill("Renamed E2E project");
    await projectName.blur();
    await expect(projectName).toHaveAttribute("aria-invalid", "false");
    await expect.poll(async () => (await core.invoke("document_state")).snapshot.name).toBe("Renamed E2E project");
  });

  // グリッド・A4・用紙向き・スナップの切り替えとズーム操作が、現在のUI状態に反映されることを検証する。
  test("toggles display aids and zoom without changing document geometry", async ({ page, core }) => {
    await openWorkspace(page);
    const stateBefore = await core.invoke("document_state");

    await clickOverflowAction(page, "グリッド");
    await clickOverflowAction(page, "A4");
    await clickOverflowAction(page, "A4横向き");
    await clickOverflowAction(page, "グリッドスナップ");
    await clickOverflowAction(page, "点スナップ");
    await clickOverflowAction(page, "拡大");

    await expect(page.getByTestId("leather.toolbar.grid")).toHaveAttribute("aria-pressed", "false");
    await expect(page.getByTestId("leather.toolbar.a4-reference")).toHaveAttribute("aria-pressed", "false");
    await expect(page.getByTestId("leather.toolbar.orientation.landscape")).toHaveAttribute("aria-pressed", "true");
    await expect(page.getByTestId("leather.toolbar.grid-snap")).toHaveAttribute("aria-pressed", "false");
    await expect(page.getByTestId("leather.toolbar.point-snap")).toHaveAttribute("aria-pressed", "false");
    await expect(page.getByTestId("leather.workspace.status-bar")).toContainText("125%");
    expect((await core.invoke("document_state")).entities).toEqual(stateBefore.entities);
  });

  // パラメータを追加し、線分長拘束の値として参照させた結果がCoreの拘束に保存されることを検証する。
  test("creates a parameter-backed segment length constraint", async ({ page, core }) => {
    await openWorkspace(page);
    await page.getByRole("tab", { name: "パラメータ", exact: true }).click();
    await page.getByRole("button", { name: "追加", exact: true }).click();

    const parameterDialog = page.getByRole("dialog");
    await parameterDialog.getByLabel("パラメータ名").fill("幅");
    await parameterDialog.getByLabel("値 (mm)").fill("25");
    await parameterDialog.getByRole("button", { name: "適用", exact: true }).click();
    await expect.poll(async () => (await core.invoke("document_state")).parameters).toHaveLength(1);
    const parameter = (await core.invoke("document_state")).parameters[0];

    await drawLine(page, [-40, 0], [40, 0]);
    await clickTool(page, "線分長");
    await clickModelPoint(page, 0, 0);
    const constraintDialog = page.getByRole("dialog");
    await constraintDialog.getByRole("button", { name: "パラメータ", exact: true }).click();
    await constraintDialog.getByRole("combobox", { name: "パラメータ", exact: true }).selectOption(parameter.id);
    await constraintDialog.getByRole("button", { name: "確定", exact: true }).click();

    await expect
      .poll(async () =>
        (await core.invoke("document_state")).constraints.filter((constraint) => constraint.kind === "segmentLength"),
      )
      .toHaveLength(1);
    const state = await core.invoke("document_state");
    expect(state.constraints.find((constraint) => constraint.kind === "segmentLength").value).toEqual({
      parameter: parameter.id,
    });
  });

  // レイヤーの追加・名称変更・非表示化と、図形を参照するレイヤーの削除確認を検証する。
  test("manages a drawing layer and protects geometry during layer deletion", async ({ page, core }) => {
    await openWorkspace(page);
    await page.getByRole("tab", { name: "レイヤー", exact: true }).click();
    await page.getByRole("button", { name: "レイヤーを追加", exact: true }).click();

    let dialog = page.getByRole("dialog");
    await dialog.getByLabel("レイヤー名").fill("検証レイヤー");
    await dialog.getByRole("button", { name: "適用", exact: true }).click();
    await expect.poll(async () => (await core.invoke("document_state")).layers).toHaveLength(2);

    let state = await core.invoke("document_state");
    const defaultLayer = state.layers.find((layer) => layer.id === "layer:cut-line") ?? state.layers[0];
    const addedLayer = state.layers.find((layer) => layer.name === "検証レイヤー");
    expect(addedLayer).toBeDefined();
    await page.getByTestId("leather.toolbar.drawing-layer").locator("select").selectOption(addedLayer.id);
    await drawLine(page, [-30, 0], [30, 0]);
    await expect.poll(async () => (await core.invoke("document_state")).entities[0].layerId).toBe(addedLayer.id);
    await page.getByTestId("leather.toolbar.drawing-layer").locator("select").selectOption(defaultLayer.id);

    let layerCard = page.locator(".inspector-card").filter({ hasText: "検証レイヤー" }).first();
    await layerCard.getByRole("button", { name: "編集", exact: true }).click();
    dialog = page.getByRole("dialog");
    await dialog.getByLabel("レイヤー名").fill("検証レイヤー改名");
    await dialog.getByRole("button", { name: "適用", exact: true }).click();
    await expect
      .poll(async () => (await core.invoke("document_state")).layers.some((layer) => layer.name === "検証レイヤー改名"))
      .toBe(true);

    layerCard = page.locator(".inspector-card").filter({ hasText: "検証レイヤー改名" }).first();
    await layerCard.getByRole("checkbox").first().click();
    await expect
      .poll(
        async () =>
          (await core.invoke("document_state")).layers.find((layer) => layer.name === "検証レイヤー改名").visible,
      )
      .toBe(false);

    await layerCard.getByRole("button", { name: "削除", exact: true }).click();
    const alert = page.getByRole("alertdialog");
    await expect(alert).toBeVisible();
    await alert.getByRole("button", { name: "キャンセル", exact: true }).click();
    await expect(page.getByRole("alertdialog")).toHaveCount(0);
    expect((await core.invoke("document_state")).layers.some((layer) => layer.name === "検証レイヤー改名")).toBe(true);

    await layerCard.getByRole("button", { name: "削除", exact: true }).click();
    await page.getByRole("alertdialog").getByRole("button", { name: "削除", exact: true }).click();
    await expect
      .poll(async () => (await core.invoke("document_state")).layers.some((layer) => layer.name === "検証レイヤー改名"))
      .toBe(false);
    state = await core.invoke("document_state");
    expect(state.entities).toHaveLength(1);
    expect(state.entities[0].layerId).toBe(defaultLayer.id);
  });

  // 共有スタイルを追加・改名し、選択図形へ適用したスタイルIDがCore状態へ伝播することを検証する。
  test("creates and applies a shared line style", async ({ page, core }) => {
    await openWorkspace(page);
    await drawLine(page, [-40, 0], [40, 0]);
    await page.keyboard.press(`${primary}+a`);
    await page.getByRole("tab", { name: "共有スタイル", exact: true }).click();
    const initialStyleCount = (await core.invoke("document_state")).sharedStyles.length;
    await page.getByRole("button", { name: "共有線種を追加", exact: true }).click();
    await expect
      .poll(async () => (await core.invoke("document_state")).sharedStyles)
      .toHaveLength(initialStyleCount + 1);

    const newStyle = (await core.invoke("document_state")).sharedStyles.find((style) => style.name === "新規線種");
    expect(newStyle).toBeDefined();
    const styleCard = page.locator(".inspector-card").filter({ hasText: "新規線種" }).first();
    await styleCard.getByRole("button", { name: "名称", exact: true }).click();
    const dialog = page.getByRole("dialog");
    await dialog.getByLabel("線種名").fill("縫い線");
    await dialog.getByRole("button", { name: "適用", exact: true }).click();
    await expect
      .poll(async () => (await core.invoke("document_state")).sharedStyles.some((style) => style.name === "縫い線"))
      .toBe(true);

    const renamedStyle = (await core.invoke("document_state")).sharedStyles.find((style) => style.name === "縫い線");
    await page.getByLabel("型紙線種").selectOption(renamedStyle.id);
    await page.getByRole("button", { name: "選択へ適用", exact: true }).click();
    await expect.poll(async () => (await core.invoke("document_state")).entities[0].styleId).toBe(renamedStyle.id);
  });

  // オフセットの不正値を拒否した後、正しい値で派生要素を作成できることを検証する。
  test("rejects an invalid offset value and creates it after correction", async ({ page, core }) => {
    await openWorkspace(page);
    await drawLine(page, [-40, 0], [40, 0]);
    await clickTool(page, "オフセット");
    await clickModelPoint(page, 0, 0);

    let dialog = page.getByRole("dialog");
    await dialog.getByRole("textbox", { name: "値 (mm)" }).fill("0");
    await expect(dialog.getByRole("button", { name: "適用", exact: true })).toBeDisabled();
    await dialog.getByRole("button", { name: "キャンセル", exact: true }).click();
    expect((await core.invoke("document_state")).derivedElements).toHaveLength(0);

    await clickTool(page, "オフセット");
    await clickModelPoint(page, 0, 0);
    dialog = page.getByRole("dialog");
    await dialog.getByRole("textbox", { name: "値 (mm)" }).fill("3");
    await dialog.getByRole("button", { name: "適用", exact: true }).click();
    await expect.poll(async () => (await core.invoke("document_state")).derivedElements).toHaveLength(1);
    const derived = (await core.invoke("document_state")).derivedElements[0];
    expect(derived.kind.offsetCurve.distance).toEqual({ fixedMm: 3 });
  });

  // 連続する2線分にフィレットを適用し、開いた輪郭の派生要素として保存されることを検証する。
  test("creates a fillet from two connected line segments", async ({ page, core }) => {
    await openWorkspace(page);
    await drawLine(page, [-40, 0], [0, 0]);
    await drawLine(page, [0, 0], [0, 40]);
    await clickTool(page, "フィレット");
    await clickModelPoint(page, -20, 0);
    await clickModelPoint(page, 0, 20);

    const dialog = page.getByRole("dialog");
    await dialog.getByRole("textbox", { name: "値 (mm)" }).fill("2");
    await dialog.getByRole("button", { name: "適用", exact: true }).click();
    await expect.poll(async () => (await core.invoke("document_state")).derivedElements).toHaveLength(1);
    const derived = (await core.invoke("document_state")).derivedElements[0];
    expect(derived.kind.fillet.radius).toEqual({ fixedMm: 2 });
    expect(derived.kind.fillet.sourceEntityIds).toHaveLength(2);
  });

  // 線分長の計測表示を作成し、インスペクタから寸法拘束へ変換できることを検証する。
  test("converts a segment measurement into a dimensional constraint", async ({ page, core }) => {
    await openWorkspace(page);
    await drawLine(page, [-40, 0], [40, 0]);
    await clickTool(page, "線分長表示");
    await clickModelPoint(page, 0, 0);
    await expect.poll(async () => (await core.invoke("document_state")).measurementAnnotations).toHaveLength(1);

    await page.getByRole("button", { name: "segmentLength", exact: true }).click();
    await expect(page.getByText("計測表示を選択中", { exact: true })).toBeVisible();
    await page.getByRole("button", { name: "寸法拘束へ変換", exact: true }).click();
    await expect
      .poll(async () =>
        (await core.invoke("document_state")).constraints.filter((constraint) => constraint.kind === "segmentLength"),
      )
      .toHaveLength(1);
    const state = await core.invoke("document_state");
    expect(state.measurementAnnotations).toHaveLength(0);
  });

  // 選択図形をパーツ化し、名称・数量変更と複製がCoreのパーツ状態へ反映されることを検証する。
  test("creates, edits, and duplicates a part", async ({ page, core }) => {
    await openWorkspace(page);
    await drawLine(page, [-40, -20], [40, -20]);
    await drawLine(page, [40, -20], [0, 40]);
    await drawLine(page, [0, 40], [-40, -20]);
    await page.keyboard.press(`${primary}+a`);
    await page
      .getByRole("heading", { name: "選択", exact: true })
      .locator("..")
      .getByRole("button", { name: "パーツ", exact: true })
      .click();

    const dialog = page.getByRole("dialog");
    await dialog.getByLabel("パーツ名").fill("本体");
    await dialog.getByRole("button", { name: "適用", exact: true }).click();
    await expect.poll(async () => (await core.invoke("document_state")).parts).toHaveLength(1);

    await page.getByRole("tab", { name: "パーツ", exact: true }).click();
    let partCard = page.locator(".inspector-card").filter({ hasText: "本体" }).first();
    const nameInput = page.getByLabel("本体 の名前");
    await nameInput.fill("本体改名");
    await nameInput.blur();
    await expect.poll(async () => (await core.invoke("document_state")).parts[0].name).toBe("本体改名");

    partCard = page.locator(".inspector-card").filter({ hasText: "本体改名" }).first();
    await page.getByRole("button", { name: "数量", exact: true }).click();
    const quantityDialog = page.getByRole("dialog");
    await quantityDialog.getByLabel("数量").fill("2");
    await quantityDialog.getByRole("button", { name: "適用", exact: true }).click();
    await expect.poll(async () => (await core.invoke("document_state")).parts[0].quantity).toBe(2);

    await page.getByRole("button", { name: "複製", exact: true }).click();
    await expect.poll(async () => (await core.invoke("document_state")).parts).toHaveLength(2);
    expect((await core.invoke("document_state")).parts.map((part) => part.name)).toContain("本体改名のコピー");
  });

  // 作図したテキストを選択して内容を編集し、Coreの自由テキストに変更が保存されることを検証する。
  test("edits a free-text annotation through the inspector", async ({ page, core }) => {
    await openWorkspace(page);
    await clickTool(page, "テキスト");
    await clickModelPoint(page, -20, 20);
    await acceptTextDialog(page, "初期注記");
    await expect.poll(async () => (await core.invoke("document_state")).freeTexts).toHaveLength(1);

    await clickTool(page, "選択");
    const canvas = page.getByTestId("leather.workspace.canvas");
    const box = await canvas.boundingBox();
    if (!box) throw new Error("CAD canvas has no layout box");
    await page.mouse.dblclick(box.x + box.width / 2 - 20, box.y + box.height / 2 - 20);
    const textInput = page.getByLabel("テキスト内容");
    await expect(textInput).toHaveValue("初期注記");
    await textInput.fill("更新後注記");
    await textInput.blur();
    await expect.poll(async () => (await core.invoke("document_state")).freeTexts[0].content).toBe("更新後注記");
  });

  // 線分上へ縫い始め点を配置し、対象図形との関連をCoreへ保存できることを検証する。
  test("places a stitch start point on a line", async ({ page, core }) => {
    await openWorkspace(page);
    await page.getByLabel("型紙線種").selectOption("style:stitch-line");
    await drawLine(page, [-40, 0], [40, 0]);
    await clickTool(page, "縫い始め点");
    await clickModelPoint(page, -25, 0);
    await expect.poll(async () => (await core.invoke("document_state")).stitchStartPoints).toHaveLength(1);
    const state = await core.invoke("document_state");
    expect(state.stitchStartPoints[0].targetId).toBe(state.entities[0].id);
  });

  // 3本の線分を端点スナップで接続し、三角形の3頂点それぞれに一致拘束が自動追加されることを検証する。
  test("builds a triangle with automatic coincident constraints", async ({ page, core }) => {
    await openWorkspace(page);
    await drawLine(page, [-40, -20], [40, -20]);
    await drawLine(page, [40, -20], [0, 40]);
    await drawLine(page, [0, 40], [-40, -20]);

    await expect.poll(async () => (await core.invoke("document_state")).entities).toHaveLength(3);
    const state = await core.invoke("document_state");
    expect(state.constraints.filter((constraint) => constraint.kind === "coincident")).toHaveLength(3);
    expect(state.coincidentPointGroups).toHaveLength(3);
    for (const group of state.coincidentPointGroups) expect(group.targets).toHaveLength(2);
  });

  // 三角形の頂点をドラッグしたとき、ドラッグ中はCoreの正式状態を変更せずプレビューだけを表示し、離した時点で一致拘束を保ったまま確定することを検証する。
  test("previews and commits a triangle vertex drag through coincident constraints", async ({ page, core }) => {
    await openWorkspace(page);
    await drawLine(page, [-40, -20], [40, -20]);
    await drawLine(page, [40, -20], [0, 40]);
    await drawLine(page, [0, 40], [-40, -20]);
    const before = await core.invoke("document_state");
    expect(before.constraints.filter((constraint) => constraint.kind === "coincident")).toHaveLength(3);

    await clickTool(page, "選択");
    await dragModelPoint(page, [-40, -20], [-55, -10]);
    await expect(page.getByRole("status")).toContainText("プレビュー中");
    await expect(page.locator("#cad-canvas-interaction-state")).toContainText("選択");
    expect((await core.invoke("document_state")).entities).toEqual(before.entities);

    await page.mouse.up();
    await expect.poll(async () => (await core.invoke("document_state")).entities).not.toEqual(before.entities);
    const after = await core.invoke("document_state");
    expect(after.constraints.filter((constraint) => constraint.kind === "coincident")).toHaveLength(3);
    expect(after.coincidentPointGroups).not.toEqual(before.coincidentPointGroups);
  });

  // 三角形の辺を一度選択してからドラッグし、辺本体の移動もプレビュー表示を経て正式状態へ反映されることを検証する。
  test("previews and commits a triangle edge drag", async ({ page, core }) => {
    await openWorkspace(page);
    await drawLine(page, [-40, -20], [40, -20]);
    await drawLine(page, [40, -20], [0, 40]);
    await drawLine(page, [0, 40], [-40, -20]);
    const before = await core.invoke("document_state");

    await clickTool(page, "選択");
    await clickModelPoint(page, 20, 10);
    await expect(page.locator("#cad-canvas-interaction-state")).toContainText("選択 1 件");
    await dragModelPoint(page, [20, 10], [25, 15]);
    await expect(page.getByRole("status")).toContainText("移動プレビュー中");
    expect((await core.invoke("document_state")).entities).toEqual(before.entities);

    await page.mouse.up();
    await expect.poll(async () => (await core.invoke("document_state")).entities).not.toEqual(before.entities);
    const after = await core.invoke("document_state");
    expect(after.constraints.filter((constraint) => constraint.kind === "coincident")).toHaveLength(3);
  });
});
