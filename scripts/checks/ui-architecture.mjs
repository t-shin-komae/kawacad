import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const tauriSource = path.join(repositoryRoot, "apps/tauri/KawaCAD/src");
const swiftSource = path.join(repositoryRoot, "apps/macos/KawaCAD/Sources/KawaCADApp");
const swiftTestSource = path.join(repositoryRoot, "apps/macos/KawaCAD/Tests/KawaCADAppTests");
const failures = [];

function walk(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const target = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(target) : [target];
  });
}

const productSourceFiles = walk(tauriSource).filter((file) => file.endsWith(".ts") || file.endsWith(".tsx"));
const reactTopLevelDirectories = new Set(["adapters", "app", "features", "localization", "shared", "test"]);
const reactFeatures = new Set(["canvas", "constraints", "document", "inspector", "output", "parts", "recovery", "workspace"]);
const reactFeatureLayers = new Set(["actions", "components", "domain", "effects", "selectors", "state"]);
const reactSharedLayers = new Set(["accessibility", "components", "domain", "state"]);
for (const file of productSourceFiles) {
  const relative = path.relative(tauriSource, file);
  const isTest = relative.startsWith(`test${path.sep}`);
  const isCatalog = relative === path.join("localization", "appStrings.ts") || relative === "appStrings.ts";
  const isCompositionRoot = relative === path.join("app", "App.tsx") || relative === path.join("app", "main.tsx");
  const segments = relative.split(path.sep);
  if (!reactTopLevelDirectories.has(segments[0])) {
    failures.push(`product source must live under a feature-first top-level directory: ${relative}`);
  }
  if (segments[0] === "features" && (!reactFeatures.has(segments[1]) || !reactFeatureLayers.has(segments[2]))) {
    failures.push(`feature source must live under features/<feature>/<layer>: ${relative}`);
  }
  if (segments[0] === "shared" && !reactSharedLayers.has(segments[1])) {
    failures.push(`shared source must declare its responsibility layer: ${relative}`);
  }
  if (segments[0] === "app") {
    const rootAppSources = new Set(["App.tsx", "main.tsx"]);
    const isRootSource = segments.length === 2 && rootAppSources.has(segments[1]);
    const isAppLayer = new Set(["actions", "domain"]).has(segments[1]);
    if (!isRootSource && !isAppLayer) failures.push(`React app source has no composition responsibility: ${relative}`);
  }
  const isFeatureComponent = segments[0] === "features" && segments[2] === "components";
  const isSharedComponent = segments[0] === "shared" && segments[1] === "components";
  if (file.endsWith(".tsx") && !isTest && !isCompositionRoot && !isFeatureComponent && !isSharedComponent) {
    failures.push(`product TSX must live under a feature/shared components directory: ${relative}`);
  }
  if (!isTest && !isCatalog && /[ぁ-んァ-ン一-龯々ー]/u.test(fs.readFileSync(file, "utf8"))) {
    failures.push(`product source contains an unregistered Japanese literal: ${relative}`);
  }
}

