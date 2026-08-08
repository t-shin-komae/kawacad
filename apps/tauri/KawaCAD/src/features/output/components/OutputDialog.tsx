import { useEffect, useState } from "react";
import { documentAdapter } from "@/adapters/documentAdapter";
import {
  PDFExportDialog,
  type Orientation,
  type OutputOptions,
} from "@/features/output/components/PDFExportDialog";
import { DirectPrintDialog } from "@/features/output/components/DirectPrintDialog";

type Destination = "pdf" | "directPrint";

type Props = {
  documentName: string;
  initialOrientation: Orientation;
  initialDestination: Destination;
  onClose: () => void;
  onSaved: (path: string) => void;
  onPrinted: () => void;
};

function initialOptions(orientation: Orientation): OutputOptions {
  return { orientation, includeDimensionLabels: true, includeScaleGuide: true, rotationDeg: 0 };
}

/** A single output sheet owns options while switching between PDF and direct printing. */
export function OutputDialog({
  documentName,
  initialOrientation,
  initialDestination,
  onClose,
  onSaved,
  onPrinted,
}: Props) {
  const [destination, setDestination] = useState<Destination>(initialDestination);
  const [options, setOptions] = useState(() => initialOptions(initialOrientation));
  const [directPrintAvailable, setDirectPrintAvailable] = useState(false);

  useEffect(() => {
    void documentAdapter
      .command<{ status: string }>("direct_print_availability")
      .then((availability) => setDirectPrintAvailable(availability.status === "available"))
      .catch(() => setDirectPrintAvailable(false));
  }, []);

  if (destination === "directPrint" && directPrintAvailable) {
    return (
      <DirectPrintDialog
        initialOrientation={initialOrientation}
        options={options}
        onOptionsChange={setOptions}
        onDestinationChange={setDestination}
        onClose={onClose}
        onPrinted={onPrinted}
      />
    );
  }
  return (
    <PDFExportDialog
      documentName={documentName}
      initialOrientation={initialOrientation}
      options={options}
      onOptionsChange={setOptions}
      onDestinationChange={setDestination}
      directPrintAvailable={directPrintAvailable}
      onClose={onClose}
      onSaved={onSaved}
    />
  );
}
