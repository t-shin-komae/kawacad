import { useRef } from "react";
import { appStrings } from "@/localization";

type Props = {
  value: number;
  min: number;
  max: number;
  onChange: (value: number) => void;
};

const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

/** Matches the SwiftUI sidebar's 8pt drag and keyboard resize affordance. */
export function PaletteResizeHandle({ value, min, max, onChange }: Props) {
  const drag = useRef<{ pointerId: number; startX: number; startValue: number }>();
  const updateFromPointer = (clientX: number) => {
    const current = drag.current;
    if (current) onChange(clamp(current.startValue + clientX - current.startX, min, max));
  };
  return (
    <div
      className="palette-resize-handle"
      role="separator"
      aria-label={appStrings.resize.paletteWidth}
      aria-orientation="vertical"
      aria-valuemin={min}
      aria-valuemax={max}
      aria-valuenow={value}
      aria-valuetext={`${Math.round(value)} pt`}
      tabIndex={0}
      onPointerDown={(event) => {
        drag.current = { pointerId: event.pointerId, startX: event.clientX, startValue: value };
        event.currentTarget.setPointerCapture(event.pointerId);
        event.preventDefault();
      }}
      onPointerMove={(event) => updateFromPointer(event.clientX)}
      onPointerUp={(event) => {
        updateFromPointer(event.clientX);
        drag.current = undefined;
      }}
      onLostPointerCapture={() => {
        drag.current = undefined;
      }}
      onKeyDown={(event) => {
        if (event.key === "ArrowLeft") {
          event.preventDefault();
          onChange(clamp(value - 8, min, max));
        } else if (event.key === "ArrowRight") {
          event.preventDefault();
          onChange(clamp(value + 8, min, max));
        } else if (event.key === "Home") {
          event.preventDefault();
          onChange(min);
        } else if (event.key === "End") {
          event.preventDefault();
          onChange(max);
        }
      }}
    />
  );
}
