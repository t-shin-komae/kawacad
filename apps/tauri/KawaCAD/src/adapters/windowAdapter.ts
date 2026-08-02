import { getCurrentWindow } from "@tauri-apps/api/window";

export const windowAdapter = {
  setTitle(title: string) {
    return getCurrentWindow().setTitle(title);
  },
  onCloseRequested(handler: (event: { preventDefault: () => void }) => void | Promise<void>) {
    return getCurrentWindow().onCloseRequested(handler);
  },
  destroy() {
    return getCurrentWindow().destroy();
  },
};