for (const file of walk(tauriSource)) {
  const contents = fs.readFileSync(file, "utf8");
  const relative = path.relative(tauriSource, file);
  if (!relative.startsWith(`test${path.sep}`) && (contents.includes('from "@tauri-apps/api/core"') || /\binvoke\s*\(/u.test(contents)) && !relative.startsWith(`adapters${path.sep}`)) {
    failures.push(`Tauri invoke must be isolated in src/adapters: ${relative}`);
  }
}

const swiftActionHandlerTypes = [
  "DocumentActionHandler",
  "CanvasActionHandler",
  "ConstraintActionHandler",
  "InspectorActionHandler",
  "PartActionHandler",
  "OutputActionHandler",
  "RecoveryActionHandler",
  "WorkspaceActionHandler",
];

const swiftTopLevelDirectories = new Set(["Adapters", "App", "Features", "Localization", "Shared"]);
const swiftFeatures = new Set(["Canvas", "Constraints", "Document", "Inspector", "Output", "Parts", "Recovery", "Workspace"]);
const swiftFeatureLayers = new Set(["Actions", "Components", "Domain", "Effects", "Selectors", "State"]);
const swiftSharedLayers = new Set(["Accessibility", "Components", "Domain", "State"]);

for (const typeName of swiftActionHandlerTypes) {
  const handlerFiles = walk(swiftSource).filter((file) => file.endsWith(".swift"));
  if (!handlerFiles.some((file) => new RegExp(`\\bclass\\s+${typeName}\\b`, "u").test(fs.readFileSync(file, "utf8")))) {
    failures.push(`feature action handler type is missing: ${typeName}`);
  }
}

const swiftDependencyTypes = [
  "CanvasActionHandlerDependencies",
  "DocumentActionHandlerDependencies",
  "ConstraintActionHandlerDependencies",
  "InspectorActionHandlerDependencies",
  "PartActionHandlerDependencies",
  "OutputActionHandlerDependencies",
  "RecoveryActionHandlerDependencies",
  "WorkspaceActionHandlerDependencies",
];
const handlerAggregateSource = fs.readFileSync(
  path.join(swiftSource, "App", "Actions", "AppActionHandlers.swift"),
  "utf8",
);
if (/^\s*(?:private\s+)?let\s+context\s*:\s*AppActionHandlerContext/mu.test(handlerAggregateSource)) {
  failures.push("Swift action aggregate must not retain the full action context");
}
if (/@dynamicMemberLookup|dynamicMember/u.test(handlerAggregateSource)) {
  failures.push("Swift action aggregate must not expose context through dynamic member lookup");
}
const dependencySource = fs.readFileSync(
  path.join(swiftSource, "App", "Actions", "FeatureActionHandlerDependencies.swift"),
  "utf8",
);
for (const typeName of swiftDependencyTypes) {
  if (!new RegExp(`\\bstruct\\s+${typeName}\\b`, "u").test(dependencySource)) {
    failures.push(`feature action dependency type is missing: ${typeName}`);
  }
}

for (const file of walk(swiftSource)) {
  const relative = path.relative(swiftSource, file);
  const basename = path.basename(file);
  if (/^AppCoordinator\+.*\.swift$/u.test(basename)) failures.push(`legacy AppCoordinator extension remains: ${relative}`);
  if (!file.endsWith(".swift")) continue;
  const segments = relative.split(path.sep);
  if (!swiftTopLevelDirectories.has(segments[0])) {
    failures.push(`Swift source must live under a feature-first top-level directory: ${relative}`);
  }
  if (segments[0] === "Features" && (!swiftFeatures.has(segments[1]) || !swiftFeatureLayers.has(segments[2]))) {
    failures.push(`Swift feature source must live under Features/<Feature>/<Layer>: ${relative}`);
  }
  if (segments[0] === "Shared" && !swiftSharedLayers.has(segments[1])) {
    failures.push(`Swift shared source must declare its responsibility layer: ${relative}`);
  }
  if (segments[0] === "App") {
    const rootAppSources = new Set(["AppCoordinator.swift", "KawaCADApp.swift", "KawaCADCommands.swift", "MainWindowView.swift"]);
    const isRootSource = segments.length === 2 && rootAppSources.has(segments[1]);
    const isAppLayer = segments[1] === "Actions";
    if (!isRootSource && !isAppLayer) failures.push(`Swift App source has no composition responsibility: ${relative}`);
  }
  const contents = fs.readFileSync(file, "utf8");
  const codeOnly = contents
    .split("\n")
    .filter((line) => !line.trim().startsWith("//"))
    .join("\n");
  if (contents.includes("extension AppCoordinator")) failures.push(`AppCoordinator extension remains: ${relative}`);
  if (relative === path.join("App", "Actions", "AppActionHandlerSelectors.swift") && /\bset\s*\{/u.test(codeOnly)) {
    failures.push(`selector file must not transfer state through setters: ${relative}`);
  }
  if (/^LeatherCanvasView\.Rendering\.swift$/u.test(basename)) {
    const lineCount = contents.split("\n").length - 1;
    if (lineCount > 1000) failures.push(`canvas rendering extension remains too large: ${relative}`);
  }
  if (/ActionHandler.*\.swift$/u.test(basename) && !basename.includes("Context") && codeOnly.includes("AppCoordinator")) {
    failures.push(`action handler reaches AppCoordinator: ${relative}`);
  }
  if (/(Feature|Factory|Selector)\.swift$/u.test(basename) && /import (SwiftUI|AppKit|Combine)/u.test(contents)) {
    failures.push(`pure selector/factory imports UI or observation framework: ${relative}`);
  }
  if (/(Feature|Factory|Selector)\.swift$/u.test(basename) && /@(Published|StateObject|ObservedObject|EnvironmentObject)|ObservableObject/u.test(contents)) {
    failures.push(`pure selector/factory owns UI state: ${relative}`);
  }
  if (relative === path.join("App", "AppCoordinator.swift")) {
    if (/final\s+class\s+AppCoordinator\s*:[^{\n]*\bAppActionHandler(?:s)?\b/u.test(codeOnly)) {
      failures.push("AppCoordinator must compose handlers instead of inheriting from them");
    }
    if (/\bfunc\s+[A-Za-z_][A-Za-z0-9_]*/u.test(codeOnly)) {
      failures.push("AppCoordinator contains an individual action method");
    }
    const coordinatorVars = [...codeOnly.matchAll(/\bvar\s+([A-Za-z_][A-Za-z0-9_]*)/gu)].map((match) => match[1]);
    const allowedCoordinatorVars = new Set(["documentLifecycleController"]);
    if (coordinatorVars.some((name) => !allowedCoordinatorVars.has(name))) {
      failures.push("AppCoordinator contains a derived or individual state property");
    }
  }
  if (codeOnly.includes("AppCoordinator")) {
    const allowed = new Set([
      path.join("App", "AppCoordinator.swift"),
      path.join("App", "KawaCADApp.swift"),
      path.join("App", "MainWindowView.swift"),
    ]);
    if (!allowed.has(relative)) failures.push(`non-root SwiftUI source reaches AppCoordinator: ${relative}`);
  }
}

for (const file of walk(swiftTestSource)) {
  const relative = path.relative(swiftTestSource, file);
  const basename = path.basename(file);
  if (!file.endsWith(".swift")) continue;
  const contents = fs.readFileSync(file, "utf8");
  if (basename === "AppCoordinatorTestAccess.swift") failures.push("legacy AppCoordinator test compatibility API remains");
  if (/\bextension\s+AppCoordinator\b/u.test(contents)) {
    failures.push(`test-only AppCoordinator compatibility extension remains: ${relative}`);
  }
}

const expectedActionHooks = [
  path.join("features", "document", "actions", "useDocumentActions.ts"),
  path.join("features", "canvas", "actions", "useCanvasActions.ts"),
  path.join("features", "constraints", "actions", "useConstraintActions.ts"),
  path.join("features", "inspector", "actions", "useInspectorActions.ts"),
  path.join("features", "parts", "actions", "usePartActions.ts"),
  path.join("features", "output", "actions", "useOutputActions.ts"),
  path.join("features", "recovery", "actions", "useRecoveryActions.ts"),
  path.join("features", "workspace", "actions", "useWorkspaceActions.ts"),
];
for (const relative of expectedActionHooks) {
  if (!fs.existsSync(path.join(tauriSource, relative))) failures.push(`feature action hook is missing: ${relative}`);
}
const actionHookFiles = walk(tauriSource).filter((candidate) => {
  const relative = path.relative(tauriSource, candidate);
  return relative.split(path.sep).includes("actions") && /\.(ts|tsx)$/u.test(candidate);
});
for (const file of actionHookFiles) {
  const relative = path.relative(tauriSource, file);
  const contents = fs.readFileSync(file, "utf8");
  if (contents.includes("@ts-nocheck")) failures.push(`action hook disables TypeScript checking: ${relative}`);
  if (/\bRecord\s*<[^>]*\bany\b/u.test(contents)) failures.push(`action hook has an untyped context: ${relative}`);
  if (/\buse(State|Reducer|Ref)\s*\(/u.test(contents)) failures.push(`action hook owns display state: ${relative}`);
  if (/\bActionRuntime\b/u.test(contents)) failures.push(`feature action hook must use a feature context, not a shared runtime: ${relative}`);
}
const featureActionImplementations = new Map([
  [path.join("features", "document", "actions", "useDocumentActions.ts"), "useDocumentActionCallbacks"],
  [path.join("features", "canvas", "actions", "useCanvasActions.ts"), "useCanvasPointActionCallbacks"],
  [path.join("features", "constraints", "actions", "useConstraintActions.ts"), "useConstraintActionCallbacks"],
  [path.join("features", "parts", "actions", "usePartActions.ts"), "usePartActionCallbacks"],
  [path.join("features", "output", "actions", "useOutputActions.ts"), "useOutputActionCallbacks"],
]);
for (const [relative, implementation] of featureActionImplementations) {
  const file = path.join(tauriSource, relative);
  if (fs.existsSync(file) && !fs.readFileSync(file, "utf8").includes(implementation)) {
    failures.push(`feature action hook must compose its feature implementation: ${relative}`);
  }
}
const featureContextRequirements = new Map([
  [path.join("features", "document", "actions", "useDocumentActions.ts"), "DocumentActionContext"],
  [path.join("features", "canvas", "actions", "useCanvasActions.ts"), "CanvasActionContext"],
  [path.join("features", "constraints", "actions", "useConstraintActions.ts"), "ConstraintActionContext"],
  [path.join("features", "inspector", "actions", "useInspectorActions.ts"), "InspectorActionContext"],
  [path.join("features", "parts", "actions", "usePartActions.ts"), "PartActionContext"],
  [path.join("features", "output", "actions", "useOutputActions.ts"), "OutputActionContext"],
  [path.join("features", "workspace", "actions", "useWorkspaceActions.ts"), "WorkspaceActionContext"],
  [path.join("features", "document", "actions", "useDocumentActionCallbacks.ts"), "DocumentActionContext"],
  [path.join("features", "canvas", "actions", "useCanvasPointerActionCallbacks.ts"), "CanvasActionContext"],
  [path.join("features", "canvas", "actions", "useCanvasPointActionCallbacks.ts"), "CanvasActionContext"],
  [path.join("features", "constraints", "actions", "useConstraintActionCallbacks.ts"), "ConstraintActionContext"],
  [path.join("features", "parts", "actions", "usePartActionCallbacks.ts"), "PartActionContext"],
  [path.join("features", "output", "actions", "useOutputActionCallbacks.ts"), "OutputActionContext"],
]);
for (const [relative, contextType] of featureContextRequirements) {
  const file = path.join(tauriSource, relative);
  if (!fs.existsSync(file)) continue;
  const contents = fs.readFileSync(file, "utf8");
  if (contents.includes("AppActionContext")) {
    failures.push(`feature action must not receive the aggregate context: ${path.relative(tauriSource, file)}`);
  }
  if (!contents.includes(contextType)) {
    failures.push(`feature action context type is missing: ${relative} -> ${contextType}`);
  }
}
const appActions = fs.readFileSync(path.join(tauriSource, "app", "actions", "useAppActions.ts"), "utf8");
if (appActions.includes("useRecoverySnapshot")) failures.push("useAppActions must not own recovery snapshot state");
if (/function\s+pickContext\s*<T[^>]*>[\s\S]*?\bas\s+T\b/u.test(appActions)) {
  failures.push("pickContext must derive its return type from the selected keys instead of casting to a requested context");
}
const recoveryActions = fs.readFileSync(
  path.join(tauriSource, "features", "recovery", "actions", "useRecoveryActions.ts"),
  "utf8",
);
if (/return\s*\{\s*\}/u.test(recoveryActions)) failures.push("useRecoveryActions must not be an empty placeholder");
const appSource = fs.readFileSync(path.join(tauriSource, "app", "App.tsx"), "utf8");
if (!appSource.includes("useRecoverySnapshot")) failures.push("App.tsx must compose recovery snapshot state");
if (!appSource.includes("useWindowLifecycle")) failures.push("App.tsx must compose useWindowLifecycle");
if (!appSource.includes("useRecoveryEffects")) failures.push("App.tsx must compose useRecoveryEffects");
if (/\bcommand\s*\(/u.test(appSource)) failures.push("App.tsx must not contain individual command action bodies");
if (/from ["']\.\/adapters\//u.test(appSource) || appSource.includes("@tauri-apps/api")) {
  failures.push("App.tsx must not access an external adapter boundary directly");
}

const catalog = path.join(tauriSource, "localization/appStrings.ts");
if (!fs.existsSync(catalog)) failures.push("React localization catalog is missing");
if (!fs.existsSync(path.join(swiftSource, "Resources/Localizable.strings"))) {
  failures.push("Swift localization catalog is missing");
}

const reactCatalogText = fs.readFileSync(catalog, "utf8");
const swiftCatalogText = fs.readFileSync(path.join(swiftSource, "Resources/Localizable.strings"), "utf8");
const sharedMapSection = reactCatalogText.match(/export const sharedLocalizationKeyMap = \{([\s\S]*?)\n\} as const;/u)?.[1] ?? "";
const sharedKeys = [...sharedMapSection.matchAll(/^\s*"([^"]+)"\s*:/gmu)].map((match) => match[1]);
for (const key of sharedKeys) {
  if (!new RegExp(`^"${key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}"\\s*=`, "mu").test(swiftCatalogText)) {
    failures.push(`Swift localization key is missing from Localizable.strings: ${key}`);
  }
}
if (!sharedKeys.length) failures.push("React/Swift localization parity map is empty");

if (failures.length) {
  console.error(failures.map((failure) => `✗ ${failure}`).join("\n"));
  process.exitCode = 1;
} else {
  console.log("UI architecture checks passed.");
}
