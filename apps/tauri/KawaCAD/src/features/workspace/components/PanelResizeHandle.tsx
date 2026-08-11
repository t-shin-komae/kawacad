import { useRef } from "react";

type Props = {
  value: number;
  min: number;
  max: number;
  ariaLabel: string;
  onChange: (value: number) => void;
};

const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

/** Shared 8pt drag and keyboard resize affordance for workspace side panels. */
export function PanelResizeHandle({ value, min, max, ariaLabel, onChange }: Props) {
  const drag = useRef<{ pointerId: number; startX: number; startValue: number }>();
  const updateFromPointer = (clientX: number) => {
    const current = drag.current;
    if (current) onChange(clamp(current.startValue + clientX - current.startX, min, max));
  };
  return (
    <div
      className="palette-resize-handle"
      role="separator"
      aria-label={ariaLabel}
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
