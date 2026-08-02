import { invoke } from "@tauri-apps/api/core";

/** The only React-side boundary allowed to talk to Tauri commands. */
export async function invokeCommand<T>(command: string, args?: Record<string, unknown>): Promise<T> {
  return args === undefined ? invoke<T>(command) : invoke<T>(command, args);
}
