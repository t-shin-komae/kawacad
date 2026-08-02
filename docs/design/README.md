# Design documents

`docs/design/` contains durable design context: ownership, boundaries, major flows, and the invariants that guide implementation. It is not a task ledger or a test-results archive.

## Start here

| Question | Document |
| --- | --- |
| What owns the system state and major flows? | [`architecture.md`](architecture.md) |
| What crosses the UI/Core boundary? | [`internal-interface-spec.md`](internal-interface-spec.md) |
| How are CAD state and edits organized? | [`cad-foundation/overview.md`](cad-foundation/overview.md) |
| How are constraints and degrees of freedom evaluated? | [`constraints/dof-algorithm.md`](constraints/dof-algorithm.md) |
| How are derived elements represented? | [`derived-elements/offset-curves.md`](derived-elements/offset-curves.md), [`derived-elements/fillet.md`](derived-elements/fillet.md) |
| How are pattern elements and parts represented? | [`pattern-elements/representation.md`](pattern-elements/representation.md), [`parts/overview.md`](parts/overview.md) |
| How does output flow through the engine? | [`output/overview.md`](output/overview.md), [`output/document-model.md`](output/document-model.md), [`a4-tile-output/overview.md`](a4-tile-output/overview.md) |
| How is UI responsibility separated? | [`ui-architecture/overview.md`](ui-architecture/overview.md) |
| How are selection and annotations designed? | [`interaction/selection-targets.md`](interaction/selection-targets.md), [`annotations/measurement-annotations.md`](annotations/measurement-annotations.md) |

The external contracts remain in [`../spec/`](../spec/). The `.lcraft` shape and interface wire shape remain in `schemas/` and are not duplicated here.
