import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { aggregateConstraintStatus } from "@/features/canvas/components/CadToolbar";
import { CADToolbar } from "@/features/canvas/components/CadToolbar";
import { appStrings } from "@/localization";

const toolbarProps = {
  tool: "line" as const,
  layers: [{ id: "layer:default", name: "レイヤー1" }],
  activeLayer: "layer:default",
  viewMode: "editDisplay" as const,
  zoomPercent: 100,
  gridVisible: true,
  a4Visible: true,
  a4Landscape: false,
  snapEnabled: true,
  pointSnapEnabled: true,
  onLayerChange: () => {},
  onViewModeChange: () => {},
  onViewportChange: () => {},
  onGridChange: () => {},
  onA4Change: () => {},
  onA4LandscapeChange: () => {},
  onSnapChange: () => {},
  onPointSnapChange: () => {},
  onToggleInspector: () => {},
  onToggleTools: () => {},
};

describe("CAD toolbar parity", () => {
  it("shows the tool palette button only in compact layout", () => {
    const { rerender } = render(<CADToolbar {...toolbarProps} showToolPaletteButton={false} />);

    expect(screen.queryByRole("button", { name: appStrings.accessibility.showTools })).not.toBeInTheDocument();

    rerender(<CADToolbar {...toolbarProps} showToolPaletteButton />);

    const toolPaletteButton = screen.getByRole("button", { name: appStrings.accessibility.showTools });
    expect(toolPaletteButton).toBeInTheDocument();
    expect(toolPaletteButton.nextElementSibling).toHaveClass("toolbar-tool-palette-divider");
    expect(toolPaletteButton.nextElementSibling?.nextElementSibling).toBe(
      screen
        .getByRole("navigation", { name: appStrings.accessibility.cadToolbar })
        .querySelector(".toolbar-tool-cluster"),
    );
  });

  it("keeps edit commands and constraint status out of the top toolbar", () => {
    render(<CADToolbar {...toolbarProps} showToolPaletteButton={false} />);

    expect(screen.queryByText(appStrings.toolbar.copySelection)).not.toBeInTheDocument();
    expect(screen.queryByText(appStrings.toolbar.pasteSelection)).not.toBeInTheDocument();
    expect(screen.queryByText(appStrings.toolbar.duplicateSelection)).not.toBeInTheDocument();
    expect(screen.queryByTitle(appStrings.accessibility.constraintStatus)).not.toBeInTheDocument();
  });

  it("uses the SwiftUI status priority when multiple Core constraints are present", () => {
    expect(aggregateConstraintStatus([])).toBe("unknown");
    expect(aggregateConstraintStatus(["underConstrained", "fullyConstrained"])).toBe("underConstrained");
    expect(aggregateConstraintStatus(["fullyConstrained", "fullyConstrained"])).toBe("fullyConstrained");
    expect(aggregateConstraintStatus(["underConstrained", "overConstrained"])).toBe("overConstrained");
    expect(aggregateConstraintStatus(["overConstrained", "conflicting"])).toBe("conflicting");
  });

  it("accepts the Core aggregated snapshot status as a single-status input", () => {
    expect(aggregateConstraintStatus(["fullyConstrained"])).toBe("fullyConstrained");
    expect(aggregateConstraintStatus(["overConstrained"])).toBe("overConstrained");
  });
});
