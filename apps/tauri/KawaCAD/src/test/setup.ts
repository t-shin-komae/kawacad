import "@testing-library/jest-dom/vitest";

class ResizeObserverMock {
  observe() {}
  disconnect() {}
  unobserve() {}
}

Object.defineProperty(globalThis, "ResizeObserver", { value: ResizeObserverMock });
Object.defineProperty(window, "innerWidth", { configurable: true, writable: true, value: 1600 });
const storage = new Map<string, string>();
Object.defineProperty(window, "localStorage", {
  value: {
    getItem: (key: string) => storage.get(key) ?? null,
    setItem: (key: string, value: string) => storage.set(key, value),
    removeItem: (key: string) => storage.delete(key),
    clear: () => storage.clear(),
  },
});
Object.defineProperty(HTMLCanvasElement.prototype, "getContext", {
  value: () => ({
    setTransform() {},
    clearRect() {},
    save() {},
    restore() {},
    beginPath() {},
    rect() {},
    roundRect() {},
    moveTo() {},
    lineTo() {},
    stroke() {},
    fill() {},
    fillRect() {},
    arc() {},
    strokeRect() {},
    setLineDash() {},
    fillText() {},
    measureText: (text: string) => ({ width: text.length * 10 }),
  }),
});
Object.defineProperties(HTMLElement.prototype, {
  setPointerCapture: { value: () => {} },
  releasePointerCapture: { value: () => {} },
  hasPointerCapture: { value: () => false },
});
