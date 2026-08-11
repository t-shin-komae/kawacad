import { Menu, MenuItem, PredefinedMenuItem, Submenu } from "@tauri-apps/api/menu";
import type { AboutMetadata } from "@tauri-apps/api/menu";
import { productInfo } from "@/app/productInfo";
import { invokeCommand } from "@/adapters/tauriCommandAdapter";
import { appStrings } from "@/localization";
import type { MenuAction } from "@/app/domain/nativeMenuTypes";
import { nativeMenuAvailability, type NativeMenuState } from "@/app/domain/nativeMenuState";

export type { MenuAction } from "@/app/domain/nativeMenuTypes";
export type { NativeMenuState } from "@/app/domain/nativeMenuState";

const dynamicMenuItems = new Map<string, MenuItem>();
let currentMenuState: NativeMenuState | undefined;
let menuStateApplyRequested = false;
let menuStateApplyInProgress = false;

export function updateNativeMenuState(state: NativeMenuState) {
  currentMenuState = state;
  menuStateApplyRequested = true;
  if (!menuStateApplyInProgress) void flushNativeMenuState();
}

async function flushNativeMenuState() {
  menuStateApplyInProgress = true;
  try {
    while (menuStateApplyRequested) {
      menuStateApplyRequested = false;
      await applyNativeMenuState(currentMenuState);
    }
  } catch (error) {
    console.info("KawaCAD menu state could not be updated.", error);
  } finally {
    menuStateApplyInProgress = false;
    if (menuStateApplyRequested) void flushNativeMenuState();
  }
}

async function applyNativeMenuState(state: NativeMenuState | undefined) {
  const availability = nativeMenuAvailability(state);
  const enabled: Record<string, boolean> = {
    save: availability.save,
    saveAs: availability.saveAs,
    exportPDF: availability.exportPDF,
    directPrint: availability.directPrint,
    undo: availability.undo,
    redo: availability.redo,
    duplicate: availability.duplicate,
    delete: availability.delete,
    paste: availability.paste,
    addLayer: availability.addLayer,
    smoothArcTangencies: availability.smoothArcTangencies,
    findInspector: availability.findInspector,
  };
  await Promise.all(
    Object.entries(enabled).map(([action, isEnabled]) => dynamicMenuItems.get(action)?.setEnabled(isEnabled)),
  );
  await Promise.all([
    dynamicMenuItems.get("toggleInspector")?.setText(availability.inspectorLabel),
    dynamicMenuItems.get("toggleBottomWorkbench")?.setText(availability.bottomWorkbenchLabel),
  ]);
}

/** Actions intentionally shared by the Windows, Linux, and macOS menu. */
export const crossPlatformMenuActions: readonly MenuAction[] = [
  "new",
  "open",
  "save",
  "saveAs",
  "exportPDF",
  "directPrint",
  "undo",
  "redo",
  "cut",
  "copy",
  "paste",
  "duplicate",
  "delete",
  "selectAll",
  "cancelCurrentInteraction",
  "findInspector",
  "select",
  "point",
  "line",
  "circle",
  "roundHole",
  "arc",
  "stitchStartPoint",
  "freeText",
  "centerLine",
  "horizontalCenterLine",
  "verticalCenterLine",
  "offset",
  "fillet",
  "coincident",
  "horizontal",
  "vertical",
  "parallel",
  "perpendicular",
  "tangent",
  "equalLength",
  "angle",
  "symmetric",
  "pointOnLine",
  "fixed",
  "smoothArcTangencies",
  "distance",
  "horizontalDistance",
  "verticalDistance",
  "lineLineDistance",
  "segmentLength",
  "diameter",
  "radius",
  "measureDistance",
  "measureSegmentLength",
  "measureAngle",
  "measureRadius",
  "measureDiameter",
  "measureArcSweepAngle",
  "addLayer",
  "editDisplay",
  "outputPreview",
  "toggleA4Orientation",
  "zoomToFit",
  "toggleInspector",
  "toggleBottomWorkbench",
  "resetLayout",
  "reload",
  "openLicenses",
];

function dispatch(action: MenuAction) {
  window.dispatchEvent(new CustomEvent<MenuAction>("kawa-cad-menu", { detail: action }));
}

