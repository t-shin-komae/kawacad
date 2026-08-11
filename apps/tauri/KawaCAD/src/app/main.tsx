import React from "react";
import ReactDOM from "react-dom/client";
import { MainWindowView } from "@/app/MainWindowView";
import { installNativeMenu } from "@/adapters/nativeMenuAdapter";
import "@/app/styles.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <MainWindowView />
  </React.StrictMode>,
);

void installNativeMenu().catch((error) => {
  console.info("Native menu is available in the Tauri app only", error);
});
