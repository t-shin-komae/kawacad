import React from "react";
import ReactDOM from "react-dom/client";
import { MainWindowView } from "@/app/MainWindowView";
import { ComparisonFixture, type ComparisonFixtureName } from "@/app/ComparisonFixture";
import { installNativeMenu } from "@/adapters/nativeMenuAdapter";
import "@/app/styles.css";

const comparisonFixture = import.meta.env.DEV
  ? (new URLSearchParams(window.location.search).get("comparison-fixture") as ComparisonFixtureName | null)
  : null;

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    {import.meta.env.DEV && comparisonFixture ? <ComparisonFixture name={comparisonFixture} /> : <MainWindowView />}
  </React.StrictMode>,
);

if (!comparisonFixture) {
  void installNativeMenu().catch((error) => {
    console.info("Native menu is available in the Tauri app only", error);
  });
}
