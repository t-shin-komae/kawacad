import { useState } from "react";

/** Owns the transient presentation state for the licenses dialog. */
export function useLicensesPresentation() {
  const [licensesOpen, setLicensesOpen] = useState(false);
  return { licensesOpen, setLicensesOpen };
}
