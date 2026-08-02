import { invokeCommand } from "@/adapters/tauriCommandAdapter";
import { getCurrentWindow } from "@tauri-apps/api/window";

export const desktopAdapter = {
  exit: () => invokeCommand<void>("exit_application"),
  async exitApplication() {
    try {
      await invokeCommand<void>("exit_application");
    } catch {
      await getCurrentWindow().destroy();
    }
  },
};
