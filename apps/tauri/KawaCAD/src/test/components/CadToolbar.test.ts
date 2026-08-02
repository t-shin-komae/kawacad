import { describe, expect, it } from "vitest";
import { aggregateConstraintStatus } from "@/features/canvas/components/CadToolbar";

describe("CAD toolbar constraint-status parity", () => {
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
