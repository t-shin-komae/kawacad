import { spawn, spawnSync } from "node:child_process";
import { createInterface } from "node:readline";
import { mkdtemp, rm } from "node:fs/promises";
import { existsSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

const appRoot = path.resolve(import.meta.dirname, "../..");
const repoRoot = path.resolve(appRoot, "../..");
const coreBinary = process.env.KAWACAD_CORE_PROCESS ?? path.join(repoRoot, "target/debug/kawacad-core-process");

function ensureCoreBinary() {
  const result = spawnSync("cargo", ["build", "-p", "kawacad-core-process"], {
    cwd: repoRoot,
    encoding: "utf8",
    stdio: "inherit",
  });
  if (result.status !== 0 || !existsSync(coreBinary)) throw new Error("kawacad-core-process could not be built");
}

function printableArea(orientation) {
  const width = orientation === "landscape" ? 297 : 210;
  const height = orientation === "landscape" ? 210 : 297;
  return {
    leftMm: -width / 2,
    rightMm: width / 2,
    topMm: height / 2,
    bottomMm: -height / 2,
  };
}

function adaptState(coreState, { path: projectPath, viewMode, orientation }) {
  const editSummary = coreState.snapshot.editDisplaySummary;
  const entities = coreState.entities;
  return {
    snapshot: {
      name: coreState.snapshot.name,
      constraintStatus: editSummary.constraintStatus,
      statistics: coreState.snapshot.statistics,
    },
    history: coreState.history,
    persistence: {
      isDirty: coreState.persistence.isDirty,
      hasPath: Boolean(projectPath),
      path: projectPath,
    },
    settings: coreState.settings,
    viewMode,
    entities,
    drawingEntityMetadata: entities
      .filter((entity) => entity.derivedElementId)
      .map((entity) => ({
        entityId: entity.id,
        derivedElementId: entity.derivedElementId,
        resolvedIndex: entity.resolvedIndex,
        sourceEntityId: entity.sourceEntityId,
        suppressedByFillet: entity.suppressedByFillet,
      })),
    layers: coreState.layers,
    sharedStyles: coreState.sharedStyles,
    parameters: coreState.parameters,
    parts: coreState.parts,
    constraints: coreState.constraints,
    freeTexts: coreState.freeTexts,
    derivedElements: coreState.derivedElements,
    roundHoles: coreState.roundHoles,
    stitchStartPoints: coreState.stitchStartPoints,
    canvasProjection: coreState.canvasProjection,
    measurementAnnotations: coreState.measurementAnnotations,
    measurementEvaluations: coreState.measurementEvaluations,
    dimensionConstraintAnnotations: coreState.dimensionConstraintAnnotations,
    coincidentPointGroups: coreState.coincidentPointGroups,
    warnings: coreState.warnings,
    outputPreview: viewMode === "outputPreview" ? undefined : null,
  };
}

/**
 * Adapts the real line-oriented Core process to the commands exposed by the
 * Tauri adapter. The browser still talks through @tauri-apps/api/core; only
 * the native IPC transport is replaced by Playwright's exposed function.
 */
export class CoreBridge {
  #child;
  #readline;
  #pending = [];
  #requestChain = Promise.resolve();
  #projectPath;
  #viewMode = "editDisplay";
  #orientation = "portrait";
  #tempDirectory;

  get orientation() {
    return this.#orientation;
  }

  async start() {
    ensureCoreBinary();
    this.#tempDirectory = await mkdtemp(path.join(tmpdir(), "kawa-cad-e2e-"));
    await this.#startProcess(["--new", "Untitled"]);
  }

  async close() {
    await this.#stopProcess();
    if (this.#tempDirectory) await rm(this.#tempDirectory, { recursive: true, force: true });
  }

  async invoke(command, args = {}) {
    switch (command) {
      case "document_state":
        return this.#state();
      case "new_document":
        await this.#restart(["--new", String(args.name ?? "Untitled").trim()]);
        this.#projectPath = undefined;
        this.#viewMode = "editDisplay";
        return this.#state();
      case "open_document":
        await this.#restart(["--read-kawa-file", String(args.path)]);
        this.#projectPath = String(args.path);
        this.#viewMode = "editDisplay";
        return this.#state();
      case "save_document":
        await this.#writeFile(String(args.path));
        this.#projectPath = String(args.path);
        return this.#state();
      case "save_current_document":
        if (!this.#projectPath) throw new Error("No project file path has been selected");
        await this.#writeFile(this.#projectPath);
        return this.#state();
      case "reload_document":
        if (!this.#projectPath) throw new Error("No project file path has been selected");
        await this.#restart(["--read-kawa-file", this.#projectPath]);
        return this.#state();
      case "set_view_mode":
        this.#viewMode = args.viewMode;
        return this.#state();
      case "apply_command":
        return this.#request({
          kind: "applyCommand",
          payload: { command: args.command, viewMode: this.#viewMode },
        }).then((state) => this.#adaptState(state));
      case "preview_command":
        return this.#request({
          kind: "previewCommand",
          payload: { command: args.command, viewMode: this.#viewMode },
        }).then((state) => this.#adaptState(state));
      case "undo":
      case "redo":
        return this.#request({
          kind: command,
          payload: { viewMode: this.#viewMode },
        }).then((state) => this.#adaptState(state));
      case "preflight_constraint":
        return this.#request({ kind: "preflightConstraint", payload: { kind: args.kind, targets: args.targets } });
      case "preflight_derived_element":
        return this.#request({
          kind: "preflightDerivedElement",
          payload: {
            kind: args.kind,
            hitEntityId: args.hitEntityId,
            selectedEntityIds: args.selectedEntityIds,
            clickPoint: args.clickPoint,
          },
        });
      case "layer_deletion_impact":
        return this.#request({ kind: "layerDeletionImpact", payload: { layerId: args.layerId } });
      case "export_selection":
        return this.#request({ kind: "exportSelection", payload: { selection: args.selection } });
      case "export_part_library_item":
        return this.#request({ kind: "exportPartLibraryItem", payload: { partId: args.partId } });
      case "load_part_library":
        return [];
      case "save_part_library":
      case "save_recovery_snapshot":
      case "discard_recovery_snapshot":
        return undefined;
      case "recovery_candidate":
        return null;
      case "restore_recovery_snapshot":
        throw new Error("No recovery snapshot exists in the browser E2E session");
      case "exit_application":
      case "plugin:window|set_title":
      case "plugin:window|destroy":
      case "plugin:window|close":
      case "plugin:window|unlisten":
      case "plugin:event|unlisten":
      case "plugin:menu|append":
      case "plugin:menu|set_as_app_menu":
      case "plugin:menu|set_as_window_menu":
        return undefined;
      case "plugin:event|listen":
        return 1;
      case "plugin:menu|new":
      case "plugin:menu|create":
      case "plugin:menu|create_submenu":
      case "plugin:menu|create_item":
        return [1, "e2e-menu"];
      case "plugin:dialog|confirm":
      case "plugin:dialog|message":
        return Array.isArray(args.buttons?.OkCustom) ? args.buttons.OkCustom[0] : "Ok";
      case "plugin:dialog|save":
        return path.join(this.#tempDirectory, "e2e-project.kawa");
      case "plugin:dialog|open":
        return this.#projectPath ?? path.join(this.#tempDirectory, "e2e-project.kawa");
      default:
        throw new Error(`Unsupported E2E Tauri command: ${command}`);
    }
  }

  async #state() {
    const state = await this.#request({ kind: "documentState", payload: { viewMode: this.#viewMode } });
    const adapted = this.#adaptState(state);
    if (this.#viewMode === "outputPreview") {
      const orientation = adapted.settings.orientation;
      const model = await this.#request({
        kind: "buildOutputDocumentModel",
        payload: {
          orientation,
          includeDimensionLabels: true,
          includeScaleGuide: true,
          rotationDeg: 0,
          printableAreaMm: printableArea(orientation),
        },
      });
      adapted.outputPreview = {
        pages: model.outputDocumentModel?.pages ?? [],
        warnings: model.warnings ?? [],
      };
    }
    return adapted;
  }

  #adaptState(state) {
    this.#orientation = state.settings.orientation;
    return adaptState(state, this.#context());
  }

  #context() {
    return { path: this.#projectPath, viewMode: this.#viewMode, orientation: this.#orientation };
  }

  async #writeFile(filePath) {
    await this.#request({
      kind: "writeKawaFile",
      payload: { path: filePath, markClean: true },
    });
  }

  async #restart(args) {
    await this.#stopProcess();
    await this.#startProcess(args);
  }

  async #startProcess(args) {
    this.#child = spawn(coreBinary, args, { stdio: ["pipe", "pipe", "pipe"] });
    this.#child.stderr.setEncoding("utf8");
    this.#child.stderr.on("data", () => {});
    this.#readline = createInterface({ input: this.#child.stdout });
    this.#readline.on("line", (line) => {
      const pending = this.#pending.shift();
      if (!pending) return;
      try {
        const parsed = JSON.parse(line);
        if (parsed.error) pending.reject(new Error(parsed.error.message ?? JSON.stringify(parsed.error)));
        else pending.resolve(parsed);
      } catch (error) {
        pending.reject(error);
      }
    });
    this.#child.once("exit", (code, signal) => {
      const error = new Error(`Core process exited (${code ?? "signal " + signal})`);
      for (const pending of this.#pending.splice(0)) pending.reject(error);
    });
  }

  async #stopProcess() {
    if (!this.#child) return;
    const child = this.#child;
    this.#child = undefined;
    this.#readline?.close();
    this.#readline = undefined;
    child.kill();
    await new Promise((resolve) => child.once("exit", resolve));
  }

  #request(request) {
    const run = this.#requestChain.then(
      () =>
        new Promise((resolve, reject) => {
          this.#pending.push({ resolve, reject });
          this.#child.stdin.write(`${JSON.stringify(request)}\n`);
        }),
    );
    this.#requestChain = run.catch(() => undefined);
    return run;
  }
}
