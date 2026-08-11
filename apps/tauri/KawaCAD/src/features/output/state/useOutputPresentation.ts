import { useState } from "react";

export type OutputDestination = "pdf" | "directPrint";

/** Owns the output sheet destination while the document remains unchanged. */
export function useOutputPresentation() {
  const [outputDestination, setOutputDestination] = useState<OutputDestination>();
  return { outputDestination, setOutputDestination };
}
