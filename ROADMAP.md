# Future directions

Concrete tasks and their status belong in
[GitHub issues](https://github.com/ejgallego/verso-run/issues). This roadmap records
possible directions. Current usage, architecture and qualification are described
in [authoring](docs/authoring.md), [internals](docs/internals.md) and
[validation](docs/validation.md).

## Diagnostics

Improve dependency-closure diagnostics when an admitted callable reaches an
unavailable runtime operation. Preserve VIR's original classifier reason,
declaration/type context and actionable wrapper guidance. Keep author errors,
reader input errors and resource/worker failures distinct.

## Build performance and upstream boundaries

Measure cold/warm builds and author iteration before selecting native
precompilation or changing compiler scheduling. Retain
`compiler.postponeCompile false` until a separate review and qualification.

Review an upstream split of Verso's Html data/serialization from its quoter, and
VIR's runtime host types from host-attribute validation. The current view/client
libraries retain the pinned upstream imports. Review upstreaming Verso's public
highlighting helper and shared command-elaboration hooks separately.

Dependency updates require a matched public source/runtime pair and consumer
qualification, preserving independent contracts, exact integers, independent
workers, explicit retry and real Stop.

## Browser and accessibility qualification

Qualify Firefox, Safari, physical mobile devices, assistive technologies and real
back-cache restoration. Wider Illuminate rendering needs the provider work
recorded in [its evidence](evidence/illuminate-gates.md).

## Interaction models

Explore finite on-demand computation with explicit successful completion. Its
lifetime differs from an endless automaton and a precomputed trace. Consider
mixed scalar input/result forms and retaining idle scalar workers across edits
as separate API choices. Reuse Illuminate animation APIs where they fit after
qualifying their required runtime path.

## Source editing

Reader editing of Lean source and the broader `verso-lab` project need their own
compiler, interaction and lifecycle design.
