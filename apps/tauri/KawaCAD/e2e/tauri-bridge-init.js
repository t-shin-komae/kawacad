// This file is installed before the React bundle. Playwright exposes the
// Node-side implementation as window.__leatherE2EInvoke; keeping the Tauri
// shape here makes the browser run exercise the same adapter imports as the
// desktop bundle.
window.__TAURI_EVENT_PLUGIN_INTERNALS__ = {
  unregisterListener() {},
};

window.__TAURI_INTERNALS__ = {
  metadata: { currentWindow: { label: "main" } },
  transformCallback() {
    return 1;
  },
  unregisterCallback() {},
  convertFileSrc(path) {
    return path;
  },
  invoke(command, args) {
    if (typeof window.__leatherE2EInvoke !== "function") {
      return Promise.reject(new Error("E2E Tauri bridge is not installed"));
    }
    return window.__leatherE2EInvoke(command, args ?? {});
  },
};
