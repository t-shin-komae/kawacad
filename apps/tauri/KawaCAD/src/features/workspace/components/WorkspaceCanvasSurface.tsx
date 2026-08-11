import type { ComponentProps } from "react";
import { CADCanvas } from "@/features/canvas/components/CadCanvas";
import { CanvasContextMenu } from "@/features/canvas/components/CanvasContextMenu";
import { PasteOptionsOverlay } from "@/features/document/components/PasteOptionsOverlay";

export type WorkspaceCanvasSurfaceProps = {
  canvas: ComponentProps<typeof CADCanvas>;
  hudText: string;
  pasteOptions?: ComponentProps<typeof PasteOptionsOverlay>;
  contextMenu?: ComponentProps<typeof CanvasContextMenu>;
};

/** Canvas rendering and its transient overlays, independent from workspace chrome. */
export function WorkspaceCanvasSurface({ canvas, hudText, pasteOptions, contextMenu }: WorkspaceCanvasSurfaceProps) {
  return (
    <section className="canvas-area">
      <CADCanvas {...canvas} />
      <div className="canvas-hud" aria-hidden="true">
        {hudText}
      </div>
      {pasteOptions && <PasteOptionsOverlay {...pasteOptions} />}
      {contextMenu && <CanvasContextMenu {...contextMenu} />}
    </section>
  );
}
