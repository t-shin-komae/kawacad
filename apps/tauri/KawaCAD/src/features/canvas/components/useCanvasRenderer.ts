import { useEffect, type RefObject } from "react";
import { drawCanvasFrame, type CanvasRenderModel } from "@/features/canvas/selectors/canvasRendering";

/** Owns canvas sizing and the immutable render-model to frame conversion. */
export function useCanvasRenderer(canvasRef: RefObject<HTMLCanvasElement | null>, renderModel: CanvasRenderModel) {
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const draw = () => {
      const rect = canvas.getBoundingClientRect();
      const pixelRatio = window.devicePixelRatio || 1;
      canvas.width = Math.max(1, Math.round(rect.width * pixelRatio));
      canvas.height = Math.max(1, Math.round(rect.height * pixelRatio));
      const context = canvas.getContext("2d");
      if (!context) return;
      context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
      context.clearRect(0, 0, rect.width, rect.height);
      drawCanvasFrame({
        ...renderModel,
        context,
        width: rect.width,
        height: rect.height,
      });
    };

    draw();
    const observer = new ResizeObserver(draw);
    observer.observe(canvas);
    return () => observer.disconnect();
  }, [canvasRef, renderModel]);
}
