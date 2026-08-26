import { useState } from "react";

export type HelpSection = "overview" | "tools" | "canvas";

export function useHelpPresentation() {
  const [helpSection, setHelpSection] = useState<HelpSection>();
  return { helpSection, setHelpSection };
}
