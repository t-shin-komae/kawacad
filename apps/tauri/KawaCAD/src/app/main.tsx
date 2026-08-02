import React from "react";
import ReactDOM from "react-dom/client";
import { App } from "@/app/App";
import { installNativeMenu } from "@/adapters/nativeMenuAdapter";
import "@/app/styles.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);

void installNativeMenu().catch((error) => {
  console.info("Native menu is available in the Tauri app only", error);
});
