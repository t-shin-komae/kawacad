import { Menu, PredefinedMenuItem, Submenu } from "@tauri-apps/api/menu";
import type { AboutMetadata } from "@tauri-apps/api/menu";
import { productInfo } from "@/app/productInfo";
import { invokeCommand } from "@/adapters/tauriCommandAdapter";
import { appStrings } from "@/localization";
import type { MenuAction } from "@/app/domain/nativeMenuTypes";

export type { MenuAction } from "@/app/domain/nativeMenuTypes";

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
  const item = (text: string, action: MenuAction, accelerator?: string) => ({
    text,
    accelerator,
    action: () => dispatch(action),
  });
  const aboutItem = await PredefinedMenuItem.new({
    text: appStrings.menu.item.about,
    item: { About: aboutMetadataForPlatform(navigator.userAgent) },
  });
  const directPrintAvailable = await invokeCommand<{ status: string }>("direct_print_availability")
    .then((availability) => availability.status === "available")
    .catch(() => false);
  const directPrintItems = directPrintAvailable ? [item(appStrings.menu.item.directPrint, "directPrint")] : [];
  const applicationMenu = await Submenu.new({
    text: productInfo.name,
    items: [aboutItem, item(appStrings.menu.item.openSourceLicenses, "openLicenses")],
  });
  const menu = await Menu.new({
    items: [
      applicationMenu,
      {
        text: appStrings.menu.section.file,
        items: [
          item(appStrings.menu.item.new, "new", "CmdOrCtrl+N"),
          item(appStrings.menu.item.open, "open", "CmdOrCtrl+O"),
          item(appStrings.menu.item.save, "save", "CmdOrCtrl+S"),
          item(appStrings.menu.item.saveAs, "saveAs", "CmdOrCtrl+Shift+S"),
          { item: "Separator" },
          item(appStrings.menu.item.exportPDF, "exportPDF"),
          ...directPrintItems,
        ],
      },
      {
        text: appStrings.menu.section.edit,
        items: [
          item(appStrings.menu.item.undo, "undo", "CmdOrCtrl+Z"),
          item(appStrings.menu.item.redo, "redo", "CmdOrCtrl+Shift+Z"),
          item(appStrings.menu.item.cut, "cut", "CmdOrCtrl+X"),
          item(appStrings.menu.item.copy, "copy", "CmdOrCtrl+C"),
          item(appStrings.menu.item.paste, "paste", "CmdOrCtrl+V"),
          item(appStrings.menu.item.duplicate, "duplicate", "CmdOrCtrl+D"),
          item(appStrings.menu.item.delete, "delete"),
          item(appStrings.menu.item.selectAll, "selectAll", "CmdOrCtrl+A"),
          item(appStrings.menu.item.findInspector, "findInspector", "CmdOrCtrl+F"),
        ],
      },
      {
        text: appStrings.menu.section.drawing,
        items: [
          item(appStrings.toolNames.select, "select", "CmdOrCtrl+1"),
          item(appStrings.toolNames.point, "point", "CmdOrCtrl+2"),
          item(appStrings.toolNames.line, "line", "CmdOrCtrl+3"),
          item(appStrings.toolNames.circle, "circle", "CmdOrCtrl+4"),
          item(appStrings.toolNames.roundHole, "roundHole"),
          item(appStrings.toolNames.arc, "arc"),
          item(appStrings.toolNames.stitchStartPoint, "stitchStartPoint"),
          item(appStrings.toolNames.freeText, "freeText"),
          { item: "Separator" },
          item(appStrings.toolNames.centerLine, "centerLine", "CmdOrCtrl+5"),
          item(appStrings.toolNames.horizontalCenterLine, "horizontalCenterLine"),
          item(appStrings.toolNames.verticalCenterLine, "verticalCenterLine"),
          { item: "Separator" },
          item(appStrings.toolNames.offset, "offset"),
          item(appStrings.toolNames.fillet, "fillet"),
        ],
      },
      {
        text: appStrings.menu.section.constraint,
        items: [
          item(appStrings.toolNames.coincident, "coincident"),
          item(appStrings.toolNames.horizontal, "horizontal", "CmdOrCtrl+Shift+H"),
          item(appStrings.toolNames.vertical, "vertical", "CmdOrCtrl+Shift+V"),
          item(appStrings.toolNames.parallel, "parallel"),
          item(appStrings.toolNames.perpendicular, "perpendicular"),
          item(appStrings.toolNames.tangent, "tangent"),
          item(appStrings.toolNames.equalLength, "equalLength"),
          item(appStrings.toolNames.angle, "angle"),
          item(appStrings.toolNames.symmetric, "symmetric"),
          item(appStrings.toolNames.pointOnLine, "pointOnLine"),
          item(appStrings.toolNames.fixed, "fixed"),
          { item: "Separator" },
          item(appStrings.menu.item.smoothArcTangencies, "smoothArcTangencies"),
          { item: "Separator" },
          item(appStrings.toolNames.distance, "distance"),
          item(appStrings.toolNames.horizontalDistance, "horizontalDistance"),
          item(appStrings.toolNames.verticalDistance, "verticalDistance"),
          item(appStrings.toolNames.lineLineDistance, "lineLineDistance"),
          item(appStrings.toolNames.segmentLength, "segmentLength"),
          item(appStrings.toolNames.diameter, "diameter"),
          item(appStrings.toolNames.radius, "radius"),
        ],
      },
      {
        text: appStrings.menu.section.measurement,
        items: [
          item(appStrings.toolNames.measureDistance, "measureDistance"),
          item(appStrings.menu.item.measureSegmentLength, "measureSegmentLength"),
          item(appStrings.toolNames.measureAngle, "measureAngle"),
          item(appStrings.toolNames.measureRadius, "measureRadius"),
          item(appStrings.toolNames.measureDiameter, "measureDiameter"),
          item(appStrings.toolNames.measureArcSweepAngle, "measureArcSweepAngle"),
        ],
      },
      {
        text: appStrings.menu.section.layer,
        items: [item(appStrings.app.addLayerTitle, "addLayer", "CmdOrCtrl+Shift+L")],
      },
      {
        text: appStrings.menu.section.view,
        items: [
          item(appStrings.canvas.editDisplay, "editDisplay", "CmdOrCtrl+Alt+1"),
          item(appStrings.canvas.outputPreview, "outputPreview", "CmdOrCtrl+Alt+2"),
          item(appStrings.menu.item.toggleA4Orientation, "toggleA4Orientation"),
          item(appStrings.toolbar.zoomToFit, "zoomToFit"),
          item(appStrings.menu.item.toggleInspector, "toggleInspector"),
          item(appStrings.menu.item.toggleBottomWorkbench, "toggleBottomWorkbench"),
          { item: "Separator" },
          item(appStrings.menu.item.resetLayout, "resetLayout"),
          item(appStrings.menu.item.reload, "reload", "CmdOrCtrl+R"),
        ],
      },
    ],
  });
  await menu.setAsAppMenu();
}
