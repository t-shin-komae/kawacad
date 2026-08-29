import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { aggregateConstraintStatus } from "@/features/canvas/components/CadToolbar";
import { CADToolbar } from "@/features/canvas/components/CadToolbar";
import { accessibilityIdentifiers } from "@/shared/accessibility/accessibilityIdentifiers";
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
  afterEach(cleanup);

  it("uses the tool palette button to hide and show the dock", () => {
    const onToggleTools = vi.fn();
    const { rerender } = render(<CADToolbar {...toolbarProps} onToggleTools={onToggleTools} toolPaletteVisible />);

    const toolPaletteButton = screen.getByRole("button", { name: appStrings.accessibility.hideTools });
    expect(toolPaletteButton).toBeInTheDocument();
    fireEvent.click(toolPaletteButton);
    expect(onToggleTools).toHaveBeenCalledOnce();
    expect(toolPaletteButton.nextElementSibling).toHaveClass("toolbar-tool-palette-divider");
    expect(toolPaletteButton.nextElementSibling?.nextElementSibling).toBe(
      screen
        .getByRole("navigation", { name: appStrings.accessibility.cadToolbar })
        .querySelector(".toolbar-tool-cluster"),
    );

    rerender(<CADToolbar {...toolbarProps} onToggleTools={onToggleTools} toolPaletteVisible={false} />);
    expect(screen.getByRole("button", { name: appStrings.accessibility.showTools })).toBeInTheDocument();
  });

  it("keeps edit commands and constraint status out of the top toolbar", () => {
    render(<CADToolbar {...toolbarProps} toolPaletteVisible />);

    expect(screen.queryByText(appStrings.toolbar.copySelection)).not.toBeInTheDocument();
    expect(screen.queryByText(appStrings.toolbar.pasteSelection)).not.toBeInTheDocument();
    expect(screen.queryByText(appStrings.toolbar.duplicateSelection)).not.toBeInTheDocument();
    expect(screen.queryByTitle(appStrings.accessibility.constraintStatus)).not.toBeInTheDocument();
  });

  it("shows a non-color mark for an enabled display toggle", () => {
    const { rerender } = render(<CADToolbar {...toolbarProps} toolPaletteVisible={false} />);
    const grid = screen.getByTestId(accessibilityIdentifiers.toolbarGrid);

    expect(grid).toHaveAttribute("aria-pressed", "true");
    expect(grid.querySelector(".toolbar-toggle-state-mark")).toBeInTheDocument();

    rerender(<CADToolbar {...toolbarProps} gridVisible={false} toolPaletteVisible={false} />);
    expect(
      screen.getByTestId(accessibilityIdentifiers.toolbarGrid).querySelector(".toolbar-toggle-state-mark"),
    ).not.toBeInTheDocument();
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