/**
 * macOS uses the bundle's CFBundleVersion when the native About metadata does
 * not provide a build version.  An empty value explicitly suppresses that
 * fallback.  Windows and Linux append shortVersion in parentheses, so omit it
 * there instead of showing an empty pair of parentheses.
 */
export function aboutMetadataForPlatform(userAgent: string): AboutMetadata {
  const metadata: AboutMetadata = {
    name: productInfo.name,
    version: productInfo.displayVersion,
    copyright: productInfo.copyright,
  };
  if (/Macintosh|Mac OS X/.test(userAgent)) {
    metadata.shortVersion = "";
  }
  return metadata;
}

/** Installs the Tauri native menu on every desktop target without bypassing
 * the React/Core command path. Platform-owned About/Window/Quit items are
 * intentionally left to the host OS so the same definition works on
 * Windows, Linux, and macOS. */
export async function installNativeMenu() {
  dynamicMenuItems.clear();
  const item = async (text: string, action: MenuAction, accelerator?: string) => {
    const menuItem = await MenuItem.new({
      id: `kawa-cad-${action}`,
      text,
      accelerator,
      action: () => dispatch(action),
    });
    if (
      [
        "save",
        "saveAs",
        "exportPDF",
        "directPrint",
        "undo",
        "redo",
        "duplicate",
        "delete",
        "paste",
        "addLayer",
        "smoothArcTangencies",
        "findInspector",
        "toggleInspector",
        "toggleBottomWorkbench",
      ].includes(action)
    )
      dynamicMenuItems.set(action, menuItem);
    return menuItem;
  };
  const aboutItem = await PredefinedMenuItem.new({
    text: appStrings.menu.item.about,
    item: { About: aboutMetadataForPlatform(navigator.userAgent) },
  });
  const platformDirectPrintAvailable = await invokeCommand<{ status: string }>("direct_print_availability")
    .then((availability) => availability.status === "available")
    .catch(() => false);
  const directPrintItems = platformDirectPrintAvailable
    ? [await item(appStrings.menu.item.directPrint, "directPrint")]
    : [];
  const applicationMenu = await Submenu.new({
    text: productInfo.name,
    items: [aboutItem, await item(appStrings.menu.item.openSourceLicenses, "openLicenses")],
  });
  const fileItems = [
    await item(appStrings.menu.item.new, "new", "CmdOrCtrl+N"),
    await item(appStrings.menu.item.open, "open", "CmdOrCtrl+O"),
    await item(appStrings.menu.item.save, "save", "CmdOrCtrl+S"),
    await item(appStrings.menu.item.saveAs, "saveAs", "CmdOrCtrl+Shift+S"),
    { item: "Separator" as const },
    await item(appStrings.menu.item.exportPDF, "exportPDF"),
    ...directPrintItems,
  ];
  const editItems = [
    await item(appStrings.menu.item.undo, "undo", "CmdOrCtrl+Z"),
    await item(appStrings.menu.item.redo, "redo", "CmdOrCtrl+Shift+Z"),
    await item(appStrings.menu.item.cut, "cut", "CmdOrCtrl+X"),
    await item(appStrings.menu.item.copy, "copy", "CmdOrCtrl+C"),
    await item(appStrings.menu.item.paste, "paste", "CmdOrCtrl+V"),
    await item(appStrings.menu.item.duplicate, "duplicate", "CmdOrCtrl+D"),
    await item(appStrings.menu.item.delete, "delete"),
    await item(appStrings.menu.item.selectAll, "selectAll", "CmdOrCtrl+A"),
    { item: "Separator" as const },
    await item(appStrings.menu.item.cancelCurrentInteraction, "cancelCurrentInteraction", "Escape"),
    await item(appStrings.menu.item.findInspector, "findInspector", "CmdOrCtrl+F"),
  ];
  const drawingItems = [
    await item(appStrings.toolNames.select, "select", "CmdOrCtrl+1"),
    await item(appStrings.toolNames.point, "point", "CmdOrCtrl+2"),
    await item(appStrings.toolNames.line, "line", "CmdOrCtrl+3"),
    await item(appStrings.toolNames.circle, "circle", "CmdOrCtrl+4"),
    await item(appStrings.toolNames.roundHole, "roundHole"),
    await item(appStrings.toolNames.arc, "arc"),
    await item(appStrings.toolNames.stitchStartPoint, "stitchStartPoint"),
    await item(appStrings.toolNames.freeText, "freeText"),
    { item: "Separator" as const },
    await item(appStrings.toolNames.centerLine, "centerLine", "CmdOrCtrl+5"),
    await item(appStrings.toolNames.horizontalCenterLine, "horizontalCenterLine"),
    await item(appStrings.toolNames.verticalCenterLine, "verticalCenterLine"),
    { item: "Separator" as const },
    await item(appStrings.toolNames.offset, "offset"),
    await item(appStrings.toolNames.fillet, "fillet"),
  ];
  const constraintItems = [
    await item(appStrings.toolNames.coincident, "coincident"),
    await item(appStrings.toolNames.horizontal, "horizontal", "CmdOrCtrl+Shift+H"),
    await item(appStrings.toolNames.vertical, "vertical", "CmdOrCtrl+Shift+V"),
    await item(appStrings.toolNames.parallel, "parallel"),
    await item(appStrings.toolNames.perpendicular, "perpendicular"),
    await item(appStrings.toolNames.tangent, "tangent"),
    await item(appStrings.toolNames.equalLength, "equalLength"),
    await item(appStrings.toolNames.angle, "angle"),
    await item(appStrings.toolNames.symmetric, "symmetric"),
    await item(appStrings.toolNames.pointOnLine, "pointOnLine"),
    await item(appStrings.toolNames.fixed, "fixed"),
    { item: "Separator" as const },
    await item(appStrings.menu.item.smoothArcTangencies, "smoothArcTangencies"),
  ];
  const measurementItems = [
    await item(appStrings.toolNames.distance, "distance"),
    await item(appStrings.toolNames.horizontalDistance, "horizontalDistance"),
    await item(appStrings.toolNames.verticalDistance, "verticalDistance"),
    await item(appStrings.toolNames.lineLineDistance, "lineLineDistance"),
    await item(appStrings.toolNames.segmentLength, "segmentLength"),
    await item(appStrings.toolNames.diameter, "diameter"),
    await item(appStrings.toolNames.radius, "radius"),
    { item: "Separator" as const },
    await item(appStrings.toolNames.measureDistance, "measureDistance"),
    await item(appStrings.menu.item.measureSegmentLength, "measureSegmentLength"),
    await item(appStrings.toolNames.measureAngle, "measureAngle"),
    await item(appStrings.toolNames.measureRadius, "measureRadius"),
    await item(appStrings.toolNames.measureDiameter, "measureDiameter"),
    await item(appStrings.toolNames.measureArcSweepAngle, "measureArcSweepAngle"),
  ];
  const viewItems = [
    await item(appStrings.canvas.editDisplay, "editDisplay", "CmdOrCtrl+Alt+1"),
    await item(appStrings.canvas.outputPreview, "outputPreview", "CmdOrCtrl+Alt+2"),
    await item(appStrings.menu.item.toggleA4Orientation, "toggleA4Orientation"),
    await item(appStrings.toolbar.zoomToFit, "zoomToFit"),
    await item(appStrings.menu.item.toggleInspector, "toggleInspector"),
    await item(appStrings.menu.item.toggleBottomWorkbench, "toggleBottomWorkbench"),
    { item: "Separator" as const },
    await item(appStrings.menu.item.resetLayout, "resetLayout"),
    await item(appStrings.menu.item.reload, "reload", "CmdOrCtrl+R"),
  ];
  const menu = await Menu.new({
    items: [
      applicationMenu,
      {
        text: appStrings.menu.section.file,
        items: fileItems,
      },
      {
        text: appStrings.menu.section.edit,
        items: editItems,
      },
      {
        text: appStrings.menu.section.drawing,
        items: drawingItems,
      },
      {
        text: appStrings.menu.section.constraint,
        items: constraintItems,
      },
      {
        text: appStrings.menu.section.measurement,
        items: measurementItems,
      },
      {
        text: appStrings.menu.section.layer,
        items: [await item(appStrings.app.addLayerTitle, "addLayer", "CmdOrCtrl+Shift+L")],
      },
      {
        text: appStrings.menu.section.view,
        items: viewItems,
      },
    ],
  });
  await menu.setAsAppMenu();
  menuStateApplyRequested = true;
  if (!menuStateApplyInProgress) await flushNativeMenuState();
}
